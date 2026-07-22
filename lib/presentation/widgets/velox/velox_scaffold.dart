import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// Root of every Velox page. Paints the shared dark gradient + mesh overlay
/// so child content only has to worry about its own composition. The mesh is
/// painted once per page; children should not nest their own meshes.
class VeloxScaffold extends StatelessWidget {
  const VeloxScaffold({
    super.key,
    required this.child,
    this.extendBodyBehindNav = true,
    this.showMesh = true,
  });

  final Widget child;
  final bool extendBodyBehindNav;
  final bool showMesh;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    // macOS / Windows 桌面端 titlebar 透明 + fullSizeContentView 后，内容
    // 延伸到 y=0；所有页面统一加 28px 顶部 padding 避开红绿黄按钮
    final isDesktop = Platform.isMacOS || Platform.isWindows;

    return Container(
      decoration: BoxDecoration(gradient: v.bgGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 深色主题 mesh —— 单一蓝光光源
          //   把光斑中心从 (-0.55, -0.55) 下移到 (-0.4, -0.15)，
          //   避免光晕扩到 macOS titlebar 区造成顶部"发亮"
          if (showMesh) ...[
            _Blob(
              align: const Alignment(-0.4, -0.15),
              radius: 0.95,
              color: const Color(0xFF4A9FFF),
              alpha: 0.35,
            ),
          ],
          isDesktop
              ? Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: child,
                )
              : child,
        ],
      ),
    );
  }
}

/// A single soft-focus radial blob used by the liquid-glass mesh.
class _Blob extends StatelessWidget {
  const _Blob({
    required this.align,
    required this.radius,
    required this.color,
    required this.alpha,
  });

  final Alignment align;
  final double radius;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: align,
            radius: radius,
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.6),
              const Color(0x00000000),
            ],
            // Very soft fade — the blob bleeds out over ~60% of its radius
            // so edges are imperceptible.
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    );
  }
}
