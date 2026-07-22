import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/invite_repository.dart';
import '../presentation/blocs/order/order_bloc.dart';
import '../presentation/blocs/invite/invite_bloc.dart';
import '../presentation/pages/splash/splash_page.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/auth/register_page.dart';
import '../presentation/pages/auth/forgot_password_page.dart';
import '../presentation/pages/auth/qr_import_page.dart';
import '../presentation/pages/auth/url_import_page.dart';
import '../presentation/pages/home/main_page.dart';
import '../presentation/pages/home/velox_home_page.dart';
import '../presentation/pages/nodes/nodes_page.dart';
import '../presentation/pages/subscription/subscription_page.dart';
import '../presentation/pages/settings/settings_page.dart';
import '../presentation/pages/settings/preferences_page.dart';
import '../presentation/pages/order/order_history_page.dart';
import '../presentation/pages/invite/invite_page.dart';
import '../presentation/pages/support/help_support_page.dart';
import '../presentation/pages/about/about_page.dart';
import '../presentation/pages/feedback/feedback_page.dart';
import '../presentation/pages/support/faq_page.dart';
import '../presentation/pages/legal/privacy_policy_page.dart';
import '../presentation/pages/legal/terms_of_service_page.dart';
import '../presentation/pages/announcements/announcements_page.dart';
import '../presentation/pages/invite/invite_records_page.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // 启动页
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // 认证页面
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // 扫码导入
      GoRoute(
        path: '/qr-import',
        name: 'qr-import',
        builder: (context, state) => const QRImportPage(),
      ),

      // 链接导入
      GoRoute(
        path: '/url-import',
        name: 'url-import',
        builder: (context, state) => const URLImportPage(),
      ),

      // 主页面（带底部导航）
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainPage(child: child),
        routes: [
          GoRoute(
            path: '/main/home',
            name: 'home',
            builder: (context, state) => const VeloxHomePage(),
          ),
          GoRoute(
            path: '/main/subscription',
            name: 'subscription',
            builder: (context, state) => const SubscriptionPage(),
          ),
          GoRoute(
            path: '/main/settings',
            name: 'settings-tab',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),

      // 节点页面（独立，从首页 push 进入）
      GoRoute(
        path: '/nodes',
        name: 'nodes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NodesPage(),
      ),

      // 应用级设置（桌面端侧栏「设置」入口，手机端 → 我的 → 偏好设置）
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const PreferencesPage(),
      ),

      // 忘记密码
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // 订单历史
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => BlocProvider(
          create: (context) => OrderBloc(
            orderRepository: getIt<OrderRepository>(),
          )..add(OrderListRequested()),
          child: const OrderHistoryPage(),
        ),
      ),

      // 邀请好友
      GoRoute(
        path: '/invite',
        name: 'invite',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => BlocProvider(
          create: (context) => InviteBloc(
            inviteRepository: getIt<InviteRepository>(),
          )..add(InviteLoadRequested()),
          child: const InvitePage(),
        ),
      ),

      // 帮助支持
      GoRoute(
        path: '/support',
        name: 'support',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final action = state.uri.queryParameters['action'];
          return HelpSupportPage(
            initialTab: tab,
            action: action,
          );
        },
      ),

      // 关于
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),

      // 提交反馈(导出日志 / 上传日志到客服 / 联系 Crisp)
      GoRoute(
        path: '/feedback',
        name: 'feedback',
        builder: (context, state) => const FeedbackPage(),
      ),

      // 常见问题
      GoRoute(
        path: '/faq',
        name: 'faq',
        builder: (context, state) => const FaqPage(),
      ),

      // 隐私政策
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyPage(),
      ),

      // 服务条款
      GoRoute(
        path: '/terms-of-service',
        name: 'terms-of-service',
        builder: (context, state) => const TermsOfServicePage(),
      ),

      // 公告
      GoRoute(
        path: '/announcements',
        name: 'announcements',
        builder: (context, state) => const AnnouncementsPage(),
      ),

      // 邀请记录
      GoRoute(
        path: '/invite-records',
        name: 'invite-records',
        builder: (context, state) => const InviteRecordsPage(),
      ),
    ],
  );
}
