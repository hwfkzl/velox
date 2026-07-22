import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/in_app_update_dialog.dart';
import '../../widgets/shared/velox_card.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_info_dialog.dart';
import '../../widgets/velox/velox_scaffold.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool _checkingUpdate = false;

  /// 手动检查更新:强拉最新 config → 比对本地版本 → 无更新弹"已是最新",有更新弹
  /// InAppUpdateDialog(桌面走应用内下载,Android 走浏览器下载 APK)。
  Future<void> _onCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      // 刷新远程配置拿到最新的 update 字段。
      await RemoteConfigService.instance.refreshAndWait();
      final result = await RemoteConfigService.instance.checkForUpdate();
      if (!mounted) return;
      if (result == null) {
        // 显示当前本地版本号,让用户知道自己是哪个版本
        final info = await PackageInfo.fromPlatform();
        if (!mounted) return;
        await showVeloxInfoDialog(
          context,
          title: '已是最新版本',
          message: '当前 v${info.version} 已是最新版本，无需更新。',
          icon: Icons.check_circle_outline_rounded,
        );
      } else {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: !result.must,
          builder: (_) => InAppUpdateDialog(result: result),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final locales = LocaleService.supportedLocales;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      // 用 transparent + 内层 gradient 从 v.bgGradient 渲染,自动跟主题
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: LocaleService.instance,
          builder: (ctx, __) {
            final v = ctx.velox;
            return Container(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              decoration: BoxDecoration(
                gradient: v.bgGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: v.text3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(ctx)!.selectLanguage,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: v.text1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...locales.map((locale) {
                    final key = locale.countryCode != null
                        ? '${locale.languageCode}_${locale.countryCode}'
                        : locale.languageCode;
                    final name = LocaleService.localeNames[key] ?? key;
                    final selected =
                        LocaleService.instance.locale == locale;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: _LanguageTile(
                        name: name,
                        icon: _iconForLocale(locale),
                        selected: selected,
                        onTap: () {
                          LocaleService.instance.setLocale(locale);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForLocale(Locale locale) {
    // Use a single globe icon across all locales — same "payment-method" feel.
    return Icons.language_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      l10n.preferences,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: v.text1,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: VeloxBackButton(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VeloxSpacing.pagePadding,
                    vertical: VeloxSpacing.lg,
                  ),
                  child: VeloxListGroup(
                              children: [
                                // 多语言
                                VeloxListTile(
                                  leading: const _PrefIcon(
                                      icon: Icons.language),
                                  title: Text(
                                    l10n.multiLanguage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: v.text1,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListenableBuilder(
                                        listenable: LocaleService.instance,
                                        builder: (_, __) => Text(
                                          LocaleService.instance.currentName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: v.text3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: v.text3,
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showLanguagePicker(context),
                                ),
                                // 检查更新(iOS 除外 —— 走 App Store 官方更新)
                                if (!Platform.isIOS)
                                  VeloxListTile(
                                    leading: const _PrefIcon(
                                        icon: Icons.system_update_alt_rounded),
                                    title: Text(
                                      l10n.checkUpdate,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: v.text1,
                                      ),
                                    ),
                                    trailing: _checkingUpdate
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: v.accent,
                                            ),
                                          )
                                        : Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: v.text3,
                                          ),
                                    onTap: _checkingUpdate ? null : _onCheckUpdate,
                                  ),
                                // 关于我们（仅桌面端；手机端 "我的" 页已直接列出此项，避免重复）
                                if (Platform.isMacOS ||
                                    Platform.isWindows)
                                  VeloxListTile(
                                    leading: const _PrefIcon(
                                        icon: Icons.info_outline),
                                    title: Text(
                                      l10n.aboutUs,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: v.text1,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: v.text3,
                                    ),
                                    onTap: () => context.push('/about'),
                                  ),
                                // 提交反馈（全平台可见 —— 导出/上传日志 + 联系客服）
                                VeloxListTile(
                                  leading: const _PrefIcon(
                                      icon: Icons.feedback_outlined),
                                  title: Text(
                                    l10n.submitFeedback,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: v.text1,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: v.text3,
                                  ),
                                  onTap: () => context.push('/feedback'),
                                ),
                              ],
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

class _PrefIcon extends StatelessWidget {
  final IconData icon;
  const _PrefIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: v.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, size: 17, color: v.accent),
      ),
    );
  }
}


/// Language option tile — matches the payment-method tile style:
/// white glass card, left circular accent icon, press-blue highlight.
/// Selected state shows an accent check on the right.
class _LanguageTile extends StatefulWidget {
  const _LanguageTile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<_LanguageTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final active = _pressed || widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? v.accent.withValues(alpha: 0.14)
              : v.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? v.accent.withValues(alpha: 0.45)
                : v.divider,
            width: active ? 1.3 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: v.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: v.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: v.text1,
                ),
              ),
            ),
            if (widget.selected)
              Icon(Icons.check_rounded, color: v.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
