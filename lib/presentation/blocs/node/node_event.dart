part of 'node_bloc.dart';

abstract class NodeEvent extends Equatable {
  const NodeEvent();

  @override
  List<Object?> get props => [];
}

class NodeLoadRequested extends NodeEvent {}

class NodeRefreshRequested extends NodeEvent {}

/// 退出账号时清理：取消 stream 订阅、回到 NodeInitial。
/// 避免账号 A 的服务器列表、selectedServer、订阅信息残留到账号 B。
class NodeAuthCleared extends NodeEvent {}

class NodePingRequested extends NodeEvent {
  final ServerModel server;

  const NodePingRequested({required this.server});

  @override
  List<Object> get props => [server];
}

class NodePingAllRequested extends NodeEvent {}

class NodeToggleFavoriteRequested extends NodeEvent {
  final int serverId;

  const NodeToggleFavoriteRequested({required this.serverId});

  @override
  List<Object> get props => [serverId];
}

class NodeSelectRequested extends NodeEvent {
  final ServerModel server;

  const NodeSelectRequested({required this.server});

  @override
  List<Object> get props => [server];
}

/// 内部事件：AutoTestService stream 推送的单节点延迟结果
/// 对标 FlClash UrlTestHook → onDelay() → NodeBloc
class _NodeDelayReceived extends NodeEvent {
  final int serverId;
  final int latency; // >0 正常(ms)，<0 超时/失败

  const _NodeDelayReceived({required this.serverId, required this.latency});

  @override
  List<Object> get props => [serverId, latency];
}
