import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/velox/velox_motion.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/order_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/node/node_bloc.dart';
import '../../widgets/in_app_update_dialog.dart';
import '../../widgets/velox/velox_bottom_nav.dart';
import '../../widgets/velox/velox_snack.dart';

class MainPage extends StatefulWidget {
  final Widget child;

  const MainPage({super.key, required this.child});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription? _autoConnectSubscription;
  bool _showSubscriptionTab = true;

  List<String> get _routes => [
    '/main/home',
    if (_showSubscriptionTab) '/main/subscription',
    '/main/settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RemoteConfigService.instance.refresh(); // 每次进入主页都刷新一次配置
    if (Platform.isIOS) _checkIosPayment();

    // 双保险: Splash 若失败,MainPage 补一次
    // 启动时自动检查更新(商业级:用户不需要手动点托盘"检查更新")。
    // 用 startupChecksRun 防止"快速切账号 unmount/remount"重复弹窗。
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  /// 启动时自动检测新版:等 OSS 拉到 → 比对版本 → 有新版弹 InAppUpdateDialog。
  /// 检测失败(拉不到 OSS / 网络问题)静默忽略,不打扰用户。
  Future<void> _autoCheckUpdate() async {
    // iOS 走 App Store 不做应用内更新
    if (Platform.isIOS) return;
    if (!mounted) return;
    if (RemoteConfigService.instance.startupChecksRun) return;
    RemoteConfigService.instance.startupChecksRun = true;

    try {
      // 先等远程配置刷到最新(否则可能用缓存的旧 update 字段)
      await RemoteConfigService.instance.refreshAndWait();
      if (!mounted) return;

      final result = await RemoteConfigService.instance.checkForUpdate();
      if (result == null || !mounted) return;

      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: !result.must,
        builder: (_) => InAppUpdateDialog(result: result),
      );
    } catch (_) {
      // 拉 OSS 失败 / 版本比对异常 — 静默忽略,不打扰用户
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RemoteConfigService.instance.refresh();
    }
  }

  Future<void> _checkIosPayment() async {
    try {
      final methods = await getIt<OrderRepository>().getPaymentMethods();
      if (mounted) setState(() => _showSubscriptionTab = methods.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _showSubscriptionTab = false);
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      context.go(_routes[index]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoConnectSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update selected tab based on current route
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _routes.length; i++) {
      if (location == _routes[i]) {
        if (_currentIndex != i) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 切账号期间 MainPage 会被快速 unmount/mount，
            // 若 setState 在 dispose 后执行会污染框架内的 Element 状态机。
            if (!mounted) return;
            setState(() {
              _currentIndex = i;
            });
          });
        }
        break;
      }
    }

    final isHome = location == '/main/home';

    // 节点拉取失败时弹一次小提示（不打断界面）：
    //   - 有缓存可回退：refreshErrorTick 自增 → "节点更新失败，已使用上次的节点"
    //   - 无缓存可回退：进入 NodeError → "节点加载失败，请检查网络后重试"
    return BlocListener<NodeBloc, NodeState>(
      listenWhen: (prev, curr) {
        if (curr is NodeError && prev is! NodeError) {
          return true;
        }
        if (prev is NodeLoaded &&
            curr is NodeLoaded &&
            curr.refreshErrorTick > prev.refreshErrorTick) {
          return true;
        }
        return false;
      },
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final msg = state is NodeError
            ? l10n.nodeLoadFailed
            : l10n.nodeUpdateFailedCached;
        showVeloxSnack(context, msg, isError: true);
      },
      child: _buildVeloxShell(context, isHome),
    );
  }

  Widget _buildVeloxShell(BuildContext context, bool isHome) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;
    final body = widget.child;

    final items = <VeloxNavItem>[
      VeloxNavItem(icon: Icons.bolt, label: l10n.navHome),
      if (_showSubscriptionTab)
        VeloxNavItem(icon: Icons.card_membership, label: l10n.navSubscription),
      VeloxNavItem(icon: Icons.person_outline, label: l10n.navSettings),
    ];

    final isDesktop = Platform.isMacOS || Platform.isWindows;

    if (isDesktop) {
      // 桌面侧栏单独构造条目列表：tab 项（与 _routes 对齐）+ push 项（跳到独立页）
      final homeIdx = 0;
      final subIdx = _showSubscriptionTab ? 1 : -1;
      final settingsIdx = _showSubscriptionTab ? 2 : 1;

      final entries = <_SideEntry>[
        _SideEntry(
          icon: Icons.bolt,
          label: l10n.navHome,
          selected: _currentIndex == homeIdx,
          onTap: () => _onTabTapped(homeIdx),
        ),
        _SideEntry(
          icon: Icons.public_outlined,
          label: l10n.selectNode,
          selected: false,
          onTap: () => context.push('/nodes'),
        ),
        if (_showSubscriptionTab)
          _SideEntry(
            icon: Icons.card_membership,
            label: l10n.navSubscription,
            selected: _currentIndex == subIdx,
            onTap: () => _onTabTapped(subIdx),
          ),
        _SideEntry(
          icon: Icons.person_outline,
          label: l10n.navSettings,
          selected: _currentIndex == settingsIdx,
          onTap: () => _onTabTapped(settingsIdx),
        ),
        _SideEntry(
          icon: Icons.settings_outlined,
          label: l10n.settings,
          selected: false,
          onTap: () => context.push('/settings'),
        ),
      ];

      return Scaffold(
        backgroundColor: v.bg0,
        body: Row(
          children: [
            _VeloxSideNav(entries: entries),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: v.bg0,
      extendBody: true,
      body: body,
      bottomNavigationBar: VeloxBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: items,
      ),
    );
  }
}

// ─── 桌面端左侧导航栏（镜像 VeloxBottomNav 的玻璃质感）────────────────────

/// 桌面侧栏一个条目：tab 项和跳转 push 项统一用这个结构承载。
class _SideEntry {
  const _SideEntry({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _VeloxSideNav extends StatelessWidget {
  const _VeloxSideNav({required this.entries});

  final List<_SideEntry> entries;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: v.blurHeavy, sigmaY: v.blurHeavy),
        child: Container(
          width: 96,
          decoration: BoxDecoration(
            color: v.surfaceHeavy,
            border: Border(
              right: BorderSide(color: v.divider, width: 1),
            ),
            boxShadow: v.navShadow,
          ),
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                const SizedBox(height: 24),
                ...entries.map((e) => _VeloxSideNavTab(entry: e)),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VeloxSideNavTab extends StatelessWidget {
  const _VeloxSideNavTab({required this.entry});

  final _SideEntry entry;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final color = entry.selected ? v.accent : v.text3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: entry.onTap,
      child: AnimatedContainer(
        duration: VeloxMotion.stateSwap,
        curve: VeloxMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: VeloxMotion.stateSwap,
              curve: VeloxMotion.stateCurve,
              width: 2,
              height: entry.selected ? 32 : 0,
              decoration: BoxDecoration(
                color: entry.selected ? v.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
                boxShadow: entry.selected
                    ? [
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : const [],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.icon, size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    entry.label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          entry.selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
