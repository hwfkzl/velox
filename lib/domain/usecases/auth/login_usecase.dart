import 'package:equatable/equatable.dart';

import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class LoginParams extends Equatable {
  final String email;
  final String password;

  const LoginParams({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class LoginUseCase implements UseCase<void, LoginParams> {
  final AuthRepository _authRepository;

  LoginUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<void> call(LoginParams params) async {
    // 验证邮箱格式
    if (!_isValidEmail(params.email)) {
      throw const FormatException('Invalid email format');
    }

    // 验证密码长度
    if (params.password.length < 6) {
      throw const FormatException('Password must be at least 6 characters');
    }

    await _authRepository.login(params.email, params.password);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}
