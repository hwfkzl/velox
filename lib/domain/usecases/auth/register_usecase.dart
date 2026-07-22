import 'package:equatable/equatable.dart';

import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class RegisterParams extends Equatable {
  final String email;
  final String password;
  final String? emailCode;
  final String? inviteCode;

  const RegisterParams({
    required this.email,
    required this.password,
    this.emailCode,
    this.inviteCode,
  });

  @override
  List<Object?> get props => [email, password, emailCode, inviteCode];
}

class RegisterUseCase implements UseCase<void, RegisterParams> {
  final AuthRepository _authRepository;

  RegisterUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<void> call(RegisterParams params) async {
    // 验证邮箱格式
    if (!_isValidEmail(params.email)) {
      throw const FormatException('Invalid email format');
    }

    // 验证密码长度
    if (params.password.length < 6) {
      throw const FormatException('Password must be at least 6 characters');
    }

    await _authRepository.register(
      email: params.email,
      password: params.password,
      emailCode: params.emailCode,
      inviteCode: params.inviteCode,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}
