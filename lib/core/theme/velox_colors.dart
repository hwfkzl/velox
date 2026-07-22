import 'package:flutter/material.dart';

/// Velox VPN 颜色系统
/// 支持亮色/深色主题
class VeloxColors {
  VeloxColors._();

  // 主色调 — 对齐 Velox accent，保留旧命名避免破坏全项目引用
  static const Color primary = Color(0xFF4A9FFF);        // Velox accent
  static const Color primaryDark = Color(0xFF3B82F6);    // 稍深一档
  static const Color primaryDarker = Color(0xFF1E40AF);  // 最深

  // ========== 统一 Velox light palette（dark/light 两套都指向同一组值） ==========
  // 原"深色主题"常量现在被直接静态引用的老页面当作默认色，指向 Velox 浅色
  // 的等效值，保证 announcement/invite 等老代码在不改一行的情况下
  // 跟随 Velox 主题。
  static const Color bgPrimary = Color(0xFFBBD4EF);      // 主背景（Velox 上空）
  static const Color bgSecondary = Color(0xFF93B8DE);    // 次背景（Velox 中段）
  static const Color bgCard = Color(0xFFFFFFFF);         // 卡片底 — 用白色，bgCardWithOpacity 再加 alpha
  static const Color bgInput = Color(0xFFF1F5F9);        // 输入框背景

  // 文字色 — 对齐 Velox text1/2/3
  static const Color textPrimary = Color(0xFF334155);    // slate-700
  static const Color textSecondary = Color(0xFF475569);  // slate-600
  static const Color textTertiary = Color(0xFF64748B);   // slate-500

  // 边框 — 对齐 Velox divider（blue-200 × 50% 会再叠 alpha 得到玻璃描边）
  static const Color border = Color(0xFFBFDBFE);         // blue-200
  static const Color borderLight = Color(0x33BFDBFE);    // blue-200 × 20%
  static const Color borderPrimary = Color(0x664A9FFF);  // accent × 40%

  // 亮色主题常量保留同名，也指向同一套值（extension 分支无论走哪边都一致）
  static const Color bgPrimaryLight = bgPrimary;
  static const Color bgSecondaryLight = bgSecondary;
  static const Color bgCardLight = bgCard;
  static const Color bgInputLight = bgInput;

  static const Color textPrimaryLight = textPrimary;
  static const Color textSecondaryLight = textSecondary;
  static const Color textTertiaryLight = textTertiary;

  static const Color borderLightTheme = border;
  static const Color borderLightLight = borderLight;

  // 功能色（不随主题变化）
  static const Color success = Color(0xFF4ADE80);        // 成功/已连接
  static const Color warning = Color(0xFFFBBF24);        // 警告/中等负载
  static const Color error = Color(0xFFF87171);          // 错误/高负载

  // VPN 状态颜色
  static const Color connected = success;
  static const Color connecting = warning;
  static const Color disconnected = textTertiary;

  // 节点延迟颜色
  static const Color latencyGood = success;      // < 50ms
  static const Color latencyMedium = warning;    // 50-150ms
  static const Color latencyBad = error;         // > 150ms

  // 渐变色
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primaryDarker],
  );

  // 页面背景渐变 — 对齐 Velox 天空（topCenter → bottomCenter，上浅下深）
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFBBD4EF),
      Color(0xFF93B8DE),
      Color(0xFF6E94C5),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient bgGradientLight = bgGradient;

  static LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, success.withValues(alpha: 0.7)],
  );

  // 透明度变体
  static Color primaryWithOpacity(double opacity) => primary.withValues(alpha: opacity);
  static Color bgCardWithOpacity(double opacity) => bgCard.withValues(alpha: opacity);
  static Color borderWithOpacity(double opacity) => border.withValues(alpha: opacity);
}

/// 主题感知的颜色扩展
/// 使用方式: context.veloxColors.bgPrimary
extension VeloxColorsExtension on BuildContext {
  _ThemeColors get veloxColors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return _ThemeColors(isDark);
  }
}

class _ThemeColors {
  final bool isDark;

  const _ThemeColors(this.isDark);

  // 背景色
  Color get bgPrimary => isDark ? VeloxColors.bgPrimary : VeloxColors.bgPrimaryLight;
  Color get bgSecondary => isDark ? VeloxColors.bgSecondary : VeloxColors.bgSecondaryLight;
  Color get bgCard => isDark ? VeloxColors.bgCard : VeloxColors.bgCardLight;
  Color get bgInput => isDark ? VeloxColors.bgInput : VeloxColors.bgInputLight;

  // 文字色
  Color get textPrimary => isDark ? VeloxColors.textPrimary : VeloxColors.textPrimaryLight;
  Color get textSecondary => isDark ? VeloxColors.textSecondary : VeloxColors.textSecondaryLight;
  Color get textTertiary => isDark ? VeloxColors.textTertiary : VeloxColors.textTertiaryLight;

  // 边框色
  Color get border => isDark ? VeloxColors.border : VeloxColors.borderLightTheme;
  Color get borderLight => isDark ? VeloxColors.borderLight : VeloxColors.borderLightLight;

  // 渐变
  LinearGradient get bgGradient => isDark ? VeloxColors.bgGradient : VeloxColors.bgGradientLight;

  // 带透明度
  Color bgCardWithOpacity(double opacity) => bgCard.withValues(alpha: opacity);
  Color borderWithOpacity(double opacity) => border.withValues(alpha: opacity);
}
