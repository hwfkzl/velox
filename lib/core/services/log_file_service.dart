import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_filter.dart';

/// 统一日志文件服务(**只写 Dart 层日志**)。
///
/// **目的**:release / 真机构建里没有终端,把所有客户端日志(Dart Logger + debugPrint)
/// 汇到一个固定路径的文件,方便用 Finder 直接找出来排查 bug。
///
/// **路径(用户视角)**:
/// - macOS:   `~/Library/Logs/Velox/client.log`         (Finder ⌘⇧G 直接进)
/// - iOS:     app sandbox `Documents/Logs/client.log`   (Files App 可见)
/// - Windows: `%APPDATA%\Velox\Logs\client.log`
/// - Linux:   `~/.local/state/velox/logs/client.log`
/// - Android: `/data/user/0/<pkg>/files/logs/client.log`(app 私有持久目录,
///            用 getApplicationSupportDirectory,不会被清缓存/低存储清理清掉)
///
/// **轮换**:单文件超 [_maxBytes] 自动重命名为 `.1`,保留最多 [_backupCount] 份。
///
/// **内核日志**:mihomo Go 内核直接写 `/tmp/velox_mihomo_tun.log`(macOS root helper
/// 落盘的原文,时间戳/格式零污染),**本服务不再镜像**。反馈 zip 里 mihomo/ 子目录
/// 独立打包。测试内核问题**看那份原文**,不看 client.log。
///
/// **过滤**:落盘前经 [LogFilter] 精简,tag 白/黑名单 + level 底线(E/W/F 全留)。
/// 控制台输出不受影响,dev 体验不变。
class LogFileService {
  LogFileService._();
  static final LogFileService instance = LogFileService._();

  static const int _maxBytes = 5 * 1024 * 1024; // 5MB
  static const int _backupCount = 3;

  IOSink? _sink;
  String? _path;
  Timer? _flushTimer;

  /// 当前 session 内已见的 [I] 行计数(供 [LogFilter] 的 startup-anchor 判断
  /// "前 4 条 RemoteConfig [I] 是引导链需保留")。
  final Map<String, int> _sessionInfoCount = {};

  /// 当前日志文件的绝对路径;init 失败或未初始化时返回 null。
  String? get path => _path;

