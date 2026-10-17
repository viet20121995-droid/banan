import 'dart:math' as math;

import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Vietnamese Women's Day (20/10) look — "Anh đào hồng phấn": a blush page,
/// sakura line-art under the top bar of every route, rose action buttons and
/// tags, and a short petal fall when the app opens. Off from 00:00 on
/// 22/10/2026 (Vietnam time); the app is back to its usual colours.
bool get womenDay2010Enabled =>
    DateTime.now().toUtc().isBefore(DateTime.utc(2026, 10, 21, 17));

const womenDay2010TopArt = 'assets/campaigns/women-day-2010-top.png';
const womenDay2010TopArtNarrow =
    'assets/campaigns/women-day-2010-top-narrow.png';

/// The gift-set category: its chip leads the list and is drawn in rose.
const womenDay2010CategorySlug = 'qua-20-10';

abstract final class WomenDay2010Colors {
  static const page = Color(0xFFF8E6E4);
  static const surface = Color(0xFFFFF8F7);
  static const rose = Color(0xFFC4507A);
  static const roseSoft = Color(0xFFFBE0E8);
  static const outline = Color(0xFFEFCFD3);
  static const petal = Color(0xFFF2B4C6);
}

/// [base] recoloured for the campaign. The brand green stays the primary
/// colour (prices, selections, links); only the page, surfaces, borders,
/// main action buttons and tags turn pink.
ThemeData womenDay2010Theme(ThemeData base) {
  const page = WomenDay2010Colors.page;
  const surface = WomenDay2010Colors.surface;
  const rose = WomenDay2010Colors.rose;
  const outline = WomenDay2010Colors.outline;
  final roseUnlessDisabled = WidgetStateProperty.resolveWith<Color?>(
    (s) => s.contains(WidgetState.disabled) ? null : rose,
  );
  final whiteUnlessDisabled = WidgetStateProperty.resolveWith<Color?>(
    (s) => s.contains(WidgetState.disabled) ? null : Colors.white,
  );
  OutlineInputBorder? recolour(InputBorder? b) => b is OutlineInputBorder
      ? b.copyWith(borderSide: b.borderSide.copyWith(color: outline))
      : null;
  final input = base.inputDecorationTheme;
  final cardShape = base.cardTheme.shape;

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(surface: surface),
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: page),
    cardTheme: base.cardTheme.copyWith(
      color: surface,
      shape: cardShape is RoundedRectangleBorder
          ? cardShape.copyWith(side: cardShape.side.copyWith(color: outline))
          : cardShape,
    ),
    inputDecorationTheme: input.copyWith(
      fillColor: surface,
      border: recolour(input.border) ?? input.border,
      enabledBorder: recolour(input.enabledBorder) ?? input.enabledBorder,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: roseUnlessDisabled,
        foregroundColor: whiteUnlessDisabled,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        side: const WidgetStatePropertyAll(BorderSide(color: outline)),
      ),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: rose,
      foregroundColor: Colors.white,
    ),
    dividerTheme: base.dividerTheme.copyWith(color: outline),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: surface,
    ),
    extensions: [
      for (final e in base.extensions.values)
        if (e is! BananAccents) e,
      const BananAccents(alert: rose, tag: rose),
    ],
  );
}

/// Blush page with the sakura art just under the top bar, and the petal fall
/// over everything for its few seconds.
class WomenDay2010Backdrop extends StatelessWidget {
  const WomenDay2010Backdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final narrow = mq.size.width < 700;
    return ColoredBox(
      color: WomenDay2010Colors.page,
      child: Stack(
        children: [
          Positioned(
            top: mq.padding.top + kToolbarHeight,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                narrow ? womenDay2010TopArtNarrow : womenDay2010TopArt,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
              ),
            ),
          ),
          child,
          if (!mq.disableAnimations)
            const Positioned.fill(
              child: IgnorePointer(child: _PetalFall()),
            ),
        ],
      ),
    );
  }
}

/// A dozen petals drift down once when the app opens, then the layer is gone.
class _PetalFall extends StatefulWidget {
  const _PetalFall();

  @override
  State<_PetalFall> createState() => _PetalFallState();
}

