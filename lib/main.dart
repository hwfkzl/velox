import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'di/injection.dart';
import 'core/services/announcement_badge_service.dart';
import 'core/services/log_file_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/tray_service.dart';
import 'core/services/user_agent_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 统一日志文件（必须最早 init,这样后续所有 Logger / debugPrint 都能被捕获）
  // 路径: macOS=~/Library/Logs/Velox/client.log; iOS=app沙盒/Documents/Logs/client.log
  await LogFileService.instance.init();
  final originalDebugPrint = debugPrint;
  debugPrint = (String? msg, {int? wrapWidth}) {
    if (msg != null) LogFileService.instance.write('D', 'print', msg);
    originalDebugPrint(msg, wrapWidth: wrapWidth);
  };

  // 加载环境变量
  await dotenv.load(fileName: '.env');

  // 初始化 Hive
  await Hive.initFlutter();

  // 初始化 User-Agent（在任何 Dio 客户端创建之前）
  await UserAgentService.instance.init();

  // OSS 远程配置：两层引导。.env 里 OSS_URL 指向 host.json 拿 API 域名列表，
  // 再对每个域名拼 /velox/config.json 拉业务字段。缓存命中立刻可用，网络拉取
  // 后台异步刷新。
  await RemoteConfigService.instance.initialize();

  // 初始化依赖注入
  await initDependencies();

  // 初始化公告红点服务（迁移旧键 + 决定首装种子路径）
  await AnnouncementBadgeService.instance.initialize();

  // 初始化语言服务
  await LocaleService.instance.initialize();

  // 初始化本地设置（autoConnect 等）
  await SettingsService.instance.init();

  // macOS：helper 安装的密码框延迟到「第一次点连接」时弹，而不是 app 启动就弹。
  // 行业主流体验：用户进入 app 时不打扰，真正需要特权时才弹（CV / Surge / ClashX 一致）。
  // 之前的 warmupAuth() 已删——首次连接时 startMihomoAsTun 内部会调 ensureHelperAvailable
  // 触发安装，弹一次密码；helper 装好后整个生命周期再也不弹。

  // 桌面(macOS / Windows)初始化窗口管理 + 菜单栏托盘图标
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    await TrayService.instance.init();
  }

  // 状态栏样式 & 屏幕方向锁定仅限移动端（iOS / Android）
  if (Platform.isIOS || Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }


  runApp(const VeloxApp());
}
