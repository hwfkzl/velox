import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_motion.dart';
import '../../../core/theme/velox/velox_tokens.dart';

class VeloxNavItem {
  const VeloxNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Heavy-glass rounded-top tab bar matching `velox-preview.html`. Active tab
/// gets a 32×2 glowing underline.
class VeloxBottomNav extends StatelessWidget {
  const VeloxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<VeloxNavItem> items;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: v.blurHeavy, sigmaY: v.blurHeavy),
        child: Container(
          decoration: BoxDecoration(
            color: v.surfaceHeavy,
            border: Border(
              top: BorderSide(color: v.divider, width: 1),
            ),
            boxShadow: v.navShadow,
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              return _VeloxNavTab(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _VeloxNavTab extends StatelessWidget {
  const _VeloxNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final VeloxNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final color = selected ? v.accent : v.text3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: VeloxMotion.stateSwap,
        curve: VeloxMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: VeloxMotion.stateSwap,
              curve: VeloxMotion.stateCurve,
              width: selected ? 32 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? v.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : const [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
