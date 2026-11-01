import 'package:flutter/material.dart';

import '../../../domain/dates.dart';
import '../../../domain/events_view.dart';

/// Preset duration chips plus a free-form field ("1h 15m", "90").
class DurationField extends StatelessWidget {
  const DurationField({
    super.key,
    required this.seconds,
    required this.custom,
    required this.onPreset,
    required this.onCustom,
  });

  /// Current valid duration, null while the custom text is invalid.
  final int? seconds;
  final TextEditingController custom;
  final ValueChanged<int> onPreset;
  final ValueChanged<String> onCustom;

  @override
  Widget build(BuildContext context) {
    final invalid = custom.text.trim().isNotEmpty && seconds == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in durationPresets)
              ChoiceChip(
                label: Text(formatDuration(preset)),
                selected: custom.text.trim().isEmpty && seconds == preset,
                onSelected: (_) => onPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: custom,
          onChanged: onCustom,
          decoration: InputDecoration(
            labelText: 'Custom duration',
            hintText: 'e.g. 1h 15m',
            helperText: seconds != null && custom.text.trim().isNotEmpty
                ? formatDuration(seconds!)
                : null,
            errorText: invalid ? 'Use minutes, 1h 15m or 1:15' : null,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
