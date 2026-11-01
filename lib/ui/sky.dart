import 'dart:math';

import 'package:flutter/material.dart';

import 'tones.dart';

/// Where the moon (dark) or sun (light) hangs: top right, below the app bar.
Offset skyAnchor(Size size) => Offset(size.width * 0.84, size.height * 0.17);

/// Moon or sun color, from the theme's section tone made luminous.
Color skyColor(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final hsl = HSLColor.fromColor(Tones.of(context).section);
  // Greys (mono preset) stay grey; colored presets get a glowing hue.
  final saturation = hsl.saturation < 0.1
      ? hsl.saturation
      : (dark ? min(hsl.saturation, 0.55) : max(hsl.saturation, 0.85));
  return hsl
      .withSaturation(saturation)
      .withLightness(dark ? 0.86 : 0.62)
      .toColor();
}

/// Glowing round moon, or a sun with rays, plus its halo. Background layer.
void paintSkyBody(Canvas canvas, Size size, Color color, {required bool dark}) {
  final c = skyAnchor(size);
  const r = 18.0;
  final halo = Rect.fromCircle(center: c, radius: r * 5);
  canvas.drawCircle(
    c,
    halo.width / 2,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        stops: const [0.15, 1],
      ).createShader(halo),
  );
  if (!dark) {
    final ray = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final dir = Offset.fromDirection(i * pi / 4);
      canvas.drawLine(c + dir * (r + 6), c + dir * (r + 13), ray);
    }
  }
  final hsl = HSLColor.fromColor(color);
  final core = hsl.withLightness(min(1, hsl.lightness + 0.1)).toColor();
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [core, color],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
  );
}

/// The moon/sun light falling over the content. Paint-only, ignores touches.
class SkyLight extends StatelessWidget {
  const SkyLight({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LightPainter(skyColor(context), dark: dark),
        ),
      ),
    );
  }
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.color, {required this.dark});

  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: skyAnchor(size),
      radius: size.shortestSide * 0.95,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        // Screen brightens what is under it, like light on a surface.
        ..blendMode = dark ? BlendMode.screen : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: dark ? 0.16 : 0.10),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LightPainter old) =>
      old.color != color || old.dark != dark;
}
