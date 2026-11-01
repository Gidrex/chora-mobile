import 'package:flutter/material.dart';

/// Applies the user's text size and whole-UI zoom below [MaterialApp].
/// Zoom lays the app out on a smaller (or larger) logical screen and scales
/// it to fit, so layout, icons, hit targets and text grow together.
class AppZoom extends StatelessWidget {
  const AppZoom({
    super.key,
    required this.textScale,
    required this.uiScale,
    required this.child,
  });

  final double textScale;
  final double uiScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final text = TextScaler.linear(mq.textScaler.scale(1) * textScale);
    if (uiScale == 1) {
      return MediaQuery(
        data: mq.copyWith(textScaler: text),
        child: child,
      );
    }
    final size = mq.size / uiScale;
    EdgeInsets shrink(EdgeInsets e) => e / uiScale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            textScaler: text,
            padding: shrink(mq.padding),
            viewPadding: shrink(mq.viewPadding),
            viewInsets: shrink(mq.viewInsets),
            systemGestureInsets: shrink(mq.systemGestureInsets),
            devicePixelRatio: mq.devicePixelRatio * uiScale,
          ),
          child: child,
        ),
      ),
    );
  }
}
