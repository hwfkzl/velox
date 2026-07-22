part of 'vpn_bloc.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class VpnState extends Equatable {
  final VpnStatus status;
  final ServerModel? server;
  final int connectionTime; // 连接时长（秒）
  final int uploadSpeed; // 上传速度 (bytes/s)
  final int downloadSpeed; // 下载速度 (bytes/s)
  final int totalUpload; // 总上传 (bytes)
  final int totalDownload; // 总下载 (bytes)
  final String? error;
  /// 连接时传入的全节点列表，供 TUN 热重载时重新生成完整配置使用
  final List<ServerModel>? allServers;

  const VpnState({
    this.status = VpnStatus.disconnected,
    this.server,
    this.connectionTime = 0,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
    this.error,
    this.allServers,
  });

  bool get isConnected => status == VpnStatus.connected;
  bool get isConnecting => status == VpnStatus.connecting;
  bool get isDisconnected => status == VpnStatus.disconnected;
  bool get isDisconnecting => status == VpnStatus.disconnecting;

  VpnState copyWith({
    VpnStatus? status,
    ServerModel? server,
    int? connectionTime,
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
    String? error,
    // P2-1 修复:显式清 error 用这个开关。不传 error 参数则**保留** this.error,
    // 不再每 tick stats 悄悄 wipe。默认 false = 保留旧行为对 error 的语义无副作用。
    bool clearError = false,
    List<ServerModel>? allServers,
    bool clearAllServers = false,
  }) {
    return VpnState(
      status: status ?? this.status,
      server: server ?? this.server,
      connectionTime: connectionTime ?? this.connectionTime,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      totalUpload: totalUpload ?? this.totalUpload,
      totalDownload: totalDownload ?? this.totalDownload,
      error: clearError ? null : (error ?? this.error),
      allServers: clearAllServers ? null : (allServers ?? this.allServers),
    );
  }

  @override
  List<Object?> get props => [
        status,
        server,
        connectionTime,
        uploadSpeed,
        downloadSpeed,
        totalUpload,
        totalDownload,
        error,
        allServers,
      ];
}
