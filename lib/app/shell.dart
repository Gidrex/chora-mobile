import 'dart:async';

import 'package:flutter/material.dart';

import '../features/capture/capture_screen.dart';
import '../features/events/events_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/settings/settings_screen.dart';
import '../ui/glass.dart';
import '../ui/sky.dart';
import '../ui/starfield.dart';
import 'app_scope.dart';

/// The four tabs. Tabs keep their state (IndexedStack), so switching makes
/// no bridge calls. Back on any tab but Capture returns to Capture.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  static const _tabs = [
    (Icons.edit_note_outlined, Icons.edit_note, 'Capture'),
    (Icons.description_outlined, Icons.description, 'Notes'),
    (Icons.event_outlined, Icons.event, 'Events'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: baseline the change stamp, plan reminders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = AppScope.of(context);
      services.reminders.start();
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final services = AppScope.of(context);
    switch (state) {
      case AppLifecycleState.paused:
        services.lock.paused();
      case AppLifecycleState.resumed:
        services.lock.resumed();
        unawaited(_refresh());
      case _:
    }
  }

  /// Pick up files changed by sync while the app was away.
  Future<void> _refresh() async {
    try {
      await AppScope.of(context).session.refreshIfChanged();
    } on Exception catch (e) {
      // Screens surface storage errors on their next load.
      debugPrint('storage check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      // One shared backdrop sample for every glass panel on screen.
      child: BackdropGroup(
        child: Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              const Positioned.fill(child: Starfield()),
              IndexedStack(
                index: _tab,
                children: const [
                  CaptureScreen(),
                  NotesScreen(),
                  EventsScreen(),
                  SettingsScreen(),
                ],
              ),
              const Positioned.fill(child: SkyLight()),
            ],
          ),
          bottomNavigationBar: GlassCard(
            radius: 28,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _tab,
              onDestinationSelected: (i) {
                // Feedback belongs to the tab that produced it.
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() => _tab = i);
              },
              destinations: [
                for (final (icon, selected, label) in _tabs)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
