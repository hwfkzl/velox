import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Extension on BuildContext for convenient localization access
extension ContextExtensions on BuildContext {
  /// Get the AppLocalizations instance for the current context
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Get the current theme
  ThemeData get theme => Theme.of(this);

  /// Get the current color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get the current text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get the current media query data
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get the screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get the screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if the current theme is dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Show a snackbar with the given message
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
