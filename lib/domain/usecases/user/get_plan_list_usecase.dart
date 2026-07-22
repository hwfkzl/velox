import '../../../data/models/subscribe_model.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetPlanListUseCase implements UseCaseNoParams<List<PlanModel>> {
  final UserRepository _userRepository;

  GetPlanListUseCase({required UserRepository userRepository})
      : _userRepository = userRepository;

  @override
  Future<List<PlanModel>> call() async {
    return await _userRepository.getPlanList();
  }
}
