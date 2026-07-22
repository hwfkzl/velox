import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSendCodeRequested>(_onSendCodeRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthSiteConfigRequested>(_onSiteConfigRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(event.email, event.password);
      emit(AuthAuthenticated());
    } catch (e) {
      // AppException → 基础设施错误(dio/HTTP 5xx/OSS 挂),veloxCode 传给 UI 显示 (error:XXXX);
      // 裸 Exception → V2Board 业务错误(密码错/账号封禁…),code 为 null,UI 只显示干净文案。
      final code = (e is AppException) ? e.veloxCode : null;
      emit(AuthError(message: extractErrorMessage(e), veloxCode: code));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.register(
        email: event.email,
        password: event.password,
        emailCode: event.emailCode,
        inviteCode: event.inviteCode,
      );
      emit(AuthAuthenticated());
    } catch (e) {
      // AppException → 基础设施错误(dio/HTTP 5xx/OSS 挂),veloxCode 传给 UI 显示 (error:XXXX);
      // 裸 Exception → V2Board 业务错误(密码错/账号封禁…),code 为 null,UI 只显示干净文案。
      final code = (e is AppException) ? e.veloxCode : null;
      emit(AuthError(message: extractErrorMessage(e), veloxCode: code));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      // AppException → 基础设施错误(dio/HTTP 5xx/OSS 挂),veloxCode 传给 UI 显示 (error:XXXX);
      // 裸 Exception → V2Board 业务错误(密码错/账号封禁…),code 为 null,UI 只显示干净文案。
      final code = (e is AppException) ? e.veloxCode : null;
      emit(AuthError(message: extractErrorMessage(e), veloxCode: code));
    }
  }

  Future<void> _onSendCodeRequested(
    AuthSendCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthCodeSending());
    try {
      await _authRepository.sendEmailCode(event.email);
      emit(AuthCodeSent());
    } catch (e) {
      // AppException → 基础设施错误(dio/HTTP 5xx/OSS 挂),veloxCode 传给 UI 显示 (error:XXXX);
      // 裸 Exception → V2Board 业务错误(密码错/账号封禁…),code 为 null,UI 只显示干净文案。
      final code = (e is AppException) ? e.veloxCode : null;
      emit(AuthError(message: extractErrorMessage(e), veloxCode: code));
    }
  }

  Future<void> _onSiteConfigRequested(
    AuthSiteConfigRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final cfg = await _authRepository.getSiteConfig();
      emit(AuthSiteConfigLoaded(
        emailVerifyRequired: cfg.emailVerifyRequired,
        inviteForce: cfg.inviteForce,
      ));
    } catch (_) {
      // 失败时保守地认为两者都不强制(与后端默认 0 一致)
      emit(const AuthSiteConfigLoaded(
        emailVerifyRequired: false,
        inviteForce: false,
      ));
    }
  }

  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.forgotPassword(
        email: event.email,
        emailCode: event.emailCode,
        password: event.password,
      );
      emit(AuthPasswordReset());
    } catch (e) {
      // AppException → 基础设施错误(dio/HTTP 5xx/OSS 挂),veloxCode 传给 UI 显示 (error:XXXX);
      // 裸 Exception → V2Board 业务错误(密码错/账号封禁…),code 为 null,UI 只显示干净文案。
      final code = (e is AppException) ? e.veloxCode : null;
      emit(AuthError(message: extractErrorMessage(e), veloxCode: code));
    }
  }
}
