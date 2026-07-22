import '../../../data/models/server_model.dart';
import '../../repositories/server_repository.dart';
import '../usecase.dart';

class SaveLastServerUseCase implements UseCase<void, ServerModel> {
  final ServerRepository _serverRepository;

  SaveLastServerUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<void> call(ServerModel server) async {
    if (server.host == null || server.host!.isEmpty) {
      throw const FormatException('Server host is required');
    }
    await _serverRepository.saveLastServer(server);
  }
}
