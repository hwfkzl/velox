import '../../l10n/app_localizations.dart';

/// 本地化错误消息映射器
/// 将错误键或消息转换为当前语言的错误提示
class LocalizedErrorMapper {
  LocalizedErrorMapper._();

  /// 错误键到本地化方法的映射
  static String getLocalizedError(AppLocalizations l10n, String errorKey) {
    // 尝试匹配错误键
    switch (errorKey) {
      // 认证相关
      case 'errorEmailOrPasswordIncorrect':
        return l10n.errorEmailOrPasswordIncorrect;
      case 'errorPasswordIncorrect':
        return l10n.errorPasswordIncorrect;
      case 'errorUserNotFound':
        return l10n.errorUserNotFound;
      case 'errorAccountNotFound':
        return l10n.errorAccountNotFound;
      case 'errorEmailNotRegistered':
        return l10n.errorEmailNotRegistered;
      case 'errorAccountDisabled':
        return l10n.errorAccountDisabled;
      case 'errorAccountBanned':
        return l10n.errorAccountBanned;
      case 'errorTooManyAttempts':
        return l10n.errorTooManyAttempts;
      case 'errorTooManyRequests':
        return l10n.errorTooManyRequests;

      // 注册相关
      case 'errorEmailAlreadyRegistered':
        return l10n.errorEmailAlreadyRegistered;
      case 'errorEmailInUse':
        return l10n.errorEmailInUse;
      case 'errorInvalidEmailFormat':
        return l10n.errorInvalidEmailFormat;
      case 'errorPasswordTooShort':
        return l10n.errorPasswordTooShort;
      case 'errorPasswordTooWeak':
        return l10n.errorPasswordTooWeak;
      case 'errorPasswordsNotMatch':
        return l10n.errorPasswordsNotMatch;
      case 'errorInvalidInviteCode':
        return l10n.errorInvalidInviteCode;
      case 'errorInviteCodeNotFound':
        return l10n.errorInviteCodeNotFound;
      case 'errorInviteCodeUsed':
        return l10n.errorInviteCodeUsed;
      case 'errorInviteCodeExpired':
        return l10n.errorInviteCodeExpired;
      case 'errorRegistrationClosed':
        return l10n.errorRegistrationClosed;
      case 'errorRegistrationRequiresInviteCode':
        return l10n.errorRegistrationRequiresInviteCode;

      // 验证码相关
      case 'errorInvalidVerificationCode':
        return l10n.errorInvalidVerificationCode;
      case 'errorVerificationCodeExpired':
        return l10n.errorVerificationCodeExpired;
      case 'errorGetVerificationCodeFirst':
        return l10n.errorGetVerificationCodeFirst;
      case 'errorSendCodeTooFrequent':
        return l10n.errorSendCodeTooFrequent;
      case 'errorEmailSendFailed':
        return l10n.errorEmailSendFailed;

      // 订阅相关
      case 'errorSubscriptionExpired':
        return l10n.errorSubscriptionExpired;
      case 'errorSubscriptionNotFound':
        return l10n.errorSubscriptionNotFound;
      case 'errorNoActiveSubscription':
        return l10n.errorNoActiveSubscription;
      case 'errorTrafficLimitExceeded':
        return l10n.errorTrafficLimitExceeded;
      case 'errorPlanNotFound':
        return l10n.errorPlanNotFound;

      // 订单相关
      case 'errorOrderNotFound':
        return l10n.errorOrderNotFound;
      case 'errorOrderAlreadyPaid':
        return l10n.errorOrderAlreadyPaid;
      case 'errorOrderCancelled':
        return l10n.errorOrderCancelled;
      case 'errorOrderExpired':
        return l10n.errorOrderExpired;
      case 'errorInsufficientBalance':
        return l10n.errorInsufficientBalance;
      case 'errorPaymentFailed':
        return l10n.errorPaymentFailed;
      case 'errorCouponNotFound':
        return l10n.errorCouponNotFound;
      case 'errorCouponUsed':
        return l10n.errorCouponUsed;
      case 'errorCouponExpired':
        return l10n.errorCouponExpired;
      case 'errorCouponNotApplicable':
        return l10n.errorCouponNotApplicable;

      // 服务器相关
      case 'errorServerBusy':
        return l10n.errorServerBusy;
      case 'errorServiceUnavailable':
        return l10n.errorServiceUnavailable;
      case 'errorGatewayError':
        return l10n.errorGatewayError;
      case 'errorGatewayTimeout':
        return l10n.errorGatewayTimeout;

      // 网络相关
      case 'errorNetworkFailed':
        return l10n.errorNetworkFailed;
      case 'errorConnectionTimeout':
        return l10n.errorConnectionTimeout;
      case 'errorConnectionRefused':
        return l10n.errorConnectionRefused;
      case 'errorNoInternet':
        return l10n.errorNoInternet;

      // 权限相关
      case 'errorPleaseLogin':
        return l10n.errorPleaseLogin;
      case 'errorNoPermission':
        return l10n.errorNoPermission;
      case 'errorAccessDenied':
        return l10n.errorAccessDenied;
      case 'errorLoginExpired':
        return l10n.errorLoginExpired;
      case 'errorInvalidToken':
        return l10n.errorInvalidToken;

      // 工单相关
      case 'errorTicketNotFound':
        return l10n.errorTicketNotFound;
      case 'errorTicketClosed':
        return l10n.errorTicketClosed;
      case 'errorCannotCloseTicket':
        return l10n.errorCannotCloseTicket;

      // 通用
      case 'errorResourceNotFound':
        return l10n.errorResourceNotFound;
      case 'errorBadRequest':
        return l10n.errorBadRequest;
      case 'errorValidationFailed':
        return l10n.errorValidationFailed;
      case 'errorOperationFailed':
        return l10n.errorOperationFailed;
      case 'errorUnknown':
        return l10n.errorUnknown;
      case 'errorExpired':
        return l10n.errorExpired;
      case 'errorRequestTimeout':
        return l10n.errorRequestTimeout;
      case 'errorLoginFailed':
        return l10n.errorLoginFailed;

      default:
        // 如果不是已知的错误键，尝试模式匹配
        return _mapByPattern(l10n, errorKey);
    }
  }

