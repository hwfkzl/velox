import 'package:shared_preferences/shared_preferences.dart';

/// 安全存储服务（用于存储敏感信息如 Token）
///
/// 说明：iOS 26 上 `flutter_secure_storage` 在插件注册阶段会触发崩溃，
/// 这里暂时使用 SharedPreferences 保证应用可启动和登录流程可用。
class SecureStorageService {
  static const Set<String> _secureKeys = {
    'auth_token',
    'refresh_token',
    'user_password',
  };

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// 写入数据
  Future<void> write(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  /// 读取数据
  Future<String?> read(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  /// 删除数据
  Future<void> delete(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  /// 删除所有安全数据
  Future<void> deleteAll() async {
    final prefs = await _prefs;
    for (final key in _secureKeys) {
      await prefs.remove(key);
    }
  }

  /// 检查是否存在
  Future<bool> containsKey(String key) async {
    final prefs = await _prefs;
    return prefs.containsKey(key);
  }

  /// 读取所有安全数据
  Future<Map<String, String>> readAll() async {
    final prefs = await _prefs;
    final result = <String, String>{};
    for (final key in _secureKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }
}
