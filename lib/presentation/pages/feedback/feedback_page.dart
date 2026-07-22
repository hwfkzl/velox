import 'package:flutter/material.dart';

import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/services/feedback_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/shared/velox_card.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_info_dialog.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_snack.dart';
import '../support/crisp_page.dart';

/// 提交反馈:导出日志 / 上传日志 / 联系客服。
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  bool _exporting = false;
  bool _uploading = false;

  Future<void> _onExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final l10n = AppLocalizations.of(context)!;
    final r = await FeedbackService.instance.exportDebugLog();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (r.ok) {
      showVeloxSnack(context, l10n.debugLogExported);
    } else {
      showVeloxSnack(
        context,
        l10n.debugLogExportFailed(r.error ?? 'unknown'),
        isError: true,
      );
    }
  }

  Future<void> _onUpload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final l10n = AppLocalizations.of(context)!;
    final r = await FeedbackService.instance.uploadDebugLogToTelegram();
    if (!mounted) return;
    setState(() => _uploading = false);
    switch (r.state) {
      case FeedbackUploadState.success:
        // 成功用玻璃态 info dialog 强调反馈编号,与 "已是最新版本" 弹窗同款
        await showVeloxInfoDialog(
          context,
          title: l10n.uploadDebugLog,
          message: l10n.debugLogUploadSuccess(r.messageId ?? '?'),
          icon: Icons.check_circle_outline_rounded,
        );
        break;
      case FeedbackUploadState.notConfigured:
        showVeloxSnack(context, l10n.debugLogUploadNotConfigured,
            isError: true);
        break;
      case FeedbackUploadState.tooLarge:
        final mb = ((r.size ?? 0) / (1024 * 1024)).toStringAsFixed(1);
        // 与"上传成功"同款玻璃态弹窗,单按钮 accent 蓝;cloud_off 图标传达
        // "上传失败"语义,文案引导用户改走"导出 → 手动发客服"路径。
        await showVeloxInfoDialog(
          context,
          title: l10n.debugLogUploadTooLargeTitle,
          message: l10n.debugLogUploadTooLarge(mb),
          icon: Icons.cloud_off_rounded,
        );
        break;
      case FeedbackUploadState.failed:
        showVeloxSnack(
          context,
          l10n.debugLogUploadFailed(r.error ?? 'unknown'),
          isError: true,
        );
        break;
    }
  }

  /// 与设置页"在线客服"入口对齐 —— 应用内 WebView 打开 Crisp,
  /// Windows 走 url_launcher(CrispPage 自己有分支)。
  void _onOpenCrisp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CrispPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;
    final tgConfigured = FeedbackService.instance.isTelegramConfigured;

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
                      l10n.submitFeedback,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提示文案
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(
                          l10n.feedbackHint,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: v.text3,
                          ),
                        ),
                      ),
                      VeloxListGroup(
                        children: [
                          // 1. 导出日志
                          _tile(
                            context,
                            icon: Icons.folder_zip_outlined,
                            title: l10n.exportDebugLog,
                            subtitle: l10n.exportDebugLogSubtitle,
                            busy: _exporting,
                            onTap: _onExport,
                          ),
                          // 2. 上传日志(TG 未配置时置灰)
                          _tile(
                            context,
                            icon: Icons.cloud_upload_outlined,
                            title: l10n.uploadDebugLog,
                            subtitle: tgConfigured
                                ? l10n.uploadDebugLogSubtitle
                                : l10n.debugLogUploadNotConfigured,
                            busy: _uploading,
                            enabled: tgConfigured,
                            onTap: _onUpload,
                          ),
                          // 3. 在线客服(应用内 WebView,与设置页入口一致)
                          _tile(
                            context,
                            icon: Icons.support_agent,
                            title: l10n.liveChat,
                            onTap: _onOpenCrisp,
                          ),
                        ],
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

/// VeloxListGroup 要求 `List<VeloxListTile>`,不能塞自定义 wrapper widget,
/// 用 factory-style helper 直接返回 VeloxListTile。
VeloxListTile _tile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  String? subtitle,
  bool busy = false,
  bool enabled = true,
}) {
  final v = context.velox;
  final effective = enabled && !busy;
  return VeloxListTile(
    leading: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: v.accent.withValues(alpha: enabled ? 0.14 : 0.06),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 17,
          color: enabled ? v.accent : v.text3,
        ),
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        color: enabled ? v.text1 : v.text3,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: v.text3,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
    trailing: busy
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
            color: enabled ? v.text3 : v.text3.withValues(alpha: 0.4),
          ),
    onTap: effective ? onTap : null,
  );
}
