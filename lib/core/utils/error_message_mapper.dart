import '../errors/error_code.dart';

/// 映射结果:同时携带错误键(用于 i18n)和 Velox 错误码(用于诊断/客服)
class ErrorMapping {
  final String errorKey;
  final VeloxErrorCode code;
  const ErrorMapping(this.errorKey, this.code);
}

/// 错误消息映射器 - 将后端错误转换为错误键
/// 返回的错误键可以通过 LocalizedErrorMapper 获取本地化消息
class ErrorMessageMapper {
  ErrorMessageMapper._();

  /// errorKey → VeloxErrorCode 的静态映射表
  /// 无对应的 key 走 unknownBusiness 兜底
  static const Map<String, VeloxErrorCode> _keyToCodeMap = {
    // 认证
    'errorEmailOrPasswordIncorrect': VeloxErrorCode.emailOrPasswordIncorrect,
    'errorPasswordIncorrect': VeloxErrorCode.emailOrPasswordIncorrect,
    'errorUserNotFound': VeloxErrorCode.accountNotFound,
    'errorAccountNotFound': VeloxErrorCode.accountNotFound,
    'errorEmailNotRegistered': VeloxErrorCode.accountNotFound,
    'errorAccountDisabled': VeloxErrorCode.accountDisabled,
    'errorAccountBanned': VeloxErrorCode.accountBanned,
    'errorTooManyAttempts': VeloxErrorCode.tooManyAttempts,
    'errorTooManyRequests': VeloxErrorCode.tooManyRequests,
    'errorLoginExpired': VeloxErrorCode.loginExpired,
    'errorInvalidToken': VeloxErrorCode.invalidToken,
    'errorPleaseLogin': VeloxErrorCode.pleaseLogin,
    'errorLoginFailed': VeloxErrorCode.emailOrPasswordIncorrect,
    'errorNoPermission': VeloxErrorCode.pleaseLogin,
    'errorAccessDenied': VeloxErrorCode.pleaseLogin,

    // 注册
    'errorEmailAlreadyRegistered': VeloxErrorCode.unknownAuth,
    'errorEmailInUse': VeloxErrorCode.unknownAuth,
    'errorInvalidEmailFormat': VeloxErrorCode.validationFailed,
    'errorPasswordTooShort': VeloxErrorCode.validationFailed,
    'errorPasswordTooWeak': VeloxErrorCode.validationFailed,
    'errorPasswordsNotMatch': VeloxErrorCode.validationFailed,
    'errorInvalidInviteCode': VeloxErrorCode.invalidInviteCode,
    'errorInviteCodeNotFound': VeloxErrorCode.invalidInviteCode,
    'errorInviteCodeUsed': VeloxErrorCode.invalidInviteCode,
    'errorInviteCodeExpired': VeloxErrorCode.invalidInviteCode,
    'errorRegistrationClosed': VeloxErrorCode.registrationClosed,
    'errorRegistrationRequiresInviteCode': VeloxErrorCode.invalidInviteCode,

    // 验证码
    'errorInvalidVerificationCode': VeloxErrorCode.invalidVerificationCode,
    'errorVerificationCodeExpired': VeloxErrorCode.invalidVerificationCode,
    'errorGetVerificationCodeFirst': VeloxErrorCode.invalidVerificationCode,
    'errorSendCodeTooFrequent': VeloxErrorCode.tooManyRequests,
    'errorEmailSendFailed': VeloxErrorCode.unknownBusiness,

    // 订阅/支付
    'errorSubscriptionExpired': VeloxErrorCode.subscriptionExpired,
    'errorSubscriptionNotFound': VeloxErrorCode.subscriptionExpired,
    'errorNoActiveSubscription': VeloxErrorCode.subscriptionExpired,
    'errorTrafficLimitExceeded': VeloxErrorCode.trafficLimitExceeded,
    'errorPlanNotFound': VeloxErrorCode.resourceNotFound,
    'errorOrderNotFound': VeloxErrorCode.resourceNotFound,
    'errorOrderAlreadyPaid': VeloxErrorCode.unknownBusiness,
    'errorOrderCancelled': VeloxErrorCode.unknownBusiness,
    'errorOrderExpired': VeloxErrorCode.unknownBusiness,
    'errorInsufficientBalance': VeloxErrorCode.paymentFailed,
    'errorPaymentFailed': VeloxErrorCode.paymentFailed,
    'errorCouponNotFound': VeloxErrorCode.resourceNotFound,
    'errorCouponUsed': VeloxErrorCode.unknownBusiness,
    'errorCouponExpired': VeloxErrorCode.unknownBusiness,
    'errorCouponNotApplicable': VeloxErrorCode.unknownBusiness,

    // 服务器 / HTTP
    'errorServerBusy': VeloxErrorCode.serverBusy,
    'errorServiceUnavailable': VeloxErrorCode.serviceUnavailable,
    'errorGatewayError': VeloxErrorCode.gatewayError,
    'errorGatewayTimeout': VeloxErrorCode.gatewayTimeout,
    'errorBadRequest': VeloxErrorCode.badRequest,
    'errorResourceNotFound': VeloxErrorCode.resourceNotFound,
    'errorValidationFailed': VeloxErrorCode.validationFailed,

    // 网络
    'errorNetworkFailed': VeloxErrorCode.networkFailed,
    'errorConnectionTimeout': VeloxErrorCode.connectionTimeout,
    'errorConnectionRefused': VeloxErrorCode.connectionRefused,
    'errorNoInternet': VeloxErrorCode.noInternet,
    'errorRequestTimeout': VeloxErrorCode.requestTimeout,

    // 工单/通用
    'errorTicketNotFound': VeloxErrorCode.resourceNotFound,
    'errorTicketClosed': VeloxErrorCode.unknownBusiness,
    'errorCannotCloseTicket': VeloxErrorCode.unknownBusiness,
    'errorOperationFailed': VeloxErrorCode.unknownBusiness,
    'errorUnknown': VeloxErrorCode.unknown,
    'errorExpired': VeloxErrorCode.unknownBusiness,
  };

