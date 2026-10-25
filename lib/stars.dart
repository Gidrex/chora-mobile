import 'dart:math';

import 'package:flutter/material.dart';

/// Subtle twinkling starfield behind the app (ambience reference).
/// Paints the surface background plus dim stars in dark mode only.
class Starfield extends StatefulWidget {
  const Starfield({super.key});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _StarsPainter(
        twinkle: _twinkle,
        background: scheme.surface,
        starColor: scheme.onSurface,
        visible: dark,
      ),
    );
  }
}

class _Star {
  _Star(this.x, this.y, this.radius, this.alpha, this.phase);

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double phase;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({
    required this.twinkle,
    required this.background,
    required this.starColor,
    required this.visible,
  }) : super(repaint: twinkle);

  final Animation<double> twinkle;
  final Color background;
  final Color starColor;
  final bool visible;

  List<_Star> _stars(Size size) {
    final random = Random(7);
    final count = (size.width * size.height / 12000).clamp(40, 160).toInt();
    return List.generate(count, (_) {
      return _Star(
        random.nextDouble(),
        random.nextDouble(),
        0.6 + random.nextDouble() * 1.1,
        0.12 + random.nextDouble() * 0.4,
        random.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (!visible) return;
    final glow = 0.7 + 0.3 * sin(twinkle.value * 2 * pi);
    for (final star in _stars(size)) {
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        Paint()..color = starColor.withValues(alpha: star.alpha * glow),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) =>
      old.background != background ||
      old.starColor != starColor ||
      old.visible != visible;
}
