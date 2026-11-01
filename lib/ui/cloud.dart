import 'dart:math';

import 'package:flutter/material.dart';

import 'tones.dart';

/// Flat, fluffy 2D cloud drawn in code. Its center sits on the bottom edge
/// of the box, so only the upper half shows (the rest is "below the
/// screen"). Colors come from the theme; static, so it costs one paint.
class CloudArt extends StatelessWidget {
  const CloudArt({super.key, this.height = 120});

  /// Visible height (the top half of the cloud).
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(painter: _CloudPainter(CloudColors.of(context))),
          ),
        ),
      ),
    );
  }
}

/// Body, inner light layer and sparkles, derived from the theme.
@immutable
class CloudColors {
  const CloudColors({
    required this.body,
    required this.light,
    required this.spark,
    required this.spark2,
  });

  factory CloudColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = Tones.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    const mix = Color.lerp;
    final body = dark
        ? mix(scheme.surfaceContainerHighest, scheme.primary, 0.30)!
        : mix(scheme.surfaceContainerLowest, scheme.primary, 0.14)!;
    return CloudColors(
      body: body,
      light: dark
          ? mix(body, scheme.onSurface, 0.22)!
          : scheme.surfaceContainerLowest,
      spark: tones.section,
      spark2: tones.heading,
    );
  }

  final Color body;
  final Color light;
  final Color spark;
  final Color spark2;

  @override
  bool operator ==(Object other) =>
      other is CloudColors &&
      other.body == body &&
      other.light == light &&
      other.spark == spark &&
      other.spark2 == spark2;

  @override
  int get hashCode => Object.hash(body, light, spark, spark2);
}

/// Bump radii along the top arc, left to right (relative to cloud height):
/// uneven on purpose, so the edge reads as fluffy, not as a scallop pattern.
const _bumps = [0.34, 0.46, 0.40, 0.58, 0.50, 0.62, 0.44, 0.52, 0.36, 0.30];

class _CloudPainter extends CustomPainter {
  _CloudPainter(this.colors);

  final CloudColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Whole cloud: nearly as wide as the box, twice the visible height,
    // centered on the bottom edge.
    final cloud = Rect.fromCenter(
      center: Offset(size.width / 2, size.height),
      width: size.width * 0.96,
      height: size.height * 2 * 0.9,
    );
    // A soft edge makes the outline look fluffy instead of cut out.
    canvas.drawPath(
      _fluff(cloud, 1),
      Paint()
        ..color = colors.body
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    final inner = Rect.fromCenter(
      center: cloud.center + Offset(-cloud.width * 0.04, cloud.height * 0.06),
      width: cloud.width * 0.80,
      height: cloud.height * 0.80,
    );
    canvas.drawPath(
      _fluff(inner, 0.85),
      Paint()..color = colors.light.withValues(alpha: 0.55),
    );
    _sparkle(
      canvas,
      Offset(size.width * 0.18, size.height * 0.28),
      5,
      colors.spark,
    );
    _sparkle(
      canvas,
      Offset(size.width * 0.84, size.height * 0.18),
      4,
      colors.spark2,
    );
  }

  /// Ellipse body plus [_bumps] circles riding its upper arc.
  Path _fluff(Rect r, double scale) {
    var path = Path()..addOval(r);
    final a = r.width / 2;
    final b = r.height / 2;
    for (var i = 0; i < _bumps.length; i++) {
      // Spread from ~170° to ~10° over the top half of the ellipse.
      final angle = pi * (0.94 - 0.88 * i / (_bumps.length - 1));
      final center = r.center + Offset(a * cos(angle), -b * sin(angle) * 0.92);
      final radius = _bumps[i] * b * 0.62 * scale;
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    return path;
  }

  /// Four-point star.
  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final star = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
    canvas.drawPath(star, Paint()..color = color.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.colors != colors;
}
