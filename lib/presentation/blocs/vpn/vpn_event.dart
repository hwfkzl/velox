part of 'vpn_bloc.dart';

abstract class VpnEvent extends Equatable {
  const VpnEvent();

  @override
  List<Object?> get props => [];
}

class VpnConnectRequested extends VpnEvent {
  final ServerModel server;
  final bool forceReconnect;
  /// 所有可用节点列表（用于生成包含全部 proxy 的 config，实现零停顿切换）
  final List<ServerModel>? allServers;

  const VpnConnectRequested({
    required this.server,
    this.forceReconnect = false,
    this.allServers,
  });

  @override
  List<Object?> get props => [server, forceReconnect, allServers];
}

class VpnDisconnectRequested extends VpnEvent {}

/// 退出账号时清理：先确保 VPN 断开，再把 state 重置回初始态。
/// 不 close() bloc 本身（MultiBlocProvider 还持有它）。
class VpnAuthCleared extends VpnEvent {}

class VpnConnectionTimeUpdated extends VpnEvent {
  final int seconds;

  const VpnConnectionTimeUpdated({required this.seconds});

  @override
  List<Object> get props => [seconds];
}

class VpnSpeedUpdated extends VpnEvent {
  final int uploadSpeed;
  final int downloadSpeed;

  const VpnSpeedUpdated({
    required this.uploadSpeed,
    required this.downloadSpeed,
  });

  @override
  List<Object> get props => [uploadSpeed, downloadSpeed];
}

class VpnServerChanged extends VpnEvent {
  final ServerModel server;

  const VpnServerChanged({required this.server});

  @override
  List<Object> get props => [server];
}

/// TUN 模式热重载切换（不重启进程，PUT /configs 热重载）。
/// 仅在 VPN 已连接时有效；热重载失败时 BLoC 自动回退到完整重连。
class VpnTunModePatched extends VpnEvent {
  final bool enabled;

  const VpnTunModePatched({required this.enabled});

  @override
  List<Object> get props => [enabled];
}

/// 路由策略切换（rule / global）。
/// 与 `nodes_page` 直接写 prefs 的行为完全等价（同 key、同取值、TUN 分支保护），
/// 额外副作用：非 TUN 下已连接时主动重连（forceReconnect），让新模式立刻生效。
/// 用途：tray 菜单、任何希望"切完立刻生效"的入口。
class VpnProxyModeChanged extends VpnEvent {
  final String mode; // 'rule' | 'global'

  const VpnProxyModeChanged({required this.mode});

  @override
  List<Object> get props => [mode];
}
