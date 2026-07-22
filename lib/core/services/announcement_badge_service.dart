import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../../data/models/notice_model.dart';
import '../../di/injection.dart';

/// 公告红点服务 —— 前台冷启动 / resume 时拉 /notice/fetch,
/// 未读则在首页顶部喇叭图标上亮红点。
///
/// 不做本地通知,不做后台唤醒,不做后台轮询。
/// 用户预期与实际能力 100% 一致:"打开 App 时会看到红点提示"。
///
/// 迁移逻辑(v1.0.8 → v1.0.9):
///  - 旧键 `last_notice_id` 平移到 `last_read_notice_id`(语义等价 = 已读到这个 id)
///  - 旧键 `notifications_enabled` 无条件清除(toggle 已删)
///  - 首次安装(两个键都不存在)第一次 refresh 拉到的 max id 只写库不亮红点,
///    修掉旧版"首装即弹 6 个月前老公告"的 bug
class AnnouncementBadgeService {
  static final AnnouncementBadgeService instance = AnnouncementBadgeService._();
  AnnouncementBadgeService._();

  static const _lastReadIdKey = 'last_read_notice_id';
  static const _legacyLastNoticeIdKey = 'last_notice_id';
  static const _legacyEnabledKey = 'notifications_enabled';

  /// UI 订阅这个 —— 有未读时首页顶部喇叭图标叠红点
  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  int _latestId = 0;
  bool _seeded = false;

  Timer? _timer;

  /// App 启动时调用一次:迁移旧键 + 决定首装种子行为
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 无条件清掉旧 toggle 键(功能已删)
    if (prefs.containsKey(_legacyEnabledKey)) {
      await prefs.remove(_legacyEnabledKey);
    }

    // 旧 last_notice_id 平移到 last_read_notice_id
    // 语义:老版本"已经作为本地通知弹过"的 id 视为"已读"
    if (prefs.containsKey(_legacyLastNoticeIdKey) &&
        !prefs.containsKey(_lastReadIdKey)) {
      final legacy = prefs.getInt(_legacyLastNoticeIdKey) ?? 0;
      await prefs.setInt(_lastReadIdKey, legacy);
      await prefs.remove(_legacyLastNoticeIdKey);
    } else if (prefs.containsKey(_legacyLastNoticeIdKey)) {
      // 双键并存(理论上不会发生)—— 直接清老键
      await prefs.remove(_legacyLastNoticeIdKey);
    }

    // 首次安装标记:两个键都不存在 → 首次 refresh 走"种子"路径,不亮红点
    _seeded = prefs.containsKey(_lastReadIdKey);
  }

  /// 冷启动、resume、以及定时兜底时调用:拉后端最新公告 id,决定 hasUnread。
  ///
  /// 网络失败 / 未登录 401 静默失败,不改变 hasUnread 当前值。
  Future<void> refresh() async {
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get(ApiConstants.noticeList);
      if (response.data == null || response.data['data'] == null) return;

      final List<dynamic> data = response.data['data'];
      if (data.isEmpty) return;

      final notices = data
          .map((json) => NoticeModel.fromJson(json as Map<String, dynamic>))
          .toList();
      notices.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      final latestId = notices.first.id ?? 0;
      if (latestId <= 0) return;

      _latestId = latestId;

      final prefs = await SharedPreferences.getInstance();

      if (!_seeded) {
        // 首次安装:把当前 max id 视为"已读起点",不亮红点
        await prefs.setInt(_lastReadIdKey, latestId);
        _seeded = true;
        hasUnread.value = false;
        return;
      }

      final lastRead = prefs.getInt(_lastReadIdKey) ?? 0;
      hasUnread.value = latestId > lastRead;
    } catch (_) {
      // 静默:网络/401/解析失败都不该崩溃,也不改变当前红点状态
    }
  }

  /// 用户点击顶部喇叭图标 → 进入公告页 → 同步清红点。
  /// 只写本地,无网络请求。
  Future<void> markAllRead() async {
    if (_latestId <= 0) {
      hasUnread.value = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadIdKey, _latestId);
    hasUnread.value = false;
  }

  /// 兜底前台定时刷新 —— 30 分钟一次,只在 app 前台运行时才 tick。
  /// 用户长时间保持前台(比如挂着 VPN 界面),依然能看到新公告出现红点。
  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => refresh());
    // 首次立即刷一次
    refresh();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
}
