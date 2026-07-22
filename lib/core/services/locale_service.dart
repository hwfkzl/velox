import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static final LocaleService instance = LocaleService._();
  LocaleService._();

  static const _prefKey = 'app_locale';

  Locale _locale = const Locale('zh');
  Locale get locale => _locale;

  static const supportedLocales = [
    Locale('zh'),
    Locale('zh', 'TW'),
    Locale('en'),
  ];

  static const localeNames = {
    'zh': '简体中文',
    'zh_TW': '繁體中文',
    'en': 'English',
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final parts = saved.split('_');
      _locale = parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    await prefs.setString(_prefKey, key);
  }

  String get currentName {
    final key = _locale.countryCode != null
        ? '${_locale.languageCode}_${_locale.countryCode}'
        : _locale.languageCode;
    return localeNames[key] ?? '简体中文';
  }
}
