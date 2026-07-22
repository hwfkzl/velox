import 'package:logger/logger.dart';

import 'log_file_service.dart';

/// 统一 Logger 工厂。**所有业务代码用这个，不要直接 `Logger()`**。
///
/// 行为：
/// - 控制台（dev 时 flutter run / IDE 看得到，对齐原来）
/// - 同步写到 [LogFileService] 的统一文件（release/真机也能找到）
///
/// 用法：
///   final _logger = appLogger(tag: 'VpnBloc');
///   _logger.i('connected');
///
/// 不传 tag 时默认 'app'。
Logger appLogger({String tag = 'app'}) => Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _DualOutput([ConsoleOutput(), _FileLogOutput(tag)]),
    );

/// 把一个 OutputEvent 同时分发给多个 LogOutput；任一 output 抛错不影响其它。
class _DualOutput extends LogOutput {
  final List<LogOutput> outputs;
  _DualOutput(this.outputs);

  @override
  void output(OutputEvent event) {
    for (final o in outputs) {
      try {
        o.output(event);
      } catch (_) {}
    }
  }
}

/// LogOutput 适配器：把 logger 包的 OutputEvent 拍平成行写入 LogFileService。
///
/// **写文件时精简 PrettyPrinter 的装饰**(dev 控制台不受影响):
/// 1. 剥离 ANSI 颜色码(`\x1b[...m`),避免文本编辑器打开满屏乱字符
/// 2. 跳过纯装饰边框行(`┌ ├ └ ─ ┄` 组成的分隔线,单条日志外面包 4 行)
/// 3. 跳过时间戳辅助行(PrettyPrinter 给每条日志单独打一行 `│ HH:MM:SS.mmm (+...)`,
///    这个信息在行首 ISO 时间戳里已经有了,重复)
/// 4. 剥离内容行前面的 `│ ` 装饰前缀
///
/// 效果:单条 log 从 5 行 × ~130 字符 压到 1 行 × ~80 字符,~8× 精简。
class _FileLogOutput extends LogOutput {
  final String tag;
  _FileLogOutput(this.tag);

  static final _reAnsi = RegExp(r'\x1B\[[0-9;]*m');
  static final _reDecoLineOnly =
      RegExp(r'^[\s┌├└─┄│]+$'); // 全部由边框字符 + 空白组成
  static final _reTimestampAux =
      RegExp(r'^\s*│\s*\d{1,2}:\d{2}:\d{2}\.\d+.*'); // │ 04:20:06.875 (+0:00:...)
  static final _reContentPrefix =
      RegExp(r'^\s*│\s?'); // "│ 💡 xxx" 去掉前缀

  @override
  void output(OutputEvent event) {
    final level = event.level.name.isEmpty
        ? '?'
        : event.level.name[0].toUpperCase();
    for (final rawLine in event.lines) {
      // 1. 去 ANSI 颜色码
      final noAnsi = rawLine.replaceAll(_reAnsi, '');
      // 2. 跳过纯装饰边框行
      if (_reDecoLineOnly.hasMatch(noAnsi)) continue;
      // 3. 跳过 PrettyPrinter 的时间戳辅助行
      if (_reTimestampAux.hasMatch(noAnsi)) continue;
      // 4. 剥离内容行前面的 `│ ` 前缀
      final cleaned = noAnsi.replaceFirst(_reContentPrefix, '').trimRight();
      if (cleaned.isEmpty) continue;
      LogFileService.instance.write(level, tag, cleaned);
    }
  }
}
