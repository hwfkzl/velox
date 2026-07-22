import 'package:equatable/equatable.dart';

/// 失败基类
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// 服务器失败
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// 网络失败
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = '网络连接失败，请检查网络设置',
    super.code,
  });
}

/// 缓存失败
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = '缓存读取失败',
    super.code,
  });
}

/// 认证失败
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = '认证失败，请重新登录',
    super.code,
  });
}

/// 验证失败
class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure({
    required super.message,
    super.code,
    this.errors,
  });

  @override
  List<Object?> get props => [message, code, errors];
}

/// 未知失败
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = '未知错误',
    super.code,
  });
}
