import '../../../data/models/server_model.dart';
import '../../repositories/server_repository.dart';
import '../usecase.dart';

class GetServerListUseCase implements UseCaseNoParams<List<ServerModel>> {
  final ServerRepository _serverRepository;

  GetServerListUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<List<ServerModel>> call() async {
    return await _serverRepository.getServerList();
  }

  /// 获取缓存的服务器列表
  List<ServerModel>? getCached() {
    return _serverRepository.getCachedServerList();
  }
}
