import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 玻璃态 SnackBar —— 全 app 统一的反馈提示样式。
///
/// 用法：
/// ```dart
/// showVeloxSnack(context, '验证码已发送');                // 成功（accent 蓝）
/// showVeloxSnack(context, '邮箱格式不正确', isError: true);  // 失败（danger 红）
///
/// // 基础设施错误 —— code 非 null 时,文案后追加"（error:1003）"
/// showVeloxSnack(context, '网络连接失败,请检查网络设置',
///     isError: true, code: VeloxErrorCode.networkFailed);
/// ```
///
/// 视觉风格：
///   - 浮于底部、固定 360px 宽、居中
///   - BackdropFilter 高斯模糊背景 + tint 半透明着色 + tint 描边
///   - 成功用 v.accent（与"续费"/"剩余"同色系），失败用 v.danger
///   - 有 code 时文案末尾追加"（error:XXXX）"(去掉 VX- 前缀);无 code 只显示文案
void showVeloxSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  VeloxErrorCode? code,
}) {
  final v = context.velox;
  final tint = isError ? v.danger : v.accent;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final String displayMessage = code != null
      ? '$message（error:${_stripVxPrefix(code.code)}）'
      : message;

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      // 360px 对齐 macOS 原生通知 banner 宽度,
      // 短文案不空旷、长错误能单行容纳、窄窗口也不顶边。
      width: 360,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      duration: Duration(seconds: isError ? 3 : 2),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: v.blurHeavy,
            sigmaY: v.blurHeavy,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              border: Border.all(
                color: tint.withValues(alpha: 0.45),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: v.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: tint,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayMessage,
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
    ),
  );
}

/// 剥离 VeloxErrorCode.code 的 "VX-" 前缀:VX-1003 → 1003。
String _stripVxPrefix(String code) =>
    code.startsWith('VX-') ? code.substring(3) : code;