  /// errorKey → VeloxErrorCode 查询(无匹配走 unknownBusiness)
  static VeloxErrorCode _keyToCode(String errorKey) {
    return _keyToCodeMap[errorKey] ?? VeloxErrorCode.unknownBusiness;
  }

  /// 同时返回 errorKey + Velox 错误码
  static ErrorMapping mapWithCode(String? message) {
    final key = map(message);
    return ErrorMapping(key, _keyToCode(key));
  }

  /// 同时返回 HTTP 状态码对应的 errorKey + Velox 错误码
  static ErrorMapping fromStatusCodeWithCode(int? statusCode) {
    final key = fromStatusCode(statusCode);
    final VeloxErrorCode code;
    switch (statusCode) {
      case 400:
        code = VeloxErrorCode.badRequest;
        break;
      case 401:
        code = VeloxErrorCode.pleaseLogin;
        break;
      case 403:
        code = VeloxErrorCode.pleaseLogin;
        break;
      case 404:
        code = VeloxErrorCode.resourceNotFound;
        break;
      case 408:
        code = VeloxErrorCode.requestTimeout;
        break;
      case 422:
        code = VeloxErrorCode.validationFailed;
        break;
      case 429:
        code = VeloxErrorCode.tooManyRequests;
        break;
      case 500:
        code = VeloxErrorCode.serverBusy;
        break;
      case 502:
        code = VeloxErrorCode.gatewayError;
        break;
      case 503:
        code = VeloxErrorCode.serviceUnavailable;
        break;
      case 504:
        code = VeloxErrorCode.gatewayTimeout;
        break;
      default:
        code = VeloxErrorCode.unknownHttp;
    }
    return ErrorMapping(key, code);
  }

