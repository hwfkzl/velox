import '../core/services/remote_config_service.dart';

/// 客户端品牌元数据 —— 单一数据源。
///
/// 解析优先级（从高到低）：
///   1. OSS 远程配置 `config.json` 的 `brand_name`（运行时可改、无需重新构建）
///   2. 构建时 `--dart-define=BRAND_NAME=...`（白标打包用）
///   3. 默认值 `Global Fast`
///
/// UA / bundle id / 加密 KEY 等协议层标识不在这里 —— 它们写死在各自的
/// 服务里（user_agent_service.dart 等）以保证后端守门稳定。
class Brand {
  Brand._();

  /// 构建期注入的品牌名（白标场景）。
  static const String _buildName = String.fromEnvironment(
    'BRAND_NAME',
    defaultValue: 'Global Fast',
  );

  /// 构建期注入的 Splash 大字。为空则跟随 [name]。
  static const String _buildSplash = String.fromEnvironment(
    'BRAND_SPLASH',
    defaultValue: '',
  );

  /// 当前运行时品牌名（远程配置 → 构建时 → 默认值）。
  static String get name {
    final remote = RemoteConfigService.instance.brandName;
    return remote.isNotEmpty ? remote : _buildName;
  }

  /// Splash 页中央大字。默认跟随 [name]。
  static String get splashText =>
      _buildSplash.isNotEmpty ? _buildSplash : name;

  /// 把文案里的 `Velox` 占位符替换成当前品牌名。
  ///
  /// 用于服务条款、隐私政策等冗长 l10n 长文内嵌品牌名的场景 —— 长文一字
  /// 不改，仅在渲染时统一替换。
  static String brandize(String text) =>
      text.isEmpty ? text : text.replaceAll('Velox', name);
}
