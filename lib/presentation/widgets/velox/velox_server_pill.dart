import 'dart:ui';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_motion.dart';
import '../../../core/theme/velox/velox_tokens.dart';

class VeloxServerPill extends StatefulWidget {
  const VeloxServerPill({
    super.key,
    required this.countryCode,
    required this.name,
    required this.onTap,
  });

  /// Two-letter ISO country code, or null to render a default globe icon.
  final String? countryCode;
  final String name;
  final VoidCallback onTap;

  @override
  State<VeloxServerPill> createState() => _VeloxServerPillState();
}

class _VeloxServerPillState extends State<VeloxServerPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: VeloxMotion.pressScale,
        curve: VeloxMotion.pressCurve,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(v.rMd),
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: v.blurHeavy, sigmaY: v.blurHeavy),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                // 深底上提升不透明度，从"半透"到"明确卡片"
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(v.rMd),
                // 边框用 accent 微染色 + 高亮，给 pill 一个"被锁定"的感觉
                border: Border.all(
                  color: _pressed
                      ? v.accent.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: v.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFlag(),
                  const SizedBox(width: 12),
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _pressed ? FontWeight.w600 : FontWeight.w500,
                      color: _pressed ? v.accent : v.text1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _pressed ? v.accent : v.text4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlag() {
    final code = widget.countryCode;
    if (code != null && code.length == 2) {
      return ClipOval(
        child: CountryFlag.fromCountryCode(
          code,
          width: 26,
          height: 26,
        ),
      );
    }
    return const Icon(Icons.public, size: 22, color: Colors.white70);
  }
}