  /// 常见错误消息映射表 (后端消息 -> 错误键)
  static const Map<String, String> _errorMappings = {
    // 认证相关
    'Invalid email or password': 'errorEmailOrPasswordIncorrect',
    'invalid email or password': 'errorEmailOrPasswordIncorrect',
    'Email or password is incorrect': 'errorEmailOrPasswordIncorrect',
    'The email or password is incorrect': 'errorEmailOrPasswordIncorrect',
    'Incorrect password': 'errorPasswordIncorrect',
    'Password is incorrect': 'errorPasswordIncorrect',
    'Wrong password': 'errorPasswordIncorrect',
    'User not found': 'errorUserNotFound',
    'Account not found': 'errorAccountNotFound',
    'Email not found': 'errorEmailNotRegistered',
    'Account does not exist': 'errorAccountNotFound',
    'Account has been disabled': 'errorAccountDisabled',
    'Account has been banned': 'errorAccountBanned',
    'Account suspended': 'errorAccountDisabled',
    'Too many login attempts': 'errorTooManyAttempts',
    'Too many requests': 'errorTooManyRequests',

    // 注册相关
    'Email already exists': 'errorEmailAlreadyRegistered',
    'Email has been registered': 'errorEmailAlreadyRegistered',
    'The email has already been taken': 'errorEmailAlreadyRegistered',
    'Email is already in use': 'errorEmailInUse',
    'Invalid email format': 'errorInvalidEmailFormat',
    'Invalid email': 'errorInvalidEmailFormat',
    'Password is too short': 'errorPasswordTooShort',
    'Password is too weak': 'errorPasswordTooWeak',
    'Passwords do not match': 'errorPasswordsNotMatch',
    'Invalid invite code': 'errorInvalidInviteCode',
    // V2Board 后端实际返回的英文(注意是 "invitation" 不是 "invite")
    'Invalid invitation code': 'errorInvalidInviteCode',
    'Invite code not found': 'errorInviteCodeNotFound',
    'Invite code has been used': 'errorInviteCodeUsed',
    'Invite code expired': 'errorInviteCodeExpired',
    'Registration is closed': 'errorRegistrationClosed',
    'Registration requires invite code': 'errorRegistrationRequiresInviteCode',
    // V2Board AuthController.php invite_force=ON + 空时的英文 abort 消息
    'You must use the invitation code to register':
        'errorRegistrationRequiresInviteCode',

    // 验证码相关
    'Invalid verification code': 'errorInvalidVerificationCode',
    'Verification code is incorrect': 'errorInvalidVerificationCode',
    'Verification code expired': 'errorVerificationCodeExpired',
    'Verification code has expired': 'errorVerificationCodeExpired',
    'Please get verification code first': 'errorGetVerificationCodeFirst',
    'Please wait before requesting another code': 'errorSendCodeTooFrequent',
    'Send too frequently': 'errorSendCodeTooFrequent',
    'Email send failed': 'errorEmailSendFailed',

    // 订阅相关
    'Subscription expired': 'errorSubscriptionExpired',
    'Subscription not found': 'errorSubscriptionNotFound',
    'No active subscription': 'errorNoActiveSubscription',
    'Traffic limit exceeded': 'errorTrafficLimitExceeded',
    'Plan not found': 'errorPlanNotFound',
    'Order not found': 'errorOrderNotFound',
    'Order has been paid': 'errorOrderAlreadyPaid',
    'Order has been cancelled': 'errorOrderCancelled',
    'Order expired': 'errorOrderExpired',
    'Insufficient balance': 'errorInsufficientBalance',
    'Payment failed': 'errorPaymentFailed',
    'Coupon not found': 'errorCouponNotFound',
    'Coupon has been used': 'errorCouponUsed',
    'Coupon expired': 'errorCouponExpired',
    'Coupon not applicable': 'errorCouponNotApplicable',

    // 服务器相关
    'Server error': 'errorServerBusy',
    'Internal server error': 'errorServerBusy',
    'Service unavailable': 'errorServiceUnavailable',
    'Bad gateway': 'errorGatewayError',
    'Gateway timeout': 'errorGatewayTimeout',
    'Database error': 'errorServerBusy',

    // 网络相关
    'Network error': 'errorNetworkFailed',
    'Connection timeout': 'errorConnectionTimeout',
    'Connection refused': 'errorConnectionRefused',
    'No internet connection': 'errorNoInternet',

    // 权限相关
    'Unauthorized': 'errorPleaseLogin',
    'Forbidden': 'errorNoPermission',
    'Access denied': 'errorAccessDenied',
    'Token expired': 'errorLoginExpired',
    'Invalid token': 'errorInvalidToken',

    // 工单相关
    'Ticket not found': 'errorTicketNotFound',
    'Ticket has been closed': 'errorTicketClosed',
    'Cannot close ticket': 'errorCannotCloseTicket',

    // 通用
    'Not found': 'errorResourceNotFound',
    'Bad request': 'errorBadRequest',
    'Validation failed': 'errorValidationFailed',
    'Operation failed': 'errorOperationFailed',
    'Unknown error': 'errorUnknown',
  };

