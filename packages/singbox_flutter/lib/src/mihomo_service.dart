import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'mihomo_stats.dart';
import 'mihomo_status.dart';
import 'mihomo_config_generator.dart';
import 'singbox_config_generator.dart';

/// Service for managing Mihomo VPN connections.
class MihomoService {
  static const _methodChannel = MethodChannel('com.velox.singbox_flutter/method');
  static const _eventChannel = EventChannel('com.velox.singbox_flutter/events');

  static MihomoService? _instance;

  /// Gets the singleton instance of MihomoService.
  static MihomoService get instance {
    _instance ??= MihomoService._();
    return _instance!;
  }

  MihomoService._();

  StreamController<MihomoStats>? _statsController;
  StreamController<MihomoStatus>? _statusController;
  StreamSubscription? _eventSubscription;
  MihomoStatus _currentStatus = MihomoStatus.disconnected;
  DateTime? _connectionStartTime;

  /// Current connection status.
  MihomoStatus get status => _currentStatus;

  /// Whether VPN is currently connected.
  bool get isConnected => _currentStatus == MihomoStatus.connected;

  /// Stream of traffic statistics.
  Stream<MihomoStats> get statsStream {
    _statsController ??= StreamController<MihomoStats>.broadcast();
    return _statsController!.stream;
  }

  /// Stream of connection status changes.
  Stream<MihomoStatus> get statusStream {
    _statusController ??= StreamController<MihomoStatus>.broadcast();
    return _statusController!.stream;
  }

