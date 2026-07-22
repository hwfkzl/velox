import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/brand.dart';
import '../../app/router.dart';
import '../../presentation/blocs/node/node_bloc.dart';
import '../../presentation/blocs/vpn/vpn_bloc.dart';
import '../../presentation/widgets/in_app_update_dialog.dart';
import '../../presentation/widgets/velox/velox_info_dialog.dart';
import '../storage/storage_keys.dart';
import 'latency_display.dart';
import 'remote_config_service.dart';

/// 桌面(macOS / Windows)菜单栏/托盘图标。
///
/// 类 ClashX 的菜单:节点列表直接在菜单里展开,点击切换;附带延迟测试、更新节点、
/// 路由策略切换、TUN 开关。SSOT 是 SharedPreferences;节点状态通过订阅
/// NodeBloc / VpnBloc 的 stream 自动刷新。
class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _initialized = false;
  StreamSubscription<NodeState>? _nodeSub;
  StreamSubscription<VpnState>? _vpnSub;

  /// 由 app.dart 的 BlocProvider.create 注入。NodeBloc 是 factory 注册,
  /// 必须用 BlocProvider 持有的同一个实例,否则 tray 和 UI 看到的是不同 bloc。
  NodeBloc? _nodeBloc;
  VpnBloc? _vpnBloc;

  Future<void> init() async {
    if (_initialized) return;
    if (!(Platform.isMacOS || Platform.isWindows)) return;

    trayManager.addListener(this);
    // ignore: avoid_print
    print('[TRAY] listener registered');

    await trayManager.setIcon('assets/icons/tray_icon.png');
    await trayManager.setToolTip(Brand.name);
    await _rebuildMenu();

    _initialized = true;
  }

  /// 由 BlocProvider.create 调用,传入 UI 树里实际使用的 bloc 实例。
  /// 每次账号切换(BlocProvider 重建)都会重新注入,订阅随之重建。
  void attachBlocs({required NodeBloc nodeBloc, required VpnBloc vpnBloc}) {
    // 取消旧订阅(账号切换场景)
    _nodeSub?.cancel();
    _vpnSub?.cancel();

    _nodeBloc = nodeBloc;
    _vpnBloc = vpnBloc;
    _nodeSub = nodeBloc.stream.listen((_) => _rebuildMenu());
    _vpnSub = vpnBloc.stream.listen((_) => _rebuildMenu());
    // ignore: avoid_print
    print('[TRAY] blocs attached');
    _rebuildMenu();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await _nodeSub?.cancel();
    await _vpnSub?.cancel();
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }

  Future<void> _rebuildMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final proxyMode = prefs.getString(StorageKeys.proxyMode) ?? 'rule';
    final isTun = proxyMode == 'tun';
    final routingMode = isTun
        ? (prefs.getString(StorageKeys.lastProxyMode) ?? 'rule')
        : proxyMode;

    final nodeState = _nodeBloc?.state ?? NodeInitial();
    final vpnState = _vpnBloc?.state ?? const VpnState();
    // 只有"已连接"时才把 server.id 当作勾选依据;
    // VpnState.server 在断开后仍保留上次连接的节点,不清就会误勾。
    final connectedId = vpnState.status == VpnStatus.connected
        ? vpnState.server?.id
        : null;

    // 状态行
    final statusLabel = _buildStatusLabel(vpnState);

    // 节点 submenu
    final nodeItems = <MenuItem>[];
    if (nodeState is NodeLoaded) {
      if (nodeState.servers.isEmpty) {
        nodeItems.add(
          MenuItem(key: 'node_empty', label: '（无节点）', disabled: true),
        );
      } else {
        final sorted = nodeState.serversSortedByLatency;
        if (nodeState.isPinging) {
          nodeItems.add(
            MenuItem(key: 'node_pinging', label: '测试中…', disabled: true),
          );
          nodeItems.add(MenuItem.separator());
        }
        for (final srv in sorted) {
          if (srv.id == null) continue;
          final name = srv.name ?? '未命名';
          final display = latencyForDisplay(srv.latency, srv.id!);
          final latencyStr = display == null
              ? ''
              : display <= 0
              ? '  ✕'
              : '  ${display}ms';
          nodeItems.add(
            MenuItem.checkbox(
              key: 'node_${srv.id}',
              label: '$name$latencyStr',
              checked: srv.id == connectedId,
            ),
          );
        }
      }
    } else if (nodeState is NodeLoading) {
      nodeItems.add(
        MenuItem(key: 'node_loading', label: '加载中…', disabled: true),
      );
    } else {
      nodeItems.add(
        MenuItem(key: 'node_empty', label: '（暂无数据）', disabled: true),
      );
    }

    final menu = Menu(
      items: [
        MenuItem(
          key: 'status',
          label: statusLabel,
          // 已连接时可点击 → 断开;其他状态保持禁用
          disabled: vpnState.status != VpnStatus.connected,
        ),
        MenuItem.separator(),
        MenuItem(key: 'home', label: '首页'),
        MenuItem.submenu(
          key: 'nodes',
          label: '节点列表',
          submenu: Menu(items: nodeItems),
        ),
        MenuItem(key: 'ping_all', label: '延迟测试'),
        MenuItem(key: 'refresh_nodes', label: '更新节点'),
        MenuItem.separator(),
        MenuItem.submenu(
          key: 'proxy_mode',
          label: '代理模式',
          submenu: Menu(
            items: [
              MenuItem.checkbox(
                key: 'proxy_rule',
                label: '规则代理',
                checked: routingMode == 'rule',
              ),
              MenuItem.checkbox(
                key: 'proxy_global',
                label: '全局代理',
                checked: routingMode == 'global',
              ),
            ],
          ),
        ),
        MenuItem.checkbox(key: 'tun', label: 'TUN 模式', checked: isTun),
        MenuItem.separator(),
        MenuItem(key: 'check_update', label: '检查更新'),
        MenuItem(key: 'quit', label: '退出 ${Brand.name}'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  String _buildStatusLabel(VpnState vpnState) {
    switch (vpnState.status) {
      case VpnStatus.connected:
        final name = vpnState.server?.name ?? '—';
        return '● 已连接 · $name';
      case VpnStatus.connecting:
        return '○ 连接中…';
      case VpnStatus.disconnecting:
        return '○ 断开中…';
      case VpnStatus.disconnected:
        return '○ 未连接';
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // ignore: avoid_print
    print('[TRAY] right mouse down');
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() {
    // ignore: avoid_print
    print('[TRAY] left mouse down');
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    // ignore: avoid_print
    print('[TRAY] menu click: key=${menuItem.key}');

    // 节点选择:key = 'node_<id>'
    final key = menuItem.key;
    if (key != null && key.startsWith('node_')) {
      final idStr = key.substring(5);
      final id = int.tryParse(idStr);
      if (id != null) await _selectNode(id);
      return;
    }

    switch (key) {
      case 'status':
        // 已连接时点击状态行 → 断开
        _vpnBloc?.add(VpnDisconnectRequested());
        break;

      case 'home':
        await _bringToFront();
        AppRouter.router.go('/main/home');
        break;

      case 'ping_all':
        _nodeBloc?.add(NodePingAllRequested());
        break;

      case 'refresh_nodes':
        _nodeBloc?.add(NodeRefreshRequested());
        break;

      case 'proxy_rule':
        await _setProxyMode('rule');
        break;

      case 'proxy_global':
        await _setProxyMode('global');
        break;

      case 'tun':
        await _toggleTun();
        break;

      case 'check_update':
        await _checkUpdate();
        break;

      case 'quit':
        await _quitApp();
        break;
    }
  }

  /// 检查更新(方案 B 辅助更新):
  /// - 无更新 → 弹提示"已是最新版本"
  /// - 有更新 → 弹 InAppUpdateDialog,用户点"立即更新":
  ///     app 内下载 dmg → 剥 xattr(Gatekeeper 放行)→ 打开 dmg 弹 Finder
  ///     → 用户把 Velox.app 拖到 /Applications → 手动重启 Velox
  Future<void> _checkUpdate() async {
    await _bringToFront();
    // 先强制刷新远程配置,再比较版本 —— 否则点"检查更新"
    // 用的是内存里上次拉取的旧配置,改了服务器版本号也检测不到。
    // 拉取失败(超时/断网)时内部静默回退缓存,不会卡死。
    await RemoteConfigService.instance.refreshAndWait();
    final result = await RemoteConfigService.instance.checkForUpdate();
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx == null) return;

    if (result == null) {
      await showVeloxInfoDialog(
        ctx,
        title: '已是最新版本',
        message: '当前已经是最新版本，无需更新。',
        icon: Icons.check_circle_outline_rounded,
      );
      return;
    }

    await showDialog<void>(
      context: ctx,
      barrierDismissible: !result.must,
      builder: (_) => InAppUpdateDialog(result: result),
    );
  }

  /// 从节点 submenu 点击节点 → 切换连接(零停顿热切)
  Future<void> _selectNode(int serverId) async {
    final nodeBloc = _nodeBloc;
    final vpnBloc = _vpnBloc;
    if (nodeBloc == null || vpnBloc == null) return;
    final nodeState = nodeBloc.state;
    if (nodeState is! NodeLoaded) return;

    final server = nodeState.servers.cast<dynamic>().firstWhere(
      (s) => s?.id == serverId,
      orElse: () => null,
    );
    if (server == null) return;

    nodeBloc.add(NodeSelectRequested(server: server));
    vpnBloc.add(
      VpnConnectRequested(server: server, allServers: nodeState.servers),
    );
  }

  Future<void> _setProxyMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(StorageKeys.proxyMode) ?? 'rule';
    final isTun = current == 'tun';

    if (isTun) {
      await prefs.setString(StorageKeys.lastProxyMode, mode);
    } else {
      await prefs.setString(StorageKeys.proxyMode, mode);
      await prefs.setString(StorageKeys.lastProxyMode, mode);
    }

    await _rebuildMenu();
    _vpnBloc?.add(VpnProxyModeChanged(mode: mode));
  }

  Future<void> _toggleTun() async {
    final prefs = await SharedPreferences.getInstance();
    final currentProxyMode = prefs.getString(StorageKeys.proxyMode) ?? 'rule';
    final enable = currentProxyMode != 'tun';

    if (enable) {
      final base = (currentProxyMode == 'tun') ? 'rule' : currentProxyMode;
      await prefs.setString(StorageKeys.lastProxyMode, base);
      await prefs.setString(StorageKeys.proxyMode, 'tun');
      await prefs.setBool(StorageKeys.tunEnabled, true);
    } else {
      final raw =
          prefs.getString(StorageKeys.lastProxyMode) ?? currentProxyMode;
      final restored = (raw == 'tun' || raw.isEmpty) ? 'rule' : raw;
      await prefs.setString(StorageKeys.proxyMode, restored);
      await prefs.setBool(StorageKeys.tunEnabled, false);
    }

    await _rebuildMenu();

    final vpnBloc = _vpnBloc;
    if (vpnBloc == null) return;
    final vpnState = vpnBloc.state;
    if (vpnState.status == VpnStatus.connected && vpnState.server != null) {
      vpnBloc.add(VpnTunModePatched(enabled: enable));
    }
  }

  Future<void> _bringToFront() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      // ignore: avoid_print
      print('[TRAY] bringToFront failed: $e');
    }
  }

  Future<void> _quitApp() async {
    final vpnBloc = _vpnBloc;
    if (vpnBloc != null &&
        (vpnBloc.state.status == VpnStatus.connected ||
            vpnBloc.state.status == VpnStatus.connecting)) {
      vpnBloc.add(VpnDisconnectRequested());
      try {
        await vpnBloc.stream
            .firstWhere((s) => s.status == VpnStatus.disconnected)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    await windowManager.destroy();
  }
}