  /// 在 main 里、runApp 之前 await 调用。幂等。
  Future<void> init() async {
    if (_sink != null) return;
    try {
      final dir = Directory(await _resolveDirPath());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/client.log');

      // 大于阈值就先轮换
      if (await file.exists() && await file.length() > _maxBytes) {
        await _rotate(file);
      }

      _sink = file.openWrite(mode: FileMode.append);
      _path = file.path;

      _writeHeader();

      // 周期 flush（IOSink 内部缓冲，崩溃时未 flush 的会丢——2s 上限可接受）
      _flushTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => _sink?.flush());
    } catch (e) {
      // 不让日志系统反过来搞挂 app
      stderr.writeln('LogFileService init failed: $e');
    }
  }

  Future<String> _resolveDirPath() async {
    final env = Platform.environment;
    if (Platform.isMacOS) {
      return '${env['HOME'] ?? ''}/Library/Logs/Velox';
    } else if (Platform.isIOS) {
      // iOS sandboxed 真机:HOME 就是 app 沙盒根目录
      return '${env['HOME'] ?? ''}/Documents/Logs';
    } else if (Platform.isWindows) {
      return '${env['APPDATA'] ?? ''}\\Velox\\Logs';
    } else if (Platform.isLinux) {
      return '${env['HOME'] ?? ''}/.local/state/velox/logs';
    } else if (Platform.isAndroid) {
      // Android app-scoped 私有持久目录:/data/user/0/<pkg>/files/logs
      // (path_provider 的 getApplicationSupportDirectory 在 Android 上就是
      //  context.getFilesDir(),不是 filesDir/support 子目录)
      // 选 support 不选 cache:cache 会被"应用信息 → 清除缓存"和系统低存储清理
      // 秒删,而"上传日志赢奖励"需要日志长期保留到用户触发反馈那一刻。
      // 选 support 不选 documents:documents 在 Android 上是 filesDir/app_flutter,
      // Flutter framework 惯例目录,语义脏;备份行为跟 support 一样(默认都受
      // AutoBackup 管),没优势。
      try {
        final dir = await getApplicationSupportDirectory();
        return '${dir.path}/logs';
      } catch (_) {
        // path_provider 挂掉极罕见,但兜底不 crash 掉 init
        return '/data/local/tmp/velox/logs';
      }
    }
    // 其它未识别平台(web?):走 tmp
    return '/tmp/velox/logs';
  }

  Future<void> _rotate(File current) async {
    final base = current.path;
    // 删最旧
    final oldest = File('$base.$_backupCount');
    if (await oldest.exists()) {
      try {
        await oldest.delete();
      } catch (_) {}
    }
    // .N-1 → .N
    for (int i = _backupCount - 1; i >= 1; i--) {
      final f = File('$base.$i');
      if (await f.exists()) {
        try {
          await f.rename('$base.${i + 1}');
        } catch (_) {}
      }
    }
    // current → .1
    try {
      await current.rename('$base.1');
    } catch (_) {}
  }

  /// ISO8601 + 本地时区偏移(如 `2026-07-19T04:20:07.462+08:00`),
  /// 与 mihomo 内核日志(自带 +HH:MM offset)交叉对齐时不会因缺 tz 被误解为 UTC。
  ///
  /// 兼容 3 种边界:
  /// - UTC DateTime → 直接返回带 'Z' 的形态,避免拼出非法 `...Z+00:00`
  /// - 半点时区(印度 +05:30 / 尼泊尔 +05:45 / 纽芬兰 -03:30)→ 用 inMinutes 计算不丢分
  /// - 负 offset(西经)→ sign 正确带 '-'
  static String _nowIso8601WithOffset() {
    final now = DateTime.now();
    if (now.isUtc) return now.toIso8601String();
    final off = now.timeZoneOffset;
    final totalMin = off.inMinutes.abs();
    final sign = off.isNegative ? '-' : '+';
    final hh = (totalMin ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMin % 60).toString().padLeft(2, '0');
    return '${now.toIso8601String()}$sign$hh:$mm';
  }

  void _writeHeader() {
    final s = _sink;
    if (s == null) return;
    final now = _nowIso8601WithOffset();
    s.writeln('');
    s.writeln('========== Velox client log @ $now ==========');
    s.writeln(
        'platform=${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    // 提示排查者去哪里找 mihomo 内核日志(macOS 才有)
    if (Platform.isMacOS) {
      s.writeln(
          'kernel_log: /tmp/velox_mihomo_tun.log (macOS root helper, not mirrored here)');
    }
    s.flush();
    // 新 session 重置 startup-anchor 计数,让 LogFilter 允许 RemoteConfig 前 4 条 [I]
    _sessionInfoCount.clear();
  }

  /// 写一行:`<iso8601> [LEVEL] [TAG] <message>`。线程安全(IOSink 串行化)。
  ///
  /// 落盘前经 [LogFilter] 精简。控制台输出不受影响(那走 app_logger 的 ConsoleOutput)。
  void write(String level, String tag, Object? message) {
    final s = _sink;
    if (s == null) return;
    try {
      final msgStr = message?.toString() ?? '';
      if (!LogFilter.shouldKeep(
        level: level,
        tag: tag,
        message: msgStr,
        sessionInfoCount: _sessionInfoCount,
      )) {
        return;
      }
      s.writeln('${_nowIso8601WithOffset()} [$level] [$tag] $msgStr');
    } catch (_) {}
  }

  /// 应用退出前主动 flush + close(cleanupOnExit 路径里可调)。
  Future<void> close() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }
}
