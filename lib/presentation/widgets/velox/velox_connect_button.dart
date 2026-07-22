import 'package:flutter/material.dart';

import '../../../core/theme/velox/velox_motion.dart';
import '../../../core/theme/velox/velox_tokens.dart';

enum VeloxConnectState { disconnected, connecting, connected, disconnecting, error }

/// The 272/216/160 three-ring connect button from `velox-preview.html`.
class VeloxConnectButton extends StatefulWidget {
  const VeloxConnectButton({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 272,
  });

  final VeloxConnectState state;
  final VoidCallback onTap;
  final double size;

  @override
  State<VeloxConnectButton> createState() => _VeloxConnectButtonState();
}

class _VeloxConnectButtonState extends State<VeloxConnectButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: VeloxMotion.pulseBreath,
    )..repeat(reverse: true);
    _press = AnimationController(
      vsync: this,
      duration: VeloxMotion.pressScale,
      value: 1.0,
      lowerBound: VeloxMotion.pressScaleFactor,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _breathing =>
      widget.state == VeloxConnectState.connecting ||
      widget.state == VeloxConnectState.disconnecting ||
      widget.state == VeloxConnectState.connected;

  Color _iconColor(VeloxTokens v) {
    switch (widget.state) {
      case VeloxConnectState.connected:
        return v.accent;
      case VeloxConnectState.error:
        return v.danger;
      case VeloxConnectState.disconnecting:
        return v.text3; // teardown — dimmer, reads as "going away"
      case VeloxConnectState.connecting:
      case VeloxConnectState.disconnected:
        return const Color(0xFF334155); // slate-700 — softer still
    }
  }

  /// Outer halo tint. Disconnected rings are soft white on top of the blue
  /// bg (not a dark slate halo) so the core looks like it's floating in
  /// a pool of light.
  Color _ringColor(VeloxTokens v) {
    switch (widget.state) {
      case VeloxConnectState.connected:
      case VeloxConnectState.connecting:
        return v.accent; // stays blue during connect — no amber flash
      case VeloxConnectState.error:
        return v.danger;
      case VeloxConnectState.disconnecting:
        return v.text3; // muted gray while tearing down
      case VeloxConnectState.disconnected:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final ring = _ringColor(v);
    final iconColor = _iconColor(v);
    final isConnected = widget.state == VeloxConnectState.connected;

    final core = widget.size * 160 / 272;
    final mid = widget.size * 216 / 272;

    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp: (_) {
        _press.forward();
        widget.onTap();
      },
      onTapCancel: () => _press.forward(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulseT = _breathing ? _pulse.value : 0.0;
          final scale = _breathing ? 1.0 + pulseT * 0.015 : 1.0;
          return ScaleTransition(
            scale: _press,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // outer ring
                    AnimatedContainer(
                      duration: VeloxMotion.glowAppear,
                      curve: VeloxMotion.glowCurve,
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ring.withValues(
                            alpha: isConnected ? 0.14 : 0.10),
                      ),
                    ),
                    // middle ring
                    AnimatedContainer(
                      duration: VeloxMotion.glowAppear,
                      curve: VeloxMotion.glowCurve,
                      width: mid,
                      height: mid,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ring.withValues(
                            alpha: isConnected ? 0.20 : 0.14),
                      ),
                    ),
                    // white core — glossy disk with accent halo + tri-stop
                    // vertical gradient to fake an embossed rim.
                    AnimatedContainer(
                      duration: VeloxMotion.stateSwap,
                      curve: VeloxMotion.stateCurve,
                      width: core,
                      height: core,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isConnected
                              ? const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF4F9FF),
                                  Color(0xFFE8F1FF),
                                ]
                              : const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF6F8FB),
                                  Color(0xFFEAEEF3),
                                ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        boxShadow: [
                          // Primary downward glow
                          BoxShadow(
                            color: ring.withValues(
                                alpha: isConnected ? 0.38 : 0.24),
                            blurRadius: isConnected ? 40 : 28,
                            offset: const Offset(0, 12),
                          ),
                          // Ambient wide halo
                          BoxShadow(
                            color: ring.withValues(
                                alpha: isConnected ? 0.22 : 0.14),
                            blurRadius: isConnected ? 80 : 60,
                            spreadRadius: isConnected ? 6 : 4,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: (widget.state == VeloxConnectState.connecting ||
                                widget.state == VeloxConnectState.disconnecting)
                            ? SizedBox(
                                width: core * 0.42,
                                height: core * 0.42,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(iconColor),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: core * 0.48,
                                color: iconColor,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
