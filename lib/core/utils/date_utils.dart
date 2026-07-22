/// 日期工具类
class AppDateUtils {
  AppDateUtils._();

  /// 格式化时间戳为日期字符串
  static String formatTimestamp(int? timestamp, {String format = 'yyyy-MM-dd'}) {
    if (timestamp == null) return 'N/A';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return formatDate(date, format: format);
  }

  /// 格式化日期
  static String formatDate(DateTime date, {String format = 'yyyy-MM-dd'}) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return format
        .replaceAll('yyyy', year)
        .replaceAll('MM', month)
        .replaceAll('dd', day)
        .replaceAll('HH', hour)
        .replaceAll('mm', minute)
        .replaceAll('ss', second);
  }

  /// 计算剩余天数
  static int daysUntil(int? timestamp) {
    if (timestamp == null) return 0;

    final expireDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    return expireDate.difference(now).inDays;
  }

  /// 格式化持续时间
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// 格式化连接时间 (秒数)
  static String formatConnectionTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// 判断是否已过期
  static bool isExpired(int? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().millisecondsSinceEpoch > timestamp * 1000;
  }

  /// 获取相对时间描述
  static String getRelativeTime(int? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) {
      // 已过期
      final absDiff = diff.abs();
      if (absDiff.inDays > 30) {
        return '已过期 ${absDiff.inDays ~/ 30} 个月';
      } else if (absDiff.inDays > 0) {
        return '已过期 ${absDiff.inDays} 天';
      } else if (absDiff.inHours > 0) {
        return '已过期 ${absDiff.inHours} 小时';
      } else {
        return '刚刚过期';
      }
    } else {
      // 未过期
      if (diff.inDays > 30) {
        return '${diff.inDays ~/ 30} 个月后到期';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} 天后到期';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} 小时后到期';
      } else {
        return '即将到期';
      }
    }
  }
}
