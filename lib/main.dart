import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'auth.dart';
import 'app/app_scope.dart';
import 'backend.dart';
import 'platform/notifications.dart';
import 'screens/capture.dart';
import 'screens/events.dart';
import 'screens/notes.dart';
import 'screens/settings.dart';
import 'stars.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled (assets/fonts); never fetch at runtime (T0.2).
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  try {
    await Backend.init(state.rootDirOverride);
    await Reminders.init();
    await Reminders.rescheduleUpcoming(
      enabled: state.notifEnabled,
      minutesBefore: state.notifMinutes,
    );
  } catch (e) {
    runApp(_BootError(state: state, message: Backend.errMsg(e)));
    return;
  }
  runApp(ChoraApp(state: state));
}

class _BootError extends StatelessWidget {
  const _BootError({required this.state, required this.message});

  final AppState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Storage init failed'),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await state.setRootDir(null);
                    await main();
                  },
                  child: const Text('Reset path and retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChoraApp extends StatefulWidget {
  const ChoraApp({super.key, required this.state});

  final AppState state;

  @override
  State<ChoraApp> createState() => _ChoraAppState();
}

class _ChoraAppState extends State<ChoraApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (_, _) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          ThemeData themed(ColorScheme? scheme, Brightness brightness) =>
              buildTheme(
                preset: widget.state.themePreset,
                brightness: brightness,
                fontName: widget.state.fontName,
                dynamicScheme: scheme,
              );
          return MaterialApp(
            title: 'Chora',
            theme: themed(lightDynamic, Brightness.light),
            darkTheme: themed(darkDynamic, Brightness.dark),
            themeMode: widget.state.themeMode,
            home: AppScope(
              state: widget.state,
              child: _Gate(state: widget.state),
            ),
          );
        },
      ),
    );
  }
}

/// Whole-app PIN/biometric gate for the `open` threshold.
class _Gate extends StatefulWidget {
  const _Gate({required this.state});

  final AppState state;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  @override
  Widget build(BuildContext context) {
    if (widget.state.securityThreshold == 'open' && !widget.state.appUnlocked) {
      return LockScreen(
        state: widget.state,
        onUnlocked: () => setState(() => widget.state.appUnlocked = true),
      );
    }
    return MainScaffold(state: widget.state);
  }
}

/// PageView on 4 screens + floating pill bar. Always starts at Capture.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.state});

  final AppState state;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _pages = PageController(initialPage: 0);
  int _index = 0;

  final _captureKey = GlobalKey<CaptureScreenState>();
  final _notesKey = GlobalKey<NotesScreenState>();
  final _eventsKey = GlobalKey<EventsScreenState>();
  final _settingsKey = GlobalKey<SettingsScreenState>();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPage(int index) {
    setState(() => _index = index);
    switch (index) {
      case 0:
        unawaited(_captureKey.currentState?.refresh());
      case 1:
        unawaited(_notesKey.currentState?.reload());
      case 2:
        unawaited(_eventsKey.currentState?.reload());
      case 3:
        _settingsKey.currentState?.setState(() {});
    }
  }

  Future<void> _reinitBackend() async {
    await Backend.init(widget.state.rootDirOverride);
    if (!mounted) return;
    unawaited(_captureKey.currentState?.refresh());
    unawaited(_notesKey.currentState?.reload());
    unawaited(_eventsKey.currentState?.reload());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Starfield()),
          PageView(
            controller: _pages,
            onPageChanged: _onPage,
            children: [
              CaptureScreen(
                key: _captureKey,
                state: widget.state,
                onSaved: () {
                  unawaited(_notesKey.currentState?.reload());
                  unawaited(_eventsKey.currentState?.reload());
                },
              ),
              NotesScreen(key: _notesKey, state: widget.state),
              EventsScreen(key: _eventsKey, state: widget.state),
              SettingsScreen(
                key: _settingsKey,
                state: widget.state,
                onRootChanged: _reinitBackend,
                onAppearanceChanged: () => setState(() {}),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _item(0, Icons.inbox_outlined, Icons.inbox, 'Capture'),
                _item(1, Icons.notes_outlined, Icons.notes, 'Notes'),
                _item(2, Icons.event_outlined, Icons.event, 'Events'),
                _item(3, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData active, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _index == index;
    return InkWell(
      onTap: () => _go(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? active : icon,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
