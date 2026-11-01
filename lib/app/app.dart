import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../features/lock/lock_screen.dart';
import '../ui/app_zoom.dart';
import '../ui/theme.dart';
import 'app_scope.dart';
import 'services.dart';
import 'shell.dart';

/// Root widget. Rebuilds [MaterialApp] only on appearance changes.
class ChoraApp extends StatelessWidget {
  const ChoraApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final appearance = services.settings.appearance;
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: appearance,
        builder: (_, _) => DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            ThemeData themed(ColorScheme? dynamic, Brightness b) => buildTheme(
              preset: appearance.themePreset.name,
              brightness: b,
              fontName: appearance.fontChoice.family,
              dynamicScheme: dynamic,
            );
            return MaterialApp(
              title: 'Chora',
              debugShowCheckedModeBanner: false,
              theme: themed(lightDynamic, Brightness.light),
              darkTheme: themed(darkDynamic, Brightness.dark),
              themeMode: appearance.themeMode,
              builder: (_, child) => AppZoom(
                textScale: appearance.textScale,
                uiScale: appearance.uiScale,
                child: child ?? const SizedBox.shrink(),
              ),
              home: const _LockGate(),
            );
          },
        ),
      ),
    );
  }
}

/// Whole-app lock for the "Everything" threshold.
class _LockGate extends StatelessWidget {
  const _LockGate();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.lock, services.settings]),
      builder: (_, _) =>
          services.lock.appLocked ? const LockScreen() : const HomeShell(),
    );
  }
}
