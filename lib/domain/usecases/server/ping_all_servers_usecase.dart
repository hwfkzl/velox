import '../../../data/models/server_model.dart';
import '../../repositories/server_repository.dart';
import '../usecase.dart';

class PingAllServersUseCase implements UseCase<Map<int, int?>, List<ServerModel>> {
  final ServerRepository _serverRepository;

  PingAllServersUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<Map<int, int?>> call(List<ServerModel> servers) async {
    if (servers.isEmpty) {
      return {};
    }
    return await _serverRepository.pingServers(servers);
  }
}
