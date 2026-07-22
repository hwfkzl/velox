import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Global User-Agent builder. Every outbound HTTP request — main API, OSS
/// config fetch, app updater, VPN connectivity check — tags itself as
/// `Velox/<version> (<platform>)` so backends and logs can identify
/// traffic coming from this client.
class UserAgentService {
  UserAgentService._();
  static final UserAgentService instance = UserAgentService._();

  static const String _app = 'Velox';

  String _value = _app; // safe default if used before init()
  bool _initialized = false;

  /// Populates the cached UA string. Call once at app startup (main.dart)
  /// before any Dio client is created; subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.isEmpty ? '1.0.0' : info.version;
      _value = '$_app/$v (${_platform()})';
    } catch (_) {
      _value = '$_app (${_platform()})';
    }
  }

  /// The header value. Always safe to read — returns a sensible default
  /// before [init] has completed.
  String get value => _value;

  static String _platform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
