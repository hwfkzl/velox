/// 应用常量
class AppConstants {
  AppConstants._();

  static const String appName = 'Velox';
  static const String appVersion = '1.0.0';

  // 存储 Key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String languageKey = 'language';
  static const String themeKey = 'theme_mode';
  static const String firstLaunchKey = 'first_launch';
  static const String lastNodeKey = 'last_node';
  static const String favoriteNodesKey = 'favorite_nodes';

  // 社交链接
  static const String telegramGroupUrl = 'https://t.me/your_group';

  // 超时配置（毫秒）
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;

  // 分页配置
  static const int pageSize = 20;

  // VPN 连接超时（秒）
  static const int vpnConnectTimeout = 30;

  // 节点测速超时（毫秒）
  static const int pingTimeout = 5000;

  // 自动测速配置（对标 mihomo HealthCheck + URLTest）
  static const int autoTestInterval = 300; // 周期测速间隔（秒），对标 hc.interval
  static const int autoTestTolerance = 50; // 容差（ms），对标 URLTest tolerance
}
