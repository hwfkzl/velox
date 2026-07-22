/// 存储键名常量
class StorageKeys {
  StorageKeys._();

  // ===== 安全存储 (加密) =====
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userPassword = 'user_password';

  // ===== 普通存储 =====
  // 用户信息
  static const String userInfo = 'user_info';
  static const String subscribeInfo = 'subscribe_info';

  // 节点信息
  static const String serverList = 'server_list';
  static const String lastServer = 'last_server';
  static const String favoriteServers = 'favorite_servers';
  static const String serverGroups = 'server_groups';

  // 应用设置
  static const String appSettings = 'app_settings';
  static const String language = 'language';
  static const String themeMode = 'theme_mode';
  static const String isFirstLaunch = 'is_first_launch';
  /// 用户是否完成过引导流程(splash → onboarding 三屏)。
  /// 首次安装为 false,看完后置 true,之后冷启动直接跳过 splash 进入 /login。
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  // VPN 设置
  static const String proxyMode = 'proxy_mode';
  static const String tunEnabled = 'tun_enabled';
  static const String lastProxyMode = 'last_proxy_mode'; // TUN 关闭后恢复的模式
  static const String autoConnect = 'auto_connect';
  static const String autoReconnect = 'auto_reconnect';
  static const String dnsSettings = 'dns_settings';
  static const String udpEnabled = 'udp_enabled';
  static const String ipv6Enabled = 'ipv6_enabled';

  // 连接日志
  static const String connectionLogs = 'connection_logs';
  static const String trafficStats = 'traffic_stats';
}
