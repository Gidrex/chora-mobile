import 'dart:math';

import 'package:flutter/material.dart';

import 'theme_helpers.dart';
import 'sky.dart';

/// App background: soft pastel glows (what glass panels frost), and in
/// dark mode a still field of stars; a glowing moon (dark) or sun (light). Static: it
/// paints once per size/theme, so blurred glass above it stays cheap.
class Starfield extends StatelessWidget {
  const Starfield({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StarsPainter(
          background: theme.colorScheme.surface,
          starColor: theme.colorScheme.onSurface,
          accents: theme.extension<EventPalette>()?.accents ?? const [],
          moon: skyColor(context),
          dark: theme.brightness == Brightness.dark,
        ),
      ),
    );
  }
}

typedef _Star = ({double x, double y, double radius, double alpha});

/// Star layout depends only on the canvas size; computed once per size.
final _starsBySize = <Size, List<_Star>>{};

List<_Star> _stars(Size size) => _starsBySize.putIfAbsent(size, () {
  final random = Random(7);
  final count = (size.width * size.height / 20000).clamp(24, 90).toInt();
  return List.generate(
    count,
    (_) => (
      x: random.nextDouble(),
      y: random.nextDouble(),
      // Small and faint: a star must never read as punctuation next to text.
      radius: 0.5 + random.nextDouble() * 0.7,
      alpha: 0.08 + random.nextDouble() * 0.22,
    ),
  );
});

class _StarsPainter extends CustomPainter {
  _StarsPainter({
    required this.background,
    required this.starColor,
    required this.accents,
    required this.moon,
    required this.dark,
  });

  final Color background;
  final Color starColor;

  /// Pastels for the glows and every fifth star.
  final List<Color> accents;
  final Color moon;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    _paintGlows(canvas, size);
    paintSkyBody(canvas, size, moon, dark: dark);
    if (!dark) return;
    final paint = Paint();
    final stars = _stars(size);
    for (var i = 0; i < stars.length; i++) {
      final star = stars[i];
      final base = i % 5 == 0 && accents.isNotEmpty
          ? accents[i ~/ 5 % accents.length]
          : starColor;
      paint.color = base.withValues(alpha: star.alpha);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  /// Three large soft color pools behind the content.
  void _paintGlows(Canvas canvas, Size size) {
    if (accents.length < 5) return;
    final spots = [
      (Offset(size.width * 0.15, size.height * 0.30), accents[2]),
      (Offset(size.width * 0.90, size.height * 0.55), accents[1]),
      (Offset(size.width * 0.35, size.height * 0.85), accents[4]),
    ];
    final radius = size.shortestSide * 0.7;
    for (final (center, color) in spots) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: dark ? 0.16 : 0.14),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) =>
      old.background != background ||
      old.starColor != starColor ||
      old.moon != moon ||
      old.dark != dark ||
      old.accents != accents;
}
