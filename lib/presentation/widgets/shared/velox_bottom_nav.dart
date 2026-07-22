import 'package:flutter/material.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';

/// Velox 底部导航栏
class VeloxBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VeloxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.bolt, label: '首页'),
    _NavItem(icon: Icons.public, label: '节点'),
    _NavItem(icon: Icons.bar_chart, label: '统计'),
    _NavItem(icon: Icons.person_outline, label: '订阅'),
    _NavItem(icon: Icons.settings_outlined, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VeloxColors.bgSecondary,
        border: Border(
          top: BorderSide(
            color: VeloxColors.borderWithOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VeloxSpacing.lg,
            vertical: VeloxSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == currentIndex;
              return _NavItemWidget(
                icon: item.icon,
                label: item.label,
                isSelected: isSelected,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

class _NavItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: VeloxSpacing.md,
          vertical: VeloxSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? VeloxColors.primary
                  : VeloxColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: VeloxSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? VeloxColors.primary
                    : VeloxColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
