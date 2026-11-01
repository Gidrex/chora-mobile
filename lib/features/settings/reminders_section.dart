import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../domain/reminders.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';
import 'tone_section.dart';

const _minuteChoices = [0, 5, 10, 15, 30, 60];

/// Event notifications and the optional system alarm.
class RemindersSection extends StatelessWidget {
  const RemindersSection({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final alarm = settings.autoAlarm;
    return ToneSection(
      title: 'Reminders',
      tone: Tones.of(context).duration,
      children: [
        SwitchRow(
          icon: Icons.notifications_outlined,
          title: 'Notify before events',
          value: settings.remindersEnabled,
          onChanged: settings.setRemindersEnabled,
        ),
        _MinuteChips(
          label: 'Notify',
          value: settings.reminderMinutes,
          enabled: settings.remindersEnabled,
          onChanged: settings.setReminderMinutes,
        ),
        SwitchRow(
          icon: Icons.alarm,
          title: 'Set a system alarm',
          value: alarm,
          onChanged: settings.setAutoAlarm,
        ),
        RadioGroup<AlarmMode>(
          groupValue: settings.alarmMode,
          onChanged: (v) {
            if (alarm && v != null) unawaited(settings.setAlarmMode(v));
          },
          child: Column(
            children: [
              for (final mode in AlarmMode.values)
                RadioListTile<AlarmMode>(
                  value: mode,
                  enabled: alarm,
                  title: Text(mode.label),
                ),
            ],
          ),
        ),
        _MinuteChips(
          label: 'Ring',
          value: settings.alarmMinutes,
          enabled: alarm,
          onChanged: settings.setAlarmMinutes,
        ),
      ],
    );
  }
}

/// "At start" / "N min before" choice chips.
class _MinuteChips extends StatelessWidget {
  const _MinuteChips({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Tones.of(context).muted),
          ),
          for (final m in _minuteChoices)
            ChoiceChip(
              label: Text(m == 0 ? 'At start' : '$m min before'),
              selected: value == m,
              onSelected: enabled ? (_) => onChanged(m) : null,
            ),
        ],
      ),
    );
  }
}
