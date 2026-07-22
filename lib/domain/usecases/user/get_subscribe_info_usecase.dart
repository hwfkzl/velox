import '../../../data/models/subscribe_model.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetSubscribeInfoUseCase implements UseCaseNoParams<SubscribeModel> {
  final UserRepository _userRepository;

  GetSubscribeInfoUseCase({required UserRepository userRepository})
      : _userRepository = userRepository;

  @override
  Future<SubscribeModel> call() async {
    return await _userRepository.getSubscribeInfo();
  }

  /// 获取缓存的订阅信息（如果有）
  SubscribeModel? getCached() {
    return _userRepository.getCachedSubscribeInfo();
  }
}
