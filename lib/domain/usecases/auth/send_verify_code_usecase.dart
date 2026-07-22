import 'package:equatable/equatable.dart';

import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SendVerifyCodeParams extends Equatable {
  final String email;

  const SendVerifyCodeParams({required this.email});

  @override
  List<Object?> get props => [email];
}

class SendVerifyCodeUseCase implements UseCase<void, SendVerifyCodeParams> {
  final AuthRepository _authRepository;

  SendVerifyCodeUseCase({required AuthRepository authRepository})
      : _authRepository = authRepository;

  @override
  Future<void> call(SendVerifyCodeParams params) async {
    // 验证邮箱格式
    if (!_isValidEmail(params.email)) {
      throw const FormatException('Invalid email format');
    }

    await _authRepository.sendEmailCode(params.email);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}
