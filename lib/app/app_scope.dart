import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/capture_repository.dart';
import '../data/events_repository.dart';
import '../data/notes_repository.dart';

/// Inherited hand-out for repositories and controllers (T2.2+).
/// Today it carries [AppState]; screens keep constructor injection until
/// the shell migration (T2.6) removes the cross-widget `GlobalKey` calls.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.state,
    required this.notes,
    required this.capture,
    required this.events,
    required super.child,
  });

  final AppState state;
  final NotesRepository notes;
  final CaptureRepository capture;
  final EventsRepository events;

  static AppState of(BuildContext context) => scopeOf(context).state;
  static NotesRepository notesOf(BuildContext context) =>
      scopeOf(context).notes;

  static CaptureRepository captureOf(BuildContext context) =>
      scopeOf(context).capture;

  static EventsRepository eventsOf(BuildContext context) =>
      scopeOf(context).events;

  static AppScope scopeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}
