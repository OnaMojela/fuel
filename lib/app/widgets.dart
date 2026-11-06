import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Faint dot grid painted behind every screen (as on nothing.tech).
/// Isolated in its own RepaintBoundary so scrolling content never repaints it.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _DotGridPainter(context.tk.dot), isComplex: true),
        ),
      ),
      child,
    ]);
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    final points = <Offset>[
      for (double y = step / 2; y < size.height; y += step)
        for (double x = step / 2; x < size.width; x += step) Offset(x, y),
    ];
    // One draw call for all dots instead of one per dot.
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

/// Panel with a translucent fill and 8px corners. (No live blur here: a
/// BackdropFilter per card is very expensive in scrolling lists, and over the
/// plain dot grid it was nearly invisible. Only the floating nav bar blurs.)
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(color: context.tk.glass, borderRadius: BorderRadius.circular(8)),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

/// Small uppercase mono label.
class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color, this.size = 11});
  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: NType.mono(size, color ?? context.tk.inkMuted));
}

/// Full-width solid black button with uppercase mono text.
class BlackButton extends StatelessWidget {
  const BlackButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.cta,
          foregroundColor: t.onCta,
          disabledBackgroundColor: t.track,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(
              child: Shrink(
                Text(label.toUpperCase(), style: NType.mono(13, onPressed == null ? t.inkMuted : t.onCta, weight: FontWeight.w700)),
                alignment: Alignment.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin ring progress (black stroke on grey track, red when over). Draws as a
/// dotted "glyph" circle when the user picked that style. With [accent], the
/// fill uses Nothing red if the user turned red details on.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.size, this.stroke = 6, this.child, this.accent = false, this.overIsBad = true});
  final double value; // 0..n (over 1 = over goal)
  final double size;
  final double stroke;
  final Widget? child;
  final bool accent;
  final bool overIsBad; // false for targets like protein, where more is fine

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final fill = (overIsBad && value > 1) ? t.accent : (accent ? t.detail(t.ink) : t.ink);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: t.glyphRings ? _GlyphRingPainter(value, stroke, t.track, fill) : _RingPainter(value, stroke, t.track, fill),
        // Inner content scales down to fit the ring (big numbers, large fonts).
        child: Padding(
          padding: EdgeInsets.all(stroke + size * 0.08),
          child: Center(child: child == null ? null : FittedBox(fit: BoxFit.scaleDown, child: child)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.track, this.fill);
  final double value, stroke;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, bg);
    final sweep = math.pi * 2 * value.clamp(0.0, 1.0);
    if (sweep > 0) canvas.drawArc(r, -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.fill != fill || o.track != track;
}

/// Dot-matrix ring: evenly spaced dots that fill clockwise from the top,
/// like the glyph lights on a Nothing phone.
class _GlyphRingPainter extends CustomPainter {
  _GlyphRingPainter(this.value, this.stroke, this.track, this.fill);
  final double value, stroke;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - stroke / 2;
    final c = size.center(Offset.zero);
    // Roughly one dot per 2 stroke-widths of circumference, at least 16.
    final n = math.max(16, (2 * math.pi * r / (stroke * 2)).floor());
    final filled = (value.clamp(0.0, 1.0) * n).round();
    final on = Paint()..color = fill;
    final off = Paint()..color = track;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, stroke / 2, i < filled ? on : off);
    }
  }

  @override
  bool shouldRepaint(_GlyphRingPainter o) => o.value != value || o.fill != fill || o.track != track;
}

/// Dot-matrix style progress bar: a row of dots that fill in.
class DotBar extends StatelessWidget {
  const DotBar({super.key, required this.value, this.dots = 24});
  final double value;
  final int dots;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final filled = (value.clamp(0.0, 1.0) * dots).round();
    final color = value > 1 ? t.accent : t.ink;
    return LayoutBuilder(builder: (context, c) {
      final d = math.min(8.0, (c.maxWidth - (dots - 1) * 3) / dots);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          dots,
          (i) => Container(
            width: d,
            height: d,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < filled ? color : t.track),
          ),
        ),
      );
    });
  }
}

/// Screen scaffold with the dot grid and a mono uppercase title.
class NScaffold extends StatelessWidget {
  const NScaffold({super.key, required this.body, this.title, this.actions, this.bottom});
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!.toUpperCase()), actions: actions),
      body: DotGridBackground(child: SafeArea(top: title == null, child: body)),
      bottomNavigationBar: bottom,
    );
  }
}

/// Shrinks its child (never grows it) when there isn't room, e.g. a big
/// number on a narrow phone or with a large system font.
class Shrink extends StatelessWidget {
  const Shrink(this.child, {super.key, this.alignment = Alignment.centerLeft});
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);
}

String fmt(num v, {int digits = 0}) =>
    v.isNaN ? '0' : (digits == 0 ? v.round().toString() : v.toStringAsFixed(digits));
