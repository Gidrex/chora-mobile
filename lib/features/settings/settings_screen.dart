import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';
import 'appearance_section.dart';
import 'calendar_section.dart';
import 'reminders_section.dart';
import 'security_section.dart';
import 'snack.dart';
import 'storage_section.dart';
import 'tone_section.dart';

/// All preferences in one scrollable list of sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (_, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const AppearanceSection(),
            CalendarSection(settings: settings),
            RemindersSection(settings: settings),
            const SecuritySection(),
            const StorageSection(),
            if (kDebugMode) const _DemoSection(),
          ],
        ),
      ),
    );
  }
}

/// Sample notes and events for an empty storage (debug builds only).
class _DemoSection extends StatelessWidget {
  const _DemoSection();

  Future<void> _seed(BuildContext context) async {
    final seeded = await AppScope.of(context).storage.seedDemo();
    if (!context.mounted) return;
    showSnack(
      context,
      seeded ? 'Demo data added' : 'Storage already has notes',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToneSection(
      title: 'Developer',
      tone: Tones.of(context).muted,
      children: [
        EvenRow(
          icon: Icons.science_outlined,
          title: 'Load demo data',
          onTap: () => _seed(context),
        ),
      ],
    );
  }
}