  /// 根据错误消息内容进行模式匹配
  static String _mapByPattern(AppLocalizations l10n, String message) {
    final lowerMessage = message.toLowerCase();

    // 登录相关
    if (lowerMessage.contains('email') && lowerMessage.contains('password') ||
        lowerMessage.contains('credentials') ||
        lowerMessage.contains('authentication failed') ||
        lowerMessage.contains('login failed') ||
        lowerMessage.contains('invalid email or password')) {
      return l10n.errorEmailOrPasswordIncorrect;
    }

    if (lowerMessage.contains('password') &&
        (lowerMessage.contains('incorrect') ||
            lowerMessage.contains('wrong') ||
            lowerMessage.contains('invalid'))) {
      return l10n.errorPasswordIncorrect;
    }

    // 用户不存在
    if (lowerMessage.contains('user') && lowerMessage.contains('not found') ||
        lowerMessage.contains('email') && lowerMessage.contains('not found') ||
        lowerMessage.contains('account') && lowerMessage.contains('not found')) {
      return l10n.errorUserNotFound;
    }

    // 邮箱已注册
    if (lowerMessage.contains('email') &&
        (lowerMessage.contains('exist') ||
            lowerMessage.contains('taken') ||
            lowerMessage.contains('registered') ||
            lowerMessage.contains('in use'))) {
      return l10n.errorEmailAlreadyRegistered;
    }

    // 验证码错误
    if (lowerMessage.contains('code') &&
        (lowerMessage.contains('invalid') ||
            lowerMessage.contains('incorrect') ||
            lowerMessage.contains('wrong'))) {
      return l10n.errorInvalidVerificationCode;
    }

    // 验证码过期
    if (lowerMessage.contains('code') && lowerMessage.contains('expire')) {
      return l10n.errorVerificationCodeExpired;
    }

    // 请求过于频繁
    if (lowerMessage.contains('too many') ||
        lowerMessage.contains('rate limit') ||
        lowerMessage.contains('frequent')) {
      return l10n.errorTooManyRequests;
    }

    // 过期
    if (lowerMessage.contains('expired') || lowerMessage.contains('expire')) {
      return l10n.errorExpired;
    }

    // 超时
    if (lowerMessage.contains('timeout') || lowerMessage.contains('timed out')) {
      return l10n.errorRequestTimeout;
    }

    // 网络错误
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('internet')) {
      return l10n.errorNetworkFailed;
    }

    // 服务器错误
    if (lowerMessage.contains('server') || lowerMessage.contains('internal')) {
      return l10n.errorServerBusy;
    }

    // 权限错误
    if (lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('permission') ||
        lowerMessage.contains('forbidden')) {
      return l10n.errorNoPermission;
    }

    // 默认返回原始消息（如果是中文则直接显示，否则显示通用错误）
    if (_containsChinese(message)) {
      return message;
    }

    return l10n.errorOperationFailed;
  }

  /// 检查字符串是否包含中文
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }
}
