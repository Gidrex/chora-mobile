import 'package:flutter/foundation.dart';

import '../backend.dart';
import 'notes_repository.dart';

/// Capture over the bridge. Draft ownership lives in the controller;
/// this repository only calls the bridge and bumps [revision] on submit.
class CaptureRepository {
  ValueListenable<int> get revision => _revision;
  final _revision = ValueNotifier<int>(0);

  Future<List<ProjectDto>> projects() async {
    try {
      return await listAllProjects(rootDir: Backend.root);
    } catch (e) {
      throw NotesFailure(Backend.errMsg(e));
    }
  }

  /// Route one capture; returns the human-relative target path.
  Future<String> submit({
    required String title,
    required String body,
    required String? targetNotePath,
    required String? targetHeader,
    required bool delegateToAgent,
    required bool createAsEvent,
    required String? eventDateIso,
    required String? eventTimeHhmm,
    required String? eventDuration,
    required Priority priority,
  }) async {
    try {
      return await submitCapture(
        req: CaptureRequest(
          rootDir: Backend.root,
          title: title,
          body: body,
          targetNotePath: targetNotePath,
          targetHeader: targetHeader,
          delegateToAgent: delegateToAgent,
          createAsEvent: createAsEvent,
          eventDateIso: eventDateIso,
          eventTimeHhmm: eventTimeHhmm,
          eventDuration: eventDuration,
          priority: priority,
        ),
      );
    } catch (e) {
      throw NotesFailure(Backend.errMsg(e));
    }
  }

  void bump() {
    _revision.value++;
  }
}
