import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Velox'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'电子邮件'**
  String get email;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @inviteCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get inviteCode;

  /// No description provided for @verifyCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get verifyCode;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @forgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？'**
  String get noAccount;

  /// No description provided for @hasAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？'**
  String get hasAccount;

  /// No description provided for @loginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get loginSuccess;

  /// No description provided for @registerSuccess.
  ///
  /// In zh, this message translates to:
  /// **'注册成功'**
  String get registerSuccess;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要登出吗？'**
  String get logoutConfirm;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @nodes.
  ///
  /// In zh, this message translates to:
  /// **'节点'**
  String get nodes;

  /// No description provided for @selectNode.
  ///
  /// In zh, this message translates to:
  /// **'选择节点'**
  String get selectNode;

  /// No description provided for @subscription.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get subscription;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @tapToConnect.
  ///
  /// In zh, this message translates to:
  /// **'点击按钮连接'**
  String get tapToConnect;

  /// No description provided for @nodeUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'节点不可用，请尝试其他节点'**
  String get nodeUnreachable;

  /// No description provided for @latencyTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时'**
  String get latencyTimeout;

  /// No description provided for @trafficUsage.
  ///
  /// In zh, this message translates to:
  /// **'流量使用'**
  String get trafficUsage;

  /// No description provided for @userCenter.
  ///
  /// In zh, this message translates to:
  /// **'用户中心'**
  String get userCenter;

  /// No description provided for @telegramGroup.
  ///
  /// In zh, this message translates to:
  /// **'Telegram 群组'**
  String get telegramGroup;

  /// No description provided for @earnRewards.
  ///
  /// In zh, this message translates to:
  /// **'获得奖励'**
  String get earnRewards;

  /// No description provided for @successfullyShared.
  ///
  /// In zh, this message translates to:
  /// **'已注册用户数'**
  String get successfullyShared;

  /// No description provided for @commissionReward.
  ///
  /// In zh, this message translates to:
  /// **'佣金奖励'**
  String get commissionReward;

  /// No description provided for @commissionPending.
  ///
  /// In zh, this message translates to:
  /// **'待结算佣金'**
  String get commissionPending;

  /// No description provided for @peopleSuffix.
  ///
  /// In zh, this message translates to:
  /// **'人'**
  String get peopleSuffix;

  /// No description provided for @connect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get disconnect;

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get connecting;

  /// No description provided for @disconnecting.
  ///
  /// In zh, this message translates to:
  /// **'断开中...'**
  String get disconnecting;

  /// No description provided for @connected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get disconnected;

  /// No description provided for @connectionTime.
  ///
  /// In zh, this message translates to:
  /// **'连接时长'**
  String get connectionTime;

  /// No description provided for @uploadSpeed.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get uploadSpeed;

  /// No description provided for @downloadSpeed.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get downloadSpeed;

  /// No description provided for @allNodes.
  ///
  /// In zh, this message translates to:
  /// **'全部节点'**
  String get allNodes;

  /// No description provided for @favoriteNodes.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favoriteNodes;

  /// No description provided for @recentNodes.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get recentNodes;

  /// No description provided for @nodeLatency.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get nodeLatency;

  /// No description provided for @nodeLoad.
  ///
  /// In zh, this message translates to:
  /// **'负载'**
  String get nodeLoad;

  /// No description provided for @testSpeed.
  ///
  /// In zh, this message translates to:
  /// **'测速'**
  String get testSpeed;

  /// No description provided for @testingSpeed.
  ///
  /// In zh, this message translates to:
  /// **'测速中...'**
  String get testingSpeed;

  /// No description provided for @addToFavorite.
  ///
  /// In zh, this message translates to:
  /// **'加入收藏'**
  String get addToFavorite;

  /// No description provided for @removeFromFavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get removeFromFavorite;

  /// No description provided for @currentPlan.
  ///
  /// In zh, this message translates to:
  /// **'当前套餐'**
  String get currentPlan;

  /// No description provided for @expireDate.
  ///
  /// In zh, this message translates to:
  /// **'到期时间：{date}'**
  String expireDate(Object date);

  /// No description provided for @dataUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用流量'**
  String get dataUsed;

  /// No description provided for @dataTotal.
  ///
  /// In zh, this message translates to:
  /// **'总流量'**
  String get dataTotal;

  /// No description provided for @resetDate.
  ///
  /// In zh, this message translates to:
  /// **'重置日期'**
  String get resetDate;

  /// No description provided for @buyPlan.
  ///
  /// In zh, this message translates to:
  /// **'购买套餐'**
  String get buyPlan;

  /// No description provided for @renewPlan.
  ///
  /// In zh, this message translates to:
  /// **'续费'**
  String get renewPlan;

  /// No description provided for @daysRemaining.
  ///
  /// In zh, this message translates to:
  /// **'还剩 {days} 天'**
  String daysRemaining(Object days);

  /// No description provided for @planExpired.
  ///
  /// In zh, this message translates to:
  /// **'已到期'**
  String get planExpired;

  /// No description provided for @expiresOnDate.
  ///
  /// In zh, this message translates to:
  /// **'{date} 到期'**
  String expiresOnDate(Object date);

  /// No description provided for @noSubscription.
  ///
  /// In zh, this message translates to:
  /// **'暂无订阅'**
  String get noSubscription;

  /// No description provided for @subscribeHint.
  ///
  /// In zh, this message translates to:
  /// **'开通订阅，解锁全部节点'**
  String get subscribeHint;

  /// No description provided for @trafficUsedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get trafficUsedLabel;

  /// No description provided for @trafficRemainingLabel.
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get trafficRemainingLabel;

  /// No description provided for @planList.
  ///
  /// In zh, this message translates to:
  /// **'可用套餐'**
  String get planList;

  /// No description provided for @orderHistory.
  ///
  /// In zh, this message translates to:
  /// **'订单记录'**
  String get orderHistory;

  /// No description provided for @balance.
  ///
  /// In zh, this message translates to:
  /// **'余额'**
  String get balance;

  /// No description provided for @inviteCount.
  ///
  /// In zh, this message translates to:
  /// **'邀请人数'**
  String get inviteCount;

  /// No description provided for @commission.
  ///
  /// In zh, this message translates to:
  /// **'佣金'**
  String get commission;

  /// No description provided for @copyInviteLink.
  ///
  /// In zh, this message translates to:
  /// **'复制邀请链接'**
  String get copyInviteLink;

  /// No description provided for @copySuccess.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copySuccess;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @autoConnect.
  ///
  /// In zh, this message translates to:
  /// **'自动连接'**
  String get autoConnect;

  /// No description provided for @autoReconnect.
  ///
  /// In zh, this message translates to:
  /// **'断线自动重连'**
  String get autoReconnect;

  /// No description provided for @proxyMode.
  ///
  /// In zh, this message translates to:
  /// **'代理模式'**
  String get proxyMode;

  /// No description provided for @proxyModeGlobal.
  ///
  /// In zh, this message translates to:
  /// **'全局代理'**
  String get proxyModeGlobal;

  /// No description provided for @proxyModeRule.
  ///
  /// In zh, this message translates to:
  /// **'规则代理'**
  String get proxyModeRule;

  /// No description provided for @proxyModeDirect.
  ///
  /// In zh, this message translates to:
  /// **'直连'**
  String get proxyModeDirect;

  /// No description provided for @dns.
  ///
  /// In zh, this message translates to:
  /// **'DNS 设置'**
  String get dns;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get termsOfService;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get info;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误，请检查网络连接'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后再试'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @createAccount.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get createAccount;

  /// No description provided for @signUpToGetStarted.
  ///
  /// In zh, this message translates to:
  /// **'注册以开始使用'**
  String get signUpToGetStarted;

  /// No description provided for @welcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In zh, this message translates to:
  /// **'登录以继续'**
  String get signInToContinue;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入电子邮件'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的电子邮件'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码长度至少6个字符'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'密码不一致'**
  String get passwordsDoNotMatch;

  /// No description provided for @resetPassword.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get resetPassword;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'输入邮箱接收验证码，重置密码'**
  String get resetPasswordSubtitle;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码重置成功，请重新登录'**
  String get passwordResetSuccess;

  /// No description provided for @rememberPassword.
  ///
  /// In zh, this message translates to:
  /// **'想起密码了？'**
  String get rememberPassword;

  /// No description provided for @enterEmailForReset.
  ///
  /// In zh, this message translates to:
  /// **'输入您的电子邮件以重置密码'**
  String get enterEmailForReset;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @verificationCodeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送'**
  String get verificationCodeSent;

  /// No description provided for @resetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码重置成功'**
  String get resetSuccess;

  /// No description provided for @step.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get step;

  /// No description provided for @enterEmail.
  ///
  /// In zh, this message translates to:
  /// **'输入电子邮件'**
  String get enterEmail;

  /// No description provided for @verifyEmail.
  ///
  /// In zh, this message translates to:
  /// **'验证电子邮件'**
  String get verifyEmail;

  /// No description provided for @setNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码'**
  String get setNewPassword;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @inviteFriends.
  ///
  /// In zh, this message translates to:
  /// **'邀请好友'**
  String get inviteFriends;

  /// No description provided for @yourInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'您的邀请码'**
  String get yourInviteCode;

  /// No description provided for @tapToCopy.
  ///
  /// In zh, this message translates to:
  /// **'点击复制'**
  String get tapToCopy;

  /// No description provided for @inviteLink.
  ///
  /// In zh, this message translates to:
  /// **'邀请链接'**
  String get inviteLink;

  /// No description provided for @shareInviteLink.
  ///
  /// In zh, this message translates to:
  /// **'分享邀请链接'**
  String get shareInviteLink;

  /// No description provided for @totalInvites.
  ///
  /// In zh, this message translates to:
  /// **'总邀请数'**
  String get totalInvites;

  /// No description provided for @pendingCommission.
  ///
  /// In zh, this message translates to:
  /// **'待确认'**
  String get pendingCommission;

  /// No description provided for @confirmedCommission.
  ///
  /// In zh, this message translates to:
  /// **'已确认'**
  String get confirmedCommission;

  /// No description provided for @inviteRecords.
  ///
  /// In zh, this message translates to:
  /// **'邀请记录'**
  String get inviteRecords;

  /// No description provided for @noInviteRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无邀请记录'**
  String get noInviteRecords;

  /// No description provided for @generateNewCode.
  ///
  /// In zh, this message translates to:
  /// **'生成新代码'**
  String get generateNewCode;

  /// No description provided for @orders.
  ///
  /// In zh, this message translates to:
  /// **'订单'**
  String get orders;

  /// No description provided for @allOrders.
  ///
  /// In zh, this message translates to:
  /// **'所有订单'**
  String get allOrders;

  /// No description provided for @pendingOrders.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get pendingOrders;

  /// No description provided for @completedOrders.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completedOrders;

  /// No description provided for @cancelledOrders.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelledOrders;

  /// No description provided for @orderNo.
  ///
  /// In zh, this message translates to:
  /// **'订单编号'**
  String get orderNo;

  /// No description provided for @orderTime.
  ///
  /// In zh, this message translates to:
  /// **'订单时间'**
  String get orderTime;

  /// No description provided for @orderAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get orderAmount;

  /// No description provided for @orderStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get orderStatus;

  /// No description provided for @payNow.
  ///
  /// In zh, this message translates to:
  /// **'立即支付'**
  String get payNow;

  /// No description provided for @cancelOrder.
  ///
  /// In zh, this message translates to:
  /// **'取消订单'**
  String get cancelOrder;

  /// No description provided for @noOrders.
  ///
  /// In zh, this message translates to:
  /// **'暂无订单'**
  String get noOrders;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In zh, this message translates to:
  /// **'选择付款方式'**
  String get selectPaymentMethod;

  /// No description provided for @pay.
  ///
  /// In zh, this message translates to:
  /// **'支付'**
  String get pay;

  /// No description provided for @helpAndSupport.
  ///
  /// In zh, this message translates to:
  /// **'帮助与支持'**
  String get helpAndSupport;

  /// No description provided for @faq.
  ///
  /// In zh, this message translates to:
  /// **'常见问题'**
  String get faq;

  /// No description provided for @submitTicket.
  ///
  /// In zh, this message translates to:
  /// **'提交工單'**
  String get submitTicket;

  /// No description provided for @myTickets.
  ///
  /// In zh, this message translates to:
  /// **'我的工单'**
  String get myTickets;

  /// No description provided for @ticketSubject.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get ticketSubject;

  /// No description provided for @ticketMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get ticketMessage;

  /// No description provided for @ticketLevel.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get ticketLevel;

  /// No description provided for @ticketLevelLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get ticketLevelLow;

  /// No description provided for @ticketLevelMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get ticketLevelMedium;

  /// No description provided for @ticketLevelHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get ticketLevelHigh;

  /// No description provided for @ticketOpen.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get ticketOpen;

  /// No description provided for @ticketClosed.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get ticketClosed;

  /// No description provided for @ticketReplied.
  ///
  /// In zh, this message translates to:
  /// **'已回复'**
  String get ticketReplied;

  /// No description provided for @noTickets.
  ///
  /// In zh, this message translates to:
  /// **'暂无工单'**
  String get noTickets;

  /// No description provided for @closeTicket.
  ///
  /// In zh, this message translates to:
  /// **'关闭工单'**
  String get closeTicket;

  /// No description provided for @replyTicket.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get replyTicket;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @newTicket.
  ///
  /// In zh, this message translates to:
  /// **'新工单'**
  String get newTicket;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @knowledgeBase.
  ///
  /// In zh, this message translates to:
  /// **'知识库'**
  String get knowledgeBase;

  /// No description provided for @selectPlan.
  ///
  /// In zh, this message translates to:
  /// **'选择套餐'**
  String get selectPlan;

  /// No description provided for @choosePlan.
  ///
  /// In zh, this message translates to:
  /// **'选择您的套餐'**
  String get choosePlan;

  /// No description provided for @billingCycle.
  ///
  /// In zh, this message translates to:
  /// **'计费周期'**
  String get billingCycle;

  /// No description provided for @monthly.
  ///
  /// In zh, this message translates to:
  /// **'月付'**
  String get monthly;

  /// No description provided for @quarterly.
  ///
  /// In zh, this message translates to:
  /// **'季付'**
  String get quarterly;

  /// No description provided for @halfYearly.
  ///
  /// In zh, this message translates to:
  /// **'半年付'**
  String get halfYearly;

  /// No description provided for @yearly.
  ///
  /// In zh, this message translates to:
  /// **'年付'**
  String get yearly;

  /// No description provided for @couponCode.
  ///
  /// In zh, this message translates to:
  /// **'优惠码'**
  String get couponCode;

  /// No description provided for @applyCoupon.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyCoupon;

  /// No description provided for @total.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get total;

  /// No description provided for @checkout.
  ///
  /// In zh, this message translates to:
  /// **'结账'**
  String get checkout;

  /// No description provided for @orderCreated.
  ///
  /// In zh, this message translates to:
  /// **'订单创建成功'**
  String get orderCreated;

  /// No description provided for @perMonth.
  ///
  /// In zh, this message translates to:
  /// **'/月'**
  String get perMonth;

  /// No description provided for @speedLimit.
  ///
  /// In zh, this message translates to:
  /// **'速度限制'**
  String get speedLimit;

  /// No description provided for @dataPerMonth.
  ///
  /// In zh, this message translates to:
  /// **'{data} / 月'**
  String dataPerMonth(Object data);

  /// No description provided for @dnsSettings.
  ///
  /// In zh, this message translates to:
  /// **'DNS 设置'**
  String get dnsSettings;

  /// No description provided for @primaryDns.
  ///
  /// In zh, this message translates to:
  /// **'主要 DNS'**
  String get primaryDns;

  /// No description provided for @secondaryDns.
  ///
  /// In zh, this message translates to:
  /// **'备用 DNS'**
  String get secondaryDns;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @savedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get savedSuccessfully;

  /// No description provided for @appInfo.
  ///
  /// In zh, this message translates to:
  /// **'应用信息'**
  String get appInfo;

  /// No description provided for @developer.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get developer;

  /// No description provided for @website.
  ///
  /// In zh, this message translates to:
  /// **'网站'**
  String get website;

  /// No description provided for @sourceCode.
  ///
  /// In zh, this message translates to:
  /// **'源代码'**
  String get sourceCode;

  /// No description provided for @licenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get licenses;

  /// No description provided for @rateApp.
  ///
  /// In zh, this message translates to:
  /// **'评价应用'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In zh, this message translates to:
  /// **'分享应用'**
  String get shareApp;

  /// No description provided for @contactUs.
  ///
  /// In zh, this message translates to:
  /// **'联系我们'**
  String get contactUs;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @dataTransfer.
  ///
  /// In zh, this message translates to:
  /// **'流量'**
  String get dataTransfer;

  /// No description provided for @expires.
  ///
  /// In zh, this message translates to:
  /// **'到期时间'**
  String get expires;

  /// No description provided for @resetDay.
  ///
  /// In zh, this message translates to:
  /// **'重置日'**
  String get resetDay;

  /// No description provided for @day.
  ///
  /// In zh, this message translates to:
  /// **'第 {day} 日'**
  String day(Object day);

  /// No description provided for @usedPercent.
  ///
  /// In zh, this message translates to:
  /// **'已使用 {percent}%'**
  String usedPercent(Object percent);

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @refreshSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get refreshSuccess;

  /// No description provided for @refreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get refreshFailed;

  /// No description provided for @refreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新订阅信息'**
  String get refreshTooltip;

  /// No description provided for @inviteCodeRequired.
  ///
  /// In zh, this message translates to:
  /// **'邀请码（必填）'**
  String get inviteCodeRequired;

  /// No description provided for @pleaseEnterInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'请填写邀请码'**
  String get pleaseEnterInviteCode;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sort;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @less.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get less;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'無'**
  String get none;

  /// No description provided for @yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get no;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @announcements.
  ///
  /// In zh, this message translates to:
  /// **'公告'**
  String get announcements;

  /// No description provided for @noAnnouncements.
  ///
  /// In zh, this message translates to:
  /// **'暂无公告'**
  String get noAnnouncements;

  /// No description provided for @readMore.
  ///
  /// In zh, this message translates to:
  /// **'阅读更多'**
  String get readMore;

  /// No description provided for @switchLanguage.
  ///
  /// In zh, this message translates to:
  /// **'切换语言'**
  String get switchLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get selectLanguage;

  /// No description provided for @currency.
  ///
  /// In zh, this message translates to:
  /// **'货币'**
  String get currency;

  /// No description provided for @selectCurrency.
  ///
  /// In zh, this message translates to:
  /// **'选择货币'**
  String get selectCurrency;

  /// No description provided for @purchaseSubscription.
  ///
  /// In zh, this message translates to:
  /// **'购买订阅'**
  String get purchaseSubscription;

  /// No description provided for @choosePlanDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择适合您的套餐'**
  String get choosePlanDescription;

  /// No description provided for @popular.
  ///
  /// In zh, this message translates to:
  /// **'热门'**
  String get popular;

  /// No description provided for @bestValue.
  ///
  /// In zh, this message translates to:
  /// **'最优惠'**
  String get bestValue;

  /// No description provided for @unlimited.
  ///
  /// In zh, this message translates to:
  /// **'无限制'**
  String get unlimited;

  /// No description provided for @devicesAllowed.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个设备'**
  String devicesAllowed(Object count);

  /// No description provided for @trafficPerMonth.
  ///
  /// In zh, this message translates to:
  /// **'{data} GB / 月'**
  String trafficPerMonth(Object data);

  /// No description provided for @noSpeedLimit.
  ///
  /// In zh, this message translates to:
  /// **'不限速'**
  String get noSpeedLimit;

  /// No description provided for @speedLimitValue.
  ///
  /// In zh, this message translates to:
  /// **'限速: {speed} Mbps'**
  String speedLimitValue(Object speed);

  /// No description provided for @subscribedPlan.
  ///
  /// In zh, this message translates to:
  /// **'当前套餐'**
  String get subscribedPlan;

  /// No description provided for @selectThisPlan.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get selectThisPlan;

  /// No description provided for @proceedToPayment.
  ///
  /// In zh, this message translates to:
  /// **'前往付款'**
  String get proceedToPayment;

  /// No description provided for @contactSupport.
  ///
  /// In zh, this message translates to:
  /// **'联系客服'**
  String get contactSupport;

  /// No description provided for @joinTelegram.
  ///
  /// In zh, this message translates to:
  /// **'加入 Telegram'**
  String get joinTelegram;

  /// No description provided for @telegramChannel.
  ///
  /// In zh, this message translates to:
  /// **'Telegram 频道'**
  String get telegramChannel;

  /// No description provided for @customerService.
  ///
  /// In zh, this message translates to:
  /// **'客服'**
  String get customerService;

  /// No description provided for @liveChat.
  ///
  /// In zh, this message translates to:
  /// **'在线客服'**
  String get liveChat;

  /// No description provided for @twoYear.
  ///
  /// In zh, this message translates to:
  /// **'两年'**
  String get twoYear;

  /// No description provided for @threeYear.
  ///
  /// In zh, this message translates to:
  /// **'三年'**
  String get threeYear;

  /// No description provided for @oneTime.
  ///
  /// In zh, this message translates to:
  /// **'一次性'**
  String get oneTime;

  /// No description provided for @savePercent.
  ///
  /// In zh, this message translates to:
  /// **'省 {percent}%'**
  String savePercent(Object percent);

  /// No description provided for @helpCenter.
  ///
  /// In zh, this message translates to:
  /// **'帮助中心'**
  String get helpCenter;

  /// No description provided for @commonQuestions.
  ///
  /// In zh, this message translates to:
  /// **'常见问题'**
  String get commonQuestions;

  /// No description provided for @viewAllArticles.
  ///
  /// In zh, this message translates to:
  /// **'查看所有文章'**
  String get viewAllArticles;

  /// No description provided for @loginToContinue.
  ///
  /// In zh, this message translates to:
  /// **'登录以继续使用 Velox'**
  String get loginToContinue;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// No description provided for @or.
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get or;

  /// No description provided for @phoneLogin.
  ///
  /// In zh, this message translates to:
  /// **'手机验证码登录'**
  String get phoneLogin;

  /// No description provided for @scanToImport.
  ///
  /// In zh, this message translates to:
  /// **'扫码导入订阅'**
  String get scanToImport;

  /// No description provided for @registerNow.
  ///
  /// In zh, this message translates to:
  /// **'立即注册'**
  String get registerNow;

  /// No description provided for @urlImport.
  ///
  /// In zh, this message translates to:
  /// **'导入订阅'**
  String get urlImport;

  /// No description provided for @pleaseEnterSubscriptionLink.
  ///
  /// In zh, this message translates to:
  /// **'请输入订阅链接'**
  String get pleaseEnterSubscriptionLink;

  /// No description provided for @pasteSubscriptionLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'请粘贴订阅链接...'**
  String get pasteSubscriptionLinkHint;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In zh, this message translates to:
  /// **'从剪贴板粘贴'**
  String get pasteFromClipboard;

  /// No description provided for @howToGetSubscriptionLink.
  ///
  /// In zh, this message translates to:
  /// **'如何获取订阅链接？'**
  String get howToGetSubscriptionLink;

  /// No description provided for @subscriptionLinkStep1.
  ///
  /// In zh, this message translates to:
  /// **'1. 登录您的服务商网站'**
  String get subscriptionLinkStep1;

  /// No description provided for @subscriptionLinkStep2.
  ///
  /// In zh, this message translates to:
  /// **'2. 在「我的订阅」页面找到订阅链接'**
  String get subscriptionLinkStep2;

  /// No description provided for @subscriptionLinkStep3.
  ///
  /// In zh, this message translates to:
  /// **'3. 复制链接并粘贴到此处'**
  String get subscriptionLinkStep3;

  /// No description provided for @importSubscription.
  ///
  /// In zh, this message translates to:
  /// **'导入订阅'**
  String get importSubscription;

  /// No description provided for @createNewTicket.
  ///
  /// In zh, this message translates to:
  /// **'创建新工单'**
  String get createNewTicket;

  /// No description provided for @ticketSubjectHint.
  ///
  /// In zh, this message translates to:
  /// **'简述您的问题'**
  String get ticketSubjectHint;

  /// No description provided for @ticketMessageHint.
  ///
  /// In zh, this message translates to:
  /// **'详细描述您的问题'**
  String get ticketMessageHint;

  /// No description provided for @priority.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get priority;

  /// No description provided for @noFaqArticles.
  ///
  /// In zh, this message translates to:
  /// **'暂无常见问题文章'**
  String get noFaqArticles;

  /// No description provided for @untitled.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get untitled;

  /// No description provided for @noContent.
  ///
  /// In zh, this message translates to:
  /// **'无内容'**
  String get noContent;

  /// No description provided for @noTicketsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无工单'**
  String get noTicketsYet;

  /// No description provided for @createTicketHelp.
  ///
  /// In zh, this message translates to:
  /// **'如需帮助，请创建工单'**
  String get createTicketHelp;

  /// No description provided for @noSubject.
  ///
  /// In zh, this message translates to:
  /// **'无主题'**
  String get noSubject;

  /// No description provided for @newReply.
  ///
  /// In zh, this message translates to:
  /// **'新'**
  String get newReply;

  /// No description provided for @closeTicketAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭工单'**
  String get closeTicketAction;

  /// No description provided for @ticketStatusOpen.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get ticketStatusOpen;

  /// No description provided for @ticketStatusClosed.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get ticketStatusClosed;

  /// No description provided for @priorityLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get priorityHigh;

  /// No description provided for @priorityUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get priorityUnknown;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navNodes.
  ///
  /// In zh, this message translates to:
  /// **'节点'**
  String get navNodes;

  /// No description provided for @navStats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get navStats;

  /// No description provided for @navSubscription.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get navSubscription;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navSettings;

  /// No description provided for @statusConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get statusConnecting;

  /// No description provided for @statusDisconnecting.
  ///
  /// In zh, this message translates to:
  /// **'断开中...'**
  String get statusDisconnecting;

  /// No description provided for @statusDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get statusDisconnected;

  /// No description provided for @selectServer.
  ///
  /// In zh, this message translates to:
  /// **'选择节点'**
  String get selectServer;

  /// No description provided for @selectServerFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择服务器'**
  String get selectServerFirst;

  /// No description provided for @autoSelect.
  ///
  /// In zh, this message translates to:
  /// **'自动选择'**
  String get autoSelect;

  /// No description provided for @autoSelectSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自动选择最优节点'**
  String get autoSelectSubtitle;

  /// No description provided for @upload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @connectButton.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connectButton;

  /// No description provided for @disconnectButton.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get disconnectButton;

  /// No description provided for @scanQrCode.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get scanQrCode;

  /// No description provided for @qrScanHint.
  ///
  /// In zh, this message translates to:
  /// **'将二维码放入框内即可自动扫描'**
  String get qrScanHint;

  /// No description provided for @gallery.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get gallery;

  /// No description provided for @flashlight.
  ///
  /// In zh, this message translates to:
  /// **'闪光灯'**
  String get flashlight;

  /// No description provided for @linkImport.
  ///
  /// In zh, this message translates to:
  /// **'链接导入'**
  String get linkImport;

  /// No description provided for @testAllNodes.
  ///
  /// In zh, this message translates to:
  /// **'延迟测试'**
  String get testAllNodes;

  /// No description provided for @updateNodes.
  ///
  /// In zh, this message translates to:
  /// **'更新节点'**
  String get updateNodes;

  /// No description provided for @noNodesAvailable.
  ///
  /// In zh, this message translates to:
  /// **'无可用节点'**
  String get noNodesAvailable;

  /// No description provided for @uuidCopied.
  ///
  /// In zh, this message translates to:
  /// **'UUID 已复制'**
  String get uuidCopied;

  /// No description provided for @inviteFriendsMenu.
  ///
  /// In zh, this message translates to:
  /// **'我的邀请'**
  String get inviteFriendsMenu;

  /// No description provided for @orderHistoryMenu.
  ///
  /// In zh, this message translates to:
  /// **'订单记录'**
  String get orderHistoryMenu;

  /// No description provided for @helpSupportMenu.
  ///
  /// In zh, this message translates to:
  /// **'帮助与支持'**
  String get helpSupportMenu;

  /// No description provided for @aboutMenu.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutMenu;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要登出吗？'**
  String get logoutConfirmMessage;

  /// No description provided for @stats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get stats;

  /// No description provided for @gameDescription.
  ///
  /// In zh, this message translates to:
  /// **'Velox 提供稳定便捷的网络加速服务，界面简洁直观，一键连接全球高速节点。'**
  String get gameDescription;

  /// No description provided for @termsContent.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 Velox！使用本应用即表示您同意以下服务条款。\n\n1. 服务说明\nVelox 是一款网络加速工具，旨在为用户提供安全、稳定的网络连接服务。\n\n2. 用户责任\n用户应遵守所在地区的法律法规，不得利用本服务从事任何违法活动。用户对其账号下的所有行为承担责任。\n\n3. 账号管理\n每个账号仅供注册用户本人使用，禁止转让、出借或共享账号。我们有权对违规账号进行限制或封禁。\n\n4. 服务变更\n我们保留随时修改、暂停或终止服务的权利，届时将通过应用内通知告知用户。\n\n5. 免责声明\n本服务按「现状」提供，我们不对因网络环境变化、不可抗力等因素导致的服务中断承担责任。\n\n6. 知识产权\n本应用的所有内容、设计和技术均受知识产权法保护，未经授权不得复制或使用。\n\n如您不同意上述条款，请立即停止使用本应用。'**
  String get termsContent;

  /// No description provided for @privacyContent.
  ///
  /// In zh, this message translates to:
  /// **'Velox 非常重视您的隐私保护。\n\n1. 信息收集\n我们仅收集提供服务所必需的最少信息，包括注册邮箱和基本设备信息。我们不会收集您的浏览记录或个人文件。\n\n2. 信息使用\n收集的信息仅用于：提供和维护服务、改善用户体验、发送服务通知。\n\n3. 信息保护\n我们采用行业标准的加密技术保护您的数据安全，防止未经授权的访问、泄露或篡改。\n\n4. 信息共享\n我们不会向任何第三方出售或共享您的个人信息，除非法律法规要求。\n\n5. 数据存储\n您的数据存储在安全的服务器上，我们会在服务需要的期限内保留数据。\n\n6. 用户权利\n您有权查看、修改或删除您的个人信息。如需行使上述权利，请联系客服。\n\n使用 Velox 即表示您同意本隐私政策。'**
  String get privacyContent;

  /// No description provided for @preferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get preferences;

  /// No description provided for @multiLanguage.
  ///
  /// In zh, this message translates to:
  /// **'多语言'**
  String get multiLanguage;

  /// No description provided for @proxyModeRuleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据规则智能分流'**
  String get proxyModeRuleSubtitle;

  /// No description provided for @proxyModeGlobalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'所有流量走代理'**
  String get proxyModeGlobalSubtitle;

  /// No description provided for @proxyModeDirectSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'不走代理直连'**
  String get proxyModeDirectSubtitle;

  /// No description provided for @proxyModeTun.
  ///
  /// In zh, this message translates to:
  /// **'TUN 模式'**
  String get proxyModeTun;

  /// No description provided for @proxyModeTunSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启用时无须连接节点'**
  String get proxyModeTunSubtitle;

  /// No description provided for @recommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get recommended;

  /// No description provided for @calendarToday.
  ///
  /// In zh, this message translates to:
  /// **'今'**
  String get calendarToday;

  /// No description provided for @noNodesSubscribe.
  ///
  /// In zh, this message translates to:
  /// **'没有节点可使用，订阅即可获得'**
  String get noNodesSubscribe;

  /// No description provided for @nodeUpdateFailedCached.
  ///
  /// In zh, this message translates to:
  /// **'节点更新失败，已使用上次的节点'**
  String get nodeUpdateFailedCached;

  /// No description provided for @nodeLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'节点加载失败，请检查网络后重试'**
  String get nodeLoadFailed;

  /// No description provided for @connectingSupport.
  ///
  /// In zh, this message translates to:
  /// **'正在连接客服...'**
  String get connectingSupport;

  /// No description provided for @supportLoading.
  ///
  /// In zh, this message translates to:
  /// **'请稍候，客服系统加载中'**
  String get supportLoading;

  /// No description provided for @inviteGetReward.
  ///
  /// In zh, this message translates to:
  /// **'获得奖励'**
  String get inviteGetReward;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已复制'**
  String get inviteCodeCopied;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'邀请链接已复制'**
  String get inviteLinkCopied;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'邀请码: {code}'**
  String inviteCodeLabel(Object code);

  /// No description provided for @commissionEarned.
  ///
  /// In zh, this message translates to:
  /// **'获得佣金'**
  String get commissionEarned;

  /// No description provided for @shareQrOrLink.
  ///
  /// In zh, this message translates to:
  /// **'分享二维码或复制链接给好友注册'**
  String get shareQrOrLink;

  /// No description provided for @registerFreeHour.
  ///
  /// In zh, this message translates to:
  /// **'注册即送 1 小时免费试用，还在等什么？'**
  String get registerFreeHour;

  /// No description provided for @inviteGlobalNodes.
  ///
  /// In zh, this message translates to:
  /// **'全球节点高速稳定 看视频永不卡顿 解锁各种app'**
  String get inviteGlobalNodes;

  /// No description provided for @splashSlogan.
  ///
  /// In zh, this message translates to:
  /// **'安全 · 极速 · 稳定'**
  String get splashSlogan;

  /// No description provided for @getStarted.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get getStarted;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？立即登录'**
  String get alreadyHaveAccount;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @trafficUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用 {used} / 总计 {total}'**
  String trafficUsed(Object used, Object total);

  /// No description provided for @onlineDevices.
  ///
  /// In zh, this message translates to:
  /// **'在线设备 {alive}/{limit}'**
  String onlineDevices(Object alive, Object limit);

  /// No description provided for @peopleCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人'**
  String peopleCount(Object count);

  /// No description provided for @minutesCount.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String minutesCount(Object minutes);

  /// No description provided for @uploadImage.
  ///
  /// In zh, this message translates to:
  /// **'上传图片'**
  String get uploadImage;

  /// No description provided for @uploadImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片上传失败: {error}'**
  String uploadImageFailed(Object error);

  /// No description provided for @passwordChangeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'修改密码成功，请重新登录'**
  String get passwordChangeSuccess;

  /// No description provided for @updateTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateTitle;

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @skipUpdate.
  ///
  /// In zh, this message translates to:
  /// **'暂不更新'**
  String get skipUpdate;

  /// No description provided for @subscriptionExpiryTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅即将到期'**
  String get subscriptionExpiryTitle;

  /// No description provided for @subscriptionExpiryMessage.
  ///
  /// In zh, this message translates to:
  /// **'您的订阅将在 {days} 天后到期，请及时续费'**
  String subscriptionExpiryMessage(int days);

  /// No description provided for @renewNow.
  ///
  /// In zh, this message translates to:
  /// **'立即续费'**
  String get renewNow;

  /// No description provided for @announcementDefaultButton.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get announcementDefaultButton;

  /// No description provided for @verificationCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get verificationCode;

  /// No description provided for @pleaseEnterVerificationCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get pleaseEnterVerificationCode;

  /// No description provided for @inviteCodeOptional.
  ///
  /// In zh, this message translates to:
  /// **'邀请码（可选）'**
  String get inviteCodeOptional;

  /// No description provided for @errorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'发生未知错误'**
  String get errorUnknown;

  /// No description provided for @errorOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请稍后再试'**
  String get errorOperationFailed;

  /// No description provided for @errorNoPermission.
  ///
  /// In zh, this message translates to:
  /// **'无权限执行此操作'**
  String get errorNoPermission;

  /// No description provided for @errorNoInternet.
  ///
  /// In zh, this message translates to:
  /// **'无网络连接，请检查网络设置'**
  String get errorNoInternet;

  /// No description provided for @errorNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败'**
  String get errorNetworkFailed;

  /// No description provided for @errorConnectionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get errorConnectionTimeout;

  /// No description provided for @errorRequestTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时'**
  String get errorRequestTimeout;

  /// No description provided for @errorConnectionRefused.
  ///
  /// In zh, this message translates to:
  /// **'连接被拒绝'**
  String get errorConnectionRefused;

  /// No description provided for @errorGatewayError.
  ///
  /// In zh, this message translates to:
  /// **'网关错误'**
  String get errorGatewayError;

  /// No description provided for @errorGatewayTimeout.
  ///
  /// In zh, this message translates to:
  /// **'网关超时'**
  String get errorGatewayTimeout;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'服务暂不可用'**
  String get errorServiceUnavailable;

  /// No description provided for @errorServerBusy.
  ///
  /// In zh, this message translates to:
  /// **'服务器繁忙，请稍后再试'**
  String get errorServerBusy;

  /// No description provided for @errorBadRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求参数错误'**
  String get errorBadRequest;

  /// No description provided for @errorValidationFailed.
  ///
  /// In zh, this message translates to:
  /// **'参数验证失败'**
  String get errorValidationFailed;

  /// No description provided for @errorAccessDenied.
  ///
  /// In zh, this message translates to:
  /// **'访问被拒绝'**
  String get errorAccessDenied;

  /// No description provided for @errorResourceNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源不存在'**
  String get errorResourceNotFound;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁'**
  String get errorTooManyRequests;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In zh, this message translates to:
  /// **'尝试次数过多，请稍后再试'**
  String get errorTooManyAttempts;

  /// No description provided for @errorLoginExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get errorLoginExpired;

  /// No description provided for @errorLoginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get errorLoginFailed;

  /// No description provided for @errorPleaseLogin.
  ///
  /// In zh, this message translates to:
  /// **'请先登录'**
  String get errorPleaseLogin;

  /// No description provided for @errorInvalidToken.
  ///
  /// In zh, this message translates to:
  /// **'登录凭证无效，请重新登录'**
  String get errorInvalidToken;

  /// No description provided for @errorEmailOrPasswordIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'邮箱或密码错误'**
  String get errorEmailOrPasswordIncorrect;

  /// No description provided for @errorPasswordIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'密码错误'**
  String get errorPasswordIncorrect;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码长度不足'**
  String get errorPasswordTooShort;

  /// No description provided for @errorPasswordTooWeak.
  ///
  /// In zh, this message translates to:
  /// **'密码强度不足'**
  String get errorPasswordTooWeak;

  /// No description provided for @errorPasswordsNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次密码输入不一致'**
  String get errorPasswordsNotMatch;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In zh, this message translates to:
  /// **'该邮箱已被注册'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @errorEmailInUse.
  ///
  /// In zh, this message translates to:
  /// **'邮箱已被使用'**
  String get errorEmailInUse;

  /// No description provided for @errorEmailNotRegistered.
  ///
  /// In zh, this message translates to:
  /// **'该邮箱未注册'**
  String get errorEmailNotRegistered;

  /// No description provided for @errorInvalidEmailFormat.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get errorInvalidEmailFormat;

  /// No description provided for @errorGetVerificationCodeFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先获取验证码'**
  String get errorGetVerificationCodeFirst;

  /// No description provided for @errorInvalidVerificationCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码错误'**
  String get errorInvalidVerificationCode;

  /// No description provided for @errorVerificationCodeExpired.
  ///
  /// In zh, this message translates to:
  /// **'验证码已过期'**
  String get errorVerificationCodeExpired;

  /// No description provided for @errorSendCodeTooFrequent.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码过于频繁'**
  String get errorSendCodeTooFrequent;

  /// No description provided for @errorEmailSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'邮件发送失败'**
  String get errorEmailSendFailed;

  /// No description provided for @errorRegistrationClosed.
  ///
  /// In zh, this message translates to:
  /// **'注册已关闭'**
  String get errorRegistrationClosed;

  /// No description provided for @errorRegistrationRequiresInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'注册需要邀请码'**
  String get errorRegistrationRequiresInviteCode;

  /// No description provided for @errorInvalidInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码无效'**
  String get errorInvalidInviteCode;

  /// No description provided for @errorInviteCodeNotFound.
  ///
  /// In zh, this message translates to:
  /// **'邀请码不存在'**
  String get errorInviteCodeNotFound;

  /// No description provided for @errorInviteCodeExpired.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已过期'**
  String get errorInviteCodeExpired;

  /// No description provided for @errorInviteCodeUsed.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已被使用'**
  String get errorInviteCodeUsed;

  /// No description provided for @errorAccountNotFound.
  ///
  /// In zh, this message translates to:
  /// **'账号不存在'**
  String get errorAccountNotFound;

  /// No description provided for @errorUserNotFound.
  ///
  /// In zh, this message translates to:
  /// **'用户不存在'**
  String get errorUserNotFound;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In zh, this message translates to:
  /// **'账号已被禁用'**
  String get errorAccountDisabled;

  /// No description provided for @errorAccountBanned.
  ///
  /// In zh, this message translates to:
  /// **'账号已被封禁'**
  String get errorAccountBanned;

  /// No description provided for @errorSubscriptionNotFound.
  ///
  /// In zh, this message translates to:
  /// **'订阅不存在'**
  String get errorSubscriptionNotFound;

  /// No description provided for @errorSubscriptionExpired.
  ///
  /// In zh, this message translates to:
  /// **'订阅已到期'**
  String get errorSubscriptionExpired;

  /// No description provided for @errorNoActiveSubscription.
  ///
  /// In zh, this message translates to:
  /// **'没有有效的订阅'**
  String get errorNoActiveSubscription;

  /// No description provided for @errorTrafficLimitExceeded.
  ///
  /// In zh, this message translates to:
  /// **'流量已用尽'**
  String get errorTrafficLimitExceeded;

  /// No description provided for @errorExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get errorExpired;

  /// No description provided for @errorPlanNotFound.
  ///
  /// In zh, this message translates to:
  /// **'套餐不存在'**
  String get errorPlanNotFound;

  /// No description provided for @errorOrderNotFound.
  ///
  /// In zh, this message translates to:
  /// **'订单不存在'**
  String get errorOrderNotFound;

  /// No description provided for @errorOrderAlreadyPaid.
  ///
  /// In zh, this message translates to:
  /// **'订单已支付'**
  String get errorOrderAlreadyPaid;

  /// No description provided for @errorOrderExpired.
  ///
  /// In zh, this message translates to:
  /// **'订单已过期'**
  String get errorOrderExpired;

  /// No description provided for @errorOrderCancelled.
  ///
  /// In zh, this message translates to:
  /// **'订单已取消'**
  String get errorOrderCancelled;

  /// No description provided for @errorPaymentFailed.
  ///
  /// In zh, this message translates to:
  /// **'支付失败'**
  String get errorPaymentFailed;

  /// No description provided for @errorInsufficientBalance.
  ///
  /// In zh, this message translates to:
  /// **'余额不足'**
  String get errorInsufficientBalance;

  /// No description provided for @errorCouponNotFound.
  ///
  /// In zh, this message translates to:
  /// **'优惠码不存在'**
  String get errorCouponNotFound;

  /// No description provided for @errorCouponExpired.
  ///
  /// In zh, this message translates to:
  /// **'优惠码已过期'**
  String get errorCouponExpired;

  /// No description provided for @errorCouponUsed.
  ///
  /// In zh, this message translates to:
  /// **'优惠码已使用'**
  String get errorCouponUsed;

  /// No description provided for @errorCouponNotApplicable.
  ///
  /// In zh, this message translates to:
  /// **'优惠码不适用于此套餐'**
  String get errorCouponNotApplicable;

  /// No description provided for @errorTicketNotFound.
  ///
  /// In zh, this message translates to:
  /// **'工单不存在'**
  String get errorTicketNotFound;

  /// No description provided for @errorTicketClosed.
  ///
  /// In zh, this message translates to:
  /// **'工单已关闭'**
  String get errorTicketClosed;

  /// No description provided for @errorCannotCloseTicket.
  ///
  /// In zh, this message translates to:
  /// **'无法关闭此工单'**
  String get errorCannotCloseTicket;

  /// No description provided for @aboutUs.
  ///
  /// In zh, this message translates to:
  /// **'关于我们'**
  String get aboutUs;

  /// No description provided for @submitFeedback.
  ///
  /// In zh, this message translates to:
  /// **'提交反馈'**
  String get submitFeedback;

  /// No description provided for @feedbackHint.
  ///
  /// In zh, this message translates to:
  /// **'遇到问题时,请先「上传 debug 日志」生成反馈编号,再联系客服并告知编号,方便快速定位问题。'**
  String get feedbackHint;

  /// No description provided for @exportDebugLog.
  ///
  /// In zh, this message translates to:
  /// **'导出 debug 日志'**
  String get exportDebugLog;

  /// No description provided for @exportDebugLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打包所有客户端日志,通过系统文件管理器/分享导出'**
  String get exportDebugLogSubtitle;

  /// No description provided for @uploadDebugLog.
  ///
  /// In zh, this message translates to:
  /// **'上传 debug 日志'**
  String get uploadDebugLog;

  /// No description provided for @uploadDebugLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自动上传日志到客服后台,生成反馈编号'**
  String get uploadDebugLogSubtitle;

  /// No description provided for @contactCustomerService.
  ///
  /// In zh, this message translates to:
  /// **'联系客服'**
  String get contactCustomerService;

  /// No description provided for @contactCustomerServiceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开在线客服'**
  String get contactCustomerServiceSubtitle;

  /// No description provided for @debugLogExporting.
  ///
  /// In zh, this message translates to:
  /// **'正在打包日志...'**
  String get debugLogExporting;

  /// No description provided for @debugLogExported.
  ///
  /// In zh, this message translates to:
  /// **'日志已导出'**
  String get debugLogExported;

  /// No description provided for @debugLogExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败: {error}'**
  String debugLogExportFailed(String error);

  /// No description provided for @debugLogUploading.
  ///
  /// In zh, this message translates to:
  /// **'正在上传日志到客服...'**
  String get debugLogUploading;

  /// No description provided for @debugLogUploadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上传成功,反馈编号 #{id}\n请告知客服此编号'**
  String debugLogUploadSuccess(String id);

  /// No description provided for @debugLogUploadNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'反馈通道未配置,请联系客服'**
  String get debugLogUploadNotConfigured;

  /// No description provided for @debugLogUploadTooLargeTitle.
  ///
  /// In zh, this message translates to:
  /// **'上传失败'**
  String get debugLogUploadTooLargeTitle;

  /// No description provided for @debugLogUploadTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'日志过大({sizeMb} MB),超过 50MB 上限。请返回上一步点「导出 debug 日志」保存到本地,再手动发给客服'**
  String debugLogUploadTooLarge(String sizeMb);

  /// No description provided for @debugLogUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败: {error}'**
  String debugLogUploadFailed(String error);

  /// No description provided for @crispNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'客服暂不可用'**
  String get crispNotAvailable;

  /// No description provided for @pendingOrderTitle.
  ///
  /// In zh, this message translates to:
  /// **'待处理订单'**
  String get pendingOrderTitle;

  /// No description provided for @pendingOrderMessage.
  ///
  /// In zh, this message translates to:
  /// **'您有未完成的订单，请先完成或取消后再创建新订单。'**
  String get pendingOrderMessage;

  /// No description provided for @viewOrders.
  ///
  /// In zh, this message translates to:
  /// **'查看订单'**
  String get viewOrders;

  /// No description provided for @noPaymentMethods.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用支付方式'**
  String get noPaymentMethods;

  /// No description provided for @paymentSuccess.
  ///
  /// In zh, this message translates to:
  /// **'支付成功'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In zh, this message translates to:
  /// **'支付失败'**
  String get paymentFailed;

  /// No description provided for @cancelOrderConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要取消此订单吗？'**
  String get cancelOrderConfirm;

  /// No description provided for @unknownPlan.
  ///
  /// In zh, this message translates to:
  /// **'未知套餐'**
  String get unknownPlan;

  /// No description provided for @pendingPayment.
  ///
  /// In zh, this message translates to:
  /// **'待支付'**
  String get pendingPayment;

  /// No description provided for @paid.
  ///
  /// In zh, this message translates to:
  /// **'已支付'**
  String get paid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
