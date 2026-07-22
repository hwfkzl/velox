// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Velox';

  @override
  String get login => 'Log In';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get verifyCode => 'Verification Code';

  @override
  String get sendCode => 'Send Code';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get hasAccount => 'Already have an account?';

  @override
  String get loginSuccess => 'Login successful';

  @override
  String get registerSuccess => 'Registration successful';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get home => 'Home';

  @override
  String get nodes => 'Nodes';

  @override
  String get selectNode => 'Select Node';

  @override
  String get subscription => 'Subscription';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get tapToConnect => 'Tap the button to connect';

  @override
  String get nodeUnreachable => 'Node unreachable, please try another node';

  @override
  String get latencyTimeout => 'Timeout';

  @override
  String get trafficUsage => 'Traffic Usage';

  @override
  String get userCenter => 'User Center';

  @override
  String get telegramGroup => 'Telegram Group';

  @override
  String get earnRewards => 'Earn Rewards';

  @override
  String get successfullyShared => 'Registered';

  @override
  String get commissionReward => 'Commission';

  @override
  String get commissionPending => 'Pending';

  @override
  String get peopleSuffix => '';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connecting => 'Connecting...';

  @override
  String get disconnecting => 'Disconnecting...';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connectionTime => 'Duration';

  @override
  String get uploadSpeed => 'Upload';

  @override
  String get downloadSpeed => 'Download';

  @override
  String get allNodes => 'All Nodes';

  @override
  String get favoriteNodes => 'Favorites';

  @override
  String get recentNodes => 'Recent';

  @override
  String get nodeLatency => 'Latency';

  @override
  String get nodeLoad => 'Load';

  @override
  String get testSpeed => 'Test Speed';

  @override
  String get testingSpeed => 'Testing...';

  @override
  String get addToFavorite => 'Add to Favorites';

  @override
  String get removeFromFavorite => 'Remove from Favorites';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String expireDate(Object date) {
    return 'Expires: $date';
  }

  @override
  String get dataUsed => 'Used';

  @override
  String get dataTotal => 'Total';

  @override
  String get resetDate => 'Reset Date';

  @override
  String get buyPlan => 'Buy Plan';

  @override
  String get renewPlan => 'Renew';

  @override
  String daysRemaining(Object days) {
    return '$days days left';
  }

  @override
  String get planExpired => 'Expired';

  @override
  String expiresOnDate(Object date) {
    return 'Expires $date';
  }

  @override
  String get noSubscription => 'No Subscription';

  @override
  String get subscribeHint => 'Subscribe to unlock all nodes';

  @override
  String get trafficUsedLabel => 'Used';

  @override
  String get trafficRemainingLabel => 'Remaining';

  @override
  String get planList => 'Available Plans';

  @override
  String get orderHistory => 'Order History';

  @override
  String get balance => 'Balance';

  @override
  String get inviteCount => 'Invites';

  @override
  String get commission => 'Commission';

  @override
  String get copyInviteLink => 'Copy Invite Link';

  @override
  String get copySuccess => 'Copied to clipboard';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get autoConnect => 'Auto Connect';

  @override
  String get autoReconnect => 'Auto Reconnect';

  @override
  String get proxyMode => 'Proxy Mode';

  @override
  String get proxyModeGlobal => 'Global';

  @override
  String get proxyModeRule => 'Rule';

  @override
  String get proxyModeDirect => 'Direct';

  @override
  String get dns => 'DNS Settings';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Info';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get noData => 'No data';

  @override
  String get networkError => 'Network error, please check your connection';

  @override
  String get serverError => 'Server error, please try again later';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signUpToGetStarted => 'Sign up to get started';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordSubtitle =>
      'Enter your email to receive a verification code';

  @override
  String get passwordResetSuccess =>
      'Password reset successfully, please login';

  @override
  String get rememberPassword => 'Remember your password?';

  @override
  String get enterEmailForReset => 'Enter your email to reset your password';

  @override
  String get newPassword => 'New Password';

  @override
  String get verificationCodeSent => 'Verification code sent';

  @override
  String get resetSuccess => 'Password reset successful';

  @override
  String get step => 'Step';

  @override
  String get enterEmail => 'Enter Email';

  @override
  String get verifyEmail => 'Verify Email';

  @override
  String get setNewPassword => 'Set New Password';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get inviteFriends => 'Invite Friends';

  @override
  String get yourInviteCode => 'Your Invite Code';

  @override
  String get tapToCopy => 'Tap to Copy';

  @override
  String get inviteLink => 'Invite Link';

  @override
  String get shareInviteLink => 'Share Invite Link';

  @override
  String get totalInvites => 'Total Invites';

  @override
  String get pendingCommission => 'Pending';

  @override
  String get confirmedCommission => 'Confirmed';

  @override
  String get inviteRecords => 'Invite Records';

  @override
  String get noInviteRecords => 'No invite records';

  @override
  String get generateNewCode => 'Generate New Code';

  @override
  String get orders => 'Orders';

  @override
  String get allOrders => 'All Orders';

  @override
  String get pendingOrders => 'Pending';

  @override
  String get completedOrders => 'Completed';

  @override
  String get cancelledOrders => 'Cancelled';

  @override
  String get orderNo => 'Order No.';

  @override
  String get orderTime => 'Order Time';

  @override
  String get orderAmount => 'Amount';

  @override
  String get orderStatus => 'Status';

  @override
  String get payNow => 'Pay Now';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get noOrders => 'No orders';

  @override
  String get selectPaymentMethod => 'Select Payment Method';

  @override
  String get pay => 'Pay';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get faq => 'FAQ';

  @override
  String get submitTicket => 'Submit Ticket';

  @override
  String get myTickets => 'My Tickets';

  @override
  String get ticketSubject => 'Subject';

  @override
  String get ticketMessage => 'Message';

  @override
  String get ticketLevel => 'Priority';

  @override
  String get ticketLevelLow => 'Low';

  @override
  String get ticketLevelMedium => 'Medium';

  @override
  String get ticketLevelHigh => 'High';

  @override
  String get ticketOpen => 'Open';

  @override
  String get ticketClosed => 'Closed';

  @override
  String get ticketReplied => 'Replied';

  @override
  String get noTickets => 'No tickets';

  @override
  String get closeTicket => 'Close Ticket';

  @override
  String get replyTicket => 'Reply';

  @override
  String get send => 'Send';

  @override
  String get newTicket => 'New Ticket';

  @override
  String get create => 'Create';

  @override
  String get knowledgeBase => 'Knowledge Base';

  @override
  String get selectPlan => 'Select Plan';

  @override
  String get choosePlan => 'Choose Your Plan';

  @override
  String get billingCycle => 'Billing Cycle';

  @override
  String get monthly => 'Monthly';

  @override
  String get quarterly => 'Quarterly';

  @override
  String get halfYearly => 'Semi-Annual';

  @override
  String get yearly => 'Annual';

  @override
  String get couponCode => 'Coupon Code';

  @override
  String get applyCoupon => 'Apply';

  @override
  String get total => 'Total';

  @override
  String get checkout => 'Checkout';

  @override
  String get orderCreated => 'Order created successfully';

  @override
  String get perMonth => '/mo';

  @override
  String get speedLimit => 'Speed Limit';

  @override
  String dataPerMonth(Object data) {
    return '$data / month';
  }

  @override
  String get dnsSettings => 'DNS Settings';

  @override
  String get primaryDns => 'Primary DNS';

  @override
  String get secondaryDns => 'Secondary DNS';

  @override
  String get save => 'Save';

  @override
  String get savedSuccessfully => 'Saved successfully';

  @override
  String get appInfo => 'App Info';

  @override
  String get developer => 'Developer';

  @override
  String get website => 'Website';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get licenses => 'Licenses';

  @override
  String get rateApp => 'Rate App';

  @override
  String get shareApp => 'Share App';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get account => 'Account';

  @override
  String get dataTransfer => 'Traffic';

  @override
  String get expires => 'Expires';

  @override
  String get resetDay => 'Reset Day';

  @override
  String day(Object day) {
    return 'Day $day';
  }

  @override
  String usedPercent(Object percent) {
    return '$percent% used';
  }

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get open => 'Open';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshSuccess => 'Updated';

  @override
  String get refreshFailed => 'Update failed';

  @override
  String get refreshTooltip => 'Refresh subscription';

  @override
  String get inviteCodeRequired => 'Invite code (required)';

  @override
  String get pleaseEnterInviteCode => 'Please enter the invite code';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get more => 'More';

  @override
  String get less => 'Less';

  @override
  String get all => 'All';

  @override
  String get none => 'None';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get done => 'Done';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get reset => 'Reset';

  @override
  String get announcements => 'Announcements';

  @override
  String get noAnnouncements => 'No announcements';

  @override
  String get readMore => 'Read More';

  @override
  String get switchLanguage => 'Switch Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get currency => 'Currency';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get purchaseSubscription => 'Purchase Subscription';

  @override
  String get choosePlanDescription => 'Choose a plan that fits you';

  @override
  String get popular => 'Popular';

  @override
  String get bestValue => 'Best Value';

  @override
  String get unlimited => 'Unlimited';

  @override
  String devicesAllowed(Object count) {
    return '$count devices';
  }

  @override
  String trafficPerMonth(Object data) {
    return '$data GB / month';
  }

  @override
  String get noSpeedLimit => 'No Speed Limit';

  @override
  String speedLimitValue(Object speed) {
    return 'Speed Limit: $speed Mbps';
  }

  @override
  String get subscribedPlan => 'Current Plan';

  @override
  String get selectThisPlan => 'Select';

  @override
  String get proceedToPayment => 'Proceed to Payment';

  @override
  String get contactSupport => 'Open Ticket';

  @override
  String get joinTelegram => 'Join Telegram';

  @override
  String get telegramChannel => 'Telegram Channel';

  @override
  String get customerService => 'Customer Service';

  @override
  String get liveChat => 'Live Chat';

  @override
  String get twoYear => '2 Years';

  @override
  String get threeYear => '3 Years';

  @override
  String get oneTime => 'One-time';

  @override
  String savePercent(Object percent) {
    return 'Save $percent%';
  }

  @override
  String get helpCenter => 'Help Center';

  @override
  String get commonQuestions => 'Common Questions';

  @override
  String get viewAllArticles => 'View All Articles';

  @override
  String get loginToContinue => 'Log in to continue using Velox';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get or => 'or';

  @override
  String get phoneLogin => 'Phone Login';

  @override
  String get scanToImport => 'Scan to Import';

  @override
  String get registerNow => 'Register Now';

  @override
  String get urlImport => 'Import Subscription';

  @override
  String get pleaseEnterSubscriptionLink => 'Please enter subscription link';

  @override
  String get pasteSubscriptionLinkHint => 'Paste subscription link here...';

  @override
  String get pasteFromClipboard => 'Paste from Clipboard';

  @override
  String get howToGetSubscriptionLink => 'How to get a subscription link?';

  @override
  String get subscriptionLinkStep1 => '1. Log in to your provider\'s website';

  @override
  String get subscriptionLinkStep2 =>
      '2. Find the subscription link on \"My Subscription\" page';

  @override
  String get subscriptionLinkStep3 => '3. Copy and paste the link here';

  @override
  String get importSubscription => 'Import';

  @override
  String get createNewTicket => 'Create New Ticket';

  @override
  String get ticketSubjectHint => 'Briefly describe your issue';

  @override
  String get ticketMessageHint => 'Describe your issue in detail';

  @override
  String get priority => 'Priority';

  @override
  String get noFaqArticles => 'No FAQ articles available';

  @override
  String get untitled => 'Untitled';

  @override
  String get noContent => 'No content';

  @override
  String get noTicketsYet => 'No tickets yet';

  @override
  String get createTicketHelp => 'Create a ticket if you need help';

  @override
  String get noSubject => 'No subject';

  @override
  String get newReply => 'New';

  @override
  String get closeTicketAction => 'Close Ticket';

  @override
  String get ticketStatusOpen => 'Open';

  @override
  String get ticketStatusClosed => 'Closed';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUnknown => 'Unknown';

  @override
  String get navHome => 'Home';

  @override
  String get navNodes => 'Nodes';

  @override
  String get navStats => 'Stats';

  @override
  String get navSubscription => 'Plans';

  @override
  String get navSettings => 'Settings';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting...';

  @override
  String get statusDisconnecting => 'Disconnecting...';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get selectServer => 'Select Node';

  @override
  String get selectServerFirst => 'Please select a server first';

  @override
  String get autoSelect => 'Auto Select';

  @override
  String get autoSelectSubtitle => 'Automatically pick the best node';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get connectButton => 'Connect';

  @override
  String get disconnectButton => 'Disconnect';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get qrScanHint => 'Place the QR code inside the frame to scan';

  @override
  String get gallery => 'Gallery';

  @override
  String get flashlight => 'Flashlight';

  @override
  String get linkImport => 'Link Import';

  @override
  String get testAllNodes => 'Test All Nodes';

  @override
  String get updateNodes => 'Update Nodes';

  @override
  String get noNodesAvailable => 'No nodes available';

  @override
  String get uuidCopied => 'UUID copied';

  @override
  String get inviteFriendsMenu => 'My Invite';

  @override
  String get orderHistoryMenu => 'Order History';

  @override
  String get helpSupportMenu => 'Help & Support';

  @override
  String get aboutMenu => 'About';

  @override
  String get logoutConfirmTitle => 'Log Out';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get stats => 'Stats';

  @override
  String get gameDescription =>
      'Velox provides stable and convenient network acceleration with a clean interface and one-tap connection to high-speed global nodes.';

  @override
  String get termsContent =>
      'Welcome to Velox! By using this app, you agree to the following Terms of Service.\n\n1. Service Description\nVelox is a network acceleration tool designed to provide users with secure and stable network connections.\n\n2. User Responsibilities\nUsers must comply with local laws and regulations and must not use the service for any illegal activities. Users are responsible for all actions under their accounts.\n\n3. Account Management\nEach account is for the registered user\'s personal use only. Transferring, lending, or sharing accounts is prohibited. We reserve the right to restrict or ban accounts that violate these terms.\n\n4. Service Changes\nWe reserve the right to modify, suspend, or terminate the service at any time and will notify users via in-app notifications.\n\n5. Disclaimer\nThe service is provided \"as is.\" We are not responsible for service interruptions caused by network changes or force majeure events.\n\n6. Intellectual Property\nAll content, design, and technology of this application are protected by intellectual property laws and may not be copied or used without authorization.\n\nIf you do not agree to these terms, please stop using this application immediately.';

  @override
  String get privacyContent =>
      'Your privacy is very important to us at Velox.\n\n1. Information Collection\nWe only collect the minimum information necessary to provide our service, including your registration email and basic device information. We do not collect your browsing history or personal files.\n\n2. Information Use\nCollected information is used solely for: providing and maintaining the service, improving user experience, and sending service notifications.\n\n3. Information Security\nWe use industry-standard encryption to protect your data from unauthorized access, disclosure, or tampering.\n\n4. Information Sharing\nWe do not sell or share your personal information with any third parties, except as required by law.\n\n5. Data Storage\nYour data is stored on secure servers and retained for as long as the service requires.\n\n6. User Rights\nYou have the right to view, modify, or delete your personal information. Please contact customer support to exercise these rights.\n\nBy using Velox, you consent to this Privacy Policy.';

  @override
  String get preferences => 'Preferences';

  @override
  String get multiLanguage => 'Language';

  @override
  String get proxyModeRuleSubtitle => 'Smart routing based on rules';

  @override
  String get proxyModeGlobalSubtitle => 'Route all traffic through proxy';

  @override
  String get proxyModeDirectSubtitle => 'Direct connection without proxy';

  @override
  String get proxyModeTun => 'TUN Mode';

  @override
  String get proxyModeTunSubtitle =>
      'Routes all system traffic — no system proxy needed';

  @override
  String get recommended => 'Recommended';

  @override
  String get calendarToday => 'T';

  @override
  String get noNodesSubscribe => 'No nodes available. Subscribe to get access.';

  @override
  String get nodeUpdateFailedCached =>
      'Failed to update nodes; using the last saved list';

  @override
  String get nodeLoadFailed =>
      'Failed to load nodes. Check your network and retry.';

  @override
  String get connectingSupport => 'Connecting to support...';

  @override
  String get supportLoading => 'Please wait, loading support system...';

  @override
  String get inviteGetReward => 'Get Rewards';

  @override
  String get inviteCodeCopied => 'Invite code copied';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String inviteCodeLabel(Object code) {
    return 'Code: $code';
  }

  @override
  String get commissionEarned => 'Commission';

  @override
  String get shareQrOrLink =>
      'Share QR code or copy link for friends to register';

  @override
  String get registerFreeHour =>
      'Register now for 1 hour free trial. What are you waiting for?';

  @override
  String get inviteGlobalNodes =>
      'Global high-speed nodes. Smooth streaming. Unlock any app.';

  @override
  String get splashSlogan => 'Secure · Fast · Stable';

  @override
  String get getStarted => 'Get Started';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get skip => 'Skip';

  @override
  String trafficUsed(Object used, Object total) {
    return 'Used $used / Total $total';
  }

  @override
  String onlineDevices(Object alive, Object limit) {
    return 'Online $alive/$limit';
  }

  @override
  String peopleCount(Object count) {
    return '$count people';
  }

  @override
  String minutesCount(Object minutes) {
    return '$minutes min';
  }

  @override
  String get uploadImage => 'Upload Image';

  @override
  String uploadImageFailed(Object error) {
    return 'Image upload failed: $error';
  }

  @override
  String get passwordChangeSuccess =>
      'Password changed successfully, please sign in again';

  @override
  String get updateTitle => 'Update Available';

  @override
  String get updateNow => 'Update Now';

  @override
  String get skipUpdate => 'Not Now';

  @override
  String get subscriptionExpiryTitle => 'Subscription Expiring Soon';

  @override
  String subscriptionExpiryMessage(int days) {
    return 'Your subscription expires in $days days. Please renew to continue.';
  }

  @override
  String get renewNow => 'Renew Now';

  @override
  String get announcementDefaultButton => 'Got it';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get pleaseEnterVerificationCode =>
      'Please enter the verification code';

  @override
  String get inviteCodeOptional => 'Invite Code (Optional)';

  @override
  String get errorUnknown => 'An unknown error occurred';

  @override
  String get errorOperationFailed => 'Operation failed, please try again';

  @override
  String get errorNoPermission => 'No permission to perform this action';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorNetworkFailed => 'Network request failed';

  @override
  String get errorConnectionTimeout => 'Connection timed out';

  @override
  String get errorRequestTimeout => 'Request timed out';

  @override
  String get errorConnectionRefused => 'Connection refused';

  @override
  String get errorGatewayError => 'Gateway error';

  @override
  String get errorGatewayTimeout => 'Gateway timeout';

  @override
  String get errorServiceUnavailable => 'Service unavailable';

  @override
  String get errorServerBusy => 'Server is busy, please try again later';

  @override
  String get errorBadRequest => 'Invalid request parameters';

  @override
  String get errorValidationFailed => 'Validation failed';

  @override
  String get errorAccessDenied => 'Access denied';

  @override
  String get errorResourceNotFound => 'Resource not found';

  @override
  String get errorTooManyRequests => 'Too many requests';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts, please try again later';

  @override
  String get errorLoginExpired => 'Login expired, please sign in again';

  @override
  String get errorLoginFailed => 'Login failed';

  @override
  String get errorPleaseLogin => 'Please log in first';

  @override
  String get errorInvalidToken => 'Invalid token, please sign in again';

  @override
  String get errorEmailOrPasswordIncorrect => 'Email or password is incorrect';

  @override
  String get errorPasswordIncorrect => 'Incorrect password';

  @override
  String get errorPasswordTooShort => 'Password is too short';

  @override
  String get errorPasswordTooWeak => 'Password is too weak';

  @override
  String get errorPasswordsNotMatch => 'Passwords do not match';

  @override
  String get errorEmailAlreadyRegistered => 'Email already registered';

  @override
  String get errorEmailInUse => 'Email already in use';

  @override
  String get errorEmailNotRegistered => 'Email not registered';

  @override
  String get errorInvalidEmailFormat => 'Invalid email format';

  @override
  String get errorGetVerificationCodeFirst =>
      'Please get a verification code first';

  @override
  String get errorInvalidVerificationCode => 'Invalid verification code';

  @override
  String get errorVerificationCodeExpired => 'Verification code expired';

  @override
  String get errorSendCodeTooFrequent =>
      'Verification code sent too frequently';

  @override
  String get errorEmailSendFailed => 'Failed to send email';

  @override
  String get errorRegistrationClosed => 'Registration is closed';

  @override
  String get errorRegistrationRequiresInviteCode =>
      'Registration requires an invite code';

  @override
  String get errorInvalidInviteCode => 'Invalid invite code';

  @override
  String get errorInviteCodeNotFound => 'Invite code not found';

  @override
  String get errorInviteCodeExpired => 'Invite code expired';

  @override
  String get errorInviteCodeUsed => 'Invite code already used';

  @override
  String get errorAccountNotFound => 'Account not found';

  @override
  String get errorUserNotFound => 'User not found';

  @override
  String get errorAccountDisabled => 'Account has been disabled';

  @override
  String get errorAccountBanned => 'Account has been banned';

  @override
  String get errorSubscriptionNotFound => 'Subscription not found';

  @override
  String get errorSubscriptionExpired => 'Subscription has expired';

  @override
  String get errorNoActiveSubscription => 'No active subscription';

  @override
  String get errorTrafficLimitExceeded => 'Traffic limit exceeded';

  @override
  String get errorExpired => 'Expired';

  @override
  String get errorPlanNotFound => 'Plan not found';

  @override
  String get errorOrderNotFound => 'Order not found';

  @override
  String get errorOrderAlreadyPaid => 'Order already paid';

  @override
  String get errorOrderExpired => 'Order expired';

  @override
  String get errorOrderCancelled => 'Order cancelled';

  @override
  String get errorPaymentFailed => 'Payment failed';

  @override
  String get errorInsufficientBalance => 'Insufficient balance';

  @override
  String get errorCouponNotFound => 'Coupon not found';

  @override
  String get errorCouponExpired => 'Coupon expired';

  @override
  String get errorCouponUsed => 'Coupon already used';

  @override
  String get errorCouponNotApplicable => 'Coupon not applicable to this plan';

  @override
  String get errorTicketNotFound => 'Ticket not found';

  @override
  String get errorTicketClosed => 'Ticket is closed';

  @override
  String get errorCannotCloseTicket => 'Cannot close this ticket';

  @override
  String get aboutUs => 'About Us';

  @override
  String get submitFeedback => 'Submit Feedback';

  @override
  String get feedbackHint =>
      'If you run into issues, first tap \"Upload debug log\" to generate a feedback ID, then contact support and share the ID for quick diagnosis.';

  @override
  String get exportDebugLog => 'Export debug log';

  @override
  String get exportDebugLogSubtitle =>
      'Package all client logs and export via system file manager / share sheet';

  @override
  String get uploadDebugLog => 'Upload debug log';

  @override
  String get uploadDebugLogSubtitle =>
      'Auto-upload logs to support backend and get a feedback ID';

  @override
  String get contactCustomerService => 'Contact customer service';

  @override
  String get contactCustomerServiceSubtitle => 'Open live chat in your browser';

  @override
  String get debugLogExporting => 'Packaging logs...';

  @override
  String get debugLogExported => 'Log exported';

  @override
  String debugLogExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get debugLogUploading => 'Uploading logs to support...';

  @override
  String debugLogUploadSuccess(String id) {
    return 'Upload succeeded. Feedback ID #$id\nPlease share this ID with support.';
  }

  @override
  String get debugLogUploadNotConfigured =>
      'Feedback channel not configured. Please contact support.';

  @override
  String get debugLogUploadTooLargeTitle => 'Upload failed';

  @override
  String debugLogUploadTooLarge(String sizeMb) {
    return 'Log too large ($sizeMb MB), exceeding the 50MB limit. Please go back and tap \"Export debug log\" to save it locally, then send it to support manually';
  }

  @override
  String debugLogUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get crispNotAvailable => 'Customer service is unavailable';

  @override
  String get pendingOrderTitle => 'Pending Order';

  @override
  String get pendingOrderMessage =>
      'You have an unfinished order. Would you like to continue payment?';

  @override
  String get viewOrders => 'View Orders';

  @override
  String get noPaymentMethods => 'No payment methods available';

  @override
  String get paymentSuccess => 'Payment Successful';

  @override
  String get paymentFailed => 'Payment Failed';

  @override
  String get cancelOrderConfirm =>
      'Are you sure you want to cancel this order?';

  @override
  String get unknownPlan => 'Unknown Plan';

  @override
  String get pendingPayment => 'Pending Payment';

  @override
  String get paid => 'Paid';
}
