import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/brand.dart';
import '../../../core/services/announcement_badge_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart' show AppLocalizations;
import '../../../core/theme/velox/velox_motion.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/models/server_model.dart';
import '../../blocs/node/node_bloc.dart';
import '../../blocs/user/user_bloc.dart';
import '../../blocs/vpn/vpn_bloc.dart';
import '../../widgets/velox/velox_connect_button.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_server_pill.dart';

class VeloxHomePage extends StatefulWidget {
  const VeloxHomePage({super.key});

  @override
  State<VeloxHomePage> createState() => _VeloxHomePageState();
}

class _VeloxHomePageState extends State<VeloxHomePage> {
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    // 主页首帧完成后检查并弹「客户端公告」—— 由 config.json 的 announcement
    // 驱动，按 id 记忆已读（同一条公告只弹一次）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowAnnouncement();
    });
  }

  Future<void> _maybeShowAnnouncement() async {
    final svc = RemoteConfigService.instance;
    if (!await svc.shouldShowAnnouncement()) return;
    final ann = svc.announcement;
    if (ann == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final v = ctx.velox;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          // 与登出对话框 / 状态 toast 同款玻璃:ClipRRect + BackdropFilter +
          // v.surfaceMid 半透明 + divider 描边,不再用写死的实色 0xFF142133。
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: v.blurHeavy,
                  sigmaY: v.blurHeavy,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: v.surfaceMid,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: v.divider),
                    boxShadow: v.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // 喇叭图标放进 accent 玻璃圆,与登出对话框图标语言一致
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: v.accent.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: v.accent.withValues(alpha: 0.32),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.campaign_rounded,
                                color: v.accent, size: 17),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ann.title ?? '系统公告',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: v.text1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            Brand.brandize(ann.content),
                            style: TextStyle(
                              fontSize: 14,
                              color: v.text2,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: v.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: v.accent.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Text(
                            ann.buttonText ?? '知道了',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: v.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    await svc.markAnnouncementSeen();
  }

  @override
  Widget build(BuildContext context) {
    return VeloxScaffold(
      child: SafeArea(
        // Status bar area is covered by the gradient; bottom nav is
        // semi-transparent, so we let SafeArea reserve just enough room
        // for the system home indicator + (with extendBody:true) the
        // bottom nav height that Scaffold reports through MediaQuery.
        top: false,
        bottom: true,
        child: Padding(
          // VeloxScaffold 已统一为桌面端预留 titlebar padding，这里只加常规上间距
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const _VeloxTopBar(),
              const _ExpireBanner(),
              Expanded(
                child: BlocBuilder<VpnBloc, VpnState>(
                  builder: (context, vpn) {
                    _maybeShowError(context, vpn.error);

                    return BlocBuilder<NodeBloc, NodeState>(
                      builder: (context, nodeState) {
                        return ValueListenableBuilder<bool>(
                          valueListenable:
                              SettingsService.instance.autoConnect,
                          builder: (context, autoConnect, _) {
                            final loaded =
                                nodeState is NodeLoaded ? nodeState : null;
                            // displayServer 解析规则：
                            //   autoConnect ON  → 不显示手选节点（自动选择由内核接管）
                            //   autoConnect OFF → 优先用 NodeBloc.selectedServer（用户在
                            //                     节点页的选择立刻反映在 pill 上），
                            //                     fallback 到 vpn.server（首次启动还
                            //                     没手选时用上次连接的节点）
                            final displayServer = autoConnect
                                ? (vpn.server ?? loaded?.selectedServer)
                                : (loaded?.selectedServer ?? vpn.server);

                            final state = _mapStatus(vpn.status);
                            final connected =
                                vpn.status == VpnStatus.connected;

                            final isDesktop =
                                Platform.isMacOS || Platform.isWindows;

                            // ── 响应式 fluid scaling ──
                            // 所有尺寸表达为可用高度的比例 + clamp 边界，
                            // 让窗口拉大/拉小时，按钮、字号、间距整体协调缩放，
                            // 而不是"小元素飘在大窗口里"。
                            return LayoutBuilder(
                              builder: (ctx, c) {
                                final h = c.maxHeight;
                                // 桌面端（窗口可调）：完整 fluid scaling
                                // 手机端：高度由系统决定，固定基准
                                final buttonSize = isDesktop
                                    ? (h * 0.42).clamp(180.0, 260.0)
                                    : 272.0;
                                final titleFs =
                                    isDesktop ? (h * 0.045).clamp(18.0, 28.0) : 22.0;
                                final hintFs =
                                    isDesktop ? (h * 0.025).clamp(11.0, 15.0) : 13.0;
                                final gap =
                                    isDesktop ? (h * 0.045).clamp(16.0, 32.0) : 24.0;
                                final bottomGap = isDesktop
                                    ? (h * 0.05).clamp(16.0, 36.0)
                                    : 96.0;

                                return Column(
                                  children: [
                                    // 顶部弹性空白（少）—— 让按钮稍偏上
                                    const Spacer(flex: 2),
                                    // ① 视觉锚点：连接按钮
                                    VeloxConnectButton(
                                      size: buttonSize,
                                      state: state,
                                      onTap: () => _onConnectTap(
                                        context: context,
                                        vpn: vpn,
                                        loaded: loaded,
                                        autoConnect: autoConnect,
                                        displayServer: displayServer,
                                      ),
                                    ),
                                    // ② 状态文字 + 副标题
                                    SizedBox(height: gap),
                                    _StatusText(
                                      connected: connected,
                                      status: vpn.status,
                                      titleFontSize: titleFs,
                                      hintFontSize: hintFs,
                                    ),
                                    // ③ 节点 pill —— 单独加大间距让它下移一点
                                    //    与状态文字保持"分组"但视觉上更靠底
                                    SizedBox(height: gap + 12),
                                    _ServerPill(server: displayServer),
                                    // 底部弹性空白（多）—— 让组合视觉重心略偏上
                                    const Spacer(flex: 3),
                                    SizedBox(height: bottomGap),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show at most one snackbar per distinct error string, and drop any
  /// in-flight snackbar first so the queue never stacks up.
  void _maybeShowError(BuildContext context, String? err) {
    if (err == null || err.isEmpty) {
      if (_lastShownError != null) _lastShownError = null;
      return;
    }
    if (err == _lastShownError) return;
    _lastShownError = err;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = err == 'node_unreachable'
          ? (l10n?.nodeUnreachable ?? 'Node unreachable, please try another node')
          : err;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(_veloxGlassSnack(context, msg));
    });
  }

  /// Velox 玻璃态 SnackBar：保持 app 整体玻璃感的视觉一致。
  /// - 背景透明，由 BackdropFilter 实现模糊
  /// - danger 色仅作为微弱着色和边框，避免实色压住玻璃感
  SnackBar _veloxGlassSnack(BuildContext context, String message) {
    final v = context.velox;
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      duration: const Duration(seconds: 3),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: v.blurHeavy, sigmaY: v.blurHeavy),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: v.danger.withValues(alpha: 0.18),
              border: Border.all(
                color: v.danger.withValues(alpha: 0.45),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: v.cardShadow,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: v.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: v.text1,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onConnectTap({
    required BuildContext context,
    required VpnState vpn,
    required NodeLoaded? loaded,
    required bool autoConnect,
    required ServerModel? displayServer,
  }) {
    // Mid-teardown: treat tap as no-op so the user can't re-trigger a
    // connect before the disconnect settles.
    if (vpn.status == VpnStatus.disconnecting) return;

    // Disconnect (also cancels connecting).
    if (vpn.isConnected || vpn.status == VpnStatus.connecting) {
      context.read<VpnBloc>().add(VpnDisconnectRequested());
      return;
    }

    // Auto connect: silent fallback if nothing is resolvable.
    if (autoConnect) {
      if (loaded != null) {
        final server = loaded.autoNow ?? loaded.selectedServer;
        if (server != null) {
          context.read<VpnBloc>().add(
                VpnConnectRequested(
                  server: server,
                  allServers: loaded.servers,
                ),
              );
        }
      }
      return;
    }

    // Manual mode: use the displayed selected server.
    if (displayServer != null) {
      context.read<VpnBloc>().add(
            VpnConnectRequested(
              server: displayServer,
              allServers: loaded?.servers,
            ),
          );
      return;
    }

    _showSelectFirstSnack(context);
  }

  void _showSelectFirstSnack(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _veloxGlassSnack(
        context,
        l10n?.selectServerFirst ?? 'Please select a server first',
      ),
    );
  }

  VeloxConnectState _mapStatus(VpnStatus s) {
    switch (s) {
      case VpnStatus.connected:
        return VeloxConnectState.connected;
      case VpnStatus.connecting:
        return VeloxConnectState.connecting;
      case VpnStatus.disconnecting:
        return VeloxConnectState.disconnecting;
      case VpnStatus.disconnected:
        return VeloxConnectState.disconnected;
    }
  }
}

/// 账号即将过期的玻璃横幅 —— 由 config.json 的 expire_notice 驱动。
/// 触发条件:enabled=true && 0 <= 剩余天数 <= days。每天最多提醒一次,
/// 用户点 ✕ 后当天不再弹;次日重新出现(除非已续费,剩余天数会自动超出阈值)。
class _ExpireBanner extends StatefulWidget {
  const _ExpireBanner();

  @override
  State<_ExpireBanner> createState() => _ExpireBannerState();
}

class _ExpireBannerState extends State<_ExpireBanner> {
  static const _dismissKey = 'expire_notice_dismissed_date';
  bool _dismissedToday = false;

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissKey);
    if (mounted) {
      setState(() => _dismissedToday = dismissed == _todayKey);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey, _todayKey);
    if (mounted) setState(() => _dismissedToday = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday) return const SizedBox.shrink();

    final notice = RemoteConfigService.instance.expireNotice;
    if (notice == null || !notice.enabled) return const SizedBox.shrink();

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (state is! UserLoaded) return const SizedBox.shrink();
        final expiredAt = state.subscribe?.expiredAt;
        if (expiredAt == null) return const SizedBox.shrink();

        // 真实计算:用户 expiredAt(秒时间戳)- 现在 = 剩余天数
        final expire = DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
        final daysLeft = expire.difference(DateTime.now()).inDays;

        // 仅在"还剩 0~notice.days 天"窗口内提醒;
        // 已过期(负数)或还早于阈值,都不提醒
        if (daysLeft < 0 || daysLeft > notice.days) {
          return const SizedBox.shrink();
        }

        final v = context.velox;
        final l10n = AppLocalizations.of(context);
        // msg 里的 %s 替换为实际剩余天数
        final msg = notice.msg.replaceAll('%s', daysLeft.toString());

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          // 限制最大宽度并居中,避免在宽窗口里横铺成一整条
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: v.blurHeavy,
                sigmaY: v.blurHeavy,
              ),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: v.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: v.warning.withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: v.warning, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msg,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: v.text1,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 立即续费 → 切到订阅 tab
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.go('/main/subscription'),
                      child: Text(
                        l10n?.renewNow ?? '立即续费',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: v.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 关闭(当天不再提醒)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            color: v.text3, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VeloxTopBar extends StatelessWidget {
  const _VeloxTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cfg = RemoteConfigService.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 44),
          cfg.showAnnouncement
              ? ValueListenableBuilder<bool>(
                  valueListenable:
                      AnnouncementBadgeService.instance.hasUnread,
                  builder: (context, hasUnread, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _IconNavButton(
                        icon: Icons.campaign_outlined,
                        label: l10n?.announcements ?? 'Announcements',
                        onTap: () {
                          // fire-and-forget:红点立即消,路由同步跳
                          AnnouncementBadgeService.instance.markAllRead();
                          context.push('/announcements');
                        },
                      ),
                      if (hasUnread)
                        const Positioned(
                          top: -2,
                          right: 4,
                          child: _AnnouncementBadgeDot(),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _IconNavButton extends StatefulWidget {
  const _IconNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_IconNavButton> createState() => _IconNavButtonState();
}

class _IconNavButtonState extends State<_IconNavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final color = _pressed ? v.accent : v.text2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: _pressed ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.connected,
    required this.status,
    this.titleFontSize = 22,
    this.hintFontSize = 13,
  });

  final bool connected;
  final VpnStatus status;
  final double titleFontSize;
  final double hintFontSize;

  String _label(AppLocalizations? l10n) {
    switch (status) {
      case VpnStatus.connected:
        return l10n?.statusConnected ?? 'Connected';
      case VpnStatus.connecting:
        return l10n?.statusConnecting ?? 'Connecting...';
      case VpnStatus.disconnecting:
        return l10n?.statusDisconnecting ?? 'Disconnecting...';
      case VpnStatus.disconnected:
        return l10n?.statusDisconnected ?? 'Disconnected';
    }
  }

  /// Following the legacy home_page spec, a hint is only shown when
  /// disconnected — "tap to connect". No invented hints for other states.
  String? _hint(AppLocalizations? l10n) {
    if (status == VpnStatus.disconnected) {
      return l10n?.tapToConnect ?? 'Tap the button to connect';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final l10n = AppLocalizations.of(context);
    // 主标题：未连接 text1（近白），已连接 accent（亮蓝），与按钮光晕呼应
    final labelColor = connected ? v.accent : v.text1;
    final hint = _hint(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(
          duration: VeloxMotion.stateSwap,
          curve: VeloxMotion.stateCurve,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 1.5,
          ),
          child: Text(_label(l10n), textAlign: TextAlign.center),
        ),
        if (hint != null) ...[
          // 主副标题间距按字号成比例（字大间距大）
          SizedBox(height: titleFontSize * 0.27),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hintFontSize,
              fontWeight: FontWeight.w400,
              color: v.text3,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _ServerPill extends StatelessWidget {
  const _ServerPill({required this.server});

  final ServerModel? server;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = server?.name ?? (l10n?.selectServer ?? 'Select server');
    final code = _countryCodeFromTags(server?.tags);
    return VeloxServerPill(
      countryCode: code,
      name: name,
      onTap: () => context.push('/nodes'),
    );
  }

  /// Pick the first 2-letter alpha tag, upper-cased, as the ISO-3166
  /// country code. Rejects tags like `v1`, `a1` that happen to have
  /// length 2 but aren't letters — those would render garbage flags.
  static final _isoLike = RegExp(r'^[A-Za-z]{2}$');
  String? _countryCodeFromTags(List<String>? tags) {
    if (tags == null || tags.isEmpty) return null;
    for (final tag in tags) {
      if (_isoLike.hasMatch(tag)) return tag.toUpperCase();
    }
    return null;
  }
}

/// 未读公告红点 —— 8×8 圆形,固定红色(不随主题变),
/// 位于顶部喇叭图标右上角。
class _AnnouncementBadgeDot extends StatelessWidget {
  const _AnnouncementBadgeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
    );
  }
}
