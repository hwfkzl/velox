import 'package:json_annotation/json_annotation.dart';

part 'auth_model.g.dart';

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  @JsonKey(name: 'email_code')
  final String? emailCode;
  @JsonKey(name: 'invite_code')
  final String? inviteCode;

  RegisterRequest({
    required this.email,
    required this.password,
    this.emailCode,
    this.inviteCode,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'auth_data')
  final String? authData; // Token
  final String? token; // 兼容不同版本

  AuthResponse({
    this.authData,
    this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  /// 获取有效 Token
  String? get validToken => authData ?? token;
}

@JsonSerializable()
class ForgotPasswordRequest {
  final String email;
  @JsonKey(name: 'email_code')
  final String emailCode;
  final String password;

  ForgotPasswordRequest({
    required this.email,
    required this.emailCode,
    required this.password,
  });

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ForgotPasswordRequestToJson(this);
}

@JsonSerializable()
class SendCodeRequest {
  final String email;

  SendCodeRequest({required this.email});

  factory SendCodeRequest.fromJson(Map<String, dynamic> json) =>
      _$SendCodeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SendCodeRequestToJson(this);
}
