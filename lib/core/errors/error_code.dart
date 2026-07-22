/// Velox 用户可见错误码 - ASCII 常量,不 i18n
/// 分配纪律: 只增不改,废弃标 @Deprecated 保留 code 值不复用
/// 完整号段表见 docs/error-codes/README.md
enum VeloxErrorCode {
  // 10xx 网络/传输
  connectionTimeout('VX-1001'),
  requestTimeout('VX-1002'),
  networkFailed('VX-1003'),
  connectionRefused('VX-1004'),
  noInternet('VX-1005'),
  badCertificate('VX-1006'),
  requestCancelled('VX-1007'),
  allHostsUnhealthy('VX-1099'),

  // 20xx HTTP
  badRequest('VX-2001'),
  resourceNotFound('VX-2004'),
  validationFailed('VX-2022'),
  tooManyRequests('VX-2029'),
  serverBusy('VX-2050'),
  gatewayError('VX-2052'),
  serviceUnavailable('VX-2053'),
  gatewayTimeout('VX-2054'),
  infraErrorPage('VX-2099'),

  // 30xx 认证/账号
  pleaseLogin('VX-3001'),
  loginExpired('VX-3002'),
  invalidToken('VX-3003'),
  emailOrPasswordIncorrect('VX-3011'),
  accountNotFound('VX-3012'),
  accountDisabled('VX-3013'),
  accountBanned('VX-3014'),
  tooManyAttempts('VX-3020'),

  // 31xx 注册
  registrationClosed('VX-3101'),
  invalidInviteCode('VX-3110'),

  // 32xx 验证码
  invalidVerificationCode('VX-3201'),

  // 40xx 订阅
  subscriptionExpired('VX-4001'),
  trafficLimitExceeded('VX-4010'),

  // 41xx 支付
  paymentFailed('VX-4101'),

  // 50xx Native VPN
  coreStartFailed('VX-5001'),
  tunPermissionDenied('VX-5010'),
  vpnServicePrepareFailed('VX-5011'),

  // 60xx 客户端自身状态
  apiEndpointListEmpty('VX-6001'),
  configLoadFailed('VX-6002'),

  // 90xx 未知兜底 (按模块细分)
  unknown('VX-9000'),
  unknownNetwork('VX-9001'),
  unknownHttp('VX-9002'),
  unknownAuth('VX-9003'),
  unknownBusiness('VX-9004'),
  unknownNative('VX-9005');

  final String code;
  const VeloxErrorCode(this.code);

  @override
  String toString() => code;
}
