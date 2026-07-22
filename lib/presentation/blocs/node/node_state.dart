part of 'node_bloc.dart';

abstract class NodeState extends Equatable {
  const NodeState();

  @override
  List<Object?> get props => [];
}

class NodeInitial extends NodeState {}

class NodeLoading extends NodeState {}

class NodeLoaded extends NodeState {
  final List<ServerModel> servers;
  final ServerModel? selectedServer;
  final bool isPinging;

  /// 对标 URLTest.fast() 结果：当前自动测速选出的最优节点（非手动覆盖）
  /// 对标 FlClash Group.now 字段
  final ServerModel? autoNow;

  /// 后台拉取节点失败、但本地有缓存节点可用时的一次性提示信号。
  /// 每次失败 +1，UI 通过 BlocListener 比较 tick 增长来弹一次"更新失败"小提示；
  /// 列表本身仍是旧缓存，不会被清空。
  final int refreshErrorTick;

  /// 配合 [refreshErrorTick] 的错误文案（仅用于提示，可空）
  final String? refreshErrorMessage;

  const NodeLoaded({
    required this.servers,
    this.selectedServer,
    this.isPinging = false,
    this.autoNow,
    this.refreshErrorTick = 0,
    this.refreshErrorMessage,
  });

  @override
  List<Object?> get props =>
      [servers, selectedServer, isPinging, autoNow, refreshErrorTick];

  NodeLoaded copyWith({
    List<ServerModel>? servers,
    ServerModel? selectedServer,
    bool? isPinging,
    ServerModel? autoNow,
    int? refreshErrorTick,
    String? refreshErrorMessage,
    bool clearSelectedServer = false,
    bool clearAutoNow = false,
  }) {
    return NodeLoaded(
      servers: servers ?? this.servers,
      selectedServer:
          clearSelectedServer ? null : (selectedServer ?? this.selectedServer),
      isPinging: isPinging ?? this.isPinging,
      autoNow: clearAutoNow ? null : (autoNow ?? this.autoNow),
      refreshErrorTick: refreshErrorTick ?? this.refreshErrorTick,
      refreshErrorMessage: refreshErrorMessage ?? this.refreshErrorMessage,
    );
  }

  /// 获取收藏节点
  List<ServerModel> get favoriteServers =>
      servers.where((s) => s.isFavorite).toList();

  /// 按延迟排序的节点
  List<ServerModel> get serversSortedByLatency {
    final sorted = List<ServerModel>.from(servers);
    sorted.sort((a, b) {
      if (a.latency == null && b.latency == null) return 0;
      if (a.latency == null) return 1;
      if (b.latency == null) return -1;
      return a.latency!.compareTo(b.latency!);
    });
    return sorted;
  }
}

class NodeError extends NodeState {
  final String message;

  const NodeError({required this.message});

  @override
  List<Object> get props => [message];
}
