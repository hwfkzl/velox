import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:singbox_flutter/singbox_flutter.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/auto_test_service.dart';
import '../../../core/services/user_agent_service.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../data/models/server_model.dart';
import '../../../domain/repositories/user_repository.dart';

part 'vpn_event.dart';
part 'vpn_state.dart';

final _logger = appLogger(tag: 'VpnBloc');

class VpnBloc extends Bloc<VpnEvent, VpnState> {
  final MihomoService _mihomoService;
  final UserRepository? _userRepository;
  final AutoTestService? _autoTestService;
  StreamSubscription<MihomoStatus>? _statusSubscription;
  StreamSubscription<MihomoStats>? _statsSubscription;
  StreamSubscription<void>? _autoTestCompletedSubscription;

  // 连通性检测
  Timer? _connectivityTimer;
  bool _hadTrafficSinceConnect = false;
  bool _pendingConnectivityError = false;
  String _currentProxyMode = 'rule'; // 记录当前连接的代理模式

  VpnBloc({
    MihomoService? mihomoService,
    UserRepository? userRepository,
    AutoTestService? autoTestService,
  })  : _mihomoService = mihomoService ?? MihomoService.instance,
        _userRepository = userRepository,
        _autoTestService = autoTestService,
        super(const VpnState()) {
    on<VpnConnectRequested>(_onConnectRequested);
    on<VpnDisconnectRequested>(_onDisconnectRequested);
    on<VpnTunModePatched>(_onTunModePatched);
    on<VpnProxyModeChanged>(_onProxyModeChanged);
    on<VpnConnectionTimeUpdated>(_onConnectionTimeUpdated);
    on<VpnSpeedUpdated>(_onSpeedUpdated);
    on<VpnServerChanged>(_onServerChanged);
    on<_VpnStatusChanged>(_onStatusChanged);
    on<_VpnStatsUpdated>(_onStatsUpdated);
    on<_VpnConnectivityFailed>(_onConnectivityFailed);
    on<VpnAuthCleared>(_onAuthCleared);

    _initService();
  }