class _PetalFallState extends State<_PetalFall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    })
    ..forward();

  static final _petals = List.generate(12, (i) {
    final r = math.Random(2010 + i);
    return (
      x: r.nextDouble(),
      delay: r.nextDouble() * 0.45,
      size: 8 + r.nextDouble() * 7,
      sway: 18 + r.nextDouble() * 30,
      spin: (r.nextDouble() - 0.5) * 8,
      phase: r.nextDouble() * math.pi * 2,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isCompleted) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(painter: _PetalPainter(_c, _petals)),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter(this.t, this.petals) : super(repaint: t);

  final Animation<double> t;
  final List<
      ({
        double x,
        double delay,
        double size,
        double sway,
        double spin,
        double phase
      })> petals;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in petals) {
      final k = ((t.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final y = -20 + k * size.height * 0.85;
      final x = p.x * size.width + math.sin(k * 6 + p.phase) * p.sway;
      final fade = k > 0.75 ? (1 - k) / 0.25 : 1.0;
      paint.color = WomenDay2010Colors.petal.withValues(alpha: 0.85 * fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.phase + k * p.spin)
        ..drawPath(_petal(p.size), paint)
        ..restore();
    }
  }

  /// A notched sakura petal, point down.
  static Path _petal(double s) => Path()
    ..moveTo(0, s)
    ..cubicTo(-s * 0.75, s * 0.45, -s * 0.7, -s * 0.55, -s * 0.22, -s)
    ..lineTo(0, -s * 0.72)
    ..lineTo(s * 0.22, -s)
    ..cubicTo(s * 0.7, -s * 0.55, s * 0.75, s * 0.45, 0, s)
    ..close();

  @override
  bool shouldRepaint(_PetalPainter old) => false;
}

/// A sakura branch across the width, between the home hero and the order
/// options — the hero covers most of the page art, so the season shows here
/// too. Scrolls with the page.
class WomenDay2010Garland extends StatelessWidget
    implements PreferredSizeWidget {
  const WomenDay2010Garland({required this.height, super.key});

  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: const CustomPaint(painter: _GarlandPainter()),
      );
}

class _GarlandPainter extends CustomPainter {
  const _GarlandPainter();

  static const _branch = Color(0x8C9C6E68);
  static const _petal = Color(0xF2F4B8C9);
  static const _petalLight = Color(0xF2FAD6E0);
  static const _core = Color(0xFFE27094);
  static const _stamen = Color(0xFFBE506E);

  double _y(double x, Size s) =>
      s.height * 0.42 + s.height * 0.16 * math.sin(x / 190 * math.pi);

  @override
  void paint(Canvas canvas, Size size) {
    final branch = Path()..moveTo(-10, _y(-10, size));
    for (var x = -10.0; x <= size.width + 10; x += 6) {
      branch.lineTo(x, _y(x, size));
    }
    canvas.drawPath(
      branch,
      Paint()
        ..color = _branch
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final r = math.Random(2010);
    final step = size.width < 700 ? 74.0 : 96.0;
    final radius = size.height * 0.27;
    var i = 0;
    for (var x = 18.0; x < size.width; x += step * (0.8 + r.nextDouble() * 0.4)) {
      final y = _y(x, size) + (r.nextDouble() - 0.5) * size.height * 0.18;
      if (i % 4 == 3) {
        // a hanging bud on a short twig
        final end = Offset(x + 8, y + size.height * 0.28);
        canvas
          ..drawLine(
            Offset(x, _y(x, size)),
            end,
            Paint()
              ..color = _branch
              ..strokeWidth = 1.2,
          )
          ..save()
          ..translate(end.dx, end.dy)
          ..drawPath(_PetalPainter._petal(radius * 0.42), Paint()..color = _core)
          ..restore();
      } else {
        _blossom(
          canvas,
          Offset(x, y),
          radius * (0.8 + r.nextDouble() * 0.35),
          r.nextDouble() * math.pi,
          light: i.isOdd,
        );
      }
      i++;
    }
  }

  void _blossom(Canvas c, Offset at, double r, double rot, {bool light = false}) {
    final petal = Paint()..color = light ? _petalLight : _petal;
    // _PetalPainter._petal points down from its centre; push it out from
    // the flower centre so five of them form the bloom.
    final shape = _PetalPainter._petal(r * 0.5);
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(rot);
    for (var k = 0; k < 5; k++) {
      c
        ..save()
        ..rotate(k * 2 * math.pi / 5)
        ..translate(0, -r * 0.5)
        ..rotate(math.pi)
        ..drawPath(shape, petal)
        ..restore();
    }
    final stamen = Paint()
      ..color = _stamen
      ..strokeWidth = 0.8;
    for (var k = 0; k < 6; k++) {
      final a = k * 2 * math.pi / 6 + 0.3;
      final tip = Offset(math.cos(a) * r * 0.42, math.sin(a) * r * 0.42);
      c
        ..drawLine(Offset.zero, tip, stamen)
        ..drawCircle(tip, r * 0.05, stamen);
    }
    c
      ..drawCircle(Offset.zero, r * 0.2, Paint()..color = _core)
      ..restore();
  }

  @override
  bool shouldRepaint(_GarlandPainter old) => false;
}
