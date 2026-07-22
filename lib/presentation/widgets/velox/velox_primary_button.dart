import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 主操作按钮 ——「描边玻璃全宽」风格。
///
/// 与 post-login 界面的"复制邀请链接 / 登出"等全宽按钮**完全同源**:
///   - 半透明深色玻璃底(v.surfaceMid),不抢页面视觉重量
///   - 1px accent 描边,微 accent 外发光阴影
///   - 文字 + 图标用 accent 蓝,brand 色作为"标识"而非"填充"
///   - 按下时 tint 加深到 accent α 0.14,描边 α 0.30 → 0.60,蓝光更强
///
/// 用法不变(只换皮肤):
/// ```dart
/// VeloxPrimaryButton(label: '登录', onTap: ..., loading: false)
/// ```
class VeloxPrimaryButton extends StatefulWidget {
  const VeloxPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.height = 52,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double height;
  /// 文字前图标 —— 用在"+ 添加 / ↻ 刷新"这类"图标描述动作"的场景
  final IconData? icon;
  /// 文字后图标 —— 用在"开始使用 →"这类"继续/下一步"的场景
  final IconData? trailingIcon;

  @override
  State<VeloxPrimaryButton> createState() => _VeloxPrimaryButtonState();
}

class _VeloxPrimaryButtonState extends State<VeloxPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final disabled = widget.onTap == null || widget.loading;
    // accent 文字色:可用时全饱和 accent,禁用时降到 text4(slate-300 灰)
    final fg = disabled ? v.text4 : v.accent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          // 默认:玻璃深底;按下:accent 浅染让按钮"亮起来"
          color: _pressed
              ? v.accent.withValues(alpha: 0.14)
              : v.surfaceMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? v.divider
                : v.accent.withValues(alpha: _pressed ? 0.60 : 0.30),
            width: 1,
          ),
          // 默认:卡片阴影做"悬浮"感;按下:accent 蓝光浮起,模拟"被点"的物理反馈
          boxShadow: disabled
              ? null
              : (_pressed
                  ? [
                      BoxShadow(
                        color: v.accent.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : v.cardShadow),
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: v.accent,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(widget.trailingIcon, color: fg, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
