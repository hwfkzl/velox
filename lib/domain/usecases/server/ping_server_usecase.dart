import '../../../data/models/server_model.dart';
import '../../repositories/server_repository.dart';
import '../usecase.dart';

class PingServerUseCase implements UseCase<int?, ServerModel> {
  final ServerRepository _serverRepository;

  PingServerUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<int?> call(ServerModel server) async {
    if (server.host == null || server.host!.isEmpty) {
      throw const FormatException('Server host is required');
    }
    return await _serverRepository.pingServer(server);
  }
}
