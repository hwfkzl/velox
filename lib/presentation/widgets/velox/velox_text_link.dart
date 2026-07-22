import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 文字链接 —— tertiary action,只用色 + 字传达可点击。
///
/// 设计:
///   - 13pt w600 accent(权重低于主按钮的"框+色"组合,层级清楚)
///   - cursor 自动变为手型 —— 桌面"可点"的最强语义
///   - hover 时 opacity → 0.85(微微变暗一档),不用下划线避免过于"网页风"
///   - press 时 opacity → 0.6 —— 触觉反馈
///
/// 用于"立即注册 / 忘记密码？/ 想起密码了？登录"等场景。
class VeloxTextLink extends StatefulWidget {
  const VeloxTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w600,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  State<VeloxTextLink> createState() => _VeloxTextLinkState();
}

class _VeloxTextLinkState extends State<VeloxTextLink> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _pressed ? 0.6 : (_hovered ? 0.85 : 1.0),
          child: Padding(
            // 6px 横向 padding 给点击区一些舒展,模拟原 TextButton 的命中区
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                color: v.accent,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
