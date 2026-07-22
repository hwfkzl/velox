import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/repositories/server_repository.dart';
import '../datasources/remote/server_remote_datasource.dart';
import '../models/server_model.dart';

class ServerRepositoryImpl implements ServerRepository {
  final ServerRemoteDataSource _remoteDataSource;
  final LocalStorageService _localStorage;

  List<ServerModel>? _cachedServers;

  ServerRepositoryImpl({
    required ServerRemoteDataSource remoteDataSource,
    required LocalStorageService localStorage,
  })  : _remoteDataSource = remoteDataSource,
        _localStorage = localStorage;

  @override
  Future<List<ServerModel>> getServerList() async {
    final servers = await _remoteDataSource.getServerList();

    // 加载收藏状态
    final favoriteIds = await getFavoriteServerIds();
    for (var server in servers) {
      server.isFavorite = favoriteIds.contains(server.id);
    }

    _cachedServers = servers;

    // 缓存到本地
    await _localStorage.setString(
      StorageKeys.serverList,
      jsonEncode(servers.map((e) => e.toJson()).toList()),
    );

    return servers;
  }

  @override
  List<ServerModel>? getCachedServerList() {
    if (_cachedServers != null) return _cachedServers;

    final jsonStr = _localStorage.getString(StorageKeys.serverList);
    if (jsonStr == null) return null;

    try {
      final list = jsonDecode(jsonStr) as List;
      _cachedServers = list
          .map((e) => ServerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cachedServers;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<int>> getFavoriteServerIds() async {
    final list = _localStorage.getStringList(StorageKeys.favoriteServers);
    if (list == null) return [];
    return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  @override
  Future<void> toggleFavorite(int serverId) async {
    final favoriteIds = await getFavoriteServerIds();

    if (favoriteIds.contains(serverId)) {
      favoriteIds.remove(serverId);
    } else {
      favoriteIds.add(serverId);
    }

    await _localStorage.setStringList(
      StorageKeys.favoriteServers,
      favoriteIds.map((e) => e.toString()).toList(),
    );

    // 更新缓存
    if (_cachedServers != null) {
      for (var server in _cachedServers!) {
        if (server.id == serverId) {
          server.isFavorite = favoriteIds.contains(serverId);
          break;
        }
      }
    }
  }

  @override
  Future<ServerModel?> getLastServer() async {
    final jsonStr = _localStorage.getString(StorageKeys.lastServer);
    if (jsonStr == null) return null;

    try {
      return ServerModel.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLastServer(ServerModel server) async {
    await _localStorage.setString(
      StorageKeys.lastServer,
      jsonEncode(server.toJson()),
    );
  }

  @override
  Future<int?> pingServer(ServerModel server) async {
    if (server.host == null) return null;

    // L0 后端权威判断：服务端 5 分钟未上报心跳 = 离线
    // CDN 中转架构下，TCP 握手永远成功（CDN 都接），所以必须先信任后端
    // 用 -2 区分"后端离线"和"网络超时（-1）"，UI 可以分别提示
    if (server.backendOnline == 0) {
      return -2;
    }

    try {
      final stopwatch = Stopwatch()..start();

      final socket = await Socket.connect(
        server.host!,
        server.port ?? 443,
        timeout: const Duration(milliseconds: AppConstants.pingTimeout),
      );

      stopwatch.stop();
      await socket.close();

      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  @override
  Future<Map<int, int?>> pingServers(List<ServerModel> servers) async {
    final results = <int, int?>{};

    // 并行测速，最多同时测试 10 个
    final chunks = <List<ServerModel>>[];
    for (var i = 0; i < servers.length; i += 10) {
      chunks.add(
        servers.sublist(
          i,
          i + 10 > servers.length ? servers.length : i + 10,
        ),
      );
    }

    for (var chunk in chunks) {
      final futures = chunk.map((server) async {
        final latency = await pingServer(server);
        if (server.id != null) {
          results[server.id!] = latency;
        }
      });
      await Future.wait(futures);
    }

    // 更新缓存
    if (_cachedServers != null) {
      for (var server in _cachedServers!) {
        if (server.id != null && results.containsKey(server.id)) {
          server.latency = results[server.id!];
        }
      }
    }

    return results;
  }

  @override
  Future<void> clearCache() async {
    _cachedServers = null;
    await _localStorage.remove(StorageKeys.serverList);
  }
}
