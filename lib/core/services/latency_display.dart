import 'dart:math';

import 'remote_config_service.dart';

/// 节点延迟 UI 渲染翻译：根据 OSS 的 [RemoteFakeLatency] 配置决定显示真实延迟
/// 还是封顶后的"漂亮数字"。
///
/// **封顶式逻辑**（不是无脑替换所有节点）：
/// - `real == null`     → 还没测过，返回 null（UI 显示 ---）
/// - `real <= 0`        → DEAD/失败，**透传**（UI 显示 ✕；节点能不能用不撒谎）
/// - 开关 OFF / 配置异常 → 透传真实延迟
/// - 开关 ON 且 `real <= maxMs` → **透传真实延迟**（快节点不撒谎，技术用户拿订阅
///   去 Clash 对比看到一致数字，OPSEC 风险大幅降低）
/// - 开关 ON 且 `real > maxMs`  → 在 [minMs, maxMs] 区间用 (serverId, dayOfYear)
///   做种子均匀采样（**只对慢节点封顶包装**）
///
/// 同一节点同一天看到的数字稳定（不会刷一下跳一下）；跨天微变看起来像
/// "今天的网络状况"。真实 [server.latency] 字段不会被污染——自动选最快、按延迟
/// 排序、DEAD 筛选都用真值，不受 UI 包装影响。
int? latencyForDisplay(int? real, int serverId) {
  if (real == null) return null;
  if (real <= 0) return real;

  final cfg = RemoteConfigService.instance.fakeLatency;
  if (!cfg.enabled) return real;
  if (cfg.minMs <= 0 || cfg.maxMs < cfg.minMs) return real;

  // 真实延迟在上限内 → 透传真值（快节点不需要包装）
  if (real <= cfg.maxMs) return real;

  // 真实延迟超过上限 → 在区间内稳定采样（仅对慢节点封顶）
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  final rng = Random(serverId * 1000003 + dayOfYear);
  return cfg.minMs + rng.nextInt(cfg.maxMs - cfg.minMs + 1);
}
