import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 自定义 AppBar
class VeloxAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool transparent;

  const VeloxAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.transparent = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    // 桌面端窗口标题栏透明、内容延伸到 y=0，顶部留白避开红绿黄交通灯按钮
    final isDesktop = Platform.isMacOS || Platform.isWindows;
    return Padding(
      padding: EdgeInsets.only(top: isDesktop ? 28.0 : 0.0),
      child: AppBar(
      backgroundColor: transparent ? Colors.transparent : VeloxColors.bgPrimary,
      elevation: 0,
      foregroundColor: v.text1,
      leading: showBackButton
          ? IconButton(
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios,
                color: v.text2,
                size: 20,
              ),
            )
          : null,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: v.text1,
                    letterSpacing: 0.2,
                  ),
                )
              : null),
      centerTitle: true,
      actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize {
    final extra = (Platform.isMacOS || Platform.isWindows) ? 28.0 : 0.0;
    return Size.fromHeight(kToolbarHeight + extra);
  }
}

/// Velox 页面头部（用于无 AppBar 的页面）
class VeloxPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const VeloxPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloxSpacing.pageHorizontal,
        vertical: VeloxSpacing.pageVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBackPressed ?? () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.only(bottom: VeloxSpacing.lg),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: VeloxColors.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: VeloxColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: VeloxSpacing.sm),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: VeloxColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ],
      ),
    );
  }
}
