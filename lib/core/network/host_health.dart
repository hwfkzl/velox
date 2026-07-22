import 'package:dio/dio.dart';

/// 每个 host 的健康状态 —— 简化版(计数 + 冷却)
/// 参考 Mullvad daemon 连续 3 次失败切下一档
class HostHealth {
  int consecutiveFailures = 0;
  DateTime? _bannedUntil;
  int rttEmaMs = 0;

  static const int failThreshold = 3;
  static const Duration banDuration = Duration(seconds: 30);

  bool get isBanned {
    if (_bannedUntil == null) return false;
    if (DateTime.now().isAfter(_bannedUntil!)) {
      _bannedUntil = null;
      return false;
    }
    return true;
  }

  void onSuccess(int rttMs) {
    rttEmaMs = rttEmaMs == 0 ? rttMs : (rttEmaMs * 0.7 + rttMs * 0.3).toInt();
    consecutiveFailures = 0;
    _bannedUntil = null;
  }

  void onFailure() {
    consecutiveFailures++;
    if (consecutiveFailures >= failThreshold) {
      _bannedUntil = DateTime.now().add(banDuration);
    }
  }

  void reset() {
    consecutiveFailures = 0;
    _bannedUntil = null;
    rttEmaMs = 0;
  }
}

/// 全局 registry —— key=host(不带 scheme),value=HostHealth
class HostHealthRegistry {
  static final HostHealthRegistry instance = HostHealthRegistry._();
  HostHealthRegistry._();

  final Map<String, HostHealth> _map = {};

  HostHealth get(String host) => _map.putIfAbsent(host, () => HostHealth());

  void resetAll() {
    for (final h in _map.values) {
      h.reset();
    }
  }

  Iterable<MapEntry<String, HostHealth>> get all => _map.entries;
}

/// 判定基础设施 4xx(CDN/nginx 兜底页 vs 真业务 4xx)
/// 关键: text/html body + 4xx = CDN 边缘错误页,应视作 host 层不可用
bool isInfrastructure4xx(Response response) {
  final code = response.statusCode ?? 0;
  if (code < 400 || code >= 500) return false;
  final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
  // 若 body 明确是 JSON 且带业务 message,视作业务 4xx
  if (contentType.contains('application/json')) {
    final data = response.data;
    if (data is Map && data['message'] != null) return false;
  }
  // 否则(HTML/text/plain/其他)视作基础设施 4xx
  return true;
}
