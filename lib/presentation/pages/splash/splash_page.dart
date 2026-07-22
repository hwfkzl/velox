import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/brand.dart';
import '../../../app/router.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/in_app_update_dialog.dart';
import '../../widgets/velox/velox_brand_tile.dart';
import '../../widgets/velox/velox_primary_button.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_text_link.dart';

/// 启动页 ——「品牌欢迎屏」。
///
/// 显示策略:
///   - 已登录用户(AuthAuthenticated) → app.dart BlocListener 自动跳 /main/home
///   - 已点过"开始使用"(hasSeenOnboarding=true) + 未登录 → 自动跳 /login
///   - 首次安装(hasSeenOnboarding=false) → 停在 splash,等用户点"开始使用"
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  // null 表示 prefs 还没读完
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadOnboardingFlag();
    // 消费级:打开就查更新(登录前就能弹),不用等进主页
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  /// 启动即查更新:走根 Navigator 弹 InAppUpdateDialog,即使还没登录也能提示。
  /// 用 RemoteConfigService.startupChecksRun 做全局幂等,避免 MainPage 再弹一次。
  Future<void> _autoCheckUpdate() async {
    // iOS 走 App Store,不做应用内更新
    if (Platform.isIOS) return;
    if (RemoteConfigService.instance.startupChecksRun) return;
    RemoteConfigService.instance.startupChecksRun = true; // 同步 set,防 race
    try {
      await RemoteConfigService.instance.refreshAndWait();
      final result = await RemoteConfigService.instance.checkForUpdate();
      if (result == null) return;
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx == null) return;
      await showDialog<void>(
        context: ctx,
        useRootNavigator: true,
        barrierDismissible: !result.must,
        builder: (_) => InAppUpdateDialog(result: result),
      );
    } catch (_) {
      // 失败静默,用户可手动进设置检查
    }
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(StorageKeys.hasSeenOnboarding) ?? false;
    if (!mounted) return;
    setState(() => _seenOnboarding = seen);

    final authState = context.read<AuthBloc>().state;
    if (seen && authState is AuthUnauthenticated && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndGo(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.hasSeenOnboarding, true);
    if (!mounted) return;
    context.go(path);
  }

  void _onGetStarted() => _markSeenAndGo('/login');
  void _onLogin() => _markSeenAndGo('/login');

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final l10n = AppLocalizations.of(context)!;

    // tagline 拆成 3 个词,变成 3 个玻璃 chip
    final taglineWords = l10n.splashSlogan
        .split(RegExp(r'\s*·\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_seenOnboarding == true &&
            state is AuthUnauthenticated &&
            mounted) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: v.bg0,
        body: VeloxScaffold(
          child: Stack(
            children: [
              // 右下角第二个 accent 光斑 —— 形成"双光源 aurora"层次,
              // 把 VeloxScaffold 默认左上角的光带向下右扩散,避免页面下半区死沉。
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.6, 0.7),
                        radius: 0.9,
                        colors: [
                          v.accent.withValues(alpha: 0.20),
                          v.accent.withValues(alpha: 0.10),
                          const Color(0x00000000),
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 5),
                          // logo + 双层呼吸光晕(内圈紧亮、外圈散开)
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              final t = _glowAnimation.value;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    // 外圈:大范围扩散的光雾
                                    BoxShadow(
                                      color: v.accent.withValues(
                                        alpha: 0.22 * t,
                                      ),
                                      blurRadius: 120,
                                      spreadRadius: 24 * t,
                                    ),
                                    // 内圈:紧贴 logo 的亮 accent
                                    BoxShadow(
                                      color: v.accent.withValues(
                                        alpha: 0.45 * t,
                                      ),
                                      blurRadius: 50,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: const VeloxBrandTile(size: 100),
                          ),
                          const SizedBox(height: 28),
                          // 品牌名 —— 白色 w800,最强视觉锚点
                          // (之前 accent 蓝渐变,和 logo + 背景同色融化)
                          Text(
                            Brand.name,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: v.text1,
                              letterSpacing: 1.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 3 个 accent 玻璃 chip,呼应整个 app 的玻璃语言
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: taglineWords
                                .map((w) => _TaglineChip(text: w))
                                .toList(),
                          ),
                          const Spacer(flex: 6),
                          // "开始使用 →" trailing 箭头作为"下一步"语义
                          VeloxPrimaryButton(
                            label: l10n.getStarted,
                            onTap: _onGetStarted,
                            trailingIcon: Icons.arrow_forward_rounded,
                          ),
                          const SizedBox(height: 16),
                          // 已有账号? 登录
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.hasAccount,
                                style: TextStyle(fontSize: 13, color: v.text2),
                              ),
                              VeloxTextLink(
                                label: l10n.login,
                                onTap: _onLogin,
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tagline 单个词 chip —— 用 accent 描边玻璃,和"复制邀请链接"/"立即注册"
/// 同款的视觉语言。让"安全/极速/稳定"从扁平灰字升级成"承诺标签"。
class _TaglineChip extends StatelessWidget {
  const _TaglineChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: v.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: v.accent.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: v.accent,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
