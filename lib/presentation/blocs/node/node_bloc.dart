import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/services/auto_test_service.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../data/models/server_model.dart';
import '../../../domain/repositories/server_repository.dart';

part 'node_event.dart';
part 'node_state.dart';

class NodeBloc extends Bloc<NodeEvent, NodeState> {
  final ServerRepository _serverRepository;
  final AutoTestService _autoTestService;
  StreamSubscription<DelayResult>? _delaySubscription;

  ServerModel? _resolvePreferredServer(
    List<ServerModel> servers,
    ServerModel? lastServer,
  ) {
    if (servers.isEmpty) return null;

    if (lastServer != null && lastServer.id != null) {
      for (final server in servers) {
        if (server.id == lastServer.id) {
          return server;
        }
      }
    }

    // 默认不自动选择任何节点，避免连接到“官网介绍”节点
    return null;
  }

  NodeBloc({
    required ServerRepository serverRepository,
    required AutoTestService autoTestService,
  })  : _serverRepository = serverRepository,
        _autoTestService = autoTestService,
        super(NodeInitial()) {
    on<NodeLoadRequested>(_onLoadRequested);
    on<NodeRefreshRequested>(_onRefreshRequested);
    on<NodePingRequested>(_onPingRequested);
    on<NodePingAllRequested>(_onPingAllRequested);
    on<NodeToggleFavoriteRequested>(_onToggleFavoriteRequested);
    on<NodeSelectRequested>(_onSelectRequested);
    on<NodeAuthCleared>(_onAuthCleared);
  }

  Future<void> _onAuthCleared(
    NodeAuthCleared event,
    Emitter<NodeState> emit,
  ) async {
    // 取消 AutoTestService 的延迟订阅，停止给上一个账号的节点测速
    await _delaySubscription?.cancel();
    _delaySubscription = null;
    emit(NodeInitial());
  }

  Future<void> _onLoadRequested(
    NodeLoadRequested event,
    Emitter<NodeState> emit,
  ) async {
    // 自动选择 ON 时不恢复上次的固定节点，由 autoNow 接管
    final prefs = await SharedPreferences.getInstance();
    final isAutoSelect = prefs.getBool(StorageKeys.autoConnect) ?? false;

    final cachedServers = _serverRepository.getCachedServerList();
    final lastServer = isAutoSelect ? null : await _serverRepository.getLastServer();

    if (cachedServers != null && cachedServers.isNotEmpty) {
      emit(
        NodeLoaded(
          servers: cachedServers,
          selectedServer: _resolvePreferredServer(cachedServers, lastServer),
        ),
      );
    } else {
      emit(NodeLoading());
    }

    // 从网络加载
    try {
      final servers = await _serverRepository.getServerList();
      emit(
        NodeLoaded(
          servers: servers,
          selectedServer: _resolvePreferredServer(servers, lastServer),
        ),
      );
      // Fast-switch 支持:节点列表一到手就存 prefs,VpnBloc auto-reconnect 时能读
      // 出来传给 config generator,PROXY selector 就有全节点。之前 auto-reconnect
      // 不带 allServers → selector 只有 1 项 → 切他方节点 mihomo 报 "proxy not
      // exist" 400 → fallback 到 full reconnect(5s 慢)。
      _persistServersForAutoReconnect(servers);
    } catch (e) {
      if (cachedServers == null || cachedServers.isEmpty) {
        // 无缓存可回退 → 报错页
        emit(NodeError(message: extractErrorMessage(e)));
      } else {
        // 有缓存 → 静默沿用旧节点，但通过 tick 自增触发一次"更新失败"小提示
        final current = state;
        final tick =
            current is NodeLoaded ? current.refreshErrorTick + 1 : 1;
        emit(
          NodeLoaded(
            servers: cachedServers,
            selectedServer: _resolvePreferredServer(cachedServers, lastServer),
            refreshErrorTick: tick,
            refreshErrorMessage: extractErrorMessage(e),
          ),
        );
      }
    }

    // 节点加载完成后启动自动测速（对标 HealthCheck 启动）
    _startAutoTest();
  }

  Future<void> _persistServersForAutoReconnect(List<ServerModel> servers) async {
    if (servers.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'vpn_last_all_servers',
        jsonEncode(servers.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _onRefreshRequested(
    NodeRefreshRequested event,
    Emitter<NodeState> emit,
  ) async {
    final currentState = state;
    try {
      final servers = await _serverRepository.getServerList();
      final selectedServer = currentState is NodeLoaded
          ? _resolvePreferredServer(servers, currentState.selectedServer)
          : null;
      emit(NodeLoaded(servers: servers, selectedServer: selectedServer));
      _persistServersForAutoReconnect(servers);
      // 节点列表刷新后重启自动测速
      _startAutoTest();
    } catch (e) {
      emit(NodeError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onPingRequested(
    NodePingRequested event,
    Emitter<NodeState> emit,
  ) async {
    if (state is! NodeLoaded) return;

    final currentState = state as NodeLoaded;
    final latency = await _serverRepository.pingServer(event.server);

    // 更新节点延迟
    final updatedServers = currentState.servers.map((s) {
      if (s.id == event.server.id) {
        return s.copyWith(latency: latency);
      }
      return s;
    }).toList();

    emit(currentState.copyWith(servers: updatedServers));
  }

  Future<void> _onPingAllRequested(
    NodePingAllRequested event,
    Emitter<NodeState> emit,
  ) async {
    if (state is! NodeLoaded) return;

    final currentState = state as NodeLoaded;
    emit(currentState.copyWith(isPinging: true));

    final results = await _serverRepository.pingServers(currentState.servers);

    // 更新所有节点延迟
    final updatedServers = currentState.servers.map((s) {
      if (s.id != null && results.containsKey(s.id)) {
        return s.copyWith(latency: results[s.id!]);
      }
      return s;
    }).toList();

    emit(currentState.copyWith(servers: updatedServers, isPinging: false));
  }

  Future<void> _onToggleFavoriteRequested(
    NodeToggleFavoriteRequested event,
    Emitter<NodeState> emit,
  ) async {
    if (state is! NodeLoaded) return;

    final currentState = state as NodeLoaded;
    await _serverRepository.toggleFavorite(event.serverId);

    // 更新节点收藏状态
    final updatedServers = currentState.servers.map((s) {
      if (s.id == event.serverId) {
        return s.copyWith(isFavorite: !s.isFavorite);
      }
      return s;
    }).toList();

    emit(currentState.copyWith(servers: updatedServers));
  }

  Future<void> _onSelectRequested(
    NodeSelectRequested event,
    Emitter<NodeState> emit,
  ) async {
    if (state is! NodeLoaded) return;

    final currentState = state as NodeLoaded;
    await _serverRepository.saveLastServer(event.server);

    // 手动覆盖：对标 ForceSet(name)，优先使用手动选中的节点
    _autoTestService.forceSet(event.server);

    emit(currentState.copyWith(selectedServer: event.server));
  }

  void _startAutoTest() {
    // 订阅 delayStream，测速结果实时更新到 UI
    _delaySubscription?.cancel();
    _delaySubscription = _autoTestService.delayStream.listen((result) {
      if (state is! NodeLoaded) return;
      final current = state as NodeLoaded;
      final updated = current.servers.map((s) {
        if (s.id == result.serverId) return s.copyWith(latency: result.latency);
        return s;
      }).toList();
      emit(current.copyWith(servers: updated));
    });

    _autoTestService.startPeriodic(
      getServers: () => _serverRepository.getServerList(),
    );
  }

  @override
  Future<void> close() async {
    await _delaySubscription?.cancel();
    return super.close();
  }
}
