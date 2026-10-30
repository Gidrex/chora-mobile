import 'package:chora_mobile/app/app_scope.dart';
import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/capture_repository.dart';
import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AppScope hands out the app state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    SettingsStore? found;
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          state: state,
          notes: BridgeNotesRepository(),
          capture: CaptureRepository(),
          events: BridgeEventsRepository(),
          child: Builder(
            builder: (context) {
              found = AppScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(found, same(state));
  });

  test('models re-export the DTO types', () {
    expect(Priority.values, contains(Priority.medium));
    expect(SecurityLevel.values, contains(SecurityLevel.open));
  });
}
