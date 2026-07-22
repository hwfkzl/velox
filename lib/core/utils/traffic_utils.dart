/// 流量工具类
class TrafficUtils {
  TrafficUtils._();

  /// 格式化字节数为可读字符串
  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// 格式化速度 (bytes/s)
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';

    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = 0;
    double speed = bytesPerSecond.toDouble();

    while (speed >= 1024 && i < suffixes.length - 1) {
      speed /= 1024;
      i++;
    }

    return '${speed.toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// 计算流量使用百分比
  static double calculateUsagePercent(int used, int total) {
    if (total <= 0) return 0;
    return (used / total * 100).clamp(0, 100);
  }

  /// 将GB转换为字节
  static int gbToBytes(double gb) {
    return (gb * 1024 * 1024 * 1024).round();
  }

  /// 将字节转换为GB
  static double bytesToGb(int bytes) {
    return bytes / 1024 / 1024 / 1024;
  }
}
