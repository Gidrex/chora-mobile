import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/tones.dart';

/// Agent task priority as wrapping chips (fits 320 dp at large text).
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.priority,
    required this.onChanged,
  });

  final Priority priority;
  final ValueChanged<Priority> onChanged;

  static const _options = [
    (Priority.low, Icons.arrow_downward, 'Low'),
    (Priority.medium, Icons.remove, 'Medium'),
    (Priority.high, Icons.arrow_upward, 'High'),
    (Priority.urgent, Icons.priority_high, 'Urgent'),
  ];

  /// Calm to loud: mint, sky, peach, error.
  static Color toneOf(BuildContext context, Priority p) {
    final tones = Tones.of(context);
    return switch (p) {
      Priority.low => tones.time,
      Priority.medium => tones.file,
      Priority.high => tones.duration,
      Priority.urgent => Theme.of(context).colorScheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, icon, label) in _options)
              ChoiceChip(
                avatar: Icon(icon, color: toneOf(context, value)),
                showCheckmark: false,
                label: Text(label),
                labelStyle: TextStyle(color: toneOf(context, value)),
                selectedColor: toneOf(context, value).withValues(alpha: 0.2),
                selected: priority == value,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}
