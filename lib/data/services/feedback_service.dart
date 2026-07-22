import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/log_file_service.dart';
import '../../core/services/remote_config_service.dart';
import '../../core/services/user_agent_service.dart';

/// 用户反馈通道:
///  - 导出日志(桌面 → Finder/资源管理器;移动 → 系统 share sheet)
///  - 上传日志到 TG log-bot(客服在私密频道收)
///  - 打开 Crisp 客服(url_launcher)
///
/// TG 单条上传上限 50 MB;我们 rotate 上限 20 MB,zip 后典型 3-6 MB。
/// **redact**:上传前脱敏订阅 token / user email / auth token,避免整条日志外泄。
class FeedbackService {
  FeedbackService._();
  static final instance = FeedbackService._();

  final _logger = appLogger(tag: 'Feedback');

  static const int _tgSizeLimit = 45 * 1024 * 1024; // TG 50MB,留 5MB 余量

  // ────────────────────────────────────────────────────────────
  // 1. 构建 zip
  // ────────────────────────────────────────────────────────────

  /// 打包所有日志 + meta.txt,返回临时目录里的 zip 路径。
  Future<String> _buildDebugLogZip() async {
    final tmp = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .split('+')[0];
    final zipPath = '${tmp.path}/velox-log-$ts.zip';

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // 1.1 meta.txt(设备/版本/网络/用户信息,用于客服快速定位)
    final metaBytes = utf8.encode(await _buildMeta());
    encoder.addArchiveFile(
      ArchiveFile('meta.txt', metaBytes.length, metaBytes),
    );

    // 1.2 client.log + 3 份 rotate
    final clientLogPath = LogFileService.instance.path;
    if (clientLogPath != null) {
      final base = File(clientLogPath);
      for (final f in [
        base,
        File('${base.path}.1'),
        File('${base.path}.2'),
        File('${base.path}.3'),
      ]) {
        if (await f.exists()) {
          final name = f.uri.pathSegments.last;
          final bytes = await f.readAsBytes();
          final redacted = _redactBytes(bytes);
          encoder.addArchiveFile(
            ArchiveFile(name, redacted.length, redacted),
          );
        }
      }
    }

    // 1.3 macOS 独有的 mihomo 日志(内核层写,root 拥有,普通用户可读)。
    //     zip 内归到 mihomo/ 子目录,客服/测试打开时能一眼分组:
    //       zip 根     = Dart 层(client.log + meta.txt)
    //       mihomo/    = 内核 + macOS helper(原始格式,不经 Dart 层)
    if (Platform.isMacOS) {
      const kernelFiles = {
        '/tmp/velox_mihomo_tun.log': 'mihomo/tun.log',
        '/tmp/velox_plugin.log': 'mihomo/plugin.log',
        '/tmp/velox_mihomo_svc.log': 'mihomo/svc.log',
      };
      for (final entry in kernelFiles.entries) {
        final f = File(entry.key);
        if (await f.exists()) {
          try {
            final bytes = await f.readAsBytes();
            final redacted = _redactBytes(bytes);
            encoder.addArchiveFile(
              ArchiveFile(entry.value, redacted.length, redacted),
            );
          } catch (e) {
            _logger.w('skip ${entry.key}: $e');
          }
        }
      }
    }

    encoder.closeSync();
    return zipPath;
  }

  /// ISO8601 + 本地时区偏移(与 [LogFileService] 内同款,保持 zip 内时间戳格式一致)。
  static String _isoWithOffset(DateTime t) {
    if (t.isUtc) return t.toIso8601String();
    final off = t.timeZoneOffset;
    final totalMin = off.inMinutes.abs();
    final sign = off.isNegative ? '-' : '+';
    final hh = (totalMin ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMin % 60).toString().padLeft(2, '0');
    return '${t.toIso8601String()}$sign$hh:$mm';
  }

