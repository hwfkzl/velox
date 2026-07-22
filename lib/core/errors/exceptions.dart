import 'package:flutter/services.dart' show PlatformException;

import 'error_code.dart';

/// 应用异常类
class AppException implements Exception {
  final String message;
  final int? code;
  final dynamic data;
  final VeloxErrorCode veloxCode;

  AppException({
    required this.message,
    this.code,
    this.data,
    this.veloxCode = VeloxErrorCode.unknown,
  });

  @override
  String toString() => '[${veloxCode.code}] $message';

  /// 调试用的详细信息
  String toDebugString() => 'AppException: $message (code: $code, velox: ${veloxCode.code})';
}

/// 服务器异常
class ServerException extends AppException {
  ServerException({
    required super.message,
    super.code,
    super.data,
    super.veloxCode = VeloxErrorCode.serverBusy,
  });
}

/// 网络异常
class NetworkException extends AppException {
  NetworkException({
    super.message = '网络连接失败，请检查网络设置',
    super.code,
    super.veloxCode = VeloxErrorCode.networkFailed,
  });
}

/// 缓存异常
class CacheException extends AppException {
  CacheException({
    super.message = '缓存读取失败',
    super.code,
    super.veloxCode = VeloxErrorCode.configLoadFailed,
  });
}

/// 认证异常
class AuthException extends AppException {
  AuthException({
    super.message = '认证失败，请重新登录',
    super.code,
    super.veloxCode = VeloxErrorCode.loginExpired,
  });
}

/// 验证异常
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  ValidationException({
    required super.message,
    super.code,
    this.errors,
    super.veloxCode = VeloxErrorCode.validationFailed,
  });
}

/// 超时异常
class TimeoutException extends AppException {
  TimeoutException({
    super.message = '请求超时，请稍后重试',
    super.code,
    super.veloxCode = VeloxErrorCode.requestTimeout,
  });
}

/// 从任意异常中提取用户友好的错误消息
String extractErrorMessage(dynamic error) {
  if (error is AppException) {
    return error.message;
  }

  // PlatformException(来自 Swift/Kotlin native 端) → 只暴露干净的 message 文案,
  // 丢弃 code / details / stacktrace。否则 UI 会显示
  // "PlatformException(START_ERROR, 你的中文文案, null, null)" 这种全壳,
  // 把技术细节暴露给最终用户。
  if (error is PlatformException) {
    final msg = error.message?.trim();
    return (msg == null || msg.isEmpty) ? '操作失败,请重试' : msg;
  }

  String message = error.toString();

  // 移除 "Exception: " 前缀
  if (message.startsWith('Exception: ')) {
    message = message.substring('Exception: '.length);
  }

  // 移除其他常见前缀
  final prefixes = ['FormatException: ', 'StateError: ', 'TypeError: '];
  for (final prefix in prefixes) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length);
      break;
    }
  }

  return message.isEmpty ? 'errorOperationFailed' : message;
}