  /// 中文错误消息映射表 (中文消息 -> 错误键)
  static const Map<String, String> _chineseMappings = {
    '邮箱或密码错误': 'errorEmailOrPasswordIncorrect',
    '密码错误': 'errorPasswordIncorrect',
    '用户不存在': 'errorUserNotFound',
    '账号不存在': 'errorAccountNotFound',
    '该邮箱未注册': 'errorEmailNotRegistered',
    '账号已被禁用': 'errorAccountDisabled',
    '账号已被封禁': 'errorAccountBanned',
    '登录尝试次数过多，请稍后再试': 'errorTooManyAttempts',
    '请求过于频繁，请稍后再试': 'errorTooManyRequests',
    '该邮箱已被注册': 'errorEmailAlreadyRegistered',
    '该邮箱已被使用': 'errorEmailInUse',
    '邮箱格式不正确': 'errorInvalidEmailFormat',
    '密码太短，至少需要6位': 'errorPasswordTooShort',
    '密码强度不够': 'errorPasswordTooWeak',
    '两次输入的密码不一致': 'errorPasswordsNotMatch',
    '邀请码无效': 'errorInvalidInviteCode',
    '邀请码不存在': 'errorInviteCodeNotFound',
    '邀请码已被使用': 'errorInviteCodeUsed',
    '邀请码已过期': 'errorInviteCodeExpired',
    // V2Board zh-CN.json 的真实返回 (invite_force=ON + 空)
    '必须使用邀请码才可以注册': 'errorRegistrationRequiresInviteCode',
    '暂不开放注册': 'errorRegistrationClosed',
    // V2Board register() stop_register=1 的真实翻译
    '本站已关闭注册': 'errorRegistrationClosed',
    '注册需要邀请码': 'errorRegistrationRequiresInviteCode',
    '验证码错误': 'errorInvalidVerificationCode',
    // V2Board register reCAPTCHA / email_code 错误的真实翻译
    '验证码有误': 'errorInvalidVerificationCode',
    '邮箱验证码有误': 'errorInvalidVerificationCode',
    '邮箱验证码不能为空': 'errorGetVerificationCodeFirst',
    '验证码已过期': 'errorVerificationCodeExpired',
    '请先获取验证码': 'errorGetVerificationCodeFirst',
    '发送过于频繁，请稍后再试': 'errorSendCodeTooFrequent',
    '邮件发送失败，请稍后再试': 'errorEmailSendFailed',
    // V2Board 账号封禁 / token 失效 / 用户不存在 的真实翻译
    '该账户已被停止使用': 'errorAccountDisabled',
    '令牌有误': 'errorInvalidToken',
    '该用户不存在': 'errorUserNotFound',
    'The user does not ': 'errorUserNotFound', // V2Board 源码有 typo,零翻译原样返回
    // V2Board register 邮箱唯一/白名单/Gmail 别名 的真实翻译
    '邮箱已在系统中存在': 'errorEmailAlreadyRegistered',
    '邮箱后缀不处于白名单中': 'errorInvalidEmailFormat',
    '不支持 Gmail 别名邮箱': 'errorInvalidEmailFormat',
    '注册失败': 'errorOperationFailed',
    // V2Board forget 分支
    '该邮箱不存在系统中': 'errorEmailNotRegistered',
    '重置失败': 'errorOperationFailed',
    '重置失败，请稍后再试': 'errorTooManyRequests',
    '订阅已过期': 'errorSubscriptionExpired',
    '未找到订阅': 'errorSubscriptionNotFound',
    '没有有效的订阅': 'errorNoActiveSubscription',
    '流量已用完': 'errorTrafficLimitExceeded',
    '套餐不存在': 'errorPlanNotFound',
    '订单不存在': 'errorOrderNotFound',
    '订单已支付': 'errorOrderAlreadyPaid',
    '订单已取消': 'errorOrderCancelled',
    '订单已过期': 'errorOrderExpired',
    '余额不足': 'errorInsufficientBalance',
    '支付失败': 'errorPaymentFailed',
    '优惠券不存在': 'errorCouponNotFound',
    '优惠券已被使用': 'errorCouponUsed',
    '优惠券已过期': 'errorCouponExpired',
    '优惠券不适用于此套餐': 'errorCouponNotApplicable',
    '服务器繁忙，请稍后再试': 'errorServerBusy',
    '服务暂时不可用': 'errorServiceUnavailable',
    '服务器网关错误': 'errorGatewayError',
    '服务器响应超时': 'errorGatewayTimeout',
    '网络连接失败，请检查网络': 'errorNetworkFailed',
    '连接超时，请检查网络': 'errorConnectionTimeout',
    '无法连接服务器': 'errorConnectionRefused',
    '无网络连接': 'errorNoInternet',
    '请先登录': 'errorPleaseLogin',
    '没有访问权限': 'errorNoPermission',
    '访问被拒绝': 'errorAccessDenied',
    '登录已过期，请重新登录': 'errorLoginExpired',
    '登录状态异常，请重新登录': 'errorInvalidToken',
    '工单不存在': 'errorTicketNotFound',
    '工单已关闭': 'errorTicketClosed',
    '无法关闭工单': 'errorCannotCloseTicket',
    '请求的资源不存在': 'errorResourceNotFound',
    '请求参数错误': 'errorBadRequest',
    '输入信息有误': 'errorValidationFailed',
    '操作失败，请重试': 'errorOperationFailed',
    '操作失败，请稍后再试': 'errorOperationFailed',
    '未知错误，请稍后再试': 'errorUnknown',
    '已过期，请重新操作': 'errorExpired',
    '请求超时，请稍后再试': 'errorRequestTimeout',
    '未登录或登陆已过期': 'errorLoginExpired',
    '未登录': 'errorPleaseLogin',
    '登陆已过期': 'errorLoginExpired',
    '登入失败': 'errorLoginFailed',
  };

