import 'package:dio/dio.dart';
import 'api_endpoint_manager.dart';
import 'host_health.dart';

/// FailoverInterceptor —— 请求驱动的 hedge:
/// - 连接层错误(所有 method): 切下一个 host
/// - 5xx(GET/HEAD/POST 均切): 切下一个 host
/// - badCertificate: 切下一个 host
/// - 基础设施 4xx(CDN 兜底 HTML): 切下一个 host
/// - 业务 4xx: 不切,透传给业务处理
///
/// 每次尝试记 host health;连续失败达阈值 30s 内禁用该 host。
class FailoverInterceptor extends Interceptor {
  final ApiEndpointManager endpointManager;
  final Dio dio;
  final HostHealthRegistry registry = HostHealthRegistry.instance;

  FailoverInterceptor({required this.endpointManager, required this.dio});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_startTs'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final host = Uri.parse(response.requestOptions.uri.toString()).host;
    final start = response.requestOptions.extra['_startTs'] as int?;
    if (isInfrastructure4xx(response)) {
      registry.get(host).onFailure();
      // 转成 DioException,让 onError 走 failover 分支
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'infrastructure 4xx: ${response.statusCode}',
      ));
      return;
    }
    // 成功: 记 RTT
    if (start != null) {
      final rtt = DateTime.now().millisecondsSinceEpoch - start;
      registry.get(host).onSuccess(rtt);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final host = Uri.parse(err.requestOptions.uri.toString()).host;
    final tried = (err.requestOptions.extra['_triedHosts'] as List?)?.cast<String>() ?? <String>[];
    // 判定是否应该 failover
    if (_shouldFailover(err)) {
      registry.get(host).onFailure();
      // 选下一个 host
      final nextHost = endpointManager.pickNext(exclude: [...tried, host]);
      if (nextHost != null) {
        try {
          final newUri = err.requestOptions.uri.replace(host: nextHost);
          final newOptions = err.requestOptions.copyWith(path: newUri.toString());
          newOptions.extra['_triedHosts'] = [...tried, host];
          newOptions.extra['_startTs'] = DateTime.now().millisecondsSinceEpoch;
          final resp = await dio.fetch(newOptions);
          endpointManager.promoteToSticky(nextHost);
          return handler.resolve(resp);
        } catch (e) {
          // 下一个也挂,让最终 handler 决定
        }
      }
    }
    handler.next(err);
  }

  bool _shouldFailover(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        // 5xx 一律切;4xx 视 body 类型:HTML 切,JSON 业务错不切
        if (code >= 500) return true;
        if (err.response != null && isInfrastructure4xx(err.response!)) return true;
        return false;
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
