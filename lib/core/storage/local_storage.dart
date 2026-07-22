import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储服务（用于存储非敏感配置）
class LocalStorageService {
  late SharedPreferences _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存字符串
  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  /// 获取字符串
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// 保存整数
  Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  /// 获取整数
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  /// 保存布尔值
  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// 保存双精度浮点数
  Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  /// 获取双精度浮点数
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  /// 保存字符串列表
  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  /// 获取字符串列表
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  /// 保存 JSON 对象
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }

  /// 获取 JSON 对象
  Map<String, dynamic>? getJson(String key) {
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 删除键
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  /// 清空所有
  Future<bool> clear() async {
    return await _prefs.clear();
  }

  /// 检查键是否存在
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
