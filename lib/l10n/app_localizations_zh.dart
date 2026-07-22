// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Velox';

  @override
  String get login => '登录';

  @override
  String get register => '注册';

  @override
  String get email => '电子邮件';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get inviteCode => '邀请码';

  @override
  String get verifyCode => '验证码';

  @override
  String get sendCode => '发送验证码';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get noAccount => '还没有账号？';

  @override
  String get hasAccount => '已有账号？';

  @override
  String get loginSuccess => '登录成功';

  @override
  String get registerSuccess => '注册成功';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirm => '确定要登出吗？';

  @override
  String get home => '首页';

  @override
  String get nodes => '节点';

  @override
  String get selectNode => '选择节点';

  @override
  String get subscription => '订阅';

  @override
  String get profile => '我的';

  @override
  String get settings => '设置';

  @override
  String get tapToConnect => '点击按钮连接';

  @override
  String get nodeUnreachable => '节点不可用，请尝试其他节点';

  @override
  String get latencyTimeout => '超时';

  @override
  String get trafficUsage => '流量使用';

  @override
  String get userCenter => '用户中心';

  @override
  String get telegramGroup => 'Telegram 群组';

  @override
  String get earnRewards => '获得奖励';

  @override
  String get successfullyShared => '已注册用户数';

  @override
  String get commissionReward => '佣金奖励';

  @override
  String get commissionPending => '待结算佣金';

  @override
  String get peopleSuffix => '人';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get connecting => '连接中...';

  @override
  String get disconnecting => '断开中...';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get connectionTime => '连接时长';

  @override
  String get uploadSpeed => '上传';

  @override
  String get downloadSpeed => '下载';

  @override
  String get allNodes => '全部节点';

  @override
  String get favoriteNodes => '收藏';

  @override
  String get recentNodes => '最近使用';

  @override
  String get nodeLatency => '延迟';

  @override
  String get nodeLoad => '负载';

  @override
  String get testSpeed => '测速';

  @override
  String get testingSpeed => '测速中...';

  @override
  String get addToFavorite => '加入收藏';

  @override
  String get removeFromFavorite => '取消收藏';

  @override
  String get currentPlan => '当前套餐';

  @override
  String expireDate(Object date) {
    return '到期时间：$date';
  }

  @override
  String get dataUsed => '已用流量';

  @override
  String get dataTotal => '总流量';

  @override
  String get resetDate => '重置日期';

  @override
  String get buyPlan => '购买套餐';

  @override
  String get renewPlan => '续费';

  @override
  String daysRemaining(Object days) {
    return '还剩 $days 天';
  }

  @override
  String get planExpired => '已到期';

  @override
  String expiresOnDate(Object date) {
    return '$date 到期';
  }

  @override
  String get noSubscription => '暂无订阅';

  @override
  String get subscribeHint => '开通订阅，解锁全部节点';

  @override
  String get trafficUsedLabel => '已用';

  @override
  String get trafficRemainingLabel => '剩余';

  @override
  String get planList => '可用套餐';

  @override
  String get orderHistory => '订单记录';

  @override
  String get balance => '余额';

  @override
  String get inviteCount => '邀请人数';

  @override
  String get commission => '佣金';

  @override
  String get copyInviteLink => '复制邀请链接';

  @override
  String get copySuccess => '已复制到剪贴板';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoReconnect => '断线自动重连';

  @override
  String get proxyMode => '代理模式';

  @override
  String get proxyModeGlobal => '全局代理';

  @override
  String get proxyModeRule => '规则代理';

  @override
  String get proxyModeDirect => '直连';

  @override
  String get dns => 'DNS 设置';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get warning => '警告';

  @override
  String get info => '提示';

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中...';

  @override
  String get noData => '暂无数据';

  @override
  String get networkError => '网络错误，请检查网络连接';

  @override
  String get serverError => '服务器错误，请稍后再试';

  @override
  String get unknownError => '未知错误';

  @override
  String get createAccount => '创建账号';

  @override
  String get signUpToGetStarted => '注册以开始使用';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get signInToContinue => '登录以继续';

  @override
  String get pleaseEnterEmail => '请输入电子邮件';

  @override
  String get pleaseEnterValidEmail => '请输入有效的电子邮件';

  @override
  String get pleaseEnterPassword => '请输入密码';

  @override
  String get passwordTooShort => '密码长度至少6个字符';

  @override
  String get passwordsDoNotMatch => '密码不一致';

  @override
  String get resetPassword => '重置密码';

  @override
  String get resetPasswordSubtitle => '输入邮箱接收验证码，重置密码';

  @override
  String get passwordResetSuccess => '密码重置成功，请重新登录';

  @override
  String get rememberPassword => '想起密码了？';

  @override
  String get enterEmailForReset => '输入您的电子邮件以重置密码';

  @override
  String get newPassword => '新密码';

  @override
  String get verificationCodeSent => '验证码已发送';

  @override
  String get resetSuccess => '密码重置成功';

  @override
  String get step => '步骤';

  @override
  String get enterEmail => '输入电子邮件';

  @override
  String get verifyEmail => '验证电子邮件';

  @override
  String get setNewPassword => '设置新密码';

  @override
  String get next => '下一步';

  @override
  String get back => '返回';

  @override
  String get inviteFriends => '邀请好友';

  @override
  String get yourInviteCode => '您的邀请码';

  @override
  String get tapToCopy => '点击复制';

  @override
  String get inviteLink => '邀请链接';

  @override
  String get shareInviteLink => '分享邀请链接';

  @override
  String get totalInvites => '总邀请数';

  @override
  String get pendingCommission => '待确认';

  @override
  String get confirmedCommission => '已确认';

  @override
  String get inviteRecords => '邀请记录';

  @override
  String get noInviteRecords => '暂无邀请记录';

  @override
  String get generateNewCode => '生成新代码';

  @override
  String get orders => '订单';

  @override
  String get allOrders => '所有订单';

  @override
  String get pendingOrders => '待处理';

  @override
  String get completedOrders => '已完成';

  @override
  String get cancelledOrders => '已取消';

  @override
  String get orderNo => '订单编号';

  @override
  String get orderTime => '订单时间';

  @override
  String get orderAmount => '金额';

  @override
  String get orderStatus => '状态';

  @override
  String get payNow => '立即支付';

  @override
  String get cancelOrder => '取消订单';

  @override
  String get noOrders => '暂无订单';

  @override
  String get selectPaymentMethod => '选择付款方式';

  @override
  String get pay => '支付';

  @override
  String get helpAndSupport => '帮助与支持';

  @override
  String get faq => '常见问题';

  @override
  String get submitTicket => '提交工單';

  @override
  String get myTickets => '我的工单';

  @override
  String get ticketSubject => '主题';

  @override
  String get ticketMessage => '消息';

  @override
  String get ticketLevel => '优先级';

  @override
  String get ticketLevelLow => '低';

  @override
  String get ticketLevelMedium => '中';

  @override
  String get ticketLevelHigh => '高';

  @override
  String get ticketOpen => '开启';

  @override
  String get ticketClosed => '已关闭';

  @override
  String get ticketReplied => '已回复';

  @override
  String get noTickets => '暂无工单';

  @override
  String get closeTicket => '关闭工单';

  @override
  String get replyTicket => '回复';

  @override
  String get send => '发送';

  @override
  String get newTicket => '新工单';

  @override
  String get create => '创建';

  @override
  String get knowledgeBase => '知识库';

  @override
  String get selectPlan => '选择套餐';

  @override
  String get choosePlan => '选择您的套餐';

  @override
  String get billingCycle => '计费周期';

  @override
  String get monthly => '月付';

  @override
  String get quarterly => '季付';

  @override
  String get halfYearly => '半年付';

  @override
  String get yearly => '年付';

  @override
  String get couponCode => '优惠码';

  @override
  String get applyCoupon => '应用';

  @override
  String get total => '总计';

  @override
  String get checkout => '结账';

  @override
  String get orderCreated => '订单创建成功';

  @override
  String get perMonth => '/月';

  @override
  String get speedLimit => '速度限制';

  @override
  String dataPerMonth(Object data) {
    return '$data / 月';
  }

  @override
  String get dnsSettings => 'DNS 设置';

  @override
  String get primaryDns => '主要 DNS';

  @override
  String get secondaryDns => '备用 DNS';

  @override
  String get save => '保存';

  @override
  String get savedSuccessfully => '保存成功';

  @override
  String get appInfo => '应用信息';

  @override
  String get developer => '开发者';

  @override
  String get website => '网站';

  @override
  String get sourceCode => '源代码';

  @override
  String get licenses => '开源许可';

  @override
  String get rateApp => '评价应用';

  @override
  String get shareApp => '分享应用';

  @override
  String get contactUs => '联系我们';

  @override
  String get account => '账号';

  @override
  String get dataTransfer => '流量';

  @override
  String get expires => '到期时间';

  @override
  String get resetDay => '重置日';

  @override
  String day(Object day) {
    return '第 $day 日';
  }

  @override
  String usedPercent(Object percent) {
    return '已使用 $percent%';
  }

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get close => '关闭';

  @override
  String get open => '打开';

  @override
  String get refresh => '刷新';

  @override
  String get refreshSuccess => '已更新';

  @override
  String get refreshFailed => '更新失败';

  @override
  String get refreshTooltip => '刷新订阅信息';

  @override
  String get inviteCodeRequired => '邀请码（必填）';

  @override
  String get pleaseEnterInviteCode => '请填写邀请码';

  @override
  String get search => '搜索';

  @override
  String get filter => '筛选';

  @override
  String get sort => '排序';

  @override
  String get more => '更多';

  @override
  String get less => '收起';

  @override
  String get all => '全部';

  @override
  String get none => '無';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get done => '完成';

  @override
  String get apply => '应用';

  @override
  String get clear => '清除';

  @override
  String get reset => '重置';

  @override
  String get announcements => '公告';

  @override
  String get noAnnouncements => '暂无公告';

  @override
  String get readMore => '阅读更多';

  @override
  String get switchLanguage => '切换语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get currency => '货币';

  @override
  String get selectCurrency => '选择货币';

  @override
  String get purchaseSubscription => '购买订阅';

  @override
  String get choosePlanDescription => '选择适合您的套餐';

  @override
  String get popular => '热门';

  @override
  String get bestValue => '最优惠';

  @override
  String get unlimited => '无限制';

  @override
  String devicesAllowed(Object count) {
    return '$count 个设备';
  }

  @override
  String trafficPerMonth(Object data) {
    return '$data GB / 月';
  }

  @override
  String get noSpeedLimit => '不限速';

  @override
  String speedLimitValue(Object speed) {
    return '限速: $speed Mbps';
  }

  @override
  String get subscribedPlan => '当前套餐';

  @override
  String get selectThisPlan => '选择';

  @override
  String get proceedToPayment => '前往付款';

  @override
  String get contactSupport => '联系客服';

  @override
  String get joinTelegram => '加入 Telegram';

  @override
  String get telegramChannel => 'Telegram 频道';

  @override
  String get customerService => '客服';

  @override
  String get liveChat => '在线客服';

  @override
  String get twoYear => '两年';

  @override
  String get threeYear => '三年';

  @override
  String get oneTime => '一次性';

  @override
  String savePercent(Object percent) {
    return '省 $percent%';
  }

  @override
  String get helpCenter => '帮助中心';

  @override
  String get commonQuestions => '常见问题';

  @override
  String get viewAllArticles => '查看所有文章';

  @override
  String get loginToContinue => '登录以继续使用 Velox';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get or => '或';

  @override
  String get phoneLogin => '手机验证码登录';

  @override
  String get scanToImport => '扫码导入订阅';

  @override
  String get registerNow => '立即注册';

  @override
  String get urlImport => '导入订阅';

  @override
  String get pleaseEnterSubscriptionLink => '请输入订阅链接';

  @override
  String get pasteSubscriptionLinkHint => '请粘贴订阅链接...';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get howToGetSubscriptionLink => '如何获取订阅链接？';

  @override
  String get subscriptionLinkStep1 => '1. 登录您的服务商网站';

  @override
  String get subscriptionLinkStep2 => '2. 在「我的订阅」页面找到订阅链接';

  @override
  String get subscriptionLinkStep3 => '3. 复制链接并粘贴到此处';

  @override
  String get importSubscription => '导入订阅';

  @override
  String get createNewTicket => '创建新工单';

  @override
  String get ticketSubjectHint => '简述您的问题';

  @override
  String get ticketMessageHint => '详细描述您的问题';

  @override
  String get priority => '优先级';

  @override
  String get noFaqArticles => '暂无常见问题文章';

  @override
  String get untitled => '无标题';

  @override
  String get noContent => '无内容';

  @override
  String get noTicketsYet => '暂无工单';

  @override
  String get createTicketHelp => '如需帮助，请创建工单';

  @override
  String get noSubject => '无主题';

  @override
  String get newReply => '新';

  @override
  String get closeTicketAction => '关闭工单';

  @override
  String get ticketStatusOpen => '开启';

  @override
  String get ticketStatusClosed => '已关闭';

  @override
  String get priorityLow => '低';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityHigh => '高';

  @override
  String get priorityUnknown => '未知';

  @override
  String get navHome => '首页';

  @override
  String get navNodes => '节点';

  @override
  String get navStats => '统计';

  @override
  String get navSubscription => '订阅';

  @override
  String get navSettings => '我的';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusConnecting => '连接中...';

  @override
  String get statusDisconnecting => '断开中...';

  @override
  String get statusDisconnected => '未连接';

  @override
  String get selectServer => '选择节点';

  @override
  String get selectServerFirst => '请先选择服务器';

  @override
  String get autoSelect => '自动选择';

  @override
  String get autoSelectSubtitle => '自动选择最优节点';

  @override
  String get upload => '上传';

  @override
  String get download => '下载';

  @override
  String get connectButton => '连接';

  @override
  String get disconnectButton => '断开';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String get qrScanHint => '将二维码放入框内即可自动扫描';

  @override
  String get gallery => '相册';

  @override
  String get flashlight => '闪光灯';

  @override
  String get linkImport => '链接导入';

  @override
  String get testAllNodes => '延迟测试';

  @override
  String get updateNodes => '更新节点';

  @override
  String get noNodesAvailable => '无可用节点';

  @override
  String get uuidCopied => 'UUID 已复制';

  @override
  String get inviteFriendsMenu => '我的邀请';

  @override
  String get orderHistoryMenu => '订单记录';

  @override
  String get helpSupportMenu => '帮助与支持';

  @override
  String get aboutMenu => '关于';

  @override
  String get logoutConfirmTitle => '登出';

  @override
  String get logoutConfirmMessage => '确定要登出吗？';

  @override
  String get stats => '统计';

  @override
  String get gameDescription => 'Velox 提供稳定便捷的网络加速服务，界面简洁直观，一键连接全球高速节点。';

  @override
  String get termsContent =>
      '欢迎使用 Velox！使用本应用即表示您同意以下服务条款。\n\n1. 服务说明\nVelox 是一款网络加速工具，旨在为用户提供安全、稳定的网络连接服务。\n\n2. 用户责任\n用户应遵守所在地区的法律法规，不得利用本服务从事任何违法活动。用户对其账号下的所有行为承担责任。\n\n3. 账号管理\n每个账号仅供注册用户本人使用，禁止转让、出借或共享账号。我们有权对违规账号进行限制或封禁。\n\n4. 服务变更\n我们保留随时修改、暂停或终止服务的权利，届时将通过应用内通知告知用户。\n\n5. 免责声明\n本服务按「现状」提供，我们不对因网络环境变化、不可抗力等因素导致的服务中断承担责任。\n\n6. 知识产权\n本应用的所有内容、设计和技术均受知识产权法保护，未经授权不得复制或使用。\n\n如您不同意上述条款，请立即停止使用本应用。';

  @override
  String get privacyContent =>
      'Velox 非常重视您的隐私保护。\n\n1. 信息收集\n我们仅收集提供服务所必需的最少信息，包括注册邮箱和基本设备信息。我们不会收集您的浏览记录或个人文件。\n\n2. 信息使用\n收集的信息仅用于：提供和维护服务、改善用户体验、发送服务通知。\n\n3. 信息保护\n我们采用行业标准的加密技术保护您的数据安全，防止未经授权的访问、泄露或篡改。\n\n4. 信息共享\n我们不会向任何第三方出售或共享您的个人信息，除非法律法规要求。\n\n5. 数据存储\n您的数据存储在安全的服务器上，我们会在服务需要的期限内保留数据。\n\n6. 用户权利\n您有权查看、修改或删除您的个人信息。如需行使上述权利，请联系客服。\n\n使用 Velox 即表示您同意本隐私政策。';

  @override
  String get preferences => '偏好设置';

  @override
  String get multiLanguage => '多语言';

  @override
  String get proxyModeRuleSubtitle => '根据规则智能分流';

  @override
  String get proxyModeGlobalSubtitle => '所有流量走代理';

  @override
  String get proxyModeDirectSubtitle => '不走代理直连';

  @override
  String get proxyModeTun => 'TUN 模式';

  @override
  String get proxyModeTunSubtitle => '启用时无须连接节点';

  @override
  String get recommended => '推荐';

  @override
  String get calendarToday => '今';

  @override
  String get noNodesSubscribe => '没有节点可使用，订阅即可获得';

  @override
  String get nodeUpdateFailedCached => '节点更新失败，已使用上次的节点';

  @override
  String get nodeLoadFailed => '节点加载失败，请检查网络后重试';

  @override
  String get connectingSupport => '正在连接客服...';

  @override
  String get supportLoading => '请稍候，客服系统加载中';

  @override
  String get inviteGetReward => '获得奖励';

  @override
  String get inviteCodeCopied => '邀请码已复制';

  @override
  String get inviteLinkCopied => '邀请链接已复制';

  @override
  String inviteCodeLabel(Object code) {
    return '邀请码: $code';
  }

  @override
  String get commissionEarned => '获得佣金';

  @override
  String get shareQrOrLink => '分享二维码或复制链接给好友注册';

  @override
  String get registerFreeHour => '注册即送 1 小时免费试用，还在等什么？';

  @override
  String get inviteGlobalNodes => '全球节点高速稳定 看视频永不卡顿 解锁各种app';

  @override
  String get splashSlogan => '安全 · 极速 · 稳定';

  @override
  String get getStarted => '开始使用';

  @override
  String get alreadyHaveAccount => '已有账号？立即登录';

  @override
  String get skip => '跳过';

  @override
  String trafficUsed(Object used, Object total) {
    return '已用 $used / 总计 $total';
  }

  @override
  String onlineDevices(Object alive, Object limit) {
    return '在线设备 $alive/$limit';
  }

  @override
  String peopleCount(Object count) {
    return '$count 人';
  }

  @override
  String minutesCount(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String get uploadImage => '上传图片';

  @override
  String uploadImageFailed(Object error) {
    return '图片上传失败: $error';
  }

  @override
  String get passwordChangeSuccess => '修改密码成功，请重新登录';

  @override
  String get updateTitle => '发现新版本';

  @override
  String get updateNow => '立即更新';

  @override
  String get skipUpdate => '暂不更新';

  @override
  String get subscriptionExpiryTitle => '订阅即将到期';

  @override
  String subscriptionExpiryMessage(int days) {
    return '您的订阅将在 $days 天后到期，请及时续费';
  }

  @override
  String get renewNow => '立即续费';

  @override
  String get announcementDefaultButton => '知道了';

  @override
  String get verificationCode => '验证码';

  @override
  String get pleaseEnterVerificationCode => '请输入验证码';

  @override
  String get inviteCodeOptional => '邀请码（可选）';

  @override
  String get errorUnknown => '发生未知错误';

  @override
  String get errorOperationFailed => '操作失败，请稍后再试';

  @override
  String get errorNoPermission => '无权限执行此操作';

  @override
  String get errorNoInternet => '无网络连接，请检查网络设置';

  @override
  String get errorNetworkFailed => '网络请求失败';

  @override
  String get errorConnectionTimeout => '连接超时';

  @override
  String get errorRequestTimeout => '请求超时';

  @override
  String get errorConnectionRefused => '连接被拒绝';

  @override
  String get errorGatewayError => '网关错误';

  @override
  String get errorGatewayTimeout => '网关超时';

  @override
  String get errorServiceUnavailable => '服务暂不可用';

  @override
  String get errorServerBusy => '服务器繁忙，请稍后再试';

  @override
  String get errorBadRequest => '请求参数错误';

  @override
  String get errorValidationFailed => '参数验证失败';

  @override
  String get errorAccessDenied => '访问被拒绝';

  @override
  String get errorResourceNotFound => '资源不存在';

  @override
  String get errorTooManyRequests => '请求过于频繁';

  @override
  String get errorTooManyAttempts => '尝试次数过多，请稍后再试';

  @override
  String get errorLoginExpired => '登录已过期，请重新登录';

  @override
  String get errorLoginFailed => '登录失败';

  @override
  String get errorPleaseLogin => '请先登录';

  @override
  String get errorInvalidToken => '登录凭证无效，请重新登录';

  @override
  String get errorEmailOrPasswordIncorrect => '邮箱或密码错误';

  @override
  String get errorPasswordIncorrect => '密码错误';

  @override
  String get errorPasswordTooShort => '密码长度不足';

  @override
  String get errorPasswordTooWeak => '密码强度不足';

  @override
  String get errorPasswordsNotMatch => '两次密码输入不一致';

  @override
  String get errorEmailAlreadyRegistered => '该邮箱已被注册';

  @override
  String get errorEmailInUse => '邮箱已被使用';

  @override
  String get errorEmailNotRegistered => '该邮箱未注册';

  @override
  String get errorInvalidEmailFormat => '邮箱格式不正确';

  @override
  String get errorGetVerificationCodeFirst => '请先获取验证码';

  @override
  String get errorInvalidVerificationCode => '验证码错误';

  @override
  String get errorVerificationCodeExpired => '验证码已过期';

  @override
  String get errorSendCodeTooFrequent => '发送验证码过于频繁';

  @override
  String get errorEmailSendFailed => '邮件发送失败';

  @override
  String get errorRegistrationClosed => '注册已关闭';

  @override
  String get errorRegistrationRequiresInviteCode => '注册需要邀请码';

  @override
  String get errorInvalidInviteCode => '邀请码无效';

  @override
  String get errorInviteCodeNotFound => '邀请码不存在';

  @override
  String get errorInviteCodeExpired => '邀请码已过期';

  @override
  String get errorInviteCodeUsed => '邀请码已被使用';

  @override
  String get errorAccountNotFound => '账号不存在';

  @override
  String get errorUserNotFound => '用户不存在';

  @override
  String get errorAccountDisabled => '账号已被禁用';

  @override
  String get errorAccountBanned => '账号已被封禁';

  @override
  String get errorSubscriptionNotFound => '订阅不存在';

  @override
  String get errorSubscriptionExpired => '订阅已到期';

  @override
  String get errorNoActiveSubscription => '没有有效的订阅';

  @override
  String get errorTrafficLimitExceeded => '流量已用尽';

  @override
  String get errorExpired => '已过期';

  @override
  String get errorPlanNotFound => '套餐不存在';

  @override
  String get errorOrderNotFound => '订单不存在';

  @override
  String get errorOrderAlreadyPaid => '订单已支付';

  @override
  String get errorOrderExpired => '订单已过期';

  @override
  String get errorOrderCancelled => '订单已取消';

  @override
  String get errorPaymentFailed => '支付失败';

  @override
  String get errorInsufficientBalance => '余额不足';

  @override
  String get errorCouponNotFound => '优惠码不存在';

  @override
  String get errorCouponExpired => '优惠码已过期';

  @override
  String get errorCouponUsed => '优惠码已使用';

  @override
  String get errorCouponNotApplicable => '优惠码不适用于此套餐';

  @override
  String get errorTicketNotFound => '工单不存在';

  @override
  String get errorTicketClosed => '工单已关闭';

  @override
  String get errorCannotCloseTicket => '无法关闭此工单';

  @override
  String get aboutUs => '关于我们';

  @override
  String get submitFeedback => '提交反馈';

  @override
  String get feedbackHint => '遇到问题时,请先「上传 debug 日志」生成反馈编号,再联系客服并告知编号,方便快速定位问题。';

  @override
  String get exportDebugLog => '导出 debug 日志';

  @override
  String get exportDebugLogSubtitle => '打包所有客户端日志,通过系统文件管理器/分享导出';

  @override
  String get uploadDebugLog => '上传 debug 日志';

  @override
  String get uploadDebugLogSubtitle => '自动上传日志到客服后台,生成反馈编号';

  @override
  String get contactCustomerService => '联系客服';

  @override
  String get contactCustomerServiceSubtitle => '在浏览器中打开在线客服';

  @override
  String get debugLogExporting => '正在打包日志...';

  @override
  String get debugLogExported => '日志已导出';

  @override
  String debugLogExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String get debugLogUploading => '正在上传日志到客服...';

  @override
  String debugLogUploadSuccess(String id) {
    return '上传成功,反馈编号 #$id\n请告知客服此编号';
  }

  @override
  String get debugLogUploadNotConfigured => '反馈通道未配置,请联系客服';

  @override
  String get debugLogUploadTooLargeTitle => '上传失败';

  @override
  String debugLogUploadTooLarge(String sizeMb) {
    return '日志过大($sizeMb MB),超过 50MB 上限。请返回上一步点「导出 debug 日志」保存到本地,再手动发给客服';
  }

  @override
  String debugLogUploadFailed(String error) {
    return '上传失败: $error';
  }

  @override
  String get crispNotAvailable => '客服暂不可用';

  @override
  String get pendingOrderTitle => '待处理订单';

  @override
  String get pendingOrderMessage => '您有未完成的订单，请先完成或取消后再创建新订单。';

  @override
  String get viewOrders => '查看订单';

  @override
  String get noPaymentMethods => '暂无可用支付方式';

  @override
  String get paymentSuccess => '支付成功';

  @override
  String get paymentFailed => '支付失败';

  @override
  String get cancelOrderConfirm => '确定要取消此订单吗？';

  @override
  String get unknownPlan => '未知套餐';

  @override
  String get pendingPayment => '待支付';

  @override
  String get paid => '已支付';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appName => 'Velox';

  @override
  String get login => '登入';

  @override
  String get register => '註冊';

  @override
  String get email => '電子郵件';

  @override
  String get password => '密碼';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get inviteCode => '邀請碼';

  @override
  String get verifyCode => '驗證碼';

  @override
  String get sendCode => '發送驗證碼';

  @override
  String get forgotPassword => '忘記密碼？';

  @override
  String get noAccount => '還沒有帳號？';

  @override
  String get hasAccount => '已有帳號？';

  @override
  String get loginSuccess => '登入成功';

  @override
  String get registerSuccess => '註冊成功';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirm => '確定要登出嗎？';

  @override
  String get home => '首頁';

  @override
  String get nodes => '節點';

  @override
  String get selectNode => '選擇節點';

  @override
  String get subscription => '訂閱';

  @override
  String get profile => '我的';

  @override
  String get settings => '設定';

  @override
  String get tapToConnect => '點擊按鈕連線';

  @override
  String get nodeUnreachable => '節點不可用，請嘗試其他節點';

  @override
  String get latencyTimeout => '超時';

  @override
  String get trafficUsage => '流量使用';

  @override
  String get userCenter => '使用者中心';

  @override
  String get telegramGroup => 'Telegram 群組';

  @override
  String get earnRewards => '獲得獎勵';

  @override
  String get successfullyShared => '已註冊用戶數';

  @override
  String get commissionReward => '佣金獎勵';

  @override
  String get commissionPending => '待結算佣金';

  @override
  String get peopleSuffix => '人';

  @override
  String get connect => '連接';

  @override
  String get disconnect => '斷開';

  @override
  String get connecting => '連接中...';

  @override
  String get disconnecting => '斷開中...';

  @override
  String get connected => '已連接';

  @override
  String get disconnected => '未連接';

  @override
  String get connectionTime => '連接時長';

  @override
  String get uploadSpeed => '上傳';

  @override
  String get downloadSpeed => '下載';

  @override
  String get allNodes => '全部節點';

  @override
  String get favoriteNodes => '收藏';

  @override
  String get recentNodes => '最近使用';

  @override
  String get nodeLatency => '延遲';

  @override
  String get nodeLoad => '負載';

  @override
  String get testSpeed => '測速';

  @override
  String get testingSpeed => '測速中...';

  @override
  String get addToFavorite => '加入收藏';

  @override
  String get removeFromFavorite => '取消收藏';

  @override
  String get currentPlan => '當前套餐';

  @override
  String expireDate(Object date) {
    return '到期時間：$date';
  }

  @override
  String get dataUsed => '已用流量';

  @override
  String get dataTotal => '總流量';

  @override
  String get resetDate => '重置日期';

  @override
  String get buyPlan => '購買套餐';

  @override
  String get renewPlan => '續費';

  @override
  String daysRemaining(Object days) {
    return '還剩 $days 天';
  }

  @override
  String get planExpired => '已到期';

  @override
  String expiresOnDate(Object date) {
    return '$date 到期';
  }

  @override
  String get noSubscription => '暫無訂閱';

  @override
  String get subscribeHint => '開通訂閱，解鎖全部節點';

  @override
  String get trafficUsedLabel => '已用';

  @override
  String get trafficRemainingLabel => '剩餘';

  @override
  String get planList => '可用套餐';

  @override
  String get orderHistory => '訂單記錄';

  @override
  String get balance => '餘額';

  @override
  String get inviteCount => '邀請人數';

  @override
  String get commission => '佣金';

  @override
  String get copyInviteLink => '複製邀請連結';

  @override
  String get copySuccess => '已複製到剪貼板';

  @override
  String get language => '語言';

  @override
  String get theme => '主題';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get autoConnect => '自動連接';

  @override
  String get autoReconnect => '斷線自動重連';

  @override
  String get proxyMode => '代理模式';

  @override
  String get proxyModeGlobal => '全局代理';

  @override
  String get proxyModeRule => '規則代理';

  @override
  String get proxyModeDirect => '直連';

  @override
  String get dns => 'DNS 設定';

  @override
  String get about => '關於';

  @override
  String get version => '版本';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get privacyPolicy => '隱私政策';

  @override
  String get termsOfService => '服務條款';

  @override
  String get error => '錯誤';

  @override
  String get success => '成功';

  @override
  String get warning => '警告';

  @override
  String get info => '提示';

  @override
  String get confirm => '確認';

  @override
  String get cancel => '取消';

  @override
  String get ok => '確定';

  @override
  String get retry => '重試';

  @override
  String get loading => '載入中...';

  @override
  String get noData => '暫無數據';

  @override
  String get networkError => '網路錯誤，請檢查網路連接';

  @override
  String get serverError => '伺服器錯誤，請稍後再試';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get createAccount => '建立帳號';

  @override
  String get signUpToGetStarted => '註冊以開始使用';

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get signInToContinue => '登入以繼續';

  @override
  String get pleaseEnterEmail => '請輸入電子郵件';

  @override
  String get pleaseEnterValidEmail => '請輸入有效的電子郵件';

  @override
  String get pleaseEnterPassword => '請輸入密碼';

  @override
  String get passwordTooShort => '密碼至少需要6個字元';

  @override
  String get passwordsDoNotMatch => '密碼不相符';

  @override
  String get resetPassword => '重設密碼';

  @override
  String get resetPasswordSubtitle => '輸入郵箱接收驗證碼，重設密碼';

  @override
  String get passwordResetSuccess => '密碼重設成功，請重新登入';

  @override
  String get rememberPassword => '想起密碼了？';

  @override
  String get enterEmailForReset => '輸入您的電子郵件以重設密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get verificationCodeSent => '驗證碼已發送';

  @override
  String get resetSuccess => '密碼重設成功';

  @override
  String get step => '步驟';

  @override
  String get enterEmail => '輸入電子郵件';

  @override
  String get verifyEmail => '驗證電子郵件';

  @override
  String get setNewPassword => '設定新密碼';

  @override
  String get next => '下一步';

  @override
  String get back => '返回';

  @override
  String get inviteFriends => '邀請好友';

  @override
  String get yourInviteCode => '您的邀請碼';

  @override
  String get tapToCopy => '點擊複製';

  @override
  String get inviteLink => '邀請連結';

  @override
  String get shareInviteLink => '分享邀請連結';

  @override
  String get totalInvites => '邀請總數';

  @override
  String get pendingCommission => '待結算';

  @override
  String get confirmedCommission => '已結算';

  @override
  String get inviteRecords => '邀請記錄';

  @override
  String get noInviteRecords => '暫無邀請記錄';

  @override
  String get generateNewCode => '生成新邀請碼';

  @override
  String get orders => '訂單';

  @override
  String get allOrders => '全部訂單';

  @override
  String get pendingOrders => '待付款';

  @override
  String get completedOrders => '已完成';

  @override
  String get cancelledOrders => '已取消';

  @override
  String get orderNo => '訂單編號';

  @override
  String get orderTime => '下單時間';

  @override
  String get orderAmount => '金額';

  @override
  String get orderStatus => '狀態';

  @override
  String get payNow => '立即付款';

  @override
  String get cancelOrder => '取消訂單';

  @override
  String get noOrders => '暫無訂單';

  @override
  String get selectPaymentMethod => '選擇付款方式';

  @override
  String get pay => '付款';

  @override
  String get helpAndSupport => '幫助與支援';

  @override
  String get faq => '常見問題';

  @override
  String get submitTicket => '提交工單';

  @override
  String get myTickets => '我的工單';

  @override
  String get ticketSubject => '主題';

  @override
  String get ticketMessage => '內容';

  @override
  String get ticketLevel => '優先級';

  @override
  String get ticketLevelLow => '低';

  @override
  String get ticketLevelMedium => '中';

  @override
  String get ticketLevelHigh => '高';

  @override
  String get ticketOpen => '處理中';

  @override
  String get ticketClosed => '已關閉';

  @override
  String get ticketReplied => '已回覆';

  @override
  String get noTickets => '暫無工單';

  @override
  String get closeTicket => '關閉工單';

  @override
  String get replyTicket => '回覆';

  @override
  String get send => '發送';

  @override
  String get newTicket => '新工單';

  @override
  String get create => '建立';

  @override
  String get knowledgeBase => '知識庫';

  @override
  String get selectPlan => '選擇套餐';

  @override
  String get choosePlan => '選擇您的套餐';

  @override
  String get billingCycle => '計費週期';

  @override
  String get monthly => '月付';

  @override
  String get quarterly => '季付';

  @override
  String get halfYearly => '半年付';

  @override
  String get yearly => '年付';

  @override
  String get couponCode => '優惠碼';

  @override
  String get applyCoupon => '使用';

  @override
  String get total => '合計';

  @override
  String get checkout => '結帳';

  @override
  String get orderCreated => '訂單建立成功';

  @override
  String get perMonth => '/月';

  @override
  String get speedLimit => '速度限制';

  @override
  String dataPerMonth(Object data) {
    return '$data / 月';
  }

  @override
  String get dnsSettings => 'DNS 設定';

  @override
  String get primaryDns => '主要 DNS';

  @override
  String get secondaryDns => '備用 DNS';

  @override
  String get save => '儲存';

  @override
  String get savedSuccessfully => '儲存成功';

  @override
  String get appInfo => '應用資訊';

  @override
  String get developer => '開發者';

  @override
  String get website => '網站';

  @override
  String get sourceCode => '原始碼';

  @override
  String get licenses => '開源授權';

  @override
  String get rateApp => '評分';

  @override
  String get shareApp => '分享';

  @override
  String get contactUs => '聯絡我們';

  @override
  String get account => '帳號';

  @override
  String get dataTransfer => '流量';

  @override
  String get expires => '到期';

  @override
  String get resetDay => '重置日';

  @override
  String day(Object day) {
    return '第 $day 天';
  }

  @override
  String usedPercent(Object percent) {
    return '已使用 $percent%';
  }

  @override
  String get delete => '刪除';

  @override
  String get edit => '編輯';

  @override
  String get close => '關閉';

  @override
  String get open => '開啟';

  @override
  String get refresh => '重新整理';

  @override
  String get refreshSuccess => '已更新';

  @override
  String get refreshFailed => '更新失敗';

  @override
  String get refreshTooltip => '重新整理訂閱資訊';

  @override
  String get inviteCodeRequired => '邀請碼（必填）';

  @override
  String get pleaseEnterInviteCode => '請填寫邀請碼';

  @override
  String get search => '搜尋';

  @override
  String get filter => '篩選';

  @override
  String get sort => '排序';

  @override
  String get more => '更多';

  @override
  String get less => '收起';

  @override
  String get all => '全部';

  @override
  String get none => '無';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get done => '完成';

  @override
  String get apply => '套用';

  @override
  String get clear => '清除';

  @override
  String get reset => '重設';

  @override
  String get announcements => '公告';

  @override
  String get noAnnouncements => '暫無公告';

  @override
  String get readMore => '閱讀更多';

  @override
  String get switchLanguage => '切換語言';

  @override
  String get selectLanguage => '選擇語言';

  @override
  String get currency => '貨幣';

  @override
  String get selectCurrency => '選擇貨幣';

  @override
  String get purchaseSubscription => '購買訂閱';

  @override
  String get choosePlanDescription => '選擇適合您的套餐';

  @override
  String get popular => '熱門';

  @override
  String get bestValue => '最優惠';

  @override
  String get unlimited => '無限制';

  @override
  String devicesAllowed(Object count) {
    return '$count 台裝置';
  }

  @override
  String trafficPerMonth(Object data) {
    return '$data GB / 月';
  }

  @override
  String get noSpeedLimit => '不限速';

  @override
  String speedLimitValue(Object speed) {
    return '限速：$speed Mbps';
  }

  @override
  String get subscribedPlan => '當前套餐';

  @override
  String get selectThisPlan => '選擇';

  @override
  String get proceedToPayment => '前往付款';

  @override
  String get contactSupport => '建立工單';

  @override
  String get joinTelegram => '加入 Telegram';

  @override
  String get telegramChannel => 'Telegram 頻道';

  @override
  String get customerService => '客服';

  @override
  String get liveChat => '線上客服';

  @override
  String get twoYear => '兩年';

  @override
  String get threeYear => '三年';

  @override
  String get oneTime => '一次性';

  @override
  String savePercent(Object percent) {
    return '省 $percent%';
  }

  @override
  String get helpCenter => '幫助中心';

  @override
  String get commonQuestions => '常見問題';

  @override
  String get viewAllArticles => '查看所有文章';

  @override
  String get loginToContinue => '登入以繼續使用 Velox';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get or => '或';

  @override
  String get phoneLogin => '手機驗證碼登入';

  @override
  String get scanToImport => '掃碼匯入訂閱';

  @override
  String get registerNow => '立即註冊';

  @override
  String get urlImport => '匯入訂閱';

  @override
  String get pleaseEnterSubscriptionLink => '請輸入訂閱連結';

  @override
  String get pasteSubscriptionLinkHint => '請貼上訂閱連結...';

  @override
  String get pasteFromClipboard => '從剪貼板貼上';

  @override
  String get howToGetSubscriptionLink => '如何取得訂閱連結？';

  @override
  String get subscriptionLinkStep1 => '1. 登入您的服務商網站';

  @override
  String get subscriptionLinkStep2 => '2. 在「我的訂閱」頁面找到訂閱連結';

  @override
  String get subscriptionLinkStep3 => '3. 複製連結並貼上到此處';

  @override
  String get importSubscription => '匯入訂閱';

  @override
  String get createNewTicket => '建立新工單';

  @override
  String get ticketSubjectHint => '簡述您的問題';

  @override
  String get ticketMessageHint => '詳細描述您的問題';

  @override
  String get priority => '優先級';

  @override
  String get noFaqArticles => '暫無常見問題文章';

  @override
  String get untitled => '無標題';

  @override
  String get noContent => '無內容';

  @override
  String get noTicketsYet => '暫無工單';

  @override
  String get createTicketHelp => '如需幫助，請建立工單';

  @override
  String get noSubject => '無主題';

  @override
  String get newReply => '新';

  @override
  String get closeTicketAction => '關閉工單';

  @override
  String get ticketStatusOpen => '處理中';

  @override
  String get ticketStatusClosed => '已關閉';

  @override
  String get priorityLow => '低';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityHigh => '高';

  @override
  String get priorityUnknown => '未知';

  @override
  String get navHome => '首頁';

  @override
  String get navNodes => '節點';

  @override
  String get navStats => '統計';

  @override
  String get navSubscription => '訂閱';

  @override
  String get navSettings => '設定';

  @override
  String get statusConnected => '已連接';

  @override
  String get statusConnecting => '連接中...';

  @override
  String get statusDisconnecting => '斷開中...';

  @override
  String get statusDisconnected => '未連接';

  @override
  String get selectServer => '選擇節點';

  @override
  String get selectServerFirst => '請先選擇伺服器';

  @override
  String get autoSelect => '自動選擇';

  @override
  String get autoSelectSubtitle => '自動選擇最佳節點';

  @override
  String get upload => '上傳';

  @override
  String get download => '下載';

  @override
  String get connectButton => '連接';

  @override
  String get disconnectButton => '斷開';

  @override
  String get scanQrCode => '掃描二維碼';

  @override
  String get qrScanHint => '將二維碼放入框內即可自動掃描';

  @override
  String get gallery => '相簿';

  @override
  String get flashlight => '閃光燈';

  @override
  String get linkImport => '連結匯入';

  @override
  String get testAllNodes => '測試所有節點';

  @override
  String get updateNodes => '更新節點';

  @override
  String get noNodesAvailable => '無可用節點';

  @override
  String get uuidCopied => 'UUID 已複製';

  @override
  String get inviteFriendsMenu => '我的邀請';

  @override
  String get orderHistoryMenu => '訂單記錄';

  @override
  String get helpSupportMenu => '幫助與支援';

  @override
  String get aboutMenu => '關於';

  @override
  String get logoutConfirmTitle => '登出';

  @override
  String get logoutConfirmMessage => '確定要登出嗎？';

  @override
  String get stats => '統計';

  @override
  String get gameDescription => 'Velox 提供穩定便捷的網路加速服務，介面簡潔直觀，一鍵連接全球高速節點。';

  @override
  String get termsContent =>
      '歡迎使用 Velox！使用本應用即表示您同意以下服務條款。\n\n1. 服務說明\nVelox 是一款網路加速工具，旨在為用戶提供安全、穩定的網路連接服務。\n\n2. 用戶責任\n用戶應遵守所在地區的法律法規，不得利用本服務從事任何違法活動。用戶對其帳號下的所有行為承擔責任。\n\n3. 帳號管理\n每個帳號僅供註冊用戶本人使用，禁止轉讓、出借或共享帳號。我們有權對違規帳號進行限制或封禁。\n\n4. 服務變更\n我們保留隨時修改、暫停或終止服務的權利，届時將通過應用內通知告知用戶。\n\n5. 免責聲明\n本服務按「現狀」提供，我們不對因網路環境變化、不可抗力等因素導致的服務中斷承擔責任。\n\n6. 知識產權\n本應用的所有內容、設計和技術均受知識產權法保護，未經授權不得複製或使用。\n\n如您不同意上述條款，請立即停止使用本應用。';

  @override
  String get privacyContent =>
      'Velox 非常重視您的隱私保護。\n\n1. 資訊收集\n我們僅收集提供服務所必需的最少資訊，包括註冊郵箱和基本設備資訊。我們不會收集您的瀏覽記錄或個人檔案。\n\n2. 資訊使用\n收集的資訊僅用於：提供和維護服務、改善用戶體驗、發送服務通知。\n\n3. 資訊保護\n我們採用業界標準的加密技術保護您的資料安全，防止未經授權的存取、洩露或篡改。\n\n4. 資訊共享\n我們不會向任何第三方出售或共享您的個人資訊，除非法律法規要求。\n\n5. 資料儲存\n您的資料儲存在安全的伺服器上，我們會在服務需要的期限內保留資料。\n\n6. 用戶權利\n您有權查看、修改或刪除您的個人資訊。如需行使上述權利，請聯繫客服。\n\n使用 Velox 即表示您同意本隱私政策。';

  @override
  String get preferences => '偏好設定';

  @override
  String get multiLanguage => '多語言';

  @override
  String get proxyModeRuleSubtitle => '根據規則智能分流';

  @override
  String get proxyModeGlobalSubtitle => '所有流量走代理';

  @override
  String get proxyModeDirectSubtitle => '不走代理直連';

  @override
  String get proxyModeTun => 'TUN 模式';

  @override
  String get proxyModeTunSubtitle => '接管系統所有流量，啟用時無須開啟系統代理';

  @override
  String get recommended => '推薦';

  @override
  String get calendarToday => '今';

  @override
  String get noNodesSubscribe => '沒有節點可使用，訂閱即可獲得';

  @override
  String get nodeUpdateFailedCached => '節點更新失敗，已使用上次的節點';

  @override
  String get nodeLoadFailed => '節點載入失敗，請檢查網路後重試';

  @override
  String get connectingSupport => '正在連接客服...';

  @override
  String get supportLoading => '請稍候，客服系統載入中';

  @override
  String get inviteGetReward => '獲得獎勵';

  @override
  String get inviteCodeCopied => '邀請碼已複製';

  @override
  String get inviteLinkCopied => '邀請連結已複製';

  @override
  String inviteCodeLabel(Object code) {
    return '邀請碼: $code';
  }

  @override
  String get commissionEarned => '獲得佣金';

  @override
  String get shareQrOrLink => '分享二維碼或複製連結給好友註冊';

  @override
  String get registerFreeHour => '註冊即送 1 小時免費試用，還在等什麼？';

  @override
  String get inviteGlobalNodes => '全球節點高速穩定 看視頻永不卡頓 解鎖各種app';

  @override
  String get splashSlogan => '安全 · 極速 · 穩定';

  @override
  String get getStarted => '開始使用';

  @override
  String get alreadyHaveAccount => '已有帳號？立即登入';

  @override
  String get skip => '跳過';

  @override
  String trafficUsed(Object used, Object total) {
    return '已用 $used / 總計 $total';
  }

  @override
  String onlineDevices(Object alive, Object limit) {
    return '在線設備 $alive/$limit';
  }

  @override
  String peopleCount(Object count) {
    return '$count 人';
  }

  @override
  String minutesCount(Object minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get uploadImage => '上傳圖片';

  @override
  String uploadImageFailed(Object error) {
    return '圖片上傳失敗: $error';
  }

  @override
  String get passwordChangeSuccess => '修改密碼成功，請重新登入';

  @override
  String get updateTitle => '發現新版本';

  @override
  String get updateNow => '立即更新';

  @override
  String get skipUpdate => '暫不更新';

  @override
  String get subscriptionExpiryTitle => '訂閱即將到期';

  @override
  String subscriptionExpiryMessage(int days) {
    return '您的訂閱將在 $days 天後到期，請及時續費';
  }

  @override
  String get renewNow => '立即續費';

  @override
  String get announcementDefaultButton => '知道了';

  @override
  String get verificationCode => '驗證碼';

  @override
  String get pleaseEnterVerificationCode => '請輸入驗證碼';

  @override
  String get inviteCodeOptional => '邀請碼（可選）';

  @override
  String get errorUnknown => '未知錯誤，請稍後再試';

  @override
  String get errorOperationFailed => '操作失敗，請重試';

  @override
  String get errorNoPermission => '沒有存取權限';

  @override
  String get errorNoInternet => '無網路連線';

  @override
  String get errorNetworkFailed => '網路連線失敗，請檢查網路';

  @override
  String get errorConnectionTimeout => '連線逾時，請檢查網路';

  @override
  String get errorRequestTimeout => '請求逾時，請稍後再試';

  @override
  String get errorConnectionRefused => '無法連線伺服器';

  @override
  String get errorGatewayError => '伺服器閘道器錯誤';

  @override
  String get errorGatewayTimeout => '伺服器響應逾時';

  @override
  String get errorServiceUnavailable => '服務暫時不可用';

  @override
  String get errorServerBusy => '伺服器繁忙，請稍後再試';

  @override
  String get errorBadRequest => '請求參數錯誤';

  @override
  String get errorValidationFailed => '輸入資訊有誤';

  @override
  String get errorAccessDenied => '存取被拒絕';

  @override
  String get errorResourceNotFound => '請求的資源不存在';

  @override
  String get errorTooManyRequests => '請求過於頻繁，請稍後再試';

  @override
  String get errorTooManyAttempts => '嘗試次數過多，請稍後再試';

  @override
  String get errorLoginExpired => '登入已過期，請重新登入';

  @override
  String get errorLoginFailed => '登入失敗';

  @override
  String get errorPleaseLogin => '請先登入';

  @override
  String get errorInvalidToken => '登入狀態異常，請重新登入';

  @override
  String get errorEmailOrPasswordIncorrect => '電子郵件或密碼錯誤';

  @override
  String get errorPasswordIncorrect => '密碼錯誤';

  @override
  String get errorPasswordTooShort => '密碼太短，至少需要6位';

  @override
  String get errorPasswordTooWeak => '密碼強度不夠';

  @override
  String get errorPasswordsNotMatch => '兩次輸入的密碼不一致';

  @override
  String get errorEmailAlreadyRegistered => '該電子郵件已被註冊';

  @override
  String get errorEmailInUse => '該電子郵件已被使用';

  @override
  String get errorEmailNotRegistered => '該電子郵件未註冊';

  @override
  String get errorInvalidEmailFormat => '電子郵件格式不正確';

  @override
  String get errorGetVerificationCodeFirst => '請先獲取驗證碼';

  @override
  String get errorInvalidVerificationCode => '驗證碼錯誤';

  @override
  String get errorVerificationCodeExpired => '驗證碼已過期';

  @override
  String get errorSendCodeTooFrequent => '發送過於頻繁，請稍後再試';

  @override
  String get errorEmailSendFailed => '郵件發送失敗，請稍後再試';

  @override
  String get errorRegistrationClosed => '暫不開放註冊';

  @override
  String get errorRegistrationRequiresInviteCode => '註冊需要邀請碼';

  @override
  String get errorInvalidInviteCode => '邀請碼無效';

  @override
  String get errorInviteCodeNotFound => '邀請碼不存在';

  @override
  String get errorInviteCodeExpired => '邀請碼已過期';

  @override
  String get errorInviteCodeUsed => '邀請碼已被使用';

  @override
  String get errorAccountNotFound => '帳號不存在';

  @override
  String get errorUserNotFound => '使用者不存在';

  @override
  String get errorAccountDisabled => '帳號已被停用';

  @override
  String get errorAccountBanned => '帳號已被封禁';

  @override
  String get errorSubscriptionNotFound => '未找到訂閱';

  @override
  String get errorSubscriptionExpired => '訂閱已過期';

  @override
  String get errorNoActiveSubscription => '沒有有效的訂閱';

  @override
  String get errorTrafficLimitExceeded => '流量已用完';

  @override
  String get errorExpired => '已過期，請重新操作';

  @override
  String get errorPlanNotFound => '套餐不存在';

  @override
  String get errorOrderNotFound => '訂單不存在';

  @override
  String get errorOrderAlreadyPaid => '訂單已支付';

  @override
  String get errorOrderExpired => '訂單已過期';

  @override
  String get errorOrderCancelled => '訂單已取消';

  @override
  String get errorPaymentFailed => '支付失敗';

  @override
  String get errorInsufficientBalance => '餘額不足';

  @override
  String get errorCouponNotFound => '優惠券不存在';

  @override
  String get errorCouponExpired => '優惠券已過期';

  @override
  String get errorCouponUsed => '優惠券已被使用';

  @override
  String get errorCouponNotApplicable => '優惠券不適用於此套餐';

  @override
  String get errorTicketNotFound => '工單不存在';

  @override
  String get errorTicketClosed => '工單已關閉';

  @override
  String get errorCannotCloseTicket => '無法關閉工單';

  @override
  String get aboutUs => '關於我們';

  @override
  String get submitFeedback => '提交回饋';

  @override
  String get feedbackHint => '遇到問題時,請先「上傳 debug 日誌」產生回饋編號,再聯絡客服並告知編號,方便快速定位問題。';

  @override
  String get exportDebugLog => '匯出 debug 日誌';

  @override
  String get exportDebugLogSubtitle => '打包所有客戶端日誌,透過系統檔案管理器/分享匯出';

  @override
  String get uploadDebugLog => '上傳 debug 日誌';

  @override
  String get uploadDebugLogSubtitle => '自動上傳日誌至客服後台,產生回饋編號';

  @override
  String get contactCustomerService => '聯絡客服';

  @override
  String get contactCustomerServiceSubtitle => '在瀏覽器中開啟線上客服';

  @override
  String get debugLogExporting => '正在打包日誌...';

  @override
  String get debugLogExported => '日誌已匯出';

  @override
  String debugLogExportFailed(String error) {
    return '匯出失敗: $error';
  }

  @override
  String get debugLogUploading => '正在上傳日誌至客服...';

  @override
  String debugLogUploadSuccess(String id) {
    return '上傳成功,回饋編號 #$id\n請告知客服此編號';
  }

  @override
  String get debugLogUploadNotConfigured => '回饋通道未設定,請聯絡客服';

  @override
  String get debugLogUploadTooLargeTitle => '上傳失敗';

  @override
  String debugLogUploadTooLarge(String sizeMb) {
    return '日誌過大($sizeMb MB),超過 50MB 上限。請返回上一步點「匯出 debug 日誌」儲存到本機,再手動傳送給客服';
  }

  @override
  String debugLogUploadFailed(String error) {
    return '上傳失敗: $error';
  }

  @override
  String get crispNotAvailable => '客服暫不可用';

  @override
  String get pendingOrderTitle => '待處理訂單';

  @override
  String get pendingOrderMessage => '您有未付款或正在處理的訂單。請先付款或取消訂單後再建立新訂單。';

  @override
  String get viewOrders => '查看訂單';

  @override
  String get noPaymentMethods => '沒有可用的支付方式';

  @override
  String get paymentSuccess => '支付成功';

  @override
  String get paymentFailed => '支付失敗';

  @override
  String get cancelOrderConfirm => '確定要取消此訂單嗎？';

  @override
  String get unknownPlan => '未知套餐';

  @override
  String get pendingPayment => '待支付';

  @override
  String get paid => '已支付';
}
