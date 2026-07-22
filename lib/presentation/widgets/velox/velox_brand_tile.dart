import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_tokens.dart';

/// 应用品牌图标 —— 深皇家蓝渐变方块 + 白色闪电，与 Dock 启动图标一致。
///
/// 用于登录 / 注册 / 忘记密码 / 关于页等地方做品牌标识。
class VeloxBrandTile extends StatelessWidget {
  const VeloxBrandTile({
    super.key,
    this.size = 88,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final radius = size * 0.27;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment(-0.3, -1),
          end: Alignment(0.5, 1),
          colors: [Color(0xFF2B70E8), Color(0xFF0F3FBF)],
        ),
        boxShadow: [
          BoxShadow(
            color: v.accent.withValues(alpha: 0.42),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.16),
          ),
          BoxShadow(
            color: v.accent.withValues(alpha: 0.18),
            blurRadius: size * 0.57,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top-half glossy sheen (iOS-native glass feel).
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 白色闪电图标 —— 与 Dock 应用图标的闪电造型一致。
            Icon(
              Icons.bolt,
              color: Colors.white,
              size: size * 0.72,
            ),
          ],
        ),
      ),
    );
  }
}
