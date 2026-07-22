import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/shared/velox_app_bar.dart';
import '../../widgets/shared/velox_button.dart';
import '../../widgets/shared/velox_card.dart';

/// 链接导入页面
class URLImportPage extends StatefulWidget {
  const URLImportPage({super.key});

  @override
  State<URLImportPage> createState() => _URLImportPageState();
}

class _URLImportPageState extends State<URLImportPage> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!;
      });
    }
  }

  void _importSubscription() {
    final l10n = AppLocalizations.of(context)!;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterSubscriptionLink),
          backgroundColor: VeloxColors.error,
        ),
      );
      return;
    }
    // TODO: 实现导入逻辑
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.veloxColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: VeloxAppBar(
        title: l10n.urlImport,
        showBackButton: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: colors.bgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: VeloxSpacing.lg),
                // 输入框
                Container(
                  height: 160,
                  padding: const EdgeInsets.all(VeloxSpacing.lg),
                  decoration: BoxDecoration(
                    color: VeloxColors.bgCardWithOpacity(0.8),
                    borderRadius: BorderRadius.circular(VeloxRadius.md),
                    border: Border.all(
                      color: VeloxColors.borderWithOpacity(0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _urlController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontSize: 14,
                      color: VeloxColors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.pasteSubscriptionLinkHint,
                      hintStyle: const TextStyle(
                        color: VeloxColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                const SizedBox(height: VeloxSpacing.lg),

                // 从剪贴板粘贴
                VeloxSecondaryButton(
                  text: l10n.pasteFromClipboard,
                  icon: Icons.content_paste,
                  height: 48,
                  onPressed: _pasteFromClipboard,
                ),

                const SizedBox(height: VeloxSpacing.xxl),

                // 提示卡片
                VeloxPrimaryCard(
                  padding: const EdgeInsets.all(VeloxSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: VeloxColors.primary,
                          ),
                          const SizedBox(width: VeloxSpacing.sm),
                          Text(
                            l10n.howToGetSubscriptionLink,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: VeloxColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: VeloxSpacing.md),
                      Text(
                        '${l10n.subscriptionLinkStep1}\n'
                        '${l10n.subscriptionLinkStep2}\n'
                        '${l10n.subscriptionLinkStep3}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: VeloxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 导入按钮
                VeloxPrimaryButton(
                  text: l10n.importSubscription,
                  onPressed: _importSubscription,
                ),

                const SizedBox(height: VeloxSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
