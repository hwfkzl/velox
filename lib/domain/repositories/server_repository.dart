import '../../data/models/server_model.dart';

abstract class ServerRepository {
  /// 获取节点列表
  Future<List<ServerModel>> getServerList();

  /// 获取缓存的节点列表
  List<ServerModel>? getCachedServerList();

  /// 获取收藏的节点 ID 列表
  Future<List<int>> getFavoriteServerIds();

  /// 添加/移除收藏
  Future<void> toggleFavorite(int serverId);

  /// 获取上次连接的节点
  Future<ServerModel?> getLastServer();

  /// 保存上次连接的节点
  Future<void> saveLastServer(ServerModel server);

  /// 测试节点延迟
  Future<int?> pingServer(ServerModel server);

  /// 批量测试节点延迟
  Future<Map<int, int?>> pingServers(List<ServerModel> servers);

  /// 清除缓存
  Future<void> clearCache();
}
