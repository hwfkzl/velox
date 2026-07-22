import 'package:flutter/material.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';

/// Velox 卡片组件
class VeloxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderRadius;

  const VeloxCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderRadius = VeloxRadius.xl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? VeloxColors.bgCardWithOpacity(0.6))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? VeloxColors.borderWithOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(VeloxSpacing.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Velox 主色渐变卡片
class VeloxPrimaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const VeloxPrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VeloxCard(
      padding: padding,
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          VeloxColors.primaryWithOpacity(0.15),
          VeloxColors.primaryDark.withValues(alpha: 0.05),
        ],
      ),
      borderColor: VeloxColors.primaryWithOpacity(0.3),
      child: child,
    );
  }
}

/// Velox 成功卡片
class VeloxSuccessCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const VeloxSuccessCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VeloxCard(
      padding: padding,
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          VeloxColors.success.withValues(alpha: 0.15),
          VeloxColors.success.withValues(alpha: 0.05),
        ],
      ),
      borderColor: VeloxColors.success.withValues(alpha: 0.3),
      child: child,
    );
  }
}

/// Velox 列表项卡片
class VeloxListTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool isFirst;
  final bool isLast;

  const VeloxListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<VeloxListTile> createState() => _VeloxListTileState();
}

class _VeloxListTileState extends State<VeloxListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(widget.isFirst ? VeloxRadius.md : 0),
      bottom: Radius.circular(widget.isLast ? VeloxRadius.md : 0),
    );

    // Minimal press feedback: only the row *content* (icon + text +
    // chevron) tints accent blue — no bg/border/scale animation. Feels
    // like a text press, closer to iOS native than the full card flash.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: borderRadius,
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(color: v.divider),
                ),
        ),
        child: Padding(
          padding: widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: VeloxSpacing.lg,
                vertical: 15,
              ),
          // ColorFiltered + srcATop tints every non-transparent pixel of
          // the child to accent blue at composite time — the only way to
          // override Text / Icon children that embed explicit colors.
          child: ColorFiltered(
            colorFilter: _pressed
                ? ColorFilter.mode(v.accent, BlendMode.srcATop)
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: VeloxSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.title,
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: VeloxSpacing.xs),
                        widget.subtitle!,
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: VeloxSpacing.md),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Velox 分组列表
class VeloxListGroup extends StatelessWidget {
  final String? title;
  final List<VeloxListTile> children;

  const VeloxListGroup({
    super.key,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: VeloxSpacing.xs,
              bottom: VeloxSpacing.sm,
            ),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: VeloxColors.textTertiary,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: v.surfaceMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: v.divider),
            boxShadow: v.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(children.length, (index) {
                final tile = children[index];
                return VeloxListTile(
                  key: tile.key,
                  leading: tile.leading,
                  title: tile.title,
                  subtitle: tile.subtitle,
                  trailing: tile.trailing,
                  onTap: tile.onTap,
                  padding: tile.padding,
                  isFirst: index == 0,
                  isLast: index == children.length - 1,
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
