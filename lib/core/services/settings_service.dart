import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/storage_keys.dart';

/// Thin settings facade that hides [SharedPreferences] from the UI layer.
///
/// Exposes the subset of prefs the home page needs as [ValueNotifier]s so
/// widgets can `AnimatedBuilder` / `ValueListenableBuilder` on them without
/// having to touch storage or remember to re-read on `didChangeDependencies`.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final ValueNotifier<bool> autoConnect = ValueNotifier(false);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    autoConnect.value = prefs.getBool(StorageKeys.autoConnect) ?? false;
  }

  /// Re-read from storage and publish to listeners. Settings pages that
  /// mutate prefs directly should call this afterwards (or use
  /// [setAutoConnect] below).
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    autoConnect.value = prefs.getBool(StorageKeys.autoConnect) ?? false;
  }

  Future<void> setAutoConnect(bool v) async {
    autoConnect.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.autoConnect, v);
  }
}
