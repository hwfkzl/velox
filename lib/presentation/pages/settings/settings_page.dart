import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../support/crisp_page.dart';
import 'preferences_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/storage/storage_keys.dart';
import '../../blocs/vpn/vpn_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/user/user_bloc.dart';
import '../../blocs/vpn/vpn_bloc.dart';
import '../../widgets/shared/velox_card.dart';
import '../../widgets/shared/velox_switch.dart';
import '../../widgets/velox/velox_scaffold.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  void _refresh(BuildContext context) {
    _refreshController.repeat();
    context.read<UserBloc>().add(UserRefreshRequested());
  }

  /// 屏幕中央的玻璃态状态弹窗(替代 SnackBar)。
  /// - 视觉风格与登出确认弹窗一致:深色玻璃容器 + 圆形 tinted 图标
  /// - 无操作按钮,自动消失(成功 1.2s,失败 2.5s 给用户更多时间看错误)
  /// - 点击 barrier 也可立刻关闭
  void _showStatusToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final v = context.velox;
    // 成功用 accent 蓝(和"续费"/"剩余"同色系),失败保留 danger 红。
    final tint = isError ? v.danger : v.accent;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_rounded;
    final autoDismiss = Duration(milliseconds: isError ? 2500 : 1200);

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogContext) {
        // 自动消失:进入下一帧后启动定时器,到点关闭。
        Future.delayed(autoDismiss, () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          // 横向布局:图标在左、文字在右,接近 macOS Volume HUD 的横条观感,
          // 不再像登出 dialog 那样上下堆叠(那种结构需要按钮配重才合理)。
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: v.blurHeavy,
                  sigmaY: v.blurHeavy,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: v.surfaceMid,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: v.divider, width: 1),
                    boxShadow: v.cardShadow,
                  ),
                  // Dialog 默认 minWidth=280,Row 用 max 撑满这 280 然后水平居中,
                  // BackdropFilter/Container 高度由 Row 内最高子节点(图标 36)决定,
                  // 整体保持紧凑横条比例,不会被任何"无界"组件撑大。
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 圆形 tinted 图标(尺寸缩小到 36 以匹配横条比例)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tint.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: tint, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: v.text1,
                            height: 1.4,
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
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: v.bg0,
        body: VeloxScaffold(
          child: SafeArea(
            child: BlocListener<UserBloc, UserState>(
              listener: (context, state) {
                // 只有用户手动点了刷新（controller 正在转）我们才弹反馈,
                // 避免页面首次进入加载完成时也弹 SnackBar。
                final wasRefreshing = _refreshController.isAnimating;
                if (state is UserLoaded || state is UserError) {
                  _refreshController.stop();
                  _refreshController.reset();
                  if (wasRefreshing) {
                    final l10n = AppLocalizations.of(context)!;
                    if (state is UserLoaded) {
                      _showStatusToast(context, l10n.refreshSuccess);
                    } else if (state is UserError) {
                      _showStatusToast(
                        context,
                        '${l10n.refreshFailed}：${state.message}',
                        isError: true,
                      );
                    }
                  }
                }
              },
              child: Stack(
                children: [
                  SingleChildScrollView(
                    // 本页内容(订阅卡 + 设置列表)整体放宽：横向 24 → 16,
                    // 让订阅卡与卡内 chip / 进度条有更充裕的展开空间。
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      VeloxSpacing.pageVertical,
                      16,
                      VeloxSpacing.pageVertical,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navSettings,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: v.text1,
                          ),
                        ),

                        // 账号身份行：紧贴标题下方,让"我的"页第一眼就能确认
                        // 当前登录的是哪个账号。刻意用 text3 小字 —— 身份是锚点
                        // 而非行动项,视觉重量必须低于下方套餐卡,不与"续费"抢焦点。
                        // 点击复制:报障时客服第一句就是"您的注册邮箱是",
                        // 这里直接可复制,省掉用户去用户中心翻的一步。
                        BlocBuilder<UserBloc, UserState>(
                          builder: (context, state) {
                            if (state is! UserLoaded) {
                              return const SizedBox.shrink();
                            }
                            final email = state.user.email ?? '';
                            if (email.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              // MouseRegion: 桌面端(macOS/Windows)悬停时给手型光标,
                              // 否则鼠标用户看不出这行可点。移动端为 no-op。
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: email),
                                    );
                                    _showStatusToast(context, l10n.copySuccess);
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: v.text3,
                                            letterSpacing: 0.1,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 12,
                                        color: v.text3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: VeloxSpacing.lg),

                        // Profile 卡片
                        BlocBuilder<UserBloc, UserState>(
                          builder: (context, state) {
                            if (state is! UserLoaded)
                              return const SizedBox.shrink();
                            final subscribe = state.subscribe;
                            final hasPlan =
                                subscribe != null && subscribe.plan != null;
                            final usagePercent = hasPlan
                                ? subscribe!.usagePercent
                                : 0.0;
                            final progressColor = usagePercent > 80
                                ? v.danger
                                : usagePercent > 50
                                ? v.warning
                                : v.success;

                            int? daysLeft;
                            String expireDateText = '';
                            if (hasPlan && subscribe?.expiredAt != null) {
                              final dt = DateTime.fromMillisecondsSinceEpoch(
                                subscribe!.expiredAt! * 1000,
                              );
                              daysLeft = dt.difference(DateTime.now()).inDays;
                              expireDateText =
                                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                            }
                            final daysLeftColor =
                                (daysLeft != null && daysLeft <= 7)
                                ? v.danger
                                : (daysLeft != null && daysLeft <= 30)
                                ? v.warning
                                : v.text1;
                            final headerTitle = hasPlan
                                ? (daysLeft != null && daysLeft >= 0
                                      ? l10n.daysRemaining(daysLeft)
                                      : l10n.planExpired)
                                : l10n.noSubscription;
                            final headerSub = hasPlan
                                ? l10n.expiresOnDate(expireDateText)
                                : l10n.subscribeHint;
                            final int remainingBytes = hasPlan
                                ? ((subscribe!.transferEnable ?? 0) -
                                          subscribe.usedTraffic)
                                      .clamp(0, 1 << 62)
                                      .toInt()
                                : 0;
                            final ctaLabel = hasPlan
                                ? l10n.renewPlan
                                : l10n.buyPlan;
                            // 低使用率时给进度条一个最小可见宽度，避免看起来像空条。
                            final double progressValue = usagePercent <= 0
                                ? 0
                                : usagePercent < 1.5
                                ? 0.015
                                : usagePercent / 100;

                            return Container(
                              decoration: BoxDecoration(
                                color: v.surfaceMid,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: v.divider),
                                boxShadow: v.cardShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // chip 作焦点(大字号 + 亮 accent),
                                              // "还剩 X 天 · 到期日期" 一行小字承接。
                                              if (hasPlan &&
                                                  (subscribe!
                                                          .plan
                                                          ?.name
                                                          ?.isNotEmpty ??
                                                      false)) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: v.accent.withValues(
                                                      alpha: 0.18,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: v.accent
                                                          .withValues(
                                                            alpha: 0.42,
                                                          ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    subscribe.plan!.name!,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: v.accent,
                                                      letterSpacing: 0.3,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              // "还剩 X 天于 Y 到期" 单 Text 渲染 →
                                              // 字号/字色自动一致,色调与"已用/剩余"标签同款灰(v.text3)。
                                              Text(
                                                (hasPlan &&
                                                        daysLeft != null &&
                                                        daysLeft >= 0)
                                                    ? '$headerTitle于 $headerSub'
                                                    : headerTitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: v.text3,
                                                  letterSpacing: 0.1,
                                                  height: 1.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 刷新按钮：玻璃态圆角小按钮,贴在"续费"左边。
                                        // 视觉重量低于"续费"主 CTA,作为辅助操作。
                                        // 加载中根据 _refreshController 自动旋转图标。
                                        Tooltip(
                                          message: l10n.refreshTooltip,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _refresh(context),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Ink(
                                                  decoration: BoxDecoration(
                                                    color: v.surfaceMid,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: v.divider,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(7),
                                                    child: RotationTransition(
                                                      turns: _refreshController,
                                                      child: Icon(
                                                        Icons.refresh_rounded,
                                                        size: 16,
                                                        color: v.text2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => context.go(
                                                '/main/subscription',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      v.accent,
                                                      v.accent.withValues(
                                                        alpha: 0.80,
                                                      ),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: v.accent
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        ctaLabel,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasPlan) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.trafficUsedLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: v.text3,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatBytes(
                                                  subscribe!.usedTraffic,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: v.text1,
                                                  letterSpacing: -0.1,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                l10n.trafficRemainingLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: v.text3,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              // 与"订单/全部"按钮同款渐变（#6BB5FF→#3B82F6）
                                              // 通过 ShaderMask 把渐变映射到文字字形上，
                                              // 视觉重心立刻和订阅页的强调色对齐。
                                              ShaderMask(
                                                blendMode: BlendMode.srcIn,
                                                shaderCallback: (rect) =>
                                                    const LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Color(0xFF6BB5FF),
                                                        Color(0xFF3B82F6),
                                                      ],
                                                    ).createShader(rect),
                                                child: Text(
                                                  _formatBytes(remainingBytes),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: -0.1,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value: progressValue,
                                          minHeight: 5,
                                          backgroundColor: v.divider.withValues(
                                            alpha: 0.45,
                                          ),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                progressColor,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: VeloxSpacing.lg),

                        VeloxListGroup(
                          children: [
                            VeloxListTile(
                              leading: const _SettingsIcon(
                                icon: Icons.account_circle_outlined,
                              ),
                              title: Text(
                                l10n.userCenter,
                                style: TextStyle(fontSize: 14, color: v.text1),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: VeloxColors.textTertiary,
                              ),
                              onTap: () {
                                final url = Uri.tryParse(
                                  RemoteConfigService.instance.websiteUrl,
                                );
                                if (url != null && url.hasScheme)
                                  launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: VeloxSpacing.sm),
                        VeloxListGroup(
                          children: [
                            VeloxListTile(
                              leading: const _SettingsIcon(
                                icon: Icons.chat_bubble_outline,
                              ),
                              title: Text(
                                l10n.myTickets,
                                style: TextStyle(fontSize: 14, color: v.text1),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: VeloxColors.textTertiary,
                              ),
                              onTap: () => context.push('/support?tab=tickets'),
                            ),
                          ],
                        ),
                        const SizedBox(height: VeloxSpacing.sm),
                        VeloxListGroup(
                          children: [
                            VeloxListTile(
                              leading: const _SettingsIcon(
                                icon: Icons.support_agent,
                              ),
                              title: Text(
                                l10n.liveChat,
                                style: TextStyle(fontSize: 14, color: v.text1),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: VeloxColors.textTertiary,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CrispPage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: VeloxSpacing.sm),
                        VeloxListGroup(
                          children: [
                            VeloxListTile(
                              leading: const _SettingsIcon(
                                icon: Icons.person_add_alt_1_outlined,
                              ),
                              title: Text(
                                l10n.inviteFriendsMenu,
                                style: TextStyle(fontSize: 14, color: v.text1),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: VeloxColors.textTertiary,
                              ),
                              onTap: () => context.push('/invite'),
                            ),
                          ],
                        ),
                        // 偏好设置：手机端（iOS / Android）显示；
                        // 桌面端（macOS / Windows）侧栏已有「设置」入口，不重复。
                        if (!(Platform.isMacOS || Platform.isWindows)) ...[
                          const SizedBox(height: VeloxSpacing.sm),
                          VeloxListGroup(
                            children: [
                              VeloxListTile(
                                leading: const _SettingsIcon(icon: Icons.tune),
                                title: Text(
                                  l10n.preferences,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: v.text1,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: VeloxColors.textTertiary,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PreferencesPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // 关于我们：仅 iOS 显示（Android / macOS / Windows 隐藏）。
                        if (Platform.isIOS) ...[
                          const SizedBox(height: VeloxSpacing.sm),
                          VeloxListGroup(
                            children: [
                              VeloxListTile(
                                leading: const _SettingsIcon(
                                  icon: Icons.info_outline,
                                ),
                                title: Text(
                                  l10n.aboutUs,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: v.text1,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: VeloxColors.textTertiary,
                                ),
                                onTap: () => context.push('/about'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: VeloxSpacing.sm),
                        if (RemoteConfigService.instance.faqEnabled) ...[
                          VeloxListGroup(
                            children: [
                              VeloxListTile(
                                leading: const _SettingsIcon(
                                  icon: Icons.help_outline,
                                ),
                                title: Text(
                                  '常见问题',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: v.text1,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: VeloxColors.textTertiary,
                                ),
                                onTap: () => context.push('/faq'),
                              ),
                            ],
                          ),
                          const SizedBox(height: VeloxSpacing.sm),
                        ],
                        VeloxListGroup(
                          children: [
                            VeloxListTile(
                              leading: const _SettingsIcon(
                                icon: Icons.telegram,
                              ),
                              title: Text(
                                l10n.telegramGroup,
                                style: TextStyle(fontSize: 14, color: v.text1),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: VeloxColors.textTertiary,
                              ),
                              onTap: () async {
                                final url = Uri.tryParse(
                                  RemoteConfigService.instance.telegramUrl,
                                );
                                if (url != null)
                                  launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: VeloxSpacing.xxl),

                        // 退出登录按钮 — Velox danger glass
                        _LogoutButton(
                          label: l10n.logout,
                          onTap: () => _showLogoutDialog(),
                        ),

                        const SizedBox(height: VeloxSpacing.xxl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpireDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: VeloxSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: VeloxColors.textTertiary,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        // 与整个 app 一致的深色玻璃态：ClipRRect + BackdropFilter,
        // 内层是 v.surfaceMid 半透明 + v.divider 描边,与卡片同语言。
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: v.blurHeavy,
                sigmaY: v.blurHeavy,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                decoration: BoxDecoration(
                  color: v.surfaceMid,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: v.divider, width: 1),
                  boxShadow: v.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Danger glyph on top —— 在深底上调高 tint 透明度,
                    // 加一圈微弱描边让它跟卡片做区分。
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: v.danger.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: v.danger.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: v.danger,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.logoutConfirm,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: v.text1,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogAction(
                            label: l10n.cancel,
                            accent: false,
                            onTap: () => Navigator.pop(dialogContext),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DialogAction(
                            label: l10n.logout,
                            accent: true,
                            onTap: () async {
                              Navigator.pop(dialogContext);
                              final vpnBloc = context.read<VpnBloc>();
                              final vpnState = vpnBloc.state;
                              if (vpnState.status == VpnStatus.connected ||
                                  vpnState.status == VpnStatus.connecting) {
                                vpnBloc.add(VpnDisconnectRequested());
                                await vpnBloc.stream
                                    .firstWhere(
                                      (state) =>
                                          state.status ==
                                          VpnStatus.disconnected,
                                    )
                                    .timeout(
                                      const Duration(seconds: 5),
                                      onTimeout: () => vpnBloc.state,
                                    );
                              }
                              if (mounted) {
                                context.read<AuthBloc>().add(
                                  AuthLogoutRequested(),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;

  const _SettingsIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: VeloxColors.primaryWithOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Icon(icon, size: 18, color: VeloxColors.primary)),
    );
  }
}

/// Logout button — white glass with danger tint, press-aware.
class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed ? v.danger.withValues(alpha: 0.14) : v.surfaceMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: v.danger.withValues(alpha: _pressed ? 0.60 : 0.30),
            width: 1,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: v.danger.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : v.cardShadow,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: v.danger,
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic dialog action button. `accent = true` renders a solid danger-red
/// pill; otherwise a ghost pill with slate border.
class _DialogAction extends StatefulWidget {
  const _DialogAction({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool accent;
  final VoidCallback onTap;

  @override
  State<_DialogAction> createState() => _DialogActionState();
}

class _DialogActionState extends State<_DialogAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final isAccent = widget.accent;

    // Accent（销毁性 CTA）: 实色 danger,保留醒目度让用户不会误点;
    // Cancel（次要操作）: 玻璃态深底 + 描边,与 dialog 容器同语言。
    final Color bg;
    final Color fg;
    final Color borderColor;
    if (isAccent) {
      bg = _pressed ? v.danger.withValues(alpha: 0.88) : v.danger;
      fg = Colors.white;
      borderColor = Colors.transparent;
    } else {
      bg = _pressed ? v.text1.withValues(alpha: 0.08) : v.surfaceHeavy;
      fg = v.text1;
      borderColor = v.divider;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isAccent
              ? [
                  BoxShadow(
                    color: v.danger.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
