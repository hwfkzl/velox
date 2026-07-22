import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'user_agent_service.dart';

import '../constants/app_constants.dart';
import '../../data/models/remote_config_model.dart';

/// OSS 远程配置服务（两层引导模型）。
///
/// 引导流程：
///   1. `.env` 里 `OSS_URL` 指向 OSS 上的 host.json：
///        `{"url": ["https://api1.example.com", "https://api2.example.com", ...]}`
///      这份数组就是 API 域名列表（轮询容灾），并被 `apiBaseUrls` getter 暴露。
///   2. 挑第一个可用的 API 域名，拉 `<url>/velox/config.json` 拿业务配置
///      （brand_name / announcement / update / faq / crisp_id / expire_notice /
///       fake_latency / …）。业务 JSON 里**不再**含 `api_base_urls`
///       （那字段已由 OSS host.json 的 url 数组接管）。
///
/// 启动时先加载缓存（host + config），网络拉取后台异步刷新。全流程失败
/// 时保留缓存，UI 无感。
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  /// 业务配置缓存 key（保留原名以兼容老装机用户升级后的既有缓存）。
  static const _cacheKey = 'remote_config_cache';

  /// OSS host.json（API 域名列表）的本地缓存 key。
  static const _hostCacheKey = 'velox_host_cache';

  static const _seenAnnouncementKey = 'seen_announcement_id';

  final _logger = appLogger(tag: 'RemoteConfig');
  RemoteConfigModel? _config;

  /// OSS host.json 拿到的 API 域名列表；`apiBaseUrls` getter 首选它。
  List<String> _apiBaseUrls = const [];

  /// 本次启动的弹窗/更新检测是否已经执行过（防止重复弹出）
  bool startupChecksRun = false;

  // ─── 公开 getter（业务配置优先，回退到 .env） ─────────────────────

  /// 多 API 列表（按优先级）。来源：OSS host.json 的 `url` 数组。
  /// 空时回退业务 config 里的 apiBaseUrls（历史缓存兼容）。
  List<String> get apiBaseUrls {
    if (_apiBaseUrls.isNotEmpty) return _apiBaseUrls;
    return _config?.apiBaseUrls ?? const [];
  }

  /// 兼容旧调用方：返回首选 API（不存在时空串）。
  /// 新代码应改用 [apiBaseUrls] 并交给 ApiEndpointManager。
  String get apiBaseUrl {
    final list = apiBaseUrls;
    return list.isEmpty ? '' : list.first;
  }

  /// API 主动探活配置（业务配置控制；默认关闭，被动失活检测永远在）。
  RemoteApiHealthCheck get apiHealthCheck =>
      _config?.apiHealthCheck ?? const RemoteApiHealthCheck();

  /// 节点延迟显示包装（业务配置控制；默认关闭，关闭时显示真实 ping）。
  RemoteFakeLatency get fakeLatency =>
      _config?.fakeLatency ?? const RemoteFakeLatency();

  String get crispId {
    final v = _config?.crispId;
    return (v != null && v.isNotEmpty)
        ? v
        : (dotenv.env['CRISP_WEBSITE_ID'] ?? '');
  }

  String get inviteBaseUrl => _config?.inviteBaseUrl ?? '';

  String get websiteUrl => _config?.websiteUrl ?? '';

  String get telegramUrl =>
      _config?.telegramUrl ?? AppConstants.telegramGroupUrl;

  bool get faqEnabled => _config?.faqEnabled ?? true;

  /// Brand name shown in the home-page top bar. Falls back to 'VELOX' so
  /// the UI never goes blank if the config hasn't loaded yet.
  String get siteName {
    final v = _config?.siteName?.trim();
    return (v == null || v.isEmpty) ? 'VELOX' : v;
  }

  /// 客户端品牌名（用于 app 名、登录页、关于、托盘菜单、splash、长文 brandize 等）。
  /// 空字符串表示远程未配置；调用方 [Brand.name] 会回退到构建时默认值。
  String get brandName => _config?.brandName?.trim() ?? '';

  /// Feature-flag the 公告 entry point on the home top bar.
  bool get showAnnouncement => _config?.showAnnouncement ?? true;

  List<RemoteFaqItem> get faq => _config?.faq ?? [];

  RemoteAnnouncementConfig? get announcement => _config?.announcement;

  RemoteExpireNotice? get expireNotice => _config?.expireNotice;

  // ─── 初始化（在 main.dart 中、initDependencies 之前调用）──────────

  Future<void> initialize() async {
    // 先加载缓存（host + config），保证 ApiClient 初始化时立即有可用配置。
    await _loadFromCache();

    // 后台异步拉取最新配置（不阻塞启动）。
    unawaited(_fetchFullFlow());
  }

  /// 主动刷新配置（app 回到前台时调用）—— fire-and-forget，不阻塞。
  Future<void> refresh() async {
    unawaited(_fetchFullFlow());
  }

  /// 强制刷新并等待完成 —— 用于"检查更新"等需要拿到服务器最新值的场景。
  /// 拉取失败（超时/网络错误）时静默回退到缓存，不抛异常。
  Future<void> refreshAndWait() async {
    await _fetchFullFlow();
  }

  // ─── 私有方法：两层引导流程 ────────────────────────────────────────

  /// 两层引导：先拉 OSS host.json 拿 API 域名列表，再对每个域名拼
  /// `/velox/config.json` 拉业务配置。任一层失败都保留缓存，不抛异常。
  Future<void> _fetchFullFlow() async {
    final ossUrls = _ossUrls();
    if (ossUrls.isEmpty) {
      _logger.w('OSS_URL / OSS_URLS 未配置，跳过配置拉取');
      return;
    }

    final dio = _buildDio();
    try {
      // 1. 拉 OSS host.json 拿 url 数组(多桶并发赛跑,首个 200 赢)
      final apiBases = await _fetchHostJson(dio, ossUrls);
      if (apiBases.isEmpty) {
        _logger.w('OSS host.json url 数组为空，配置拉取跳过');
        return;
      }
      _apiBaseUrls = apiBases;
      await _saveHostCache(apiBases);
      _logger.i('OSS host.json 拉取成功，API 域名 ${apiBases.length} 个');
      notifyListeners(); // apiBaseUrls 变了先通知一次

      // 2. 对每个 API 域名尝试 /velox/config.json，首个成功赢
      final configUrls = apiBases
          .map((base) => _joinUrl(base, '/velox/config.json'))
          .toList();
      await _raceFetchConfig(dio, configUrls);
    } finally {
      dio.close();
    }
  }

  /// 读 OSS 引导地址列表(按优先级)。
  /// - OSS_URLS(复数,逗号分隔) 优先,支持多桶容灾并发赛跑
  /// - OSS_URL(单条) 向后兼容,只有一条时用这个
  /// 两者都配时以 OSS_URLS 为准。
  List<String> _ossUrls() {
    final multi = (dotenv.env['OSS_URLS'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (multi.isNotEmpty) return multi;
    final single = (dotenv.env['OSS_URL'] ?? '').trim();
    return single.isEmpty ? const [] : [single];
  }

  /// 多个 OSS URL 并发赛跑拉 host.json,首个 200 且 url 数组非空赢。
  /// 全部失败读本地缓存兜底。
  Future<List<String>> _fetchHostJson(Dio dio, List<String> ossUrls) async {
    final completer = Completer<List<String>>();
    final cancelTokens = List.generate(ossUrls.length, (_) => CancelToken());
    var remaining = ossUrls.length;

    for (var i = 0; i < ossUrls.length; i++) {
      final url = ossUrls[i];
      final token = cancelTokens[i];
      unawaited(() async {
        try {
          final resp = await dio.get<dynamic>(url, cancelToken: token);
          if (completer.isCompleted) return;
          if (resp.statusCode == 200 && resp.data != null) {
            final urls = _extractHostUrls(resp.data);
            if (urls.isNotEmpty) {
              _logger.i('OSS 引导命中: $url');
              completer.complete(urls);
              // 掐掉其他并发请求
              for (var j = 0; j < cancelTokens.length; j++) {
                if (j != i && !cancelTokens[j].isCancelled) {
                  cancelTokens[j].cancel('winner selected');
                }
              }
              return;
            }
          }
          _logger.w('OSS 引导 $url 返回无效数据');
        } catch (e) {
          if (!completer.isCompleted && !CancelToken.isCancel(e is DioException ? e : DioException(requestOptions: RequestOptions(path: url)))) {
            _logger.w('OSS 引导 $url 失败: $e');
          }
        } finally {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            // 全挂 → 用缓存兜底
            _logger.w('全部 OSS 引导失败,读缓存');
            completer.complete(_loadHostCache());
          }
        }
      }());
    }
    return completer.future;
  }

  /// 从 host.json 响应体里抽 url 数组，兼容明文 JSON 与 `{data:{...}}` 包装。
  List<String> _extractHostUrls(dynamic data) {
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      map = inner is Map<String, dynamic> ? inner : data;
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          final inner = decoded['data'];
          map = inner is Map<String, dynamic> ? inner : decoded;
        }
      } catch (_) {}
    }
    if (map == null) return const [];
    final raw = map['url'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// 并发拉多条 config.json URL；谁先返回可解析 JSON 就用谁，其余 CancelToken 取消。
  /// 全失败：保留缓存，UI 无感。
  Future<void> _raceFetchConfig(Dio dio, List<String> configUrls) async {
    if (configUrls.isEmpty) return;

    final tokens = [for (final _ in configUrls) CancelToken()];
    final completer = Completer<Map<String, dynamic>>();
    var pending = configUrls.length;

    for (var i = 0; i < configUrls.length; i++) {
      final token = tokens[i];
      _fetchOne(dio, configUrls[i], token).then((payload) {
        if (payload != null && !completer.isCompleted) {
          completer.complete(payload);
          for (final t in tokens) {
            if (t != token) t.cancel();
          }
        }
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError('all-config-failed');
        }
      });
    }

    try {
      final payload = await completer.future;
      _config = RemoteConfigModel.fromJson(payload);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(payload));
      _logger.i('已拉取并缓存最新业务配置');
      notifyListeners();
    } catch (e) {
      _logger.w('全部 config.json 拉取失败，保留缓存 $e');
    }
  }

  /// 单个 URL 拉取；成功返回业务 payload map（兼容明文 JSON 与 `{data:{...}}` 包装）。
  Future<Map<String, dynamic>?> _fetchOne(
      Dio dio, String url, CancelToken token) async {
    try {
      final resp = await dio.get<dynamic>(url, cancelToken: token);
      if (resp.statusCode != 200 || resp.data == null) return null;
      final data = resp.data;
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        map = inner is Map<String, dynamic> ? inner : data;
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            final inner = decoded['data'];
            map = inner is Map<String, dynamic> ? inner : decoded;
          }
        } catch (_) {}
      }
      if (map == null || map.isEmpty) return null;
      return map;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return null;
      _logger.w('RemoteConfigService: $url 拉取失败 $e');
      return null;
    }
  }

  /// 拼接 base 与 path，容忍尾/首斜杠。
  String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  // ─── 缓存读写 ─────────────────────────────────────────────────────

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // host.json 缓存
      final cachedHost = prefs.getStringList(_hostCacheKey);
      if (cachedHost != null && cachedHost.isNotEmpty) {
        _apiBaseUrls = cachedHost;
        _logger.d('RemoteConfigService: 已从缓存加载 host（${cachedHost.length} 个 API）');
      }

      // config.json 缓存
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        _config = RemoteConfigModel.fromJson(json);
        _logger.d('RemoteConfigService: 已从缓存加载业务配置');
      }
    } catch (e) {
      _logger.w('RemoteConfigService: 缓存加载失败 $e');
    }
  }

  Future<void> _saveHostCache(List<String> apiBases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hostCacheKey, apiBases);
    } catch (e) {
      _logger.w('RemoteConfigService: host 缓存写入失败 $e');
    }
  }

  Future<List<String>> _loadHostCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_hostCacheKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// 构建拉配置用的 Dio（桌面 + Android 强制 DIRECT，绕系统代理）。
  ///
  /// 历史污染场景：旧版 mihomo/v2rayN 等代理客户端退出时没清理系统代理，
  /// 残留 127.0.0.1:<随机端口> 指向死端口 → Dart HttpClient 默认读系统代理
  /// → Connection refused → 拉配置全挂 → UI 装饰字段空白。
  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': UserAgentService.instance.value,
        'Accept': 'application/json',
      },
    ));
    if (Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux ||
        Platform.isAndroid) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'DIRECT';
        // 【安全】禁止放行任意证书。以前有 badCertificateCallback = true 是调试残留 —
        // 关掉 TLS 校验后中间人只需自签根 CA 就能推恶意 host.json/config.json/APK。
        // 引导链是最敏感的信任根,必须走系统信任 CA 严格校验。
        return client;
      };
    }
    return dio;
  }

  // ─── 公告检测 ──────────────────────────────────────────────────────

  /// 是否应显示公告弹窗（每条公告只弹一次，按 ID 记录已读）
  Future<bool> shouldShowAnnouncement() async {
    final ann = _config?.announcement;
    if (ann == null || !ann.enabled || ann.content.isEmpty) return false;
    if (ann.id.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final seenId = prefs.getString(_seenAnnouncementKey);
    return seenId != ann.id;
  }

  Future<void> markAnnouncementSeen() async {
    final id = _config?.announcement?.id;
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenAnnouncementKey, id);
  }

  // ─── 版本更新检测 ──────────────────────────────────

  Future<UpdateCheckResult?> checkForUpdate() async {
    // iOS 不做应用内更新检测
    if (Platform.isIOS) return null;

    final updateCfg = _config?.update;
    if (updateCfg == null) return null;

    final platform = Platform.isWindows
        ? updateCfg.windows
        : Platform.isMacOS
            ? updateCfg.macos
            : updateCfg.android;
    if (platform == null || !platform.enabled || platform.version.isEmpty) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      if (_isNewer(platform.version, info.version)) {
        return UpdateCheckResult(
          currentVersion: info.version,
          latestVersion: platform.version,
          downloadUrl: platform.downloadUrl ?? '',
          message: platform.message ?? '',
          must: platform.must,
          sha256: platform.sha256,
        );
      }
    } catch (e) {
      _logger.w('RemoteConfigService: 版本检测失败 $e');
    }
    return null;
  }

  /// 比较版本号，newVer > curVer 返回 true
  bool _isNewer(String newVer, String curVer) {
    int parse(String s) => int.tryParse(s) ?? 0;
    final n = newVer.split('.').map(parse).toList();
    final c = curVer.split('.').map(parse).toList();
    for (var i = 0; i < 3; i++) {
      final ni = i < n.length ? n[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (ni > ci) return true;
      if (ni < ci) return false;
    }
    return false;
  }
}
