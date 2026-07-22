import '../../models/server_model.dart';
import 'velox_sync_datasource.dart';

abstract class ServerRemoteDataSource {
  Future<List<ServerModel>> getServerList();
}

class ServerRemoteDataSourceImpl implements ServerRemoteDataSource {
  final VeloxSyncDataSource _veloxSync;

  ServerRemoteDataSourceImpl({required VeloxSyncDataSource veloxSync})
      : _veloxSync = veloxSync;

  @override
  Future<List<ServerModel>> getServerList() async {
    // 节点列表改走 Velox 加密订阅通道
    // 传输层密文，客户端本地解密；对下游完全透明
    final servers = await _veloxSync.fetchServers();

    // DEBUG: 保留现有调试行为
    print('🔍 velox/sync decrypted, ${servers.length} servers');

    return servers;
  }
}
