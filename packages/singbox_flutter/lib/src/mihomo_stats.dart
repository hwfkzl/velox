/// Traffic statistics from Mihomo core.
class MihomoStats {
  /// Upload speed in bytes per second.
  final int uploadSpeed;

  /// Download speed in bytes per second.
  final int downloadSpeed;

  /// Total bytes uploaded since connection started.
  final int totalUpload;

  /// Total bytes downloaded since connection started.
  final int totalDownload;

  /// Connection duration in seconds.
  final int connectionTime;

  /// Timestamp when these stats were captured.
  final DateTime timestamp;

  const MihomoStats({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
    required this.connectionTime,
    required this.timestamp,
  });

  /// Creates empty stats (all zeros).
  factory MihomoStats.empty() => MihomoStats(
        uploadSpeed: 0,
        downloadSpeed: 0,
        totalUpload: 0,
        totalDownload: 0,
        connectionTime: 0,
        timestamp: DateTime.now(),
      );

  /// Creates stats from a map (platform channel response).
  factory MihomoStats.fromMap(Map<String, dynamic> map) => MihomoStats(
        uploadSpeed: map['uploadSpeed'] as int? ?? 0,
        downloadSpeed: map['downloadSpeed'] as int? ?? 0,
        totalUpload: map['totalUpload'] as int? ?? 0,
        totalDownload: map['totalDownload'] as int? ?? 0,
        connectionTime: map['connectionTime'] as int? ?? 0,
        timestamp: DateTime.now(),
      );

  /// Converts stats to a map.
  Map<String, dynamic> toMap() => {
        'uploadSpeed': uploadSpeed,
        'downloadSpeed': downloadSpeed,
        'totalUpload': totalUpload,
        'totalDownload': totalDownload,
        'connectionTime': connectionTime,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  /// Creates a copy with optional modifications.
  MihomoStats copyWith({
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
    int? connectionTime,
    DateTime? timestamp,
  }) =>
      MihomoStats(
        uploadSpeed: uploadSpeed ?? this.uploadSpeed,
        downloadSpeed: downloadSpeed ?? this.downloadSpeed,
        totalUpload: totalUpload ?? this.totalUpload,
        totalDownload: totalDownload ?? this.totalDownload,
        connectionTime: connectionTime ?? this.connectionTime,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  String toString() =>
      'MihomoStats(up: $uploadSpeed B/s, down: $downloadSpeed B/s, '
      'totalUp: $totalUpload, totalDown: $totalDownload, '
      'time: ${connectionTime}s)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MihomoStats &&
          runtimeType == other.runtimeType &&
          uploadSpeed == other.uploadSpeed &&
          downloadSpeed == other.downloadSpeed &&
          totalUpload == other.totalUpload &&
          totalDownload == other.totalDownload &&
          connectionTime == other.connectionTime;

  @override
  int get hashCode =>
      uploadSpeed.hashCode ^
      downloadSpeed.hashCode ^
      totalUpload.hashCode ^
      totalDownload.hashCode ^
      connectionTime.hashCode;
}
