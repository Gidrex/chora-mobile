import 'package:flutter/material.dart';

import '../../../ui/theme_helpers.dart';

/// Date/time/duration/priority pickers for Capture's "Record as Event" mode.
/// Pure UI: the screen owns the state and passes labels + callbacks.
class CaptureEventForm extends StatelessWidget {
  const CaptureEventForm({
    super.key,
    required this.dateLabel,
    required this.timeLabel,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onStepTime,
    required this.duration,
    required this.durationManual,
    required this.onDurationChanged,
    required this.onDurationManualChanged,
    required this.prioritySelector,
  });

  final String dateLabel;
  final String timeLabel;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;

  /// Step the time by 15 minutes; [forward] picks the direction.
  final ValueChanged<bool> onStepTime;
  final String duration;
  final TextEditingController durationManual;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<String> onDurationManualChanged;

  /// Priority control owned by the screen (shared with note mode).
  final Widget prioritySelector;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevDay,
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: onPickDate,
                child: Text('Date: $dateLabel', style: mono(context)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextDay,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => onStepTime(false),
              child: const Text('-15m'),
            ),
            Expanded(
              child: Center(
                child: Text('Time: $timeLabel', style: mono(context, size: 14)),
              ),
            ),
            OutlinedButton(
              onPressed: () => onStepTime(true),
              child: const Text('+15m'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final d in ['15m', '30m', '45m', '1h', '2h'])
              ChoiceChip(
                label: Text(d, style: mono(context)),
                selected: duration == d,
                onSelected: (_) => onDurationChanged(d),
              ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: durationManual,
                style: mono(context),
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  isDense: true,
                ),
                onChanged: onDurationManualChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        prioritySelector,
      ],
    );
  }
}
