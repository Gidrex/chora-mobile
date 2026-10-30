import 'package:flutter/material.dart';

import '../capture_controller.dart';
import 'capture_event_form.dart';
import 'priority_segmented.dart';

/// Event pickers (event mode) or the priority selector (note mode).
class EventSection extends StatelessWidget {
  const EventSection({
    super.key,
    required this.controller,
    required this.durationManual,
    required this.onPickDate,
    required this.onDurationSet,
  });

  final CaptureController controller;
  final TextEditingController durationManual;
  final VoidCallback onPickDate;
  final ValueChanged<String> onDurationSet;

  @override
  Widget build(BuildContext context) {
    if (!controller.asEvent) {
      return PrioritySegmented(
        priority: controller.priority,
        onChanged: controller.setPriority,
      );
    }
    return CaptureEventForm(
      dateLabel: controller.eventDateLabel,
      timeLabel: controller.timeLabel,
      onPrevDay: () => controller.setEventDate(
        controller.eventDate.subtract(const Duration(days: 1)),
      ),
      onNextDay: () => controller.setEventDate(
        controller.eventDate.add(const Duration(days: 1)),
      ),
      onPickDate: onPickDate,
      onStepTime: controller.stepEventTime,
      duration: controller.duration,
      durationManual: durationManual,
      onDurationChanged: onDurationSet,
      onDurationManualChanged: controller.setDurationManual,
      prioritySelector: PrioritySegmented(
        priority: controller.priority,
        onChanged: controller.setPriority,
      ),
    );
  }
}
