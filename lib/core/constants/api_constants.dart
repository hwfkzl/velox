/// V2Board API 常量
class ApiConstants {
  ApiConstants._();

  // 站点配置（游客可访问）
  static const String siteConfig = '/api/v1/guest/comm/config';

  // 认证相关
  static const String register = '/api/v1/passport/auth/register';
  static const String login = '/api/v1/passport/auth/login';
  static const String logout = '/api/v1/passport/auth/logout';
  static const String forgotPassword = '/api/v1/passport/auth/forget';
  static const String sendVerifyCode = '/api/v1/passport/comm/sendEmailVerify';

  // 用户相关
  static const String userInfo = '/api/v1/user/info';
  static const String userUpdate = '/api/v1/user/update';
  static const String userSubscribe = '/api/v1/user/getSubscribe';
  static const String resetSubscribe = '/api/v1/user/resetSecurity';

  // 套餐相关
  static const String planList = '/api/v1/user/plan/fetch';
  static const String orderSave = '/api/v1/user/order/save';
  static const String orderList = '/api/v1/user/order/fetch';
  static const String orderDetail = '/api/v1/user/order/detail';
  static const String orderCheckout = '/api/v1/user/order/checkout';
  static const String orderCancel = '/api/v1/user/order/cancel';
  static const String paymentMethods = '/api/v1/user/order/getPaymentMethod';

  // 节点相关
  static const String serverList = '/api/v1/user/server/fetch';
  static const String subscribe = '/api/v1/client/subscribe';
  static const String veloxSync = '/api/v1/client/velox/sync';

  // 通知相关
  static const String noticeList = '/api/v1/user/notice/fetch';

  // 工单相关
  static const String ticketList = '/api/v1/user/ticket/fetch';
  static const String ticketDetail = '/api/v1/user/ticket/fetch';
  static const String ticketSave = '/api/v1/user/ticket/save';
  static const String ticketReply = '/api/v1/user/ticket/reply';
  static const String ticketClose = '/api/v1/user/ticket/close';
  static const String ticketUpload = '/api/v1/user/ticket/attach';

  // 邀请相关
  static const String inviteInfo    = '/api/v1/user/invite/fetch';
  static const String inviteSave    = '/api/v1/user/invite/save';
  static const String inviteDetails = '/api/v1/user/invite/details';

  // 知识库
  static const String knowledgeList = '/api/v1/user/knowledge/fetch';
  static const String knowledgeDetail = '/api/v1/user/knowledge/getCategory';

  // 优惠券
  static const String couponCheck = '/api/v1/user/coupon/check';
}
