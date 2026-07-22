import 'package:flutter/material.dart';
import '../../../core/theme/velox_colors.dart';

/// Velox 开关组件
class VeloxSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  const VeloxSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 50,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: value ? VeloxColors.primaryGradient : null,
          color: value ? null : VeloxColors.borderWithOpacity(0.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 6,
            height: height - 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular((height - 6) / 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Velox 选项选择器
class VeloxSelector<T> extends StatelessWidget {
  final T value;
  final List<SelectorOption<T>> options;
  final ValueChanged<T>? onChanged;
  final double height;

  const VeloxSelector({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: VeloxColors.bgCardWithOpacity(0.6),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: VeloxColors.borderWithOpacity(0.3),
        ),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: onChanged != null ? () => onChanged!(option.value) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: height,
                decoration: BoxDecoration(
                  gradient: isSelected ? VeloxColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: Center(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : VeloxColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SelectorOption<T> {
  final T value;
  final String label;

  const SelectorOption({required this.value, required this.label});
}

/// Velox 单选列表项
class VeloxRadioTile<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final ValueChanged<T>? onChanged;

  const VeloxRadioTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    this.subtitle,
    this.badge,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? VeloxColors.primaryWithOpacity(0.15)
              : VeloxColors.bgCardWithOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? VeloxColors.primaryWithOpacity(0.5)
                : VeloxColors.borderWithOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: VeloxColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: VeloxColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? VeloxColors.primary : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(
                        color: VeloxColors.borderWithOpacity(0.5),
                        width: 2,
                      ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 推荐标签
class VeloxRecommendedBadge extends StatelessWidget {
  final String text;

  const VeloxRecommendedBadge({
    super.key,
    this.text = '推荐',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: VeloxColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: VeloxColors.success,
        ),
      ),
    );
  }
}
