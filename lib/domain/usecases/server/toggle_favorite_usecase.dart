import '../../repositories/server_repository.dart';
import '../usecase.dart';

class ToggleFavoriteUseCase implements UseCase<void, int> {
  final ServerRepository _serverRepository;

  ToggleFavoriteUseCase({required ServerRepository serverRepository})
      : _serverRepository = serverRepository;

  @override
  Future<void> call(int serverId) async {
    if (serverId <= 0) {
      throw const FormatException('Invalid server ID');
    }
    await _serverRepository.toggleFavorite(serverId);
  }
}
