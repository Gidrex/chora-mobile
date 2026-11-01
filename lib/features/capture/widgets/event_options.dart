import 'package:flutter/material.dart';

import '../../../domain/dates.dart';
import '../capture_controller.dart';
import '../../../ui/tones.dart';

/// Date, start time, duration and weekly switch for Event mode.
class EventOptions extends StatelessWidget {
  const EventOptions({
    super.key,
    required this.controller,
    required this.customDuration,
    required this.onPickDate,
    required this.onPickTime,
  });

  final CaptureController controller;
  final TextEditingController customDuration;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final c = controller;
    final time = loc.formatTimeOfDay(
      TimeOfDay(hour: c.startMin ~/ 60, minute: c.startMin % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stepper(
          label: loc.formatMediumDate(c.eventDate),
          icon: Icons.calendar_today_outlined,
          tooltip: 'Pick date',
          onTap: onPickDate,
          back: ('Previous day', () => c.shiftDay(-1)),
          forward: ('Next day', () => c.shiftDay(1)),
        ),
        const SizedBox(height: 8),
        _Stepper(
          label: time,
          tone: Tones.of(context).time,
          icon: Icons.schedule,
          tooltip: 'Pick start time',
          onTap: onPickTime,
          back: ('15 minutes earlier', () => c.stepTime(forward: false)),
          forward: ('15 minutes later', () => c.stepTime(forward: true)),
        ),
        const SizedBox(height: 16),
        Text('Duration', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _DurationChips(controller: c, customDuration: customDuration),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repeats weekly'),
          subtitle: Text(
            'Every ${loc.formatFullDate(c.eventDate).split(',').first}',
            style: TextStyle(color: Tones.of(context).weekly),
          ),
          value: c.weekly,
          onChanged: c.setWeekly,
        ),
      ],
    );
  }
}

/// `‹ [label] ›` row: arrows step, the middle button opens a picker.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    this.tone,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.back,
    required this.forward,
  });

  final String label;

  /// Text/icon color of the middle button; null keeps the theme's.
  final Color? tone;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final (String, VoidCallback) back;
  final (String, VoidCallback) forward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: back.$1,
          onPressed: back.$2,
        ),
        Expanded(
          child: Tooltip(
            message: tooltip,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(foregroundColor: tone),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: forward.$1,
          onPressed: forward.$2,
        ),
      ],
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({
    required this.controller,
    required this.customDuration,
  });

  final CaptureController controller;
  final TextEditingController customDuration;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final duration = Tones.of(context).duration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final secs in durationPresets)
              ChoiceChip(
                label: Text(formatDuration(secs)),
                labelStyle: TextStyle(
                  color: c.presetDuration == secs ? duration : null,
                ),
                selectedColor: duration.withValues(alpha: 0.2),
                selected: c.presetDuration == secs,
                onSelected: (_) => c.setPresetDuration(secs),
              ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: c.presetDuration == null,
              onSelected: (_) => c.setPresetDuration(null),
            ),
          ],
        ),
        if (c.presetDuration == null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customDuration,
            decoration: InputDecoration(
              labelText: 'Custom duration',
              hintText: '1h 30m',
              errorText: c.durationError,
            ),
            onChanged: c.setCustomDuration,
          ),
        ],
      ],
    );
  }
}