  /// Initializes the service and starts listening to platform events.
  Future<void> initialize() async {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handlePlatformEvent,
      onError: _handlePlatformError,
    );
  }

  /// Disposes the service and releases resources.
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _statsController?.close();
    await _statusController?.close();
    _statsController = null;
    _statusController = null;
    _eventSubscription = null;
  }

  /// 切换到另一个已在 config 中的代理节点（原子操作，零停顿）。
  /// 仅通过 Clash API 切换 GLOBAL Selector，Mihomo 进程不重启。
  /// [proxyName] 例如 "proxy-2"（对应 MihomoConfigGenerator.proxyNameForId(2)）。
  Future<bool> switchProxy({required String proxyName}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'switchProxy',
        // Kotlin 侧参数名是 proxyName(跟 Dart 变量名保持一致,不用 'name');
        // 之前误传 'name' → PlatformException(INVALID_ARGUMENT)
        {'proxyName': proxyName},
      );
      return result == true;
    } catch (e) {
      debugPrint('MihomoService: switchProxy error: $e');
      return false;
    }
  }

  /// Connects to a VPN server using the provided configuration.
  Future<void> connect(Map<String, dynamic> serverConfig) async {
    // Use debugPrint for better log visibility in Flutter
    debugPrint('=== MihomoService.connect START ===');
    debugPrint('MihomoService: current status = $_currentStatus');
    debugPrint('MihomoService: serverConfig keys = ${serverConfig.keys.toList()}');

    // 只阻止并发的重复连接请求；已连接时允许 forceReconnect 重新触发。
    // VpnBloc 已在上层保证不会发出真正重复的请求。
    if (_currentStatus == MihomoStatus.connecting) {
      debugPrint('MihomoService: already connecting, skipping duplicate request');
      return;
    }

    _updateStatus(MihomoStatus.connecting);
    debugPrint('MihomoService: status updated to connecting');

    try {
      // Generate sing-box configuration
      debugPrint('MihomoService: generating config...');
      // Android VpnService.Builder 只能建 tun 设备,mihomo 也走 tun 模式接管流量,
      // 所以 Android 上无视 proxy_mode='rule'/'global',永远 tun。desktop 尊重原设定。
      final proxyMode = Platform.isAndroid
          ? 'tun'
          : (serverConfig['proxy_mode'] as String? ?? 'rule');
      final routingMode = serverConfig['routing_mode'] as String?;
      debugPrint('MihomoService: proxyMode = $proxyMode, routingMode = $routingMode');
      final options = MihomoConfigOptions(
        platform: MihomoConfigGenerator.detectPlatform(),
        proxyMode: proxyMode,
        routingMode: routingMode,
      );
      debugPrint('MihomoService: platform = ${options.platform}');

      // allServersConfig: 所有节点列表（若有），用于生成包含全部 proxy 的 config
      final allServersConfig = serverConfig['all_servers'] as List<Map<String, dynamic>>?;
      final selectedId = serverConfig['id'] as int?;

      // 全平台统一 mihomo YAML。原本 Android 走 sing-box JSON,因 sing-box 的
      // xtls-rprx-vision 客户端跟 xray 服务端在 splice 直传阶段兼容不完善(实测 15s
      // deadline + Chrome ERR_CONNECTION_RESET),换回 mihomo 内核跟 macOS 端同栈。
      final String configYaml;
      configYaml = allServersConfig != null && allServersConfig.isNotEmpty
          ? MihomoConfigGenerator.generate(
              servers: allServersConfig,
              selectedServerId: selectedId,
              options: options,
            )
          : MihomoConfigGenerator.generate(
              server: serverConfig,
              options: options,
            );
      debugPrint('MihomoService: ${options.platform} → mihomo YAML (${configYaml.length} chars)');
      debugPrint('MihomoService: config preview:\n${configYaml.substring(0, configYaml.length > 500 ? 500 : configYaml.length)}');

      // 计算选中节点在 Mihomo config 中的代理名称（用于 GLOBAL Selector 切换）
      // type-id 复合命名：跨协议表 ID 重复时不冲突
      String selectedProxyName;
      if (allServersConfig != null && allServersConfig.isNotEmpty && selectedId != null) {
        // 从 allServersConfig 找到选中节点的 type
        final selectedSrv = allServersConfig.firstWhere(
          (s) => s['id'] == selectedId,
          orElse: () => serverConfig,
        );
        selectedProxyName = MihomoConfigGenerator.proxyNameForId(
          selectedId,
          selectedSrv['type'] as String?,
        );
      } else {
        final rawId = serverConfig['id'];
        selectedProxyName = rawId != null
            ? MihomoConfigGenerator.proxyNameForId(
                rawId as int,
                serverConfig['type'] as String?,
              )
            : 'proxy';
      }
      debugPrint('MihomoService: selectedProxyName = $selectedProxyName');

      // Send to platform
      // Windows TUN Plan C: 用 tun_enabled 布尔告知 native 是否需要 ShellExecuteEx runas
      // 提权启动 mihomo（TUN 模式需要打开 Wintun 驱动，必须管理员权限）。
      final tunEnabled = _isTunConfig(configYaml);
      debugPrint('MihomoService: tun_enabled = $tunEnabled (proxyMode=$proxyMode)');
      debugPrint('MihomoService: invoking platform connect via MethodChannel...');
      await _methodChannel.invokeMethod('connect', {
        'config': configYaml,
        'selectedProxyName': selectedProxyName,
        'tun_enabled': tunEnabled,
      });
      debugPrint('MihomoService: platform connect completed successfully');
    } catch (e, stackTrace) {
      debugPrint('MihomoService: connect error: $e');
      debugPrint('MihomoService: stackTrace: $stackTrace');
      _updateStatus(MihomoStatus.error);
      rethrow;
    }
    debugPrint('=== MihomoService.connect END ===');
  }

  /// TUN 模式热重载：生成新配置并通知 Swift PUT /configs?force=true。
  /// 不重启 mihomo 进程，切换延迟 < 500ms。
  /// 返回 true 表示热重载成功；false 时调用方应回退到完整重连。
  Future<bool> patchTunMode({
    required bool enabled,
    required Map<String, dynamic> serverConfig,
  }) async {
    debugPrint('MihomoService: patchTunMode enabled=$enabled');
    try {
      // Android VpnService.Builder 只能建 tun 设备,mihomo 也走 tun 模式接管流量,
      // 所以 Android 上无视 proxy_mode='rule'/'global',永远 tun。desktop 尊重原设定。
      final proxyMode = Platform.isAndroid
          ? 'tun'
          : (serverConfig['proxy_mode'] as String? ?? 'rule');
      final routingMode = serverConfig['routing_mode'] as String?;
      final options = MihomoConfigOptions(
        platform: MihomoConfigGenerator.detectPlatform(),
        proxyMode: proxyMode,
        routingMode: routingMode,
      );

      final allServersConfig =
          serverConfig['all_servers'] as List<Map<String, dynamic>>?;
      final selectedId = serverConfig['id'] as int?;

      final configYaml = (allServersConfig != null && allServersConfig.isNotEmpty)
          ? MihomoConfigGenerator.generate(
              servers: allServersConfig,
              selectedServerId: selectedId,
              options: options,
            )
          : MihomoConfigGenerator.generate(
              server: serverConfig,
              options: options,
            );

      // 计算选中节点名，热重载后需重新切换 GLOBAL/PROXY 选择器
      // type-id 复合命名：跨协议表 ID 重复时不冲突
      final String selectedProxyName;
      if (allServersConfig != null && allServersConfig.isNotEmpty && selectedId != null) {
        final selectedSrv = allServersConfig.firstWhere(
          (s) => s['id'] == selectedId,
          orElse: () => serverConfig,
        );
        selectedProxyName = MihomoConfigGenerator.proxyNameForId(
          selectedId,
          selectedSrv['type'] as String?,
        );
      } else {
        final rawId = serverConfig['id'];
        selectedProxyName = rawId != null
            ? MihomoConfigGenerator.proxyNameForId(
                rawId as int,
                serverConfig['type'] as String?,
              )
            : 'proxy';
      }

      final result = await _methodChannel.invokeMethod<bool>('patchTunMode', {
        'config': configYaml,
        'enabled': enabled,
        'selectedProxyName': selectedProxyName,
        // Windows：patchTunMode 只做 hot-reload,不新起进程,所以不需要提权;
        // 但如果 native 端将来 fallback 到完整重启,可用此字段决定是否走 runas。
        'tun_enabled': enabled,
      });

      debugPrint('MihomoService: patchTunMode result=$result');
      return result == true;
    } catch (e) {
      debugPrint('MihomoService: patchTunMode error: $e');
      return false;
    }
  }

  /// Disconnects from the current VPN server.
  Future<void> disconnect() async {
    if (_currentStatus == MihomoStatus.disconnected ||
        _currentStatus == MihomoStatus.disconnecting) {
      return;
    }

    _updateStatus(MihomoStatus.disconnecting);

    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      _updateStatus(MihomoStatus.error);
      rethrow;
    }
  }

  /// Gets the current traffic statistics.
  Future<MihomoStats> getStats() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getStats');
      if (result != null) {
        final stats = MihomoStats.fromMap(Map<String, dynamic>.from(result));
        return stats;
      }
    } catch (e) {
      // Ignore errors, return empty stats
    }
    return MihomoStats.empty();
  }

  /// Checks if VPN permission is granted (Android/iOS).
  Future<bool> hasVpnPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // Desktop platforms don't need VPN permission
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasVpnPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Requests VPN permission (Android/iOS).
  Future<bool> requestVpnPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 确保特权 Helper 已安装（仅 macOS）。
  /// 首次调用时弹一次管理员密码框安装 LaunchDaemon，之后永不再弹。
  Future<bool> warmupAuth() async {
    if (!Platform.isMacOS) return true;
    try {
      final result = await _methodChannel.invokeMethod<bool>('warmupAuth');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 卸载特权 Helper（仅 macOS，应用卸载时可调用）。
  Future<bool> uninstallHelper() async {
    if (!Platform.isMacOS) return true;
    try {
      final result = await _methodChannel.invokeMethod<bool>('uninstallHelper');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Gets the sing-box core version.
  Future<String> getVersion() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('getVersion');
      return result ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Gets the extension status for debugging.
  Future<Map<String, dynamic>> getExtensionStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getExtensionStatus');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      debugPrint('getExtensionStatus error: $e');
    }
    return {'status': 'error', 'message': 'Failed to get extension status'};
  }

  /// Handles events from the platform.
  void _handlePlatformEvent(dynamic event) {
    debugPrint('MihomoService: received platform event: $event');
    if (event is! Map) {
      debugPrint('MihomoService: event is not a Map, ignoring');
      return;
    }
    final eventMap = Map<String, dynamic>.from(event);
    final type = eventMap['type'] as String?;
    debugPrint('MihomoService: event type = $type');

    switch (type) {
      case 'statusChanged':
        final statusStr = eventMap['status'] as String?;
        debugPrint('MihomoService: statusChanged event, status = $statusStr');
        final newStatus = _parseStatus(statusStr);
        debugPrint('MihomoService: parsed status = $newStatus');
        _updateStatus(newStatus);
        break;

      case 'stats':
        final stats = MihomoStats.fromMap(eventMap);
        _statsController?.add(stats);
        break;

      case 'error':
        debugPrint('MihomoService: error event received');
        // Error message is in eventMap['message'] if needed
        _updateStatus(MihomoStatus.error);
        break;
    }
  }

  /// Handles errors from the platform.
  void _handlePlatformError(dynamic error) {
    _updateStatus(MihomoStatus.error);
  }

  /// Parses status string to enum.
  MihomoStatus _parseStatus(String? status) {
    switch (status) {
      case 'connected':
        return MihomoStatus.connected;
      case 'connecting':
        return MihomoStatus.connecting;
      case 'disconnecting':
        return MihomoStatus.disconnecting;
      case 'disconnected':
        return MihomoStatus.disconnected;
      // Kill Switch:Android 侧 mihomo 保留、tun 保留、PROXY→REJECT。
      // 对 Flutter/UI 层来说底层依然是"VPN 连着且流量被拦",映射成 connected
      // 让 UI 显示"已连接"图标(用户 IP 不泄漏),彻底关闭走通知栏"彻底关闭"按钮。
      // TODO 后续接 UI 后可加独立 MihomoStatus.killSwitch,让 UI 显示"🛡️ 保护中"。
      case 'kill_switch':
        return MihomoStatus.connected;
      case 'error':
        return MihomoStatus.error;
      default:
        return MihomoStatus.disconnected;
    }
  }

  /// Updates status and notifies listeners.
  void _updateStatus(MihomoStatus newStatus) {
    debugPrint('MihomoService: _updateStatus called, current=$_currentStatus, new=$newStatus');
    if (_currentStatus == newStatus) {
      debugPrint('MihomoService: status unchanged, skipping');
      return;
    }

    _currentStatus = newStatus;
    debugPrint('MihomoService: emitting status to statusController');
    _statusController?.add(newStatus);

    if (newStatus == MihomoStatus.connected) {
      debugPrint('MihomoService: recording connection start time');
      _connectionStartTime = DateTime.now();
    } else if (newStatus == MihomoStatus.disconnected) {
      _connectionStartTime = null;
    }
  }

  /// Gets the connection duration in seconds.
  int get connectionDuration {
    if (_connectionStartTime == null) return 0;
    return DateTime.now().difference(_connectionStartTime!).inSeconds;
  }

  /// 扫描 mihomo YAML 里的 `tun:` block，判断 `enable: true` 是否开启。
  /// Windows native 端根据这个值决定是否走 ShellExecuteEx runas 提权路径。
  /// 注意：mihomo 生成的 config 里 `tun.enable` 是 bool，`tun:` block 前无缩进。
  static bool _isTunConfig(String yaml) {
    // 逐行扫,进入 top-level `tun:` block 后找 `enable:` 是否 true
    final lines = yaml.split('\n');
    bool inTunBlock = false;
    for (final raw in lines) {
      final line = raw.replaceAll('\r', '');
      if (line.isEmpty) continue;
      // top-level key（无缩进，冒号结尾）
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        inTunBlock = line.trimRight() == 'tun:';
        continue;
      }
      if (!inTunBlock) continue;
      final t = line.trim();
      if (t.startsWith('enable:')) {
        final v = t.substring('enable:'.length).trim().toLowerCase();
        return v == 'true' || v == 'yes' || v == 'on';
      }
    }
    return false;
  }
}
