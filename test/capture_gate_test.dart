import 'dart:io';

import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/app/app_scope.dart';
import 'package:chora_mobile/data/capture_repository.dart';
import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/features/capture/capture_screen.dart';
import 'package:chora_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_backend.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final root = await initTestBackend();
    await seedVault(root);
  });

  testWidgets('gated file hides headers until unlocked', (tester) async {
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    await state.setSecurityThreshold(SecurityThreshold.restricted);
    await tester.pumpWidget(
      AppScope(
        state: state,
        notes: BridgeNotesRepository(),
        capture: CaptureRepository(),
        events: BridgeEventsRepository(),
        child: MaterialApp(
          theme: buildTheme(
            preset: 'system',
            brightness: Brightness.dark,
            fontName: 'Onest',
            dynamicScheme: null,
          ),
          home: CaptureScreen(state: state, onSaved: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    final body = find.byType(TextField).at(1);
    // File name is visible while locked; headers are not reachable yet.
    await tester.enterText(body, '@vault/secrets.md');
    await tester.pump();
    expect(find.text('vault/secrets.md'), findsOneWidget);
    expect(find.text('Passwords'), findsNothing);

    // Pick the file after a session unlock, then relock it.
    state.fileUnlocked['vault/secrets.md'] = true;
    await tester.enterText(body, '@vault/secrets.md');
    await tester.pump();
    await tester.tap(find.text('vault/secrets.md'));
    await tester.pump();
    state.fileUnlocked.remove('vault/secrets.md');

    await tester.enterText(body, '#');
    await tester.pump();
    expect(find.text('No matching headers'), findsOneWidget);
    expect(find.text('# Passwords'), findsNothing);

    state.fileUnlocked['vault/secrets.md'] = true;
    await tester.enterText(body, '#P');
    await tester.pump();
    expect(find.text('# Passwords'), findsOneWidget);
  });
}

Future<void> seedVault(String root) async {
  final secret = File('$root/notes/vault/secrets.md');
  await secret.create(recursive: true);
  await secret.writeAsString('# Secrets\n\n## Passwords\n\ns3cret\n');
  await File('$root/index.md').writeAsString(
    '## Notes\n\n### vault\nsecurity: restricted\n\n#### secrets.md\nabout: Secrets\n',
  );
}
