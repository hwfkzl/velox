import '../../../data/models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserInfoUseCase implements UseCaseNoParams<UserModel> {
  final UserRepository _userRepository;

  GetUserInfoUseCase({required UserRepository userRepository})
      : _userRepository = userRepository;

  @override
  Future<UserModel> call() async {
    return await _userRepository.getUserInfo();
  }

  /// 获取缓存的用户信息（如果有）
  UserModel? getCached() {
    return _userRepository.getCachedUserInfo();
  }
}
