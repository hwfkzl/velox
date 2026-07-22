import 'package:flutter/material.dart';

import 'velox_tokens.dart';

/// Factory for the Velox light [ThemeData]. Used when
/// `ThemeBloc` is in velox mode — fed to `MaterialApp.theme`/`darkTheme`.
class VeloxThemeData {
  VeloxThemeData._();

  static ThemeData build() {
    final tokens = VeloxTokens.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: tokens.bg0,
      canvasColor: tokens.bg0,
      fontFamily: '.SF Pro Text',
      colorScheme: ColorScheme.light(
        primary: tokens.accent,
        onPrimary: Colors.white,
        secondary: tokens.accent,
        onSecondary: Colors.white,
        surface: tokens.bg1,
        onSurface: tokens.text1,
        error: tokens.danger,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: tokens.text1, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: tokens.text1, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: tokens.text1, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: tokens.text1, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: tokens.text2),
        bodyMedium: TextStyle(color: tokens.text2),
        bodySmall: TextStyle(color: tokens.text3),
        labelLarge: TextStyle(color: tokens.text1, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: tokens.text2),
        labelSmall: TextStyle(color: tokens.text3),
      ),
      iconTheme: IconThemeData(color: tokens.text2, size: 22),
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}
