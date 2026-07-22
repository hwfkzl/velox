part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthCodeSending extends AuthState {}

class AuthCodeSent extends AuthState {}

class AuthPasswordReset extends AuthState {}

class AuthSiteConfigLoaded extends AuthState {
  final bool emailVerifyRequired;
  final bool inviteForce;
  const AuthSiteConfigLoaded({
    required this.emailVerifyRequired,
    required this.inviteForce,
  });
  @override
  List<Object> get props => [emailVerifyRequired, inviteForce];
}

class AuthError extends AuthState {
  final String message;

  /// null = V2Board 业务错误(密码错/账号封禁…),UI 只显示干净文案。
  /// 非 null = 基础设施错误(网络/超时/5xx),UI 追加"（error:XXXX）"。
  final VeloxErrorCode? veloxCode;

  const AuthError({
    required this.message,
    this.veloxCode,
  });

  @override
  List<Object?> get props => [message, veloxCode];
}
