// One-shot PNG generator for the Velox app icon.
//
// Design: a bold geometric "V" monogram — a speed-leaning glyph that doubles
// as the brand letter. Deep diagonal accent gradient + a glossy top sheen
// give the tile iOS-native depth. The V's right stroke is drawn slightly
// thicker than the left for a subtle motion cue.
//
// Run once with:
//   dart run tool/gen_app_icon.dart
//   dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

const int _size = 1024;
const int _radius = 224; // iOS squircle feel

// Deep royal blue gradient — richer than plain accent so the icon feels
// premium next to the stock Apple palette.
final img.ColorRgb8 _top = img.ColorRgb8(0x2B, 0x70, 0xE8);
final img.ColorRgb8 _bottom = img.ColorRgb8(0x0F, 0x3F, 0xBF);

void main() {
  final image = img.Image(width: _size, height: _size, numChannels: 4);

  // Transparent outside the rounded square.
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  _drawRoundedGradientBase(image);
  _drawGlossySheen(image);
  _drawVMark(image);

  File('assets/icons/app_icon.png').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('✅ Wrote assets/icons/app_icon.png (${_size}×$_size)');
}

/// Vertical diagonal gradient, clipped to a rounded square.
void _drawRoundedGradientBase(img.Image image) {
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      if (!_insideRoundedRect(x, y, _size, _size, _radius)) continue;
      // Diagonal 0..1, slight asymmetry — darker toward bottom-right.
      final t = (0.35 * x + 0.65 * y) / _size;
      image.setPixel(x, y, _lerpRgb(_top, _bottom, t.clamp(0.0, 1.0)));
    }
  }
}

/// Subtle top-half white highlight — fades out by ~55% height.
void _drawGlossySheen(img.Image image) {
  final cutoff = (_size * 0.55).round();
  for (var y = 0; y < cutoff; y++) {
    final k = 1.0 - (y / cutoff);
    final alpha = (k * k * 60).round(); // max ~23% white up top
    for (var x = 0; x < _size; x++) {
      if (!_insideRoundedRect(x, y, _size, _size, _radius)) continue;
      image.setPixel(x, y, _overlayWhite(image.getPixel(x, y), alpha));
    }
  }
}

/// Bold geometric V — two thick strokes that meet at the lower-center.
/// Right stroke is 5% thicker than the left, creating a tiny lean that
/// reads as motion instead of a static letterform.
void _drawVMark(img.Image image) {
  const cx = _size ~/ 2;
  // Vertical span: top at 22%, bottom tip pushes to 82% — slight
  // asymmetry centered lower than geometric middle for visual balance.
  const topY = 224;
  const botY = 842;
  // Horizontal tops of the V strokes.
  const leftTopX = 220;
  const rightTopX = 804;
  // Stroke thickness.
  const leftThick = 154;
  const rightThick = 162;

  final white = img.ColorRgb8(255, 255, 255);

  // Left arm: top-left → bottom tip.
  _drawThickLine(image, leftTopX, topY, cx, botY, leftThick, white);
  // Right arm: top-right → bottom tip.
  _drawThickLine(image, rightTopX, topY, cx, botY, rightThick, white);

  // Round off the joint at the bottom with a filled circle so the strokes
  // merge cleanly instead of showing a seam.
  img.fillCircle(
    image,
    x: cx,
    y: botY,
    radius: leftThick ~/ 2,
    color: white,
  );
}

/// Draw a thick line by sweeping a filled circle along the segment —
/// avoids the jagged aliasing of naive rectangle rasters and gives the
/// strokes rounded ends.
void _drawThickLine(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  int thickness,
  img.ColorRgb8 color,
) {
  final r = thickness ~/ 2;
  final dx = (x2 - x1).toDouble();
  final dy = (y2 - y1).toDouble();
  final dist = (dx * dx + dy * dy);
  final steps = (dist > 0 ? (dist.toDouble()).ceil() : 1);
  final stride = 1.0 / (steps + 1);
  for (var t = 0.0; t <= 1.0; t += stride * 8) {
    final x = (x1 + dx * t).round();
    final y = (y1 + dy * t).round();
    img.fillCircle(image, x: x, y: y, radius: r, color: color);
  }
}

bool _insideRoundedRect(int x, int y, int w, int h, int r) {
  if (x >= r && x < w - r) return y >= 0 && y < h;
  if (y >= r && y < h - r) return x >= 0 && x < w;
  final cx = (x < r) ? r : w - r - 1;
  final cy = (y < r) ? r : h - r - 1;
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy <= r * r;
}

img.ColorRgb8 _lerpRgb(img.ColorRgb8 a, img.ColorRgb8 b, double t) {
  return img.ColorRgb8(
    (a.r + (b.r - a.r) * t).round(),
    (a.g + (b.g - a.g) * t).round(),
    (a.b + (b.b - a.b) * t).round(),
  );
}

/// Composite a white pixel with the given alpha over the existing pixel.
img.ColorRgba8 _overlayWhite(img.Color src, int alpha) {
  final a = alpha.clamp(0, 255);
  final sa = src.a.toInt();
  final sr = src.r.toInt();
  final sg = src.g.toInt();
  final sb = src.b.toInt();
  final outA = (a + sa * (255 - a) ~/ 255).clamp(1, 255);
  final outR = ((255 * a + sr * sa * (255 - a) ~/ 255) ~/ outA).clamp(0, 255);
  final outG = ((255 * a + sg * sa * (255 - a) ~/ 255) ~/ outA).clamp(0, 255);
  final outB = ((255 * a + sb * sa * (255 - a) ~/ 255) ~/ outA).clamp(0, 255);
  return img.ColorRgba8(outR, outG, outB, outA);
}