  /// 中文部分匹配表 —— 处理带 :minute 动态变量的 V2Board 文案。
  /// Laravel 已把 :minute 替换成实际分钟数(如 "60"),客户端拿到的是
  ///   "密码错误次数过多，请 60 分钟后再试"
  /// 无法用精确匹配 —— 走 contains-match。
  /// 顺序:选取最具区分度的前缀,避免与其他消息误撞。
  static const List<MapEntry<String, String>> _chinesePartialMappings = [
    MapEntry('密码错误次数过多', 'errorTooManyAttempts'),
    MapEntry('注册频繁', 'errorTooManyRequests'),
    MapEntry('发送频繁', 'errorSendCodeTooFrequent'),
  ];

  /// 将后端错误消息转换为错误键
  static String map(String? message) {
    if (message == null || message.isEmpty) {
      return 'errorOperationFailed';
    }

    // 清理消息：去除前后空格，移除 "Exception:" 前缀
    String cleanMessage = message.trim();
    if (cleanMessage.startsWith('Exception:')) {
      cleanMessage = cleanMessage.substring('Exception:'.length).trim();
    }

    // 直接匹配英文映射
    if (_errorMappings.containsKey(cleanMessage)) {
      return _errorMappings[cleanMessage]!;
    }

    // 直接匹配中文映射
    if (_chineseMappings.containsKey(cleanMessage)) {
      return _chineseMappings[cleanMessage]!;
    }

    // 中文部分匹配(带 :minute 动态变量的场景)—— 必须在英文包含匹配之前,
    // 以防中文消息被英文关键词误吞。
    for (final entry in _chinesePartialMappings) {
      if (cleanMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    // 不区分大小写匹配英文
    final lowerMessage = cleanMessage.toLowerCase();
    for (final entry in _errorMappings.entries) {
      if (entry.key.toLowerCase() == lowerMessage) {
        return entry.value;
      }
    }

    // 部分匹配（包含关键词）
    for (final entry in _errorMappings.entries) {
      if (lowerMessage.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // 检查常见错误模式

    // 登录相关错误
    if ((lowerMessage.contains('email') || lowerMessage.contains('user')) &&
        lowerMessage.contains('password')) {
      return 'errorEmailOrPasswordIncorrect';
    }

    if (lowerMessage.contains('credentials') ||
        lowerMessage.contains('authentication failed') ||
        lowerMessage.contains('login failed') ||
        lowerMessage.contains('auth failed')) {
      return 'errorEmailOrPasswordIncorrect';
    }

    if (lowerMessage.contains('password') && lowerMessage.contains('incorrect') ||
        lowerMessage.contains('password') && lowerMessage.contains('wrong') ||
        lowerMessage.contains('password') && lowerMessage.contains('invalid')) {
      return 'errorPasswordIncorrect';
    }

    if (lowerMessage.contains('email') && lowerMessage.contains('exist') ||
        lowerMessage.contains('email') && lowerMessage.contains('taken') ||
        lowerMessage.contains('email') && lowerMessage.contains('registered')) {
      return 'errorEmailAlreadyRegistered';
    }

    if (lowerMessage.contains('email') && lowerMessage.contains('not found') ||
        lowerMessage.contains('user') && lowerMessage.contains('not found')) {
      return 'errorUserNotFound';
    }

    if (lowerMessage.contains('code') && lowerMessage.contains('invalid') ||
        lowerMessage.contains('code') && lowerMessage.contains('incorrect') ||
        lowerMessage.contains('code') && lowerMessage.contains('wrong')) {
      return 'errorInvalidVerificationCode';
    }

    if (lowerMessage.contains('code') && lowerMessage.contains('expire')) {
      return 'errorVerificationCodeExpired';
    }

    if (lowerMessage.contains('expired')) {
      return 'errorExpired';
    }

    if (lowerMessage.contains('timeout')) {
      return 'errorRequestTimeout';
    }

    if (lowerMessage.contains('network') || lowerMessage.contains('connection')) {
      return 'errorNetworkFailed';
    }

    if (lowerMessage.contains('server')) {
      return 'errorServerBusy';
    }

    // 如果是中文消息且能匹配到已知中文，返回对应键
    // 否则将中文消息作为键返回（LocalizedErrorMapper会直接显示）
    if (_isChinese(cleanMessage)) {
      return cleanMessage;
    }

    // 如果无法识别，返回通用错误
    return 'errorOperationFailed';
  }

  /// 检查字符串是否包含中文
  static bool _isChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  /// 根据 HTTP 状态码返回错误键
  static String fromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'errorBadRequest';
      case 401:
        return 'errorPleaseLogin';
      case 403:
        return 'errorNoPermission';
      case 404:
        return 'errorResourceNotFound';
      case 408:
        return 'errorRequestTimeout';
      case 422:
        return 'errorValidationFailed';
      case 429:
        return 'errorTooManyRequests';
      case 500:
        return 'errorServerBusy';
      case 502:
        return 'errorGatewayError';
      case 503:
        return 'errorServiceUnavailable';
      case 504:
        return 'errorGatewayTimeout';
      default:
        return 'errorOperationFailed';
    }
  }
}
