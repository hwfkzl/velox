import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
// import 'package:dio/io.dart';  // 仅 _setupDebugProxy 用，调试时一起取消注释
import 'package:logger/logger.dart';

import '../services/app_logger.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../services/user_agent_service.dart';
import '../storage/secure_storage.dart';
import '../storage/storage_keys.dart';
import '../utils/error_message_mapper.dart';
import 'api_endpoint_manager.dart';
import 'failover_interceptor.dart';
import 'host_health.dart';

/// API 客户端
class ApiClient {
  late final Dio _dio;
  final SecureStorageService _secureStorage;
  final Logger _logger = appLogger(tag: 'ApiClient');

  ApiClient({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage {
    _dio = Dio(_baseOptions);
    _bypassSystemProxy();
    _setupInterceptors();
    // _setupDebugProxy();  // 抓包调试时取消注释。release 构建保持注释。
  }

  /// 桌面端关键防御:让 Velox 的 API 请求**不读 macOS/Windows/Linux 系统代理**。
  ///
  /// 为什么必须这样做:
  ///   1. **新用户开箱即用**:不能要求用户先装 v2rayN/Clash 才能用 Velox(否则商业版死路)
  ///   2. **系统代理污染防御**:用户机器上随便一个代理工具退出没清,死端口残留就让
  ///      Velox 启动失败(127.0.0.1:<死端口> Connection refused)
  ///   3. **避免借力依赖**:用户付了 Velox 钱却被借去用 v2rayN 出去,产品逻辑荒谬
  ///
  /// 不会破坏的场景:
  ///   - v2rayN/Clash **TUN 模式**:在路由表层面接管流量,Velox DIRECT 后流量仍被
  ///     路由强制劫持,**继续走 v2rayN/Clash 出 GFW**(开发者环境无影响)
  ///   - 新用户**无任何代理**:DIRECT 直连后端域名 → 200 OK(curl 实测)
  ///   - 真被墙地区:这种情况靠 OSS 多 API endpoint 备份(L2 防御),非代码可救
  ///
  /// 不会影响用户的其他代理工具——v2rayN 仍在系统代理里,**浏览器/Telegram 等
  /// 继续走系统代理 → v2rayN**,只有 Velox 自己绕开。
  void _bypassSystemProxy() {
    // 桌面 + Android 都防(Android 上用户装 Drony/ProxyDroid 等
    // 会改 Dart HttpClient 默认读的 http_proxy 系统属性,导致 Velox 流量被借走)。
    // iOS 走系统 URLSession,尊重用户在 Wi-Fi 设置里手动配的代理,不强干预。
    if (Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux ||
        Platform.isAndroid) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
    }
  }

  // ignore: unused_element
  /// 调试代理（仅 --dart-define=PROXY=host:port 时生效）
  /// 用法：取消上面 ApiClient 构造函数里的 _setupDebugProxy() 调用注释，
  ///       然后启动：flutter run -d macos --dart-define=PROXY=127.0.0.1:8888
  /// ⚠️ 注意：此方法会关闭 SSL 证书校验。release 构建绝不能调用。
  // void _setupDebugProxy() {
  //   const proxy = String.fromEnvironment('PROXY');
  //   if (proxy.isEmpty) return;
  //
  //   _logger.w('🛠  Using debug proxy: $proxy (all traffic routed, cert verification off)');
  //
  //   (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  //     final client = HttpClient();
  //     client.findProxy = (uri) => 'PROXY $proxy';
  //     // Charles / mitmproxy / Proxyman 用的是自签根证书，debug 模式下统一放行
  //     client.badCertificateCallback = (cert, host, port) => true;
  //     return client;
  //   };
  // }

  static String get _clientType {
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  /// 不在 BaseOptions 里设 baseUrl —— 每次请求由 [_dispatch] 拼上 ApiEndpointManager
  /// 选出的 baseUrl 后以"完整 URL"形式传给 Dio，绕过 BaseOptions 的固定 baseUrl，
  /// 这样 hedge 切换端点时无需重建 Dio 实例。
  BaseOptions get _baseOptions => BaseOptions(
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConstants.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': UserAgentService.instance.value,
        },
      );

  void _setupInterceptors() {
    // FailoverInterceptor 放在最前 —— 遇到连接层错误 / 5xx / 基础设施 4xx
    // 时用 host-level 切换重试;成功则透传给后续拦截器与 _dispatch 层。
    // 与 _dispatch 里已有的 baseUrl-级 hedge 是叠加关系:
    //   - _dispatch 只切 baseUrl(整包 URL 换),用于 GET 语义安全的场景;
    //   - FailoverInterceptor 换 host 保留 path/query,兜住 POST 幂等失败前
    //     "请求还没到服务器" 那段。
    _dio.interceptors.add(FailoverInterceptor(
      endpointManager: ApiEndpointManager.instance,
      dio: _dio,
    ));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 添加 Token
    final token = await _secureStorage.read(StorageKeys.authToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = token;
    }

    // 告知后端客户端平台类型（iOS 用于过滤 ios_enable 支付方式）
    options.headers['X-Client-Type'] = _clientType;

    // 简洁的请求日志
    _logger.d('🌐 ${options.method} ${options.path}');

    handler.next(options);
  }

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // 简洁的响应日志
    _logger.d('✅ ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final responseData = err.response?.data;

    // 检查是否是未登录/登录过期的错误（静默处理，不打印大量日志）
    final isAuthError = _isAuthenticationError(statusCode, responseData);

    if (isAuthError) {
      // 未登录或登录过期，静默处理
      _logger.d('🔐 认证失败，需要重新登录');
      // 消费级铁律(Slack/Discord/Notion 通用做法):
      // 拦截器只识别错、只 reject,永远不清 token。
      // 清 token 的唯一入口是 isLoggedIn 冷启动 verifyToken 遇 AuthException,或用户主动登出。
      // 好处: 后端偶发 blip 不误伤 token,用户下次冷启动如果 blip 恢复,直接秒进主界面无感。
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: AuthException(message: '登录已过期，请重新登录'),
        ),
      );
      return;
    }

