import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../events_controller.dart';
import 'event_form.dart';

/// Open the form and handle its outcome: delete with Undo, stale reloads.
Future<void> openEventForm(
  BuildContext context,
  EventsController controller, {
  required DateTime date,
  EventDto? original,
  bool weekly = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text, {SnackBarAction? action}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
  final outcome = await Navigator.of(context).push<FormOutcome>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventFormPage(
        controller: controller,
        date: date,
        original: original,
        weekly: weekly,
      ),
    ),
  );
  switch (outcome) {
    case FormOutcome.stale:
      say(EventsController.changedMessage);
    case FormOutcome.deleteRequested when original != null:
      final error = await controller.delete(original);
      if (error != null) return say(error);
      say(
        'Event deleted',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            controller.save(updated: original).then((e) {
              if (e != null) say(e);
            }),
          ),
        ),
      );
    case _:
  }
}
