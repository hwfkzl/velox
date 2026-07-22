import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 玻璃态信息对话框 —— 全 app 统一的"图标 + 标题 + 说明 + 单按钮"弹窗。
///
/// 与登出确认 / 系统公告 / 状态 toast 同款玻璃语言:
///   ClipRRect + BackdropFilter + v.surfaceMid 半透明 + divider 描边
///
/// 用法:
/// ```dart
/// await showVeloxInfoDialog(
///   context,
///   title: '已是最新版本',
///   message: '当前已经是最新版本,无需更新。',
/// );
/// ```
Future<void> showVeloxInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = '好的',
  IconData icon = Icons.info_outline_rounded,
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    barrierDismissible: barrierDismissible,
    builder: (dialogCtx) {
      final v = dialogCtx.velox;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                decoration: BoxDecoration(
                  color: v.surfaceMid,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: v.divider, width: 1),
                  boxShadow: v.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // accent 玻璃圆图标(与登出对话框图标语言一致)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: v.accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: v.accent.withValues(alpha: 0.32),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: v.accent, size: 24),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: v.text1,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: v.text2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // accent 玻璃按钮(全宽)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(dialogCtx).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: v.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v.accent.withValues(alpha: 0.40),
                          ),
                        ),
                        child: Text(
                          buttonText,
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
}
