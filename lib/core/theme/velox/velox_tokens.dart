import 'package:flutter/material.dart';

/// Velox design system tokens, delivered via [ThemeExtension] so the same
/// widget tree renders differently when the user switches themes.
@immutable
class VeloxTokens extends ThemeExtension<VeloxTokens> {
  const VeloxTokens({
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.surfaceLight,
    required this.surfaceMid,
    required this.surfaceHeavy,
    required this.accent,
    required this.accentSoft,
    required this.accentGlow,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.divider,
    required this.success,
    required this.warning,
    required this.danger,
    required this.rLg,
    required this.rMd,
    required this.rSm,
    required this.blurLight,
    required this.blurMid,
    required this.blurHeavy,
    required this.cardShadow,
    required this.navShadow,
    required this.glowShadow,
    required this.meshGradient,
    required this.bgGradient,
  });

  // --- Surfaces ---
  final Color bg0; // app root bg (solid fallback behind gradient)
  final Color bg1; // card
  final Color bg2; // elevated
  final Color surfaceLight; // pills, small chips
  final Color surfaceMid;   // primary glass cards
  final Color surfaceHeavy; // bottom nav glass

  // --- Brand ---
  final Color accent;
  final Color accentSoft;
  final Color accentGlow;

  // --- Text ---
  final Color text1; // title            (slate-700)
  final Color text2; // body             (slate-600)
  final Color text3; // secondary        (slate-500)
  final Color text4; // disabled / hint  (slate-300)

  final Color divider;

  // --- Intent ---
  final Color success;
  final Color warning;
  final Color danger;

  // --- Shape ---
  final double rLg;
  final double rMd;
  final double rSm;

  // --- Blur ---
  final double blurLight;
  final double blurMid;
  final double blurHeavy;

  // --- Elevation ---
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> navShadow;
  final List<BoxShadow> glowShadow;

  // --- Backgrounds ---
  final Gradient meshGradient;
  final Gradient bgGradient;

