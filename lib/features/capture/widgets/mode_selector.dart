import 'package:flutter/material.dart';

import '../capture_controller.dart';

/// Note | Event | Agent switch.
class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.mode, required this.onChanged});

  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CaptureMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: CaptureMode.note,
          icon: Icon(Icons.description_outlined),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('Note')),
          tooltip: 'Append to a note',
        ),
        ButtonSegment(
          value: CaptureMode.event,
          icon: Icon(Icons.event_outlined),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('Event')),
          tooltip: 'Add to the calendar',
        ),
        ButtonSegment(
          value: CaptureMode.agent,
          icon: Icon(Icons.smart_toy_outlined),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('Agent')),
          tooltip: 'Send a task to the agent inbox',
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
