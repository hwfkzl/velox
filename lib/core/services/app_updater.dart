import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_logger.dart';
import 'user_agent_service.dart';

/// 下载停滞判定阈值:onReceiveProgress 连续 N 秒未收到任何字节 → 判定 stall。
/// 网络切换/CDN 抖动通常 <10s 恢复,30s 是一个"确认卡死而非临时抖动"的稳妥阈值。
const Duration _kStallThreshold = Duration(seconds: 30);

/// stall 检测的巡逻粒度。5s tick 足够检出 30s 阈值,同时对 CPU 无感。
const Duration _kStallCheckInterval = Duration(seconds: 5);

/// Android / Windows / macOS 应用内下载并安装更新
class AppUpdater {
  AppUpdater._();
  static final AppUpdater instance = AppUpdater._();

  final _logger = appLogger(tag: 'AppUpdater');

  /// 下载并安装更新包
  /// [url]            下载地址(必须 https)
  /// [expectedSha256] config 里的期望指纹;非空则强制校验,空则跳过
  /// [onProgress]     下载进度回调 0.0 ~ 1.0
  Future<AppUpdateResult> downloadAndInstall(
    String url, {
    String? expectedSha256,
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
    CancelToken? cancelToken,
  }) async {
    // stall 检测本地状态。整块下载生命周期结束前 stallTimer 必须 cancel,
    // 否则会污染后续 SHA256/OpenFile 阶段(那两个阶段不产生 progress 回调,
    // lastTick 长期不刷 → 假 stall)。
    Timer? stallTimer;
    DateTime lastTick = DateTime.now();
    bool stalledFlag = false;
    String? savePath;

    // 无外部 CancelToken 时自建一个,方便 stall 分支主动取消。
    // 复用同一个 token(不管是外部传的还是内部建的)—— 通过 stalledFlag 布尔位
    // 区分"用户主动 cancel"与"stall 触发 cancel",避免双 token 转发复杂度。
    final effectiveCancelToken = cancelToken ?? CancelToken();

    try {
      // 安全:更新包下载地址必须 HTTPS,挡住明文劫持
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme.toLowerCase() != 'https') {
        _logger.e('AppUpdater: download url is not https: $url');
        return AppUpdateResult.insecureUrl;
      }

      // Android 8+ 需要「安装未知来源」权限
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final result = await Permission.requestInstallPackages.request();
          if (!result.isGranted) {
            return AppUpdateResult.permissionDenied;
          }
        }
      }

      // 决定保存路径
      savePath = await _getSavePath(url);

      // 下载
      final dio = Dio(BaseOptions(
        headers: {'User-Agent': UserAgentService.instance.value},
      ));

      // 关键:stall 计时窗口从这里开始 —— 而不是函数入口。
      // Android 8+ 首次授权"安装未知应用"会跳系统设置页,用户操作可能耗时 20-60s,
      // 若沿用函数入口的 lastTick,Timer 首 tick 就会误判 stalled 触发 cancel。
      lastTick = DateTime.now();

      // 启动 stall 巡逻:每 5s 检查 now - lastTick,超阈值则标记 + 取消。
      // Timer.periodic 在 dio.download await 返回之后必须立即 cancel,
      // 详见函数尾部 finally 与 dio.download 后的显式 cancel。
      stallTimer = Timer.periodic(_kStallCheckInterval, (t) {
        if (DateTime.now().difference(lastTick) > _kStallThreshold) {
          stalledFlag = true;
          _logger.w(
              'AppUpdater: download stalled (no progress in ${_kStallThreshold.inSeconds}s), cancelling');
          if (!effectiveCancelToken.isCancelled) {
            effectiveCancelToken.cancel('stalled');
          }
          t.cancel();
        }
      });

      await dio.download(
        url,
        savePath,
        cancelToken: effectiveCancelToken,
        onReceiveProgress: (received, total) {
          // 无条件刷新 lastTick —— 包括 chunked/Content-Length=-1 场景,
          // 只要有字节到达就算"活着",与 total 是否可用解耦。
          lastTick = DateTime.now();
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      // 下载结束立即 cancel Timer,不让它污染后续 SHA256/OpenFile 阶段。
      stallTimer.cancel();
      stallTimer = null;

      // SHA256 校验:确认下载的包是发布的原版(没被篡改/损坏/劫持)。
      // config 提供了指纹才校验;不一致则删除文件并拒绝安装。
      final expected = expectedSha256?.trim().toLowerCase();
      if (expected != null && expected.isNotEmpty) {
        onVerifying?.call();
        final actual = await _sha256OfFile(savePath);
        if (actual == null || actual != expected) {
          _logger.e(
              'AppUpdater: sha256 mismatch expected=$expected actual=$actual');
          await _deleteQuietly(savePath);
          return AppUpdateResult.checksumFailed;
        }
        _logger.d('AppUpdater: sha256 verified ok');
      } else {
        _logger.w('AppUpdater: no sha256 provided, skipping integrity check');
      }

      // macOS:剥离 quarantine,避免 Gatekeeper 拦截刚下载的 dmg。
      // 之后 OpenFile.open(dmg) 会自动 hdiutil attach 并弹 Finder 显示 app,
      // 用户手动把 app 拖到 Applications 完成更新。
      // 注意:仅在 SHA256 校验【通过之后】才剥离 —— 绝不给未验证的文件撕标记。
      if (Platform.isMacOS) {
        final xattrOk = await _stripQuarantine(savePath);
        if (!xattrOk) {
          // 剥离失败 → 即使挂载,拖出的 app 仍带 quarantine 会被 Gatekeeper 拦,
          // 与其假装成功不如明确报错,让用户知道需要手动处理。
          return AppUpdateResult.xattrFailed;
        }
      }

      // 打开安装器(Android=apk 安装、Windows=exe、macOS=dmg 挂载+Finder)
      final openResult = await OpenFile.open(savePath);
      _logger.d('AppUpdater: open result = ${openResult.type} ${openResult.message}');

      if (openResult.type == ResultType.done) {
        return AppUpdateResult.success;
      } else {
        return AppUpdateResult.openFailed;
      }
    } on DioException catch (e) {
      // 关键顺序:stall 判定优先于普通 cancel。stalled 情况下清残包再返回。
      if (CancelToken.isCancel(e) && stalledFlag) {
        _logger.w('AppUpdater: mapped to stalled');
        if (savePath != null) await _deleteQuietly(savePath);
        return AppUpdateResult.stalled;
      }
      if (CancelToken.isCancel(e)) return AppUpdateResult.cancelled;
      _logger.e('AppUpdater: download failed $e');
      return AppUpdateResult.downloadFailed;
    } catch (e) {
      _logger.e('AppUpdater: unexpected error $e');
      return AppUpdateResult.downloadFailed;
    } finally {
      // 双保险:任何 return/throw 路径都保证 Timer 被 cancel,防泄漏
      stallTimer?.cancel();
    }
  }

  /// 流式计算文件 SHA256(大文件不会一次性读进内存)
  Future<String?> _sha256OfFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase();
    } catch (e) {
      _logger.e('AppUpdater: sha256 compute failed $e');
      return null;
    }
  }

  /// macOS 剥离 quarantine;成功返回 true。
  Future<bool> _stripQuarantine(String path) async {
    try {
      final res = await Process.run('/usr/bin/xattr', ['-cr', path]);
      _logger.d('AppUpdater: xattr -cr rc=${res.exitCode} ${res.stderr}');
      return res.exitCode == 0;
    } catch (e) {
      _logger.e('AppUpdater: xattr -cr failed $e');
      return false;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 根据 URL 后缀决定文件名和保存目录
  Future<String> _getSavePath(String url) async {
    final uri = Uri.parse(url);
    String fileName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'update_installer';

    // 确保有后缀。URL 已带 .exe / .msi / .dmg / .apk 时保持原样,只在 URL 无后缀
    // (如后端返回 CDN 短链)时按平台补默认;Windows 默认 .exe 安装器,后端若下发
    // .msi 会因 URL 本身带后缀而保留,ShellExecute(OpenFile) 能同时处理两种。
    if (!fileName.contains('.')) {
      if (Platform.isAndroid) fileName += '.apk';
      if (Platform.isWindows) fileName += '.exe';
      if (Platform.isMacOS) fileName += '.dmg';
    }

    Directory dir;
    if (Platform.isAndroid) {
      // Android 用应用缓存目录（不需要存储权限）
      dir = await getApplicationCacheDirectory();
    } else {
      // macOS / Windows 用 Downloads 文件夹
      dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    }

    return '${dir.path}/$fileName';
  }
}

enum AppUpdateResult {
  success,
  permissionDenied,
  downloadFailed,
  openFailed,
  cancelled,
  /// 下载地址不是 https
  insecureUrl,
  /// SHA256 指纹与 config 不符(可能被篡改/损坏)
  checksumFailed,
  /// macOS 剥离 quarantine 失败(装上去会被 Gatekeeper 拦)
  xattrFailed,
  /// 下载 30s 无字节到达 —— 视作卡死,即使 must:true 也允许用户关闭对话框
  stalled,
}
