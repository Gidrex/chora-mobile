import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';
import 'tone_section.dart';

/// Month grid options.
class CalendarSection extends StatelessWidget {
  const CalendarSection({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ToneSection(
      title: 'Calendar',
      tone: Tones.of(context).time,
      children: [
        SwitchRow(
          icon: Icons.event_repeat,
          title: 'Show weekly events in the month',
          value: settings.showWeekly,
          onChanged: settings.setShowWeekly,
        ),
        SwitchRow(
          icon: Icons.grid_view,
          title: 'Square day cells',
          value: settings.squareCells,
          onChanged: settings.setSquareCells,
        ),
      ],
    );
  }
}
