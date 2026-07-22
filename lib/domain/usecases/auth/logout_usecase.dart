import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class LogoutUseCase implements UseCaseNoParams<void> {
  final AuthRepository _authRepository;

  LogoutUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<void> call() async {
    await _authRepository.logout();
  }
}