  /// Velox 深色主题色板 —— 深空蓝底 + 半透玻璃卡片 + 亮蓝光晕。
  /// 文字用近白系（slate-50 → slate-400）保持可读性层级。
  static final VeloxTokens light = VeloxTokens(
    bg0: const Color(0xFF061226), // 实色兜底（深空近黑）
    bg1: Colors.white.withValues(alpha: 0.08),  // 卡片底 — 半透浮于深底
    bg2: Colors.white.withValues(alpha: 0.12),  // elevated 卡片
    surfaceLight: Colors.white.withValues(alpha: 0.10), // pills / chips
    surfaceMid: Colors.white.withValues(alpha: 0.08),   // 主玻璃卡片
    surfaceHeavy: Colors.white.withValues(alpha: 0.06), // 底栏更透
    accent: const Color(0xFF6BB5FF), // 深底上更亮的蓝（原 4A9FFF 在深底偏暗）
    accentSoft: const Color(0xFF6BB5FF).withValues(alpha: 0.18),
    accentGlow: const Color(0xFF6BB5FF).withValues(alpha: 0.40),
    text1: const Color(0xFFE8EEF7), // 主标题  — 近白略蓝（slate-50）
    text2: const Color(0xFFC1CCDF), // 正文    — slate-200
    text3: const Color(0xFF94A3C0), // 次要    — slate-400
    text4: const Color(0xFF54607A), // 禁用/hint
    divider: Colors.white.withValues(alpha: 0.10),
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFFBAC24),
    danger: const Color(0xFFEF4444),
    rLg: 22,
    rMd: 20,
    rSm: 16,
    blurLight: 20,
    blurMid: 28,
    blurHeavy: 40,
    cardShadow: [
      // 深底上用深黑阴影 + 微弱蓝光晕，比纯蓝阴影更"沉"
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.40),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: const Color(0xFF6BB5FF).withValues(alpha: 0.10),
        blurRadius: 16,
        offset: const Offset(0, 3),
      ),
    ],
    navShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.30),
        blurRadius: 32,
        offset: const Offset(0, -10),
      ),
      BoxShadow(
        color: const Color(0xFF6BB5FF).withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, -4),
      ),
    ],
    glowShadow: [
      BoxShadow(
        color: const Color(0xFF6BB5FF).withValues(alpha: 0.40),
        blurRadius: 40,
        spreadRadius: 2,
      ),
    ],
    // 左上主光源 — 纯蓝（#4A9FFF），不带紫调，VPN 客户端"科技蓝"心智
    meshGradient: const RadialGradient(
      center: Alignment(-0.6, -0.4),
      radius: 1.4,
      colors: [Color(0x554A9FFF), Color(0x00000000)],
      stops: [0.0, 0.6],
    ),
    // 深空垂直渐变：保留渐变但不"砸到底"，整体维持"夜空深蓝"质感
    bgGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF15355F), // 顶 — 纯净深皇家蓝
        Color(0xFF0B1F3D), // 中 — 过渡
        Color(0xFF050E1E), // 底 — 深邃黑蓝（有"夜空"还有"深度"）
      ],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  /// Placeholder mapping used when the app is NOT in velox mode, so lookups
  /// never crash. Values aren't consumed visually.
  static final VeloxTokens fallback = light.copyWith();

  @override
  VeloxTokens copyWith({
    Color? bg0,
    Color? bg1,
    Color? bg2,
    Color? surfaceLight,
    Color? surfaceMid,
    Color? surfaceHeavy,
    Color? accent,
    Color? accentSoft,
    Color? accentGlow,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? text4,
    Color? divider,
    Color? success,
    Color? warning,
    Color? danger,
    double? rLg,
    double? rMd,
    double? rSm,
    double? blurLight,
    double? blurMid,
    double? blurHeavy,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? navShadow,
    List<BoxShadow>? glowShadow,
    Gradient? meshGradient,
    Gradient? bgGradient,
  }) {
    return VeloxTokens(
      bg0: bg0 ?? this.bg0,
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      surfaceMid: surfaceMid ?? this.surfaceMid,
      surfaceHeavy: surfaceHeavy ?? this.surfaceHeavy,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentGlow: accentGlow ?? this.accentGlow,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      text4: text4 ?? this.text4,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      rLg: rLg ?? this.rLg,
      rMd: rMd ?? this.rMd,
      rSm: rSm ?? this.rSm,
      blurLight: blurLight ?? this.blurLight,
      blurMid: blurMid ?? this.blurMid,
      blurHeavy: blurHeavy ?? this.blurHeavy,
      cardShadow: cardShadow ?? this.cardShadow,
      navShadow: navShadow ?? this.navShadow,
      glowShadow: glowShadow ?? this.glowShadow,
      meshGradient: meshGradient ?? this.meshGradient,
      bgGradient: bgGradient ?? this.bgGradient,
    );
  }

  @override
  VeloxTokens lerp(ThemeExtension<VeloxTokens>? other, double t) {
    if (other is! VeloxTokens) return this;
    return VeloxTokens(
      bg0: Color.lerp(bg0, other.bg0, t)!,
      bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      surfaceMid: Color.lerp(surfaceMid, other.surfaceMid, t)!,
      surfaceHeavy: Color.lerp(surfaceHeavy, other.surfaceHeavy, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      text4: Color.lerp(text4, other.text4, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      rLg: lerpDouble(rLg, other.rLg, t),
      rMd: lerpDouble(rMd, other.rMd, t),
      rSm: lerpDouble(rSm, other.rSm, t),
      blurLight: lerpDouble(blurLight, other.blurLight, t),
      blurMid: lerpDouble(blurMid, other.blurMid, t),
      blurHeavy: lerpDouble(blurHeavy, other.blurHeavy, t),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      navShadow: t < 0.5 ? navShadow : other.navShadow,
      glowShadow: t < 0.5 ? glowShadow : other.glowShadow,
      meshGradient: Gradient.lerp(meshGradient, other.meshGradient, t) ?? meshGradient,
      bgGradient: Gradient.lerp(bgGradient, other.bgGradient, t) ?? bgGradient,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience lookup. Returns the velox tokens or a safe fallback when the
/// current theme does not include them.
extension VeloxTokensContext on BuildContext {
  VeloxTokens get velox =>
      Theme.of(this).extension<VeloxTokens>() ?? VeloxTokens.fallback;
}
