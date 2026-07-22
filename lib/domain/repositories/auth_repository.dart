abstract class AuthRepository {
  /// 登录
  Future<void> login(String email, String password);

  /// 注册
  Future<void> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  });

  /// 登出
  Future<void> logout();

  /// 发送验证码
  Future<void> sendEmailCode(String email);

  /// 重置密码
  Future<void> forgotPassword({
    required String email,
    required String emailCode,
    required String password,
  });

  /// 获取站点配置 (V2Board `/api/v1/guest/comm/config`)：
  ///   - emailVerifyRequired: `is_email_verify`
  ///   - inviteForce:         `is_invite_force`
  Future<({bool emailVerifyRequired, bool inviteForce})> getSiteConfig();

  /// 检查是否已登录
  Future<bool> isLoggedIn();

  /// 获取 Token
  Future<String?> getToken();
}
