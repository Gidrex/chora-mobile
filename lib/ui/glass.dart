import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Frosted glass panels (reference: soft translucent cards over colored
/// glows). The fill and edge come from the theme, so every preset gets its
/// own tint. Blur samples the backdrop once per `BackdropGroup` (the shell
/// provides one), which keeps many panels cheap.
BoxDecoration glassDecoration(BuildContext context, {double radius = 24}) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final tint = dark
      ? scheme.surfaceContainerHigh
      : scheme.surfaceContainerLowest;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    // Lit from the top left, thinner toward the bottom right.
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tint.withValues(alpha: dark ? 0.62 : 0.72),
        tint.withValues(alpha: dark ? 0.38 : 0.50),
      ],
    ),
    border: Border.all(
      color: scheme.onSurface.withValues(alpha: dark ? 0.10 : 0.08),
    ),
    boxShadow: [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.35 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// A rounded frosted-glass block: blurred backdrop + [glassDecoration].
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        // Shadow outside the clip; fill and edge drawn above the blur.
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: glassDecoration(context, radius: radius).boxShadow,
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: glassDecoration(
                context,
                radius: radius,
              ).copyWith(boxShadow: const []),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
