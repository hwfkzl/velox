import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// Shared Velox back-arrow. Mirrors the home-page top-bar press feedback:
/// the icon tints to accent blue on tap-down and restores on release.
class VeloxBackButton extends StatefulWidget {
  const VeloxBackButton({super.key, this.onTap, this.size = 20});

  /// Optional override. Defaults to `Navigator.of(context).pop()`.
  final VoidCallback? onTap;
  final double size;

  @override
  State<VeloxBackButton> createState() => _VeloxBackButtonState();
}

class _VeloxBackButtonState extends State<VeloxBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap ?? () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: widget.size,
          color: _pressed ? v.accent : v.text1,
        ),
      ),
    );
  }
}
