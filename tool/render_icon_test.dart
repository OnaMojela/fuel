// Renders the Fuel app icon PNGs into assets/icon/.
// Run:  flutter test tool/render_icon_test.dart
// Then: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFD71921); // Nothing red

/// The Fuel mark: one solid flame with a teardrop of negative space inside.
/// Coordinates are in a 1000×1000 box.
Path flamePath() {
  final outer = Path()
    ..moveTo(500, 900)
    ..cubicTo(320, 900, 215, 775, 215, 615)
    ..cubicTo(215, 455, 330, 360, 410, 255)
    ..cubicTo(455, 195, 470, 140, 455, 80) // tip leans slightly left
    ..cubicTo(640, 170, 785, 380, 785, 615)
    ..cubicTo(785, 775, 680, 900, 500, 900)
    ..close();
  final inner = Path()
    ..moveTo(500, 840)
    ..cubicTo(425, 840, 380, 785, 380, 718)
    ..cubicTo(380, 648, 432, 600, 478, 535)
    ..cubicTo(570, 590, 620, 650, 620, 718)
    ..cubicTo(620, 785, 575, 840, 500, 840)
    ..close();
  return Path.combine(PathOperation.difference, outer, inner);
}

/// Draws the mark scaled to [scale] of the canvas, centred, plus the small red dot.
void paintMark(Canvas c, double size, {required double scale, Color color = _white, bool dot = true}) {
  final s = size * scale / 1000;
  final offset = (size - 1000 * s) / 2;
  c.save();
  c.translate(offset, offset);
  c.scale(s);
  c.drawPath(flamePath(), Paint()..color = color..isAntiAlias = true);
  if (dot) c.drawCircle(const Offset(800, 175), 42, Paint()..color = _red);
  c.restore();
}

Future<void> _save(String path, int size, void Function(Canvas) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(size, size);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render icons', () async {
    const n = 1024;
    // Full icon (iOS, legacy Android, web): black square, flame at ~62%.
    await _save('assets/icon/icon.png', n, (c) {
      c.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()..color = _black);
      paintMark(c, n.toDouble(), scale: 0.62);
    });
    // Android adaptive foreground: transparent. flutter_launcher_icons insets it
    // by 16% per side, so 0.80 here ≈ 55% of the final icon (inside the safe zone).
    await _save('assets/icon/foreground.png', n, (c) => paintMark(c, n.toDouble(), scale: 0.80));
    // Android 13+ themed icon: single-colour silhouette, no red dot.
    await _save('assets/icon/monochrome.png', n, (c) => paintMark(c, n.toDouble(), scale: 0.80, dot: false));
  });
}