    // 其他错误正常打印日志
    _logger.e(
      '❌ ERROR[$statusCode] => PATH: ${err.requestOptions.path}',
    );
    _logger.e('Message: ${err.message}');
    if (responseData != null) {
      _logger.e('Response Data: $responseData');
    }

    handler.next(err);
  }

  /// 检查是否是认证相关错误（未登录/登录过期）
  bool _isAuthenticationError(int? statusCode, dynamic responseData) {
    // 401 直接判定为认证错误
    if (statusCode == 401) return true;

    // 403 需要检查错误信息
    if (statusCode == 403) {
      if (responseData is Map) {
        final message = responseData['message']?.toString() ?? '';
        // 包含未登录相关信息
        if (message.contains('未登录') ||
            message.contains('登录已过期') ||
            message.contains('登陆已过期') ||
            message.contains('token') ||
            message.contains('Token')) {
          return true;
        }
      }
    }

    return false;
  }

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dispatch<T>('GET', path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dispatch<T>('POST', path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dispatch<T>('PUT', path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dispatch<T>('DELETE', path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── 多 API hedge 调度 ──────────────────────────────────────────────
  //
  // 1) 从 ApiEndpointManager 取调度序列 [当前首选, fallback1, fallback2, ...]
  // 2) 用 _sendTo 发到首选；成功 → recordSuccess → 返回。
  // 3) 失败 + _shouldHedge=true + 还有下一个 → recordFailure → 递归试下一个（hedge）。
  //    这样用户感受到的失败时延只有"首选超时" + "fallback 成功时间"，
  //    不会等"首选 3 次超时"那种 9 秒延迟。
  // 4) 全部 endpoint 都失败 → 抛最后一个错（由公开方法转 AppException）。

  Future<Response<T>> _dispatch<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final endpoints = ApiEndpointManager.instance.sequence;
    if (endpoints.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.unknown,
        error: NetworkException(message: 'API 列表为空，请检查 OSS 配置 / .env'),
      );
    }
    return _trySequential<T>(endpoints, 0, method, path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken);
  }

  Future<Response<T>> _trySequential<T>(
    List<String> endpoints,
    int idx,
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = endpoints[idx];
    try {
      final resp = await _sendTo<T>(baseUrl, method, path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      ApiEndpointManager.instance.recordSuccess(baseUrl);
      return resp;
    } on DioException catch (e) {
      final hedgeable = _shouldHedge(e, method);
      final hasNext = idx + 1 < endpoints.length;
      if (hedgeable && hasNext) {
        _logger.w(
            '🔄 hedge: $baseUrl 失败(${e.type}) → 切下一个 ${endpoints[idx + 1]}');
        ApiEndpointManager.instance.recordFailure(baseUrl);
        return _trySequential<T>(endpoints, idx + 1, method, path,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken);
      }
      // 已是最后一个 / 不可 hedge：归档失败再抛出
      if (_isNetworkError(e)) {
        ApiEndpointManager.instance.recordFailure(baseUrl);
      }
      rethrow;
    }
  }

  Future<Response<T>> _sendTo<T>(
    String baseUrl,
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    // 拼完整 URL（Dio 看到 http(s):// 前缀会忽略 baseOptions.baseUrl 直接用）。
    final fullUrl = _joinUrl(baseUrl, path);
    final mergedOptions = (options ?? Options()).copyWith(method: method);
    return _dio.request<T>(
      fullUrl,
      data: data,
      queryParameters: queryParameters,
      options: mergedOptions,
      cancelToken: cancelToken,
    );
  }

  String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  /// 这种失败值得 hedge 到下一个 API 吗？
  /// 关键约束：非幂等方法（POST/PUT/DELETE）只在"请求未到达服务器"时 hedge，
  /// 避免重发造成重复副作用（重复登录、重复支付等）。
  bool _shouldHedge(DioException e, String method) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        // 连接前/连接阶段失败 → 请求肯定没到服务器 → 任何 method 都安全 hedge
        return true;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // 请求可能已到服务器（POST 可能已被处理）→ 只 GET 安全 hedge
        return method.toUpperCase() == 'GET';
      case DioExceptionType.badResponse:
        // 5xx → 只 hedge GET；4xx 业务错不切（切了也是同结果）
        final code = e.response?.statusCode ?? 0;
        return method.toUpperCase() == 'GET' && code >= 500 && code < 600;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  bool _isNetworkError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return true;
    }
    if (e.type == DioExceptionType.badResponse) {
      final code = e.response?.statusCode ?? 0;
      return code >= 500 && code < 600;
    }
    return false;
  }

  /// 处理 Dio 错误
  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException();
      case DioExceptionType.connectionError:
        return NetworkException();
      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);
      case DioExceptionType.cancel:
        return AppException(message: '请求已取消');
      default:
        if (error.error is AppException) {
          return error.error as AppException;
        }
        return AppException(message: error.message ?? '未知错误');
    }
  }

  /// 处理响应错误
  AppException _handleResponseError(Response? response) {
    if (response == null) {
      return ServerException(message: '服务器无响应');
    }

    final data = response.data;
    final rawMessage = data is Map ? (data['message']?.toString() ?? '') : '';
    // 使用错误映射器转换为友好消息
    final friendlyMessage = rawMessage.isNotEmpty
        ? ErrorMessageMapper.map(rawMessage)
        : ErrorMessageMapper.fromStatusCode(response.statusCode);

    switch (response.statusCode) {
      case 400:
        return ValidationException(
          message: friendlyMessage,
          code: 400,
          errors: _parseErrors(data),
        );
      case 401:
        return AuthException(message: friendlyMessage, code: 401);
      case 403:
        return AuthException(message: friendlyMessage, code: 403);
      case 404:
        return ServerException(message: friendlyMessage, code: 404);
      case 422:
        return ValidationException(
          message: friendlyMessage,
          code: 422,
          errors: _parseErrors(data),
        );
      case 500:
        return ServerException(message: friendlyMessage, code: 500);
      case 502:
      case 503:
      case 504:
        return ServerException(message: '服务器暂时不可用，请稍后重试', code: response.statusCode);
      case 429:
        return ServerException(message: friendlyMessage, code: 429);
      default:
        // 基础设施 4xx(CDN/nginx 兜底页,非业务 JSON)→ 单独标注为"资源不存在"级
        // message 用 i18n errorKey,让 UI 层翻译时命中"资源不存在/临时不可达"文案
        if (isInfrastructure4xx(response)) {
          return ServerException(
            message: 'errorResourceNotFound',
            code: response.statusCode,
          );
        }
        return ServerException(
          message: friendlyMessage,
          code: response.statusCode,
        );
    }
  }

  /// 解析验证错误
  Map<String, List<String>>? _parseErrors(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors == null) return null;
    if (errors is! Map) return null;

    final result = <String, List<String>>{};
    errors.forEach((key, value) {
      if (value is List) {
        result[key.toString()] = value.map((e) => e.toString()).toList();
      } else if (value is String) {
        result[key.toString()] = [value];
      }
    });
    return result.isEmpty ? null : result;
  }
}
