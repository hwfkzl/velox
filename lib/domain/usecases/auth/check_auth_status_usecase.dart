import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class CheckAuthStatusUseCase implements UseCaseNoParams<bool> {
  final AuthRepository _authRepository;

  CheckAuthStatusUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<bool> call() async {
    return await _authRepository.isLoggedIn();
  }
}
