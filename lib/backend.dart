import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'src/rust/api.dart';
import 'src/rust/frb_generated.dart';

export 'src/rust/api.dart';

/// Rust backend handle: storage root + one-line error mapping.
class Backend {
  static late String root;

  static Future<void> init(String? override) async {
    await RustLib.init();
    root = override ?? await _defaultRoot();
    await initStorage(rootDir: root);
  }

  static Future<String> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/chora';
  }

  /// Short human message from any bridge/IO error.
  static String errMsg(Object e) {
    var text = e.toString();
    // Strip `FrbAnyhowException: ` / `Exception: ` prefixes.
    final colon = text.indexOf(': ');
    if (colon > 0 && colon < 60) text = text.substring(colon + 2);
    return text.split('\n').first.trim();
  }

  static String isoOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dateOf(String iso) => DateTime.parse(iso);

  /// Files matching Syncthing conflict markers under the storage root.
  static Future<List<String>> conflicts() async {
    final out = <String>[];
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return out;
    await for (final entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      final name = entity.path.split('/').last;
      if (name.contains('.sync-conflict-')) out.add(entity.path);
    }
    return out..sort();
  }
}

/// Demo content for first-run review (no `index.md`: missing index = all open).
Future<void> seedDemo(String root) async {
  final notes = Directory('$root/notes');
  if (await notes.exists() &&
      await notes.list().any((_) => true).catchError((_) => false)) {
    return;
  }
  Future<void> write(String rel, String text) async {
    final file = File('$root/$rel');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  await write(
    'notes/work/todo.md',
    '# Todo\n\n## Tasks\n\n- [ ] Ship chora-mobile review\n- [x] Read SPEC.md\n\n## Bugs\n\n- [ ] Checkbox tap area too small\n',
  );
  await write(
    'notes/work/guides/deploy.md',
    '# Deploy\n\n## Steps\n\n1. Build APK\n2. Install on device\n',
  );
  await write(
    'notes/home/shopping.md',
    '# Shopping\n\n- [ ] Milk\n- [ ] Bread\n',
  );
  await write('notes/inbox.md', '# Inbox\n');
  await write(
    'events/repeatable/monday.md',
    '# Monday\n\n## Gym\nTime: 19:00\nDuration: 1h\n\nLegs day.\n',
  );
  final today = Backend.isoOf(DateTime.now());
  await write(
    'events/$today.md',
    '# $today\n\n## Standup\nTime: 11:00\nDuration: 15m\n\nWhat is cooking.\n\n## Demo Day\nTime: 15:00\nDuration: 1h\n\nShow the app.\n',
  );
}
