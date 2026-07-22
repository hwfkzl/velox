import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/error_message_mapper.dart';
import '../../models/invite_model.dart';

abstract class InviteRemoteDataSource {
  /// 获取邀请信息
  Future<InviteModel> getInviteInfo();

  /// 生成新邀请码
  Future<void> generateInviteCode();
}

class InviteRemoteDataSourceImpl implements InviteRemoteDataSource {
  final ApiClient _apiClient;

  InviteRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<InviteModel> getInviteInfo() async {
    final response = await _apiClient.get(ApiConstants.inviteInfo);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => InviteModel.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to get invite info'));
    }

    return apiResponse.data!;
  }

  @override
  Future<void> generateInviteCode() async {
    final response = await _apiClient.get(ApiConstants.inviteSave);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to generate invite code'));
    }
  }
}
