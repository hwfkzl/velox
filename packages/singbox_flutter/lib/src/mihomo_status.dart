/// Connection status for Mihomo VPN.
enum MihomoStatus {
  /// Not connected to any server.
  disconnected,

  /// Currently establishing connection.
  connecting,

  /// Successfully connected to server.
  connected,

  /// Currently disconnecting from server.
  disconnecting,

  /// Connection failed with error.
  error,
}

/// Extension methods for MihomoStatus.
extension MihomoStatusExtension on MihomoStatus {
  /// Whether the VPN is currently connected.
  bool get isConnected => this == MihomoStatus.connected;

  /// Whether the VPN is currently connecting.
  bool get isConnecting => this == MihomoStatus.connecting;

  /// Whether the VPN is currently disconnected.
  bool get isDisconnected => this == MihomoStatus.disconnected;

  /// Whether the VPN is currently disconnecting.
  bool get isDisconnecting => this == MihomoStatus.disconnecting;

  /// Whether the VPN has an error.
  bool get hasError => this == MihomoStatus.error;

  /// Whether the VPN is in a transitional state.
  bool get isTransitioning =>
      this == MihomoStatus.connecting || this == MihomoStatus.disconnecting;
}
