import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/error_message_mapper.dart';
import '../../models/user_model.dart';
import '../../models/subscribe_model.dart';

abstract class UserRemoteDataSource {
  Future<UserModel> getUserInfo();
  Future<SubscribeModel> getSubscribeInfo();
  Future<List<PlanModel>> getPlanList();
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final ApiClient _apiClient;

  UserRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<UserModel> getUserInfo() async {
    final response = await _apiClient.get(ApiConstants.userInfo);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? '获取用户信息失败'));
    }

    return apiResponse.data!;
  }

  @override
  Future<SubscribeModel> getSubscribeInfo() async {
    final response = await _apiClient.get(ApiConstants.userSubscribe);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => SubscribeModel.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? '获取订阅信息失败'));
    }

    return apiResponse.data!;
  }

  @override
  Future<List<PlanModel>> getPlanList() async {
    final response = await _apiClient.get(ApiConstants.planList);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) {
        if (json is List) {
          return json
              .map((e) => PlanModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <PlanModel>[];
      },
    );

    if (!apiResponse.isSuccess) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? '获取套餐列表失败'));
    }

    return apiResponse.data ?? [];
  }
}
