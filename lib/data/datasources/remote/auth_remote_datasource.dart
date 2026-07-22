import '../../../core/constants/api_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/error_message_mapper.dart';
import '../../models/auth_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<void> logout();
  Future<void> sendEmailCode(String email);
  Future<void> forgotPassword(ForgotPasswordRequest request);
  Future<void> verifyToken();
  /// 获取站点配置 (V2Board /api/v1/guest/comm/config)：
  ///   - emailVerifyRequired: is_email_verify
  ///   - inviteForce:         is_invite_force
  Future<({bool emailVerifyRequired, bool inviteForce})> getSiteConfig();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess) {
      // V2Board 业务错误 —— 裸 Exception,下游 AuthBloc 拿不到 veloxCode → 不显示 error 码,
      // 用户只看干净中文文案。基础设施错误(dio 抛 AppException)才会带 code。
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? '邮箱或密码错误'),
      );
    }

    return apiResponse.data!;
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? '注册失败'),
      );
    }

    return apiResponse.data!;
  }

  @override
  Future<void> logout() async {
    // V2Board xiaoV2b 无服务端 logout 端点，本地清除即可
  }

  @override
  Future<void> sendEmailCode(String email) async {
    final response = await _apiClient.post(
      ApiConstants.sendVerifyCode,
      data: {'email': email},
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? '发送验证码失败'),
      );
    }
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.forgotPassword,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? '重置密码失败'),
      );
    }
  }

  @override
  Future<({bool emailVerifyRequired, bool inviteForce})> getSiteConfig() async {
    final response = await _apiClient.get(ApiConstants.siteConfig);
    final data = response.data as Map<String, dynamic>?;
    final siteData = data?['data'] as Map<String, dynamic>?;
    bool toBool(dynamic v) => v == 1 || v == true;
    return (
      emailVerifyRequired: toBool(siteData?['is_email_verify']),
      inviteForce: toBool(siteData?['is_invite_force']),
    );
  }

  @override
  Future<void> verifyToken() async {
    // 通过获取用户信息来验证 token 是否有效
    final response = await _apiClient.get(ApiConstants.userInfo);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      final msg = (apiResponse.message ?? '').toLowerCase();
      // 登录相关消息 → AuthException(触发 isLoggedIn 清盘)
      final isAuthMsg = msg.contains('登录') || msg.contains('未登录')
          || msg.contains('登陆') || msg.contains('token')
          || msg.contains('unauth') || msg.contains('expired');
      if (isAuthMsg) {
        throw AuthException(message: apiResponse.message ?? '登录已过期');
      }
      // 非登录相关 → ServerException(isLoggedIn 会保留 token)
      throw ServerException(message: apiResponse.message ?? '服务器错误');
    }
  }
}
