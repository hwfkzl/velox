import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/remote_config_service.dart';
import 'host_health.dart';

/// 多 API 端点调度器。
///
/// 职责：
/// - 从 [RemoteConfigService.apiBaseUrls] 拿到 OSS 配的 API 列表（按优先级）。
/// - 维护"当前首选"索引，按"成功用过的"持久化到 SharedPreferences，下次冷启动直接用上次能通的。
/// - 给 ApiClient 提供 [sequence]：[当前首选, 其余 fallback in 原序]，按这个顺序 hedge。
/// - 接收 ApiClient 的 [recordSuccess] / [recordFailure] 反馈；
///   连续 [_switchThreshold] 次真实失败 → 把首选切到下一个。
/// - hedge 救场（非当前 URL 反而成功了）→ 直接升它为新首选。
/// - 监听 RemoteConfigService 通知，OSS 配置变更时无缝重载列表。
///
/// 本类只管"选哪个用"的状态机，不做任何主动探测请求；
/// 主动探活是独立模块（OSS 开关控制，默认关；面向大陆用户不发周期性探测包）。
class ApiEndpointManager extends ChangeNotifier {
  ApiEndpointManager._();
  static final ApiEndpointManager instance = ApiEndpointManager._();

  /// SharedPreferences key：上次成功用过的 baseUrl（粘性 sticky）。
  static const String _stickyKey = 'velox_api_sticky_base_url';
  static const String _stickyTsKey = 'velox_api_sticky_ts';
  static const String _stickyVerKey = 'velox_api_sticky_ver';

  /// sticky 最长有效期。超过则弃用重新按 OSS 原序走。
  static const Duration _stickyTtl = Duration(hours: 24);

  /// 连续失败多少次切下一个 API。
  /// 偶发抖动（1 次）不走，3 次稳定失败才认定首选挂了。
  static const int _switchThreshold = 3;

  List<String> _endpoints = const [];
  int _currentIdx = 0;
  final Map<String, int> _failureCount = {};
  bool _wired = false;

  /// 当前首选 baseUrl；列表为空时返回空串（调用方自己处理）。
  String get currentBaseUrl {
    _ensureWired();
    if (_endpoints.isEmpty) return '';
    return _endpoints[_currentIdx.clamp(0, _endpoints.length - 1)];
  }

  /// 整张 endpoint 列表（按 OSS 原序，只读视图）。
  List<String> get endpoints {
    _ensureWired();
    return _endpoints;
  }

  /// 调度顺序：[当前首选, 其余按原序]。ApiClient 按此序 hedge。
  List<String> get sequence {
    _ensureWired();
    if (_endpoints.isEmpty) return const [];
    final cur = currentBaseUrl;
    final rest = _endpoints.where((u) => u != cur).toList(growable: false);
    return [cur, ...rest];
  }

  /// 版本字符串 —— 由当前 endpoints 列表派生。用于 sticky 版本校验:
  /// OSS 换过 endpoint 后 sticky 应作废,避免锁死到已下线域名。
  String get _endpointsVersion => _endpoints.join('|');