  Future<String> _buildMeta() async {
    final info = await PackageInfo.fromPlatform();
    final buf = StringBuffer();
    buf.writeln('===== Velox debug log package =====');
    buf.writeln('generated_at: ${_isoWithOffset(DateTime.now())}');
    buf.writeln('app_name:     ${info.appName}');
    buf.writeln('app_version:  ${info.version}+${info.buildNumber}');
    buf.writeln('package:      ${info.packageName}');
    buf.writeln('platform:     ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('locale:       ${Platform.localeName}');
    buf.writeln('user_agent:   ${UserAgentService.instance.value}');

    final email = await _readUserEmail();
    buf.writeln('user_email:   ${email ?? '(not logged in)'}');

    // 内核日志健康度:让客服一眼看出 helper 是否起来
    // (kernel_log_present=false 意味着 mihomo 没跑到落盘阶段,而非 zip 遗漏)
    if (Platform.isMacOS) {
      final kernelLog = File('/tmp/velox_mihomo_tun.log');
      final present = await kernelLog.exists();
      buf.writeln('kernel_log_present: $present');
      if (present) {
        try {
          final len = await kernelLog.length();
          buf.writeln('kernel_log_bytes:   $len');
        } catch (_) {
          buf.writeln('kernel_log_bytes:   (stat failed)');
        }
      }
    }

    buf.writeln('===================================');
    return buf.toString();
  }

  Future<String?> _readUserEmail() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('user_info');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      final e = map?['email'];
      return e is String && e.isNotEmpty ? e : null;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // 2. 脱敏
  // ────────────────────────────────────────────────────────────

  /// 简单 redact:
  ///  - 订阅链接 token 段(长 24+ 的 hex/base64)→ 保留前 4 后 4
  ///  - Bearer / auth 头 token
  ///  - email 邮箱 → 保留 @ 前 2 位 + 后缀
  ///  - URL query 里 ?token= / ?key= / ?secret= / ?password= 值
  ///
  /// 只处理文本类日志;若解码失败(二进制)按原样带过。
  List<int> _redactBytes(List<int> bytes) {
    try {
      final s = utf8.decode(bytes, allowMalformed: true);
      return utf8.encode(_redact(s));
    } catch (_) {
      return bytes;
    }
  }

  static final _reLongToken =
      RegExp(r'([A-Za-z0-9_\-]{24,})'); // 至少 24 字节的连续 token
  static final _reQueryToken =
      RegExp(r'([?&](?:token|key|secret|password|auth|access_token)=)([^&\s"]+)',
          caseSensitive: false);
  static final _reBearer = RegExp(r'(Bearer\s+)(\S+)', caseSensitive: false);
  static final _reEmail = RegExp(r'([A-Za-z0-9._%+\-]+)@([A-Za-z0-9.\-]+)');

  String _redact(String s) {
    s = s.replaceAllMapped(_reQueryToken, (m) => '${m[1]}***');
    s = s.replaceAllMapped(_reBearer, (m) => '${m[1]}***');
    s = s.replaceAllMapped(_reEmail, (m) {
      final local = m[1]!;
      final keep = local.length <= 2 ? local : local.substring(0, 2);
      return '$keep***@${m[2]}';
    });
    // 长 token 保守打:仅当不在时间戳/文件路径/常见词内(不含 - . / 特征)
    s = s.replaceAllMapped(_reLongToken, (m) {
      final t = m[0]!;
      if (t.contains('.')) return t; // 疑似 iso8601 / 版本号
      return '${t.substring(0, 4)}***${t.substring(t.length - 4)}';
    });
    return s;
  }

  // ────────────────────────────────────────────────────────────
  // 3. 导出:弹系统文件管理器(桌面)或 share sheet(移动)
  // ────────────────────────────────────────────────────────────

  Future<FeedbackExportResult> exportDebugLog() async {
    try {
      final zipPath = await _buildDebugLogZip();
      final size = await File(zipPath).length();
      _logger.d('exported log zip: $zipPath ($size bytes)');

      if (Platform.isMacOS) {
        // Finder 里选中该文件
        await Process.run('/usr/bin/open', ['-R', zipPath]);
      } else if (Platform.isWindows) {
        // Explorer /select,<path> —— 必须单个 arg 拼接,不能拆两个参数,
        // 否则 explorer 会把 /select, 当成待打开路径失败。
        await Process.run('explorer.exe', ['/select,$zipPath']);
      } else if (Platform.isLinux) {
        // 打开所在目录(Linux 桌面没有统一的 "reveal in file manager")
        final dir = File(zipPath).parent.path;
        await Process.run('xdg-open', [dir]);
      } else {
        // iOS / Android:系统 share sheet
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipPath)],
            text: 'Velox debug log',
          ),
        );
      }
      return FeedbackExportResult.success(zipPath, size);
    } catch (e, st) {
      _logger.e('exportDebugLog failed', error: e, stackTrace: st);
      return FeedbackExportResult.failure(e.toString());
    }
  }

  // ────────────────────────────────────────────────────────────
  // 4. 上传到 TG log-bot
  // ────────────────────────────────────────────────────────────

  bool get isTelegramConfigured {
    final t = dotenv.env['TG_LOG_BOT_TOKEN'];
    final c = dotenv.env['TG_LOG_CHAT_ID'];
    return t != null && t.isNotEmpty && c != null && c.isNotEmpty;
  }

  Future<FeedbackUploadResult> uploadDebugLogToTelegram({
    String? userNote,
  }) async {
    final token = dotenv.env['TG_LOG_BOT_TOKEN'];
    final chatId = dotenv.env['TG_LOG_CHAT_ID'];
    if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) {
      return FeedbackUploadResult.notConfigured();
    }

    String? zipPath;
    try {
      zipPath = await _buildDebugLogZip();
      final size = await File(zipPath).length();
      if (size > _tgSizeLimit) {
        return FeedbackUploadResult.tooLarge(size);
      }

      final caption = await _buildCaption(userNote: userNote);

      // 独立 dio,不走 app 内 http_proxy=DIRECT 的 bypass(TG 需要走系统正常网络)
      // 但也别读用户的系统代理污染:TG API 在被墙区就是要靠 mihomo VPN 出去,
      // 用户开着 Velox 时全局 tun 会带 telegram 一起走,直连没问题。
      final dio = Dio(BaseOptions(
        headers: {'User-Agent': UserAgentService.instance.value},
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 30),
      ));
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final c = HttpClient();
        c.findProxy = (_) => 'DIRECT';
        return c;
      };

      final form = FormData.fromMap({
        'chat_id': chatId,
        'caption': caption,
        'document': await MultipartFile.fromFile(
          zipPath,
          filename: zipPath.split('/').last,
        ),
      });

      final resp = await dio.post(
        'https://api.telegram.org/bot$token/sendDocument',
        data: form,
      );

      final data = resp.data;
      final okFlag = data is Map ? data['ok'] == true : false;
      final result = data is Map ? data['result'] as Map<String, dynamic>? : null;
      if (!okFlag || result == null) {
        _logger.e('tg upload not ok: $data');
        return FeedbackUploadResult.failure(
            'Telegram API 返回失败: ${data is Map ? data['description'] : data}');
      }
      final msgId = result['message_id']?.toString() ?? '?';
      _logger.d('tg upload ok, msg_id=$msgId');
      return FeedbackUploadResult.success(msgId, size);
    } on DioException catch (e) {
      _logger.e('tg upload DioException: ${e.message}');
      return FeedbackUploadResult.failure(
          e.response?.data?.toString() ?? e.message ?? 'network error');
    } catch (e, st) {
      _logger.e('tg upload failed', error: e, stackTrace: st);
      return FeedbackUploadResult.failure(e.toString());
    } finally {
      // 上传完删本地 zip(用户已通过反馈编号获得后续追溯手段,无需保留)
      if (zipPath != null) {
        try {
          await File(zipPath).delete();
        } catch (_) {}
      }
    }
  }

  Future<String> _buildCaption({String? userNote}) async {
    final info = await PackageInfo.fromPlatform();
    final email = await _readUserEmail();
    final buf = StringBuffer();
    buf.writeln('📮 Velox feedback');
    buf.writeln('version: ${info.version}+${info.buildNumber}');
    buf.writeln('platform: ${Platform.operatingSystem}');
    buf.writeln('email: ${email ?? '(guest)'}');
    if (userNote != null && userNote.trim().isNotEmpty) {
      final safe = userNote.length > 512 ? userNote.substring(0, 512) : userNote;
      buf.writeln('note: $safe');
    }
    return buf.toString();
  }

  // ────────────────────────────────────────────────────────────
  // 5. 打开 Crisp 客服
  // ────────────────────────────────────────────────────────────

  Future<bool> openCrisp() async {
    final crispId = RemoteConfigService.instance.crispId;
    if (crispId.isEmpty) return false;
    final uri = Uri.parse(
        'https://go.crisp.chat/chat/embed/?website_id=$crispId');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────── 结果类型 ────────────────────────────────────

class FeedbackExportResult {
  final bool ok;
  final String? path;
  final int? size;
  final String? error;
  FeedbackExportResult._(this.ok, this.path, this.size, this.error);
  factory FeedbackExportResult.success(String path, int size) =>
      FeedbackExportResult._(true, path, size, null);
  factory FeedbackExportResult.failure(String error) =>
      FeedbackExportResult._(false, null, null, error);
}

enum FeedbackUploadState { success, notConfigured, tooLarge, failed }

class FeedbackUploadResult {
  final FeedbackUploadState state;
  final String? messageId;
  final int? size;
  final String? error;
  FeedbackUploadResult._(this.state, this.messageId, this.size, this.error);
  factory FeedbackUploadResult.success(String messageId, int size) =>
      FeedbackUploadResult._(
          FeedbackUploadState.success, messageId, size, null);
  factory FeedbackUploadResult.notConfigured() => FeedbackUploadResult._(
      FeedbackUploadState.notConfigured, null, null, null);
  factory FeedbackUploadResult.tooLarge(int size) =>
      FeedbackUploadResult._(FeedbackUploadState.tooLarge, null, size, null);
  factory FeedbackUploadResult.failure(String error) =>
      FeedbackUploadResult._(FeedbackUploadState.failed, null, null, error);
}
