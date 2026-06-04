import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/colors.dart';

/// Classic Japanese *seigaiha* (青海波) wave motif — rows of overlapping
/// concentric arcs. Painted very faintly so it reads as a texture behind
/// hero / header content, never competing with it.
class SeigaihaPainter extends CustomPainter {
  const SeigaihaPainter({
    required this.color,
    this.radius = 46,
    this.rings = 4,
    this.opacity = 0.06,
    this.strokeWidth = 1.4,
  });

  final Color color;
  final double radius;
  final int rings;
  final double opacity;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: opacity);

    final r = radius;
    // Each "scale" is a stack of concentric half-circles; rows step by r and
    // alternate a half-step horizontally so the fans interlock.
    final rowStep = r * 0.66;
    var row = 0;
    for (double cy = 0; cy < size.height + r; cy += rowStep) {
      final shift = row.isEven ? 0.0 : r;
      for (double cx = -r + shift; cx < size.width + r; cx += r * 2) {
        for (var i = rings; i >= 1; i--) {
          final rr = r * (i / rings);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: rr),
            math.pi, // start: left
            math.pi, // sweep: top half
            false,
            paint,
          );
        }
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(SeigaihaPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.radius != radius ||
      old.rings != rings;
}

/// Faint seigaiha texture layer. Drop it into a [Stack] above a background
/// (image / gradient) and below the content.
class SeigaihaBackground extends StatelessWidget {
  const SeigaihaBackground({
    this.color = Colors.white,
    this.opacity = 0.06,
    this.radius = 46,
    super.key,
  });

  final Color color;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: SeigaihaPainter(
            color: color,
            opacity: opacity,
            radius: radius,
          ),
        ),
      ),
    );
  }
}

/// App-root page background: washi paper colour + one faint, large-scale
/// seigaiha wave. Wrap the whole app with this (via `MaterialApp.builder`)
/// so every route — bare [Scaffold] or [AppScaffold] — shares the identical
/// texture. Distinct in scale/tint from the hero banner's tighter white
/// motif so they never look duplicated.
class BananPageBackground extends StatelessWidget {
  const BananPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.brightness == Brightness.dark
        ? BananColors.darkBg
        : BananColors.cream;
    // Plain peach-cream fill — the seigaiha wave pattern is intentionally
    // omitted now for a calmer, less Japanese-leaning look. Keeping the
    // wrapper widget itself so every page still gets the right backdrop
    // colour even when nested inside a bare Scaffold.
    return ColoredBox(color: bg, child: child);
  }
}

/// A soft "torn washi paper" section divider — a gentle wavy hairline with
/// a faint paper-grain tint, calmer than a hard [Divider].
class WashiDivider extends StatelessWidget {
  const WashiDivider({this.color, this.height = 18, super.key});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BananColors.outline;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WashiPainter(c)),
    );
  }
}

class _WashiPainter extends CustomPainter {
  const _WashiPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final path = Path()..moveTo(0, midY);
    // Gentle low-amplitude sine wave across the width.
    const amp = 3.0;
    final wave = size.width / 18;
    for (double x = 0; x <= size.width; x += 4) {
      path.lineTo(x, midY + amp * math.sin(x / wave));
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.55),
      )
      // Soft echo line for a hand-torn feel.
      ..drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.22),
      );
  }

  @override
  bool shouldRepaint(_WashiPainter old) => old.color != color;
}