  /// 首次访问时挂接 RemoteConfigService。幂等。
  /// 不在 main 显式调它也行——getter 第一次被读会自动起来。
  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _reloadFromConfig();
    RemoteConfigService.instance.addListener(_reloadFromConfig);
    // 异步恢复 sticky；不阻塞首调用。
    // ignore: discarded_futures
    _loadStickyFromPrefs();
  }

  void _reloadFromConfig() {
    final newList = RemoteConfigService.instance.apiBaseUrls;
    if (listEquals(newList, _endpoints)) return;

    final prevCurrent = _endpoints.isEmpty ? '' : currentBaseUrl;
    _endpoints = List.unmodifiable(newList);
    _failureCount.clear();

    // 尽量保持当前选择：若前一个 currentUrl 仍在新列表里，固定到它；否则回首位。
    if (prevCurrent.isNotEmpty) {
      final keepIdx = _endpoints.indexOf(prevCurrent);
      _currentIdx = keepIdx >= 0 ? keepIdx : 0;
    } else {
      _currentIdx = 0;
    }

    notifyListeners();
  }

  Future<void> _loadStickyFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sticky = prefs.getString(_stickyKey);
      if (sticky == null || sticky.isEmpty) return;
      if (_endpoints.isEmpty) return;

      // 版本校验:endpoints 变了 → sticky 作废
      final savedVer = prefs.getString(_stickyVerKey) ?? '';
      if (savedVer != _endpointsVersion) {
        await prefs.remove(_stickyKey);
        await prefs.remove(_stickyTsKey);
        await prefs.remove(_stickyVerKey);
        return;
      }

      // TTL 校验:超过 24h → sticky 作废
      final savedTs = prefs.getInt(_stickyTsKey) ?? 0;
      if (savedTs > 0) {
        final age = DateTime.now().millisecondsSinceEpoch - savedTs;
        if (age > _stickyTtl.inMilliseconds) {
          await prefs.remove(_stickyKey);
          await prefs.remove(_stickyTsKey);
          await prefs.remove(_stickyVerKey);
          return;
        }
      }

      final idx = _endpoints.indexOf(sticky);
      if (idx >= 0 && idx != _currentIdx) {
        _currentIdx = idx;
        notifyListeners();
      }
    } catch (_) {
      // 不致命，吞掉
    }
  }

  Future<void> _saveSticky() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stickyKey, currentBaseUrl);
      await prefs.setInt(_stickyTsKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_stickyVerKey, _endpointsVersion);
    } catch (_) {}
  }

  /// 真实请求成功反馈。清掉该 url 的失败计数。
  /// 如果 url 不是当前首选（说明是 hedge 救场了）→ 立即升它为新首选 + 持久化。
  void recordSuccess(String baseUrl) {
    if (baseUrl.isEmpty || _endpoints.isEmpty) return;
    _failureCount[baseUrl] = 0;

    if (baseUrl == currentBaseUrl) return;

    final idx = _endpoints.indexOf(baseUrl);
    if (idx < 0) return;
    _currentIdx = idx;
    // ignore: discarded_futures
    _saveSticky();
    notifyListeners();
  }

  /// 真实请求失败反馈（仅"网络类失败"——超时/连接错/5xx，业务 4xx 不算）。
  /// 累加该 url 的失败计数；如果它是当前首选且达阈值 → 切下一个。
  void recordFailure(String baseUrl) {
    if (baseUrl.isEmpty || _endpoints.isEmpty) return;
    final n = (_failureCount[baseUrl] ?? 0) + 1;
    _failureCount[baseUrl] = n;
    if (baseUrl == currentBaseUrl && n >= _switchThreshold) {
      _switchToNext();
    }
  }

  /// DioException 版本:根据错误类型决定是否计入失败。
  /// - connectionTimeout / connectionError / sendTimeout / receiveTimeout: 计入
  /// - badResponse:5xx 计入;基础设施 4xx(CDN 兜底 HTML)计入;业务 4xx 不计入
  /// - 其他:不计入
  void recordFailureForError(String baseUrl, DioException err) {
    if (baseUrl.isEmpty || _endpoints.isEmpty) return;
    if (!_isCountableFailure(err)) return;
    recordFailure(baseUrl);
  }

  bool _isCountableFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        if (code >= 500) return true;
        if (err.response != null && isInfrastructure4xx(err.response!)) {
          return true;
        }
        return false;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  /// 挑选下一个可用 host —— FailoverInterceptor 用。
  /// 从 [_endpoints] 里返回第一个:
  ///   - 不在 exclude 里
  ///   - 未被 HostHealthRegistry 禁用
  /// 无可用返 null。
  ///
  /// 注意:[_endpoints] 存的是完整 baseUrl(含 scheme+可能的路径),这里返回的
  /// 是"能被 Uri.replace(host: ...) 用的 host 字符串"—— 也就是 Uri.parse().host。
  String? pickNext({List<String> exclude = const []}) {
    _ensureWired();
    if (_endpoints.isEmpty) return null;
    for (final url in _endpoints) {
      final host = Uri.tryParse(url)?.host ?? '';
      if (host.isEmpty) continue;
      if (exclude.contains(host) || exclude.contains(url)) continue;
      if (HostHealthRegistry.instance.get(host).isBanned) continue;
      return host;
    }
    return null;
  }

  /// 把 host 提升为当前 sticky —— FailoverInterceptor 救场后调用。
  /// 等价于 recordSuccess 里的 "非当前 URL 成功了 → 升它为首选" 分支,
  /// 差异是入参是 host(不带 scheme),需在 endpoints 里按 host 匹配定位。
  void promoteToSticky(String host) {
    _ensureWired();
    if (host.isEmpty || _endpoints.isEmpty) return;
    for (var i = 0; i < _endpoints.length; i++) {
      final urlHost = Uri.tryParse(_endpoints[i])?.host ?? '';
      if (urlHost == host) {
        _failureCount[_endpoints[i]] = 0;
        if (i == _currentIdx) return;
        _currentIdx = i;
        // ignore: discarded_futures
        _saveSticky();
        notifyListeners();
        return;
      }
    }
  }

  void _switchToNext() {
    if (_endpoints.length <= 1) return;
    _currentIdx = (_currentIdx + 1) % _endpoints.length;
    _failureCount[currentBaseUrl] = 0; // 给新首选一个干净起点
    // ignore: discarded_futures
    _saveSticky();
    notifyListeners();
  }

  /// 测试/手动重置时用。
  @visibleForTesting
  void resetForTest() {
    _endpoints = const [];
    _currentIdx = 0;
    _failureCount.clear();
    _wired = false;
  }
}
