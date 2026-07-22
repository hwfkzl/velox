import '../../core/errors/exceptions.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;
  final LocalStorageService _localStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
    required LocalStorageService localStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage,
        _localStorage = localStorage;

  @override
  Future<void> login(String email, String password) async {
    final request = LoginRequest(email: email, password: password);
    final response = await _remoteDataSource.login(request);

    if (response.validToken != null) {
      await _secureStorage.write(StorageKeys.authToken, response.validToken!);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) async {
    final request = RegisterRequest(
      email: email,
      password: password,
      emailCode: emailCode,
      inviteCode: inviteCode,
    );
    final response = await _remoteDataSource.register(request);

    if (response.validToken != null) {
      await _secureStorage.write(StorageKeys.authToken, response.validToken!);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // 忽略登出 API 错误
    }

    // 清除本地数据
    await _secureStorage.delete(StorageKeys.authToken);
    await _localStorage.remove(StorageKeys.userInfo);
    await _localStorage.remove(StorageKeys.subscribeInfo);
    await _localStorage.remove(StorageKeys.serverList);
  }

  @override
  Future<void> sendEmailCode(String email) async {
    await _remoteDataSource.sendEmailCode(email);
  }

  @override
  Future<void> forgotPassword({
    required String email,
    required String emailCode,
    required String password,
  }) async {
    final request = ForgotPasswordRequest(
      email: email,
      emailCode: emailCode,
      password: password,
    );
    await _remoteDataSource.forgotPassword(request);
  }

  @override
  Future<({bool emailVerifyRequired, bool inviteForce})> getSiteConfig() {
    return _remoteDataSource.getSiteConfig();
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(StorageKeys.authToken);
    if (token == null || token.isEmpty) {
      return false;
    }

    // 验证 token 是否有效（通过获取用户信息）
    try {
      await _remoteDataSource.verifyToken();
      return true;
    } catch (e) {
      // 明确 AuthException 才清 token(拦截器 401/403 命中 + verifyToken 抛的登录错)
      if (e is AuthException) {
        await _secureStorage.delete(StorageKeys.authToken);
        await _localStorage.remove(StorageKeys.userInfo);
        await _localStorage.remove(StorageKeys.subscribeInfo);
        await _localStorage.remove(StorageKeys.serverList);
        return false;
      }
      // 网络错/超时/5xx/未知 → 保守认为仍登录,让主界面业务请求自己处理
      return true;
    }
  }

  @override
  Future<String?> getToken() async {
    return await _secureStorage.read(StorageKeys.authToken);
  }
}
