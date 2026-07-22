import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';

import '../core/theme/velox/velox_theme_data.dart';
import '../core/services/announcement_badge_service.dart';
import '../core/services/locale_service.dart';
import '../core/services/tray_service.dart';
import 'brand.dart';
import '../di/injection.dart';
import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/user/user_bloc.dart';
import '../presentation/blocs/node/node_bloc.dart';
import '../presentation/blocs/vpn/vpn_bloc.dart';
import '../presentation/blocs/theme/theme_bloc.dart';
import 'router.dart';

class VeloxApp extends StatelessWidget {
  const VeloxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppLifecycle(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeBloc>(
            create: (_) => ThemeBloc()..add(ThemeInitialized()),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
          ),
          BlocProvider<UserBloc>(create: (_) => getIt<UserBloc>()),
          BlocProvider<NodeBloc>(create: (_) => getIt<NodeBloc>()),
          BlocProvider<VpnBloc>(create: (_) => getIt<VpnBloc>()),
        ],
        child: _DesktopTrayBinder(
          child: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return ListenableBuilder(
                listenable: LocaleService.instance,
                builder: (context, _) {
                  return BlocListener<AuthBloc, AuthState>(
                    listener: (context, state) {
                      if (state is AuthAuthenticated) {
                        // 切账号场景：先把残留的 BLoC 状态归零，再跳转、再加载新数据。
                        // 数据加载放到 router.go 之后的下一帧，避免 ShellRoute
                        // 挂载期间 NodeBloc emit 触发 _retakeInactiveElement 重入。
                        context.read<NodeBloc>().add(NodeAuthCleared());
                        context.read<UserBloc>().add(UserAuthCleared());
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          AppRouter.router.go('/main/home');
                          SchedulerBinding.instance
                              .addPostFrameCallback((_) {
                            if (!context.mounted) return;
                            context.read<UserBloc>().add(UserLoadRequested());
                            context.read<NodeBloc>().add(NodeLoadRequested());
                          });
                        });
                      } else if (state is AuthUnauthenticated) {
                        // 退出账号：先清理所有携带账号数据的 BLoC，再跳到 /login。
                        // V2Board 后端没有 /logout 端点,本地清理是唯一保证。
                        context.read<NodeBloc>().add(NodeAuthCleared());
                        context.read<VpnBloc>().add(VpnAuthCleared());
                        context.read<UserBloc>().add(UserAuthCleared());
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          // 如果用户正在看 splash,让 splash 自己决定是否跳 login
                          // (新用户停留,看过的返回用户由 splash 内部跳)
                          final loc = AppRouter
                              .router
                              .routerDelegate
                              .currentConfiguration
                              .uri
                              .path;
                          if (loc == '/splash') return;
                          AppRouter.router.go('/login');
                        });
                      }
                    },
                    child: MaterialApp.router(
                      title: Brand.name,
                      debugShowCheckedModeBanner: false,
                      theme: VeloxThemeData.build(),
                      // Velox is a light-only theme; dark mode is not supported.
                      darkTheme: VeloxThemeData.build(),
                      themeMode: ThemeMode.light,
                      routerConfig: AppRouter.router,
                      locale: LocaleService.instance.locale,
                      localizationsDelegates: const [
                        AppLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      supportedLocales: LocaleService.supportedLocales,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 在 MultiBlocProvider 内部把 NodeBloc / VpnBloc 引用注入给 TrayService。
/// 必须在这里做,因为 NodeBloc 是 factory 注册(getIt 每次返回新实例),
/// 只有通过 BlocProvider 的 context 才能拿到 UI 实际使用的那个实例。
class _DesktopTrayBinder extends StatefulWidget {
  final Widget child;
  const _DesktopTrayBinder({required this.child});

  @override
  State<_DesktopTrayBinder> createState() => _DesktopTrayBinderState();
}

class _DesktopTrayBinderState extends State<_DesktopTrayBinder> {
  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        TrayService.instance.attachBlocs(
          nodeBloc: context.read<NodeBloc>(),
          vpnBloc: context.read<VpnBloc>(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 监听 app 生命周期,切回前台时刷新公告红点。
/// 前台 30 分钟兜底轮询由 badge service 内部管理。
class _AppLifecycle extends StatefulWidget {
  final Widget child;
  const _AppLifecycle({required this.child});

  @override
  State<_AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends State<_AppLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 启动前台兜底轮询(30 分钟一次) + 立刻拉一次判定红点
    AnnouncementBadgeService.instance.startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AnnouncementBadgeService.instance.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 切回前台立即刷新红点
      AnnouncementBadgeService.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
