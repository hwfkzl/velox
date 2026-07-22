import 'package:flutter/material.dart';

/// Canonical motion vocabulary for the Velox design system. All Velox widgets
/// should pull their Duration/Curve from here — do not hand-roll timings.
class VeloxMotion {
  VeloxMotion._();

  /// Page push/pop, slide + fade.
  static const navPush = Duration(milliseconds: 400);
  static const navCurve = Curves.easeOutCubic;

  /// Bottom sheet / modal entrance.
  static const modalRise = Duration(milliseconds: 350);
  static const modalCurve = Curves.easeOutQuart;

  /// State transitions: connect/disconnect, tab switch, toggle active.
  static const stateSwap = Duration(milliseconds: 500);
  static const stateCurve = Curves.easeInOut;

  /// Slow breathing pulse used for the "connecting" and idle glow states.
  static const pulseBreath = Duration(milliseconds: 3000);

  /// External glow / shadow fade-in when activating a focal element.
  static const glowAppear = Duration(milliseconds: 700);
  static const glowCurve = Curves.easeOut;

  /// Tactile press feedback scale.
  static const pressScale = Duration(milliseconds: 150);
  static const pressCurve = Curves.easeOut;
  static const pressScaleFactor = 0.96;
}