  Future<void> _onAuthCleared(
    VpnAuthCleared event,
    Emitter<VpnState> emit,
  ) async {
    // 退出账号前若仍连接，先断开（避免账号 B 的 UI 显示 A 的连接）
    if (state.status == VpnStatus.connected ||
        state.status == VpnStatus.connecting) {
      try {
        await _mihomoService.disconnect();
      } catch (_) {}
    }
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    _hadTrafficSinceConnect = false;
    _pendingConnectivityError = false;
    // 清除"上次已连接"，防止下次启动用旧账号的节点自动重连
    // 同时清账号级偏好（proxyMode/tunEnabled/lastProxyMode），实现账号隔离：
    // 账号 B 登录后不应继承账号 A 的 TUN/规则模式选择。
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vpn_was_connected', false);
      await prefs.remove(StorageKeys.proxyMode);
      await prefs.remove(StorageKeys.tunEnabled);
      await prefs.remove(StorageKeys.lastProxyMode);
      await prefs.remove(StorageKeys.lastServer);
    } catch (_) {}
    _currentProxyMode = 'rule'; // 重置 bloc 内存字段，下次连接从 prefs 默认值 'rule' 重读
    emit(const VpnState());
  }

  Future<void> _initService() async {
    _logger.i('VpnBloc: _initService called');
    await _mihomoService.initialize();
    _logger.i('VpnBloc: mihomoService initialized');
    _subscribeToService();
    _logger.i('VpnBloc: subscribed to service');
    // 启动时修复历史脏数据：lastProxyMode 不应为 'tun'
    _fixStalePrefs();
    // 打开 App 不再自动连接 —— 用户明确要求手动触发。以前会读 vpn_was_connected
    // + lastServer 自动 dispatch VpnConnectRequested,导致"一打开 app 就连"。
    // 若日后想做"开机自启"或"意外掉线自愈"可以重新启用 _autoReconnectIfNeeded()。
    // _autoReconnectIfNeeded();
  }

  /// 修复历史脏 prefs：lastProxyMode 存成 'tun' 会导致关闭 TUN 后继续以 TUN 重连。
  Future<void> _fixStalePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMode = prefs.getString(StorageKeys.lastProxyMode);
      if (lastMode == 'tun' || lastMode == 'direct') {
        await prefs.setString(StorageKeys.lastProxyMode, 'rule');
        _logger.w('VpnBloc: fixed stale lastProxyMode=$lastMode → rule');
      }
    } catch (_) {}
  }

  /// 行业标准自动重连：应用启动时检查上次连接状态，若 wasConnected=true 则自动重连。
  Future<void> _autoReconnectIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('vpn_was_connected') ?? false;
      if (!wasConnected) return;

      final lastServerJson = prefs.getString(StorageKeys.lastServer);
      if (lastServerJson == null) return;

      final serverMap = jsonDecode(lastServerJson) as Map<String, dynamic>;
      final server = ServerModel.fromJson(serverMap);
      // Fast-switch 修:从 prefs 读回全节点列表,传给 config generator 让 PROXY
      // selector 包含所有节点。冷启动后第一次切节点也走 fast-switch,不用 fallback。
      List<ServerModel>? allServers;
      final allJson = prefs.getString('vpn_last_all_servers');
      if (allJson != null) {
        try {
          final list = jsonDecode(allJson) as List;
          allServers = list
              .map((s) => ServerModel.fromJson(s as Map<String, dynamic>))
              .toList();
        } catch (e) {
          _logger.w('VpnBloc: parse vpn_last_all_servers failed: $e');
        }
      }
      _logger.i('VpnBloc: auto-reconnect to ${server.name} '
          '(allServers=${allServers?.length ?? 0})');

      // 延迟 1s 等待 UI 完全加载后再重连
      await Future.delayed(const Duration(seconds: 1));
      // P1-3 修复:防跟用户手 tap race。1s 窗口内用户可能自己选了别的节点/主动连,
      // 若 state 已不是"未连接且无 server",说明用户或其它系统先动手了,不再跟他打架。
      if (isClosed) return;
      if (state.status != VpnStatus.disconnected || state.server != null) {
        _logger.i('VpnBloc: auto-reconnect skipped — user or system already acting '
            '(status=${state.status}, hasServer=${state.server != null})');
        return;
      }
      add(VpnConnectRequested(server: server, allServers: allServers));
    } catch (e) {
      _logger.w('VpnBloc: auto-reconnect failed: $e');
    }
  }

  void _subscribeToService() {
    _statusSubscription?.cancel();
    _statsSubscription?.cancel();
    _autoTestCompletedSubscription?.cancel();

    _statusSubscription = _mihomoService.statusStream.listen((status) {
      add(_VpnStatusChanged(status: status));
    });

    _statsSubscription = _mihomoService.statsStream.listen((stats) {
      add(_VpnStatsUpdated(stats: stats));
    });

    // 订阅自动测速完成事件（URLTest 自动切换逻辑）
    // 每次 AutoTestService 周期测速跑完 → 检查是否需要切到更优节点
    _autoTestCompletedSubscription = _autoTestService?.runOnceCompleted.listen((_) {
      _onAutoTestCompleted();
    });
  }

  /// 周期测速完成后的自动切换逻辑（URLTest 核心）
  /// 条件：
  ///   1. 用户开启了"自动选择"开关
  ///   2. VPN 当前处于 connected 状态
  ///   3. 有节点列表（allServers 非空）
  ///   4. pickBestWithTolerance 返回的推荐节点 != 当前节点
  /// 满足时触发 VpnConnectRequested → bloc 走 fast-switch 路径（PUT /proxies/GLOBAL 零停顿）
  Future<void> _onAutoTestCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSelect = prefs.getBool(StorageKeys.autoConnect) ?? false;
      if (!autoSelect) return;

      if (state.status != VpnStatus.connected || state.server == null) return;

      final servers = state.allServers;
      if (servers == null || servers.isEmpty) return;

      final recommended = _autoTestService?.pickBestWithTolerance(
        servers,
        state.server!.id,
      );
      if (recommended == null) return;
      if (recommended.id == state.server!.id) return; // 已是最优

      _logger.i('[AutoSelect] 后台切换：${state.server!.name} → ${recommended.name}');
      add(VpnConnectRequested(
        server: recommended,
        allServers: servers,
      ));
    } catch (e) {
      _logger.w('[AutoSelect] 后台切换检查失败: $e');
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _statsSubscription?.cancel();
    _autoTestCompletedSubscription?.cancel();
    _connectivityTimer?.cancel();
    _mihomoService.dispose();
    return super.close();
  }

  Future<void> _onConnectRequested(
    VpnConnectRequested event,
    Emitter<VpnState> emit,
  ) async {
    _logger.i('=== VpnBloc._onConnectRequested START ===');
    _logger.i('VpnBloc: server name = ${event.server.name}');
    _logger.i('VpnBloc: server host = ${event.server.host}');
    _logger.i('VpnBloc: server port = ${event.server.port}');
    _logger.i('VpnBloc: current state.status = ${state.status}');
    _logger.i('VpnBloc: current server = ${state.server?.name}');

    // If currently connecting, don't interrupt (unless force reconnect)
    if (state.status == VpnStatus.connecting && !event.forceReconnect) {
      _logger.w('VpnBloc: currently connecting, returning');
      return;
    }

    // If connected to the same server and not force reconnecting, do nothing
    if (state.status == VpnStatus.connected &&
        state.server?.id == event.server.id &&
        !event.forceReconnect) {
      _logger.w('VpnBloc: already connected to this server, returning');
      return;
    }

    // 提前读取 SharedPreferences（后续逻辑复用，避免重复 IO）
    final prefs = await SharedPreferences.getInstance();
    final proxyMode = prefs.getString(StorageKeys.proxyMode) ?? 'rule';

    // ── 行业标准：已连接时直接切换节点（零停顿，不重启 Mihomo）────────────────
    // 首次连接时已将所有节点写入 Mihomo config（all_servers），
    // 切换时只需 PUT /proxies/GLOBAL 即可，Mihomo 进程不重启，系统代理/TUN 全程保持，无本地 IP 闪烁。
    if (state.status == VpnStatus.connected &&
        !event.forceReconnect &&
        event.server.id != null) {
      final proxyName = MihomoConfigGenerator.proxyNameForId(
        event.server.id!,
        event.server.type,
      );
      _logger.i('VpnBloc: fast-switching to $proxyName (no Mihomo restart)');
      emit(state.copyWith(status: VpnStatus.connecting, server: event.server, clearError: true));
      final switched = await _mihomoService.switchProxy(proxyName: proxyName);
      if (switched) {
        _logger.i('VpnBloc: switchProxy OK, emitting connected');
        _autoTestService?.setVpnState(connected: true, connectedServerId: event.server.id);
        emit(state.copyWith(status: VpnStatus.connected));
        _logger.i('=== VpnBloc._onConnectRequested END (fast-switch) ===');
        return;
      }
      // 切换失败（节点名不在 config 中），回退到完整重连
      _logger.w('VpnBloc: switchProxy failed, falling back to full connect');
    }

    _logger.i('VpnBloc: emitting connecting status');
    emit(state.copyWith(
      status: VpnStatus.connecting,
      server: event.server,
      clearError: true,
      // 保存全节点列表，供 TUN 热重载时重新生成完整配置
      allServers: event.allServers ?? state.allServers,
    ));
    _logger.i('VpnBloc: state emitted');

    try {
      // Check VPN permission first (Android/iOS)
      final hasPermission = await _mihomoService.hasVpnPermission();
      if (!hasPermission) {
        final granted = await _mihomoService.requestVpnPermission();
        if (!granted) {
          emit(state.copyWith(
            status: VpnStatus.disconnected,
            error: 'VPN permission denied',
          ));
          return;
        }
      }

      // Get user's UUID for password
      String? userUuid;
      if (_userRepository != null) {
        final user = _userRepository.getCachedUserInfo();
        userUuid = user?.uuid;
        _logger.i('VpnBloc: user uuid = $userUuid');
      } else {
        _logger.w('VpnBloc: userRepository is null!');
      }

      // 代理模式已在函数顶部读取（prefs / proxyMode）
      _currentProxyMode = proxyMode;
      _logger.i('VpnBloc: proxyMode = $proxyMode');

      // 路由层：TUN 模式下从 lastProxyMode 读取用户选择的路由策略，
      // 非 TUN 模式下路由层与 proxyMode 一致。
      // 参照 Clash Verge / sing-box 官方：TUN 与 rule/global 正交独立。
      final isTun = proxyMode == 'tun';
      final routingMode = isTun
          ? (prefs.getString(StorageKeys.lastProxyMode) ?? 'rule')
          : proxyMode;
      _logger.i('VpnBloc: routingMode = $routingMode (isTun=$isTun)');

      // Convert ServerModel to config map with user UUID
      final serverConfig = _serverToConfigMap(event.server, userUuid: userUuid);
      serverConfig['proxy_mode'] = proxyMode;
      serverConfig['routing_mode'] = routingMode;

      // ── 行业标准：首次连接时将所有节点写入 config，后续切换只需 PUT /proxies/GLOBAL ──
      // event.allServers 由 nodes_page 在点击节点时传入完整节点列表
      if (event.allServers != null && event.allServers!.isNotEmpty) {
        final allServersConfigList = event.allServers!
            .map((s) => _serverToConfigMap(s, userUuid: userUuid))
            .toList();
        serverConfig['all_servers'] = allServersConfigList;
        _logger.i('VpnBloc: including ${allServersConfigList.length} servers in config');
      }

      _logger.i('VpnBloc: serverConfig keys = ${serverConfig.keys.toList()}');

      // Connect using Mihomo via VPN service
      _logger.i('VpnBloc: calling mihomoService.connect...');
      await _mihomoService.connect(serverConfig);
      _logger.i('VpnBloc: connect call completed');
      _logger.i('=== VpnBloc._onConnectRequested END (success) ===');

      // Status will be updated via stream subscription
    } catch (e, stackTrace) {
      _logger.e('VpnBloc: connect error: $e', error: e, stackTrace: stackTrace);
      _logger.i('=== VpnBloc._onConnectRequested END (error) ===');
      emit(state.copyWith(
        status: VpnStatus.disconnected,
        error: extractErrorMessage(e),
      ));
    }
  }

  Future<void> _onDisconnectRequested(
    VpnDisconnectRequested event,
    Emitter<VpnState> emit,
  ) async {
    if (state.status == VpnStatus.disconnecting ||
        state.status == VpnStatus.disconnected) {
      return;
    }

    emit(state.copyWith(status: VpnStatus.disconnecting));

    try {
      await _mihomoService.disconnect();
      // Status will be updated via stream subscription
    } catch (e) {
      emit(state.copyWith(
        status: VpnStatus.connected,
        error: extractErrorMessage(e),
      ));
    }
  }

  /// TUN 模式切换：开/关 TUN = root↔用户 权限切换。
  /// 行为：
  ///   - 未连接：只持久化 prefs，下次点"连接"时由 _onConnectRequested 按新 proxy_mode 启动对应权限核心
  ///   - 已连接：持久化 prefs 后发起 forceReconnect（不能热重载，必须停旧核心起新权限核心）
  /// lastProxyMode 永不存 'tun'，防脏数据。
  Future<void> _onTunModePatched(
    VpnTunModePatched event,
    Emitter<VpnState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final wasConnected =
        state.status == VpnStatus.connected && state.server != null;

    // 计算切换后的"路由模式"（rule/global），同时持久化（lastProxyMode 永不存 'tun'）。
    final String routingMode;
    if (event.enabled) {
      final source = wasConnected
          ? _currentProxyMode
          : (prefs.getString(StorageKeys.proxyMode) ?? 'rule');
      final modeToSave = (source == 'tun' || source.isEmpty) ? 'rule' : source;
      await prefs.setString(StorageKeys.lastProxyMode, modeToSave);
      await prefs.setString(StorageKeys.proxyMode, 'tun');
      await prefs.setBool(StorageKeys.tunEnabled, true);
      routingMode = modeToSave;
      _logger.i('VpnBloc: TUN on → proxyMode=tun (routing=$modeToSave), connected=$wasConnected');
    } else {
      final raw = prefs.getString(StorageKeys.lastProxyMode) ?? 'rule';
      final restored = (raw == 'tun' || raw.isEmpty) ? 'rule' : raw;
      await prefs.setString(StorageKeys.proxyMode, restored);
      await prefs.setBool(StorageKeys.tunEnabled, false);
      routingMode = restored;
      _logger.i('VpnBloc: TUN off → proxyMode=$restored, connected=$wasConnected');
    }

    // 未连接：到此为止，下次点连接时生效。
    if (!wasConnected) return;

    // CV 式：核心永远 root 服务 → 开/关 TUN 都走热重载（PUT /configs），
    // 进程不重启、连接不中断。UI 一闪 connecting → connected，绝不出现"断开"。
    emit(state.copyWith(status: VpnStatus.connecting));
    try {
      final userUuid = _userRepository?.getCachedUserInfo()?.uuid;
      final serverConfig = _serverToConfigMap(state.server!, userUuid: userUuid);
      serverConfig['proxy_mode'] = event.enabled ? 'tun' : routingMode;
      serverConfig['routing_mode'] = routingMode;
      final servers = state.allServers;
      if (servers != null && servers.isNotEmpty) {
        serverConfig['all_servers'] =
            servers.map((s) => _serverToConfigMap(s, userUuid: userUuid)).toList();
      }
      final ok = await _mihomoService.patchTunMode(
        enabled: event.enabled,
        serverConfig: serverConfig,
      );
      if (ok) {
        emit(state.copyWith(status: VpnStatus.connected));
      } else {
        _logger.w('VpnBloc: TUN hot-reload failed, full reconnect');
        add(VpnConnectRequested(
          server: state.server!,
          forceReconnect: true,
          allServers: state.allServers,
        ));
      }
    } catch (e, st) {
      _logger.e('VpnBloc: TUN hot-reload error', error: e, stackTrace: st);
      add(VpnConnectRequested(
        server: state.server!,
        forceReconnect: true,
        allServers: state.allServers,
      ));
    }
  }

  /// 路由策略切换（rule / global）。
  /// 与 nodes_page 直接写 prefs 的 TUN 分支语义完全对齐：
  ///   - TUN 开：只改 lastProxyMode，保持 proxyMode='tun'
  ///   - TUN 关：同时写 proxyMode 和 lastProxyMode
  /// 非 TUN 下已连接时，发 VpnConnectRequested(forceReconnect:true) 触发重连。
  Future<void> _onProxyModeChanged(
    VpnProxyModeChanged event,
    Emitter<VpnState> emit,
  ) async {
    if (event.mode != 'rule' && event.mode != 'global') {
      _logger.w('VpnBloc: invalid proxy mode "${event.mode}", ignoring');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final currentPersisted = prefs.getString(StorageKeys.proxyMode) ?? 'rule';
    final isTun = currentPersisted == 'tun';

    if (isTun) {
      await prefs.setString(StorageKeys.lastProxyMode, event.mode);
      _logger.i('VpnBloc: TUN routing → ${event.mode}');
    } else {
      await prefs.setString(StorageKeys.proxyMode, event.mode);
      await prefs.setString(StorageKeys.lastProxyMode, event.mode);
      _currentProxyMode = event.mode;
      _logger.i('VpnBloc: proxy mode → ${event.mode}');
    }

    // 持久化后，若未连接则到此为止（下次连接生效）。
    if (state.status != VpnStatus.connected || state.server == null) return;

    if (isTun) {
      // TUN 开着切 rule/global：热重载 config（proxy_mode 仍 tun，routing_mode 换新），
      // 进程不重启、代理不中断 —— 对标 Clash Verge 切 mode 的即时性。
      // （不能复用 VpnTunModePatched(enabled:true)：它的开启分支会把 lastProxyMode
      //  强制改回 'rule'，反而冲掉刚选的模式。）
      _logger.i('VpnBloc: hot-reloading routing=${event.mode} under TUN');
      emit(state.copyWith(status: VpnStatus.connecting));
      try {
        final userUuid = _userRepository?.getCachedUserInfo()?.uuid;
        final serverConfig = _serverToConfigMap(state.server!, userUuid: userUuid);
        serverConfig['proxy_mode'] = 'tun';
        serverConfig['routing_mode'] = event.mode;
        final servers = state.allServers;
        if (servers != null && servers.isNotEmpty) {
          serverConfig['all_servers'] =
              servers.map((s) => _serverToConfigMap(s, userUuid: userUuid)).toList();
        }
        final ok = await _mihomoService.patchTunMode(
          enabled: true,
          serverConfig: serverConfig,
        );
        if (ok) {
          emit(state.copyWith(status: VpnStatus.connected));
        } else {
          _logger.w('VpnBloc: routing hot-reload failed, full reconnect');
          add(VpnConnectRequested(
            server: state.server!,
            forceReconnect: true,
            allServers: state.allServers,
          ));
        }
      } catch (e, st) {
        _logger.e('VpnBloc: routing hot-reload error', error: e, stackTrace: st);
        add(VpnConnectRequested(
          server: state.server!,
          forceReconnect: true,
          allServers: state.allServers,
        ));
      }
    } else {
      // 非 TUN：完整重连使新模式立即生效。
      _logger.i('VpnBloc: reconnecting to apply new proxy mode');
      add(VpnConnectRequested(
        server: state.server!,
        forceReconnect: true,
        allServers: state.allServers,
      ));
    }
  }

  /// 保存/清除"上次 VPN 连接状态"，供下次启动自动重连使用。
  /// 必须 await：Cmd+Q 退出时 tray._quitApp 等 disconnected 状态后立刻 destroy()，
  /// 这里若 fire-and-forget 则 vpn_was_connected=false 可能未落盘 → 下次启动误自动重连。
  Future<void> _saveLastConnectedState({required bool connected}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vpn_was_connected', connected);
    if (connected && state.server != null) {
      // 保存当前连接的节点信息（用于自动重连）
      await prefs.setString(StorageKeys.lastServer, jsonEncode(state.server!.toJson()));
      // Fast-switch 修复:同时保存全节点列表。auto-reconnect 时读回来传给 config
      // generator,让 PROXY selector 包含所有节点,冷启动后第一次切节点也能 fast-switch。
      // 之前 auto-reconnect 只传单节点 → PROXY selector 只有 1 项 → 切他方节点报
      // "proxy not exist" 400 → fallback 到 full reconnect(慢 5s)。
      final all = state.allServers;
      if (all != null && all.isNotEmpty) {
        await prefs.setString(
          'vpn_last_all_servers',
          jsonEncode(all.map((s) => s.toJson()).toList()),
        );
      }
    }
  }

  Future<void> _onStatusChanged(
    _VpnStatusChanged event,
    Emitter<VpnState> emit,
  ) async {
    final vpnStatus = _mihomoStatusToVpnStatus(event.status);

    if (vpnStatus == VpnStatus.connected) {
      // 连上后启动 5 秒连通性检测倒计时
      _hadTrafficSinceConnect = false;
      _connectivityTimer?.cancel();
      _connectivityTimer = Timer(const Duration(seconds: 20), _checkConnectivity);
      // 通知 AutoTestService：VPN 已连接，使用 Clash API 测速
      _autoTestService?.setVpnState(
        connected: true,
        connectedServerId: state.server?.id,
      );
      // 保存"上次已连接"状态，供下次启动自动重连使用
      await _saveLastConnectedState(connected: true);
    }

    if (vpnStatus == VpnStatus.disconnected || vpnStatus == VpnStatus.disconnecting) {
      _connectivityTimer?.cancel();
      if (vpnStatus == VpnStatus.disconnected) {
        _connectivityTimer = null;
        // 通知 AutoTestService：VPN 已断开，回退到 TCP Ping
        _autoTestService?.setVpnState(connected: false);
        // 主动断开时清除"已连接"标记，不自动重连。
        // 这里必须 await：tray._quitApp 等 disconnected 状态后立刻退出，
        // 不 await 会让 prefs 写盘竞速，导致下次启动误自动重连。
        await _saveLastConnectedState(connected: false);
      }
    }

    // 若 _pendingConnectivityError 为真，说明是因节点不通而断开，保留错误信息
    final String? error;
    if (_pendingConnectivityError && vpnStatus == VpnStatus.disconnected) {
      error = 'node_unreachable';
      _pendingConnectivityError = false;
    } else {
      error = event.status == MihomoStatus.error ? state.error : null;
    }

    emit(state.copyWith(status: vpnStatus, error: error));

    if (vpnStatus == VpnStatus.disconnected) {
      // 重置统计数据，同时保留 error 字段
      emit(state.copyWith(
        connectionTime: 0,
        uploadSpeed: 0,
        downloadSpeed: 0,
        error: state.error,
      ));
    }
  }

  void _onStatsUpdated(
    _VpnStatsUpdated event,
    Emitter<VpnState> emit,
  ) {
    // 检测到流量 → 节点正常，取消连通性检测定时器
    if (!_hadTrafficSinceConnect &&
        state.status == VpnStatus.connected &&
        (event.stats.uploadSpeed > 0 || event.stats.downloadSpeed > 0)) {
      _hadTrafficSinceConnect = true;
      _connectivityTimer?.cancel();
      _connectivityTimer = null;
      _logger.i('VpnBloc: traffic detected, node is working');
    }

    emit(state.copyWith(
      uploadSpeed: event.stats.uploadSpeed,
      downloadSpeed: event.stats.downloadSpeed,
      totalUpload: event.stats.totalUpload,
      totalDownload: event.stats.totalDownload,
      connectionTime: event.stats.connectionTime,
    ));
  }

  void _onConnectionTimeUpdated(
    VpnConnectionTimeUpdated event,
    Emitter<VpnState> emit,
  ) {
    emit(state.copyWith(connectionTime: event.seconds));
  }

  void _onSpeedUpdated(
    VpnSpeedUpdated event,
    Emitter<VpnState> emit,
  ) {
    emit(state.copyWith(
      uploadSpeed: event.uploadSpeed,
      downloadSpeed: event.downloadSpeed,
      totalUpload: state.totalUpload + event.uploadSpeed,
      totalDownload: state.totalDownload + event.downloadSpeed,
    ));
  }

  void _onServerChanged(
    VpnServerChanged event,
    Emitter<VpnState> emit,
  ) {
    emit(state.copyWith(server: event.server));
  }

  /// Converts MihomoStatus to VpnStatus
  VpnStatus _mihomoStatusToVpnStatus(MihomoStatus status) {
    switch (status) {
      case MihomoStatus.connected:
        return VpnStatus.connected;
      case MihomoStatus.connecting:
        return VpnStatus.connecting;
      case MihomoStatus.disconnecting:
        return VpnStatus.disconnecting;
      case MihomoStatus.disconnected:
      case MihomoStatus.error:
        return VpnStatus.disconnected;
    }
  }

  /// Converts ServerModel to configuration map for Mihomo config generator
  Map<String, dynamic> _serverToConfigMap(ServerModel server, {String? userUuid}) {
    // Build protocol settings with user UUID as password
    final protocolSettings = Map<String, dynamic>.from(server.protocolSettings ?? {});

    // 解析真实协议类型，处理两层包装：
    // (1) v2node 是后端 server_v2node 表的多协议容器（统一表 + 多种协议），
    //     真实协议在 protocol 字段。对齐后端 Singbox/ClashMeta 的
    //     `if (item.type === 'v2node') item.type = item.protocol` 适配模式。
    // (2) V2Board 的 hysteria 表把 v1/v2 都存 type='hysteria'，靠 version 区分。
    final rawTypeFromServer = (server.type ?? '').toLowerCase();
    final rawProtocol = (server.protocol ?? '').toLowerCase();
    final String rawType;
    if (rawTypeFromServer == 'v2node' && rawProtocol.isNotEmpty) {
      rawType = rawProtocol;
    } else if (rawTypeFromServer.isNotEmpty) {
      rawType = rawTypeFromServer;
    } else if (rawProtocol.isNotEmpty) {
      rawType = rawProtocol;
    } else {
      rawType = 'shadowsocks';
    }
    final effectiveType = (rawType == 'hysteria' && server.version == 2)
        ? 'hysteria2'
        : rawType;

    // For shadowsocks/trojan/hysteria2, password is the user's UUID
    // For vmess/vless, uuid is the user's UUID
    if (userUuid != null && userUuid.isNotEmpty) {
      if (effectiveType == 'shadowsocks') {
        final cipher = server.cipher ?? '';
        if (cipher.contains('2022-blake3')) {
          // SS2022 密码格式：serverKey:userKey，两者均为 base64
          // 与后端 Helper::uuidToBase64 / Helper::getServerKey 保持一致
          final keyLen = cipher == '2022-blake3-aes-128-gcm' ? 16 : 32;
          final userKey = base64Encode(
            utf8.encode(userUuid.substring(0, min(keyLen, userUuid.length))),
          );
          final createdAt = server.createdAt;
          if (createdAt != null) {
            final md5Hex = md5.convert(utf8.encode(createdAt.toString())).toString();
            final serverKey = base64Encode(
              utf8.encode(md5Hex.substring(0, min(keyLen, md5Hex.length))),
            );
            protocolSettings['password'] = '$serverKey:$userKey';
          } else {
            protocolSettings['password'] = userKey;
          }
        } else {
          protocolSettings['password'] ??= userUuid;
        }
      } else if (effectiveType == 'trojan' || effectiveType == 'hysteria2' || effectiveType == 'hy2') {
        protocolSettings['password'] ??= userUuid;
      } else if (effectiveType == 'vmess' || effectiveType == 'vless') {
        protocolSettings['uuid'] ??= userUuid;
      } else if (effectiveType == 'hysteria') {
        // Hysteria v1 uses auth_str
        protocolSettings['auth_str'] ??= userUuid;
      } else if (effectiveType == 'tuic') {
        // TUIC：uuid 和 password 均使用用户 UUID
        protocolSettings['uuid'] ??= userUuid;
        protocolSettings['password'] ??= userUuid;
      } else if (effectiveType == 'anytls') {
        protocolSettings['password'] ??= userUuid;
        if (server.paddingScheme != null) {
          protocolSettings['padding_scheme'] ??= server.paddingScheme;
        }
      }
    }

    // Hysteria v1: inject top-level bandwidth fields into protocol_settings
    if (effectiveType == 'hysteria') {
      if (server.upMbps != null) protocolSettings['up_mbps'] ??= server.upMbps;
      if (server.downMbps != null) protocolSettings['down_mbps'] ??= server.downMbps;
    }

    // TUIC: inject top-level DB columns into protocol_settings
    if (effectiveType == 'tuic') {
      if (server.congestionControl != null) {
        protocolSettings['congestion_control'] ??= server.congestionControl;
      }
      if (server.udpRelayMode != null) {
        protocolSettings['udp_relay_mode'] ??= server.udpRelayMode;
      }
      if (server.zeroRttHandshake != null) {
        protocolSettings['zero_rtt_handshake'] ??= server.zeroRttHandshake;
      }
    }

    // Merge top-level TLS fields (server_name, allow_insecure, insecure) into tls_settings.
    // V2Board stores these as separate DB columns for Trojan/Hysteria/Tuic nodes.
    final tlsSettings = Map<String, dynamic>.from(server.tlsSettings ?? {});
    if (server.serverName != null && server.serverName!.isNotEmpty) {
      tlsSettings['server_name'] ??= server.serverName;
    }
    if (server.allowInsecure != null) {
      // Trojan uses allow_insecure column
      tlsSettings['allow_insecure'] ??= server.allowInsecure;
    }
    if (server.insecure != null) {
      // Hysteria/Tuic use insecure column
      tlsSettings['allow_insecure'] ??= server.insecure;
    }
    if (server.disableSni != null) {
      // TUIC 专用
      tlsSettings['disable_sni'] ??= server.disableSni;
    }
    // Hysteria v1/v2 的 obfs 字段存在顶层 DB 列，不在 obfs_settings JSON 里，
    // 需要按版本重新组装成 MihomoConfigGenerator 期望的格式。
    final Map<String, dynamic> obfsSettings;
    if (effectiveType == 'hysteria' && server.obfs != null) {
      // v1：obfs 字段本身就是混淆密码字符串
      obfsSettings = {'password': server.obfs};
    } else if ((effectiveType == 'hysteria2' || effectiveType == 'hy2') &&
        server.obfs != null) {
      // v2：obfs 是混淆类型（如 salamander），obfsPassword 是密码
      obfsSettings = {
        'type': server.obfs,
        'password': server.obfsPassword ?? '',
      };
    } else {
      obfsSettings = server.obfsSettings ?? {};
    }

    return {
      'id': server.id,
      'name': server.name,
      'host': server.host,
      'port': server.port,
      'mport': server.mport,
      'server_port': server.serverPort,
      // type 保留原始 ServerModel.type（如 'v2node' / 'hysteria'）——proxy 名字格式是
      // `<type>-<id>`，跨表 ID 重复时（v2_server_v2node 与 v2_server_vmess 各自 id=5）
      // 必须用原始 type 区分，否则 mihomo YAML duplicate name 解析失败。
      'type': server.type ?? effectiveType,
      // effective_type 是 v2node 解包 + hysteria v1/v2 推断后的真实协议，
      // 供 mihomo_config_generator 在 switch 里识别（mihomo 不认 'v2node'）。
      'effective_type': effectiveType,
      'cipher': server.cipher,
      'protocol': server.protocol,
      'protocol_settings': protocolSettings,
      'network': server.network,
      'network_settings': server.networkSettings ?? {},
      'tls': server.tls,
      'tls_settings': tlsSettings,
      'obfs_settings': obfsSettings,
      'flow': server.flow,
      // VLESS 后量子加密（v2node 引入）— 上层透传，由 mihomo_config_generator vless case 拼成
      // 'algorithm.mode.rtt[.padding].password' 单字符串，对齐后端 ClashMeta::buildVless 输出格式
      'encryption': server.encryption,
      'encryption_settings': server.encryptionSettings,
    };
  }

  /// 5 秒后仍无流量 → 通过 VPN 隧道 ping generate_204 验证连通性
  Future<void> _checkConnectivity() async {
    if (isClosed || state.status != VpnStatus.connected || _hadTrafficSinceConnect) return;

    _logger.w('VpnBloc: 5s no traffic, pinging generate_204 via VPN tunnel...');
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: {'User-Agent': UserAgentService.instance.value},
      ));

      // 桌面端:统一覆盖 Dart HttpClient 的代理策略,避免它读到 macOS 系统代理残留
      // (历史污染:旧版本/动态端口 Mihomo 退出时没清理系统代理,残留 127.0.0.1:<随机口> 指向死端口)
      // - TUN 模式:强制 DIRECT,让 kernel 层 utun 劫持,绕开系统代理
      // - 非 TUN:显式指向 Mihomo 的 mixed-port(默认 17890,对应 MihomoConfigOptions.proxyPort)
      final isTunMode = _currentProxyMode == 'tun';
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (uri) =>
              isTunMode ? 'DIRECT' : 'PROXY 127.0.0.1:17890';
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        };
      }

      final response = await dio.get(
        'http://www.gstatic.com/generate_204',
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null,
        ),
      );
      if (response.statusCode == 204) {
        _logger.i('VpnBloc: generate_204 → 204, node is fine (no traffic yet)');
        // 节点通了，用户只是还没浏览，什么都不做
      } else {
        _logger.w('VpnBloc: generate_204 → ${response.statusCode}, treating as dead');
        if (!isClosed) add(const _VpnConnectivityFailed());
      }
    } catch (e) {
      _logger.w('VpnBloc: generate_204 timeout/error → node is dead: $e');
      if (!isClosed) add(const _VpnConnectivityFailed());
    }
  }

  /// 节点不通：只标记错误，不强制断开（行业标准：让用户决定是否断开）
  Future<void> _onConnectivityFailed(
    _VpnConnectivityFailed event,
    Emitter<VpnState> emit,
  ) async {
    _logger.w('VpnBloc: node unreachable, marking error but keeping VPN alive...');
    // 只更新 error 字段提示用户，不断开 VPN —— 与 ClashX/Clash Verge 行为一致
    emit(state.copyWith(error: 'node_unreachable'));
    _logger.w('VpnBloc: node_unreachable error set, VPN remains connected');
  }
}

// Internal events for service callbacks
class _VpnStatusChanged extends VpnEvent {
  final MihomoStatus status;

  const _VpnStatusChanged({required this.status});

  @override
  List<Object?> get props => [status];
}

class _VpnStatsUpdated extends VpnEvent {
  final MihomoStats stats;

  const _VpnStatsUpdated({required this.stats});

  @override
  List<Object?> get props => [stats];
}

class _VpnConnectivityFailed extends VpnEvent {
  const _VpnConnectivityFailed();
}
