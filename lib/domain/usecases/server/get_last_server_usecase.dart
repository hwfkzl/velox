import '../../../data/models/server_model.dart';
import '../../repositories/server_repository.dart';
import '../usecase.dart';

class GetLastServerUseCase implements UseCaseNoParams<ServerModel?> {
  final ServerRepository _serverRepository;

  GetLastServerUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<ServerModel?> call() async {
    return await _serverRepository.getLastServer();
  }
}
