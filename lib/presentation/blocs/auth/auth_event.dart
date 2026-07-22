part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String? emailCode;
  final String? inviteCode;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.emailCode,
    this.inviteCode,
  });

  @override
  List<Object?> get props => [email, password, emailCode, inviteCode];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthSendCodeRequested extends AuthEvent {
  final String email;

  const AuthSendCodeRequested({required this.email});

  @override
  List<Object> get props => [email];
}

class AuthSiteConfigRequested extends AuthEvent {}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;
  final String emailCode;
  final String password;

  const AuthForgotPasswordRequested({
    required this.email,
    required this.emailCode,
    required this.password,
  });

  @override
  List<Object> get props => [email, emailCode, password];
}
