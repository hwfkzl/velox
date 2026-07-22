import 'package:equatable/equatable.dart';

import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class ForgotPasswordParams extends Equatable {
  final String email;
  final String emailCode;
  final String password;

  const ForgotPasswordParams({
    required this.email,
    required this.emailCode,
    required this.password,
  });

  @override
  List<Object?> get props => [email, emailCode, password];
}

class ForgotPasswordUseCase implements UseCase<void, ForgotPasswordParams> {
  final AuthRepository _authRepository;

  ForgotPasswordUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<void> call(ForgotPasswordParams params) async {
    // 验证邮箱格式
    if (!_isValidEmail(params.email)) {
      throw const FormatException('Invalid email format');
    }

    // 验证验证码
    if (params.emailCode.isEmpty || params.emailCode.length < 4) {
      throw const FormatException('Invalid verification code');
    }

    // 验证密码长度
    if (params.password.length < 6) {
      throw const FormatException('Password must be at least 6 characters');
    }

    await _authRepository.forgotPassword(
      email: params.email,
      emailCode: params.emailCode,
      password: params.password,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}
