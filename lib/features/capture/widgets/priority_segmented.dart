import 'package:flutter/material.dart';

import '../../../data/models.dart';

/// Capture priority selector shared by note and event modes.
class PrioritySegmented extends StatelessWidget {
  const PrioritySegmented({
    super.key,
    required this.priority,
    required this.onChanged,
  });

  final Priority priority;
  final ValueChanged<Priority> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<Priority>(
        segments: const [
          ButtonSegment(value: Priority.low, label: Text('Low')),
          ButtonSegment(value: Priority.medium, label: Text('Med')),
          ButtonSegment(value: Priority.high, label: Text('High')),
          ButtonSegment(value: Priority.urgent, label: Text('! Urgent')),
        ],
        selected: {priority},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
