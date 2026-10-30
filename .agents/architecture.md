# Architecture

Binding for every change in `lib/`. `test/architecture_test.dart` enforces the mechanical rules; the rest is
checked in review. Legacy code is migrated by `.agents/roadmap.md`, never by drive-by rewrites.

## Verdict on the current code

- Keep: the Rust core (`chora` + `rust/src/api.rs`), the bridge, Material 3 theming, the 4-tab shell.
- Rewrite by migration, not from scratch: screens own I/O, state and business logic at once
  (`lib/screens/*.dart` call the bridge, schedule reminders, write files). Every screen moves to the layout below.
- `events.dart` (1390 lines) is split into feature widgets; `AppState` is split by owner.

## Target layout

```
lib/
  main.dart                boot only: RustLib + storage init, runApp. Nothing else awaited before first frame.
  app/                     ChoraApp, tab shell, AppScope (InheritedWidget that hands out repositories/controllers)
  data/                    the ONLY Dart code that calls the bridge or touches files
    models.dart            export 'package:chora_mobile/src/rust/api.dart' show <DTO types only>;
    notes_repository.dart  events_repository.dart  capture_repository.dart  settings_store.dart
  platform/                Android side effects: notifications, alarms, biometrics, storage access channel
  domain/                  pure Dart, no Flutter import: formatting, reminder planning, gate decisions, enums
  features/<name>/         <name>_controller.dart, <name>_screen.dart, widgets/*.dart
  ui/                      shared widgets (section card, badge, empty state) and tokens; theme
```

## Data flow

`Widget -> Controller -> Repository -> bridge (Rust) -> disk`. Never skip a layer, never go backwards.

- **Repository**: one per domain. Calls the bridge, caches the last result, exposes
  `ValueListenable<int> revision` that bumps after every write it performs and on `invalidate()`.
  `invalidate()` runs on app resume (Syncthing may have changed files). No widgets, no `BuildContext`.
- **Controller**: `ChangeNotifier` per screen. Owns screen state (loaded data, `loading`, `error`),
  listens to repository `revision`, exposes intent methods (`save()`, `toggle(line)`). No `BuildContext`,
  no `showSnackBar`; it exposes an error/one-shot message the widget renders.
- **Widget State**: only ephemeral UI state — `TextEditingController`, `FocusNode`, animations, expanded flags.
- Cross-screen refresh goes through repository `revision`, never through `GlobalKey<State>` calls.
- Settings: `SettingsStore` over `SharedPreferences`, split so appearance changes (theme/font/preset) are the
  only thing that rebuilds `MaterialApp`. `ThemeData` is cached per (preset, brightness, font).

## Rules (MUST / MUST NOT)

Layers and state:
- Only `lib/backend.dart`, `lib/data/**`, `lib/platform/**` import `src/rust/`, `backend.dart`, `dart:io`.
  UI imports DTO types from `data/models.dart`.
- Dart never writes user files. Every write to `chora_dir` goes through a Rust function (atomic, tested).
- One owner per piece of state. If two widgets need it, it lives in a controller or repository.
- Typed enums, not strings: security level, alarm mode, old-events policy, theme preset. Prefs store `.name`.
- No static mutable state besides `Backend.root` (set once in `Backend.init`).
- Events are edited by the backend's identity check (see `.agents/backend-tasks.md`), never by a bare index
  computed on another day or another read.

Code shape:
- File <= 300 lines. `build()` <= 60 lines: extract `StatelessWidget` classes (const-constructible), not
  `_buildFoo()` helper methods.
- Function <= 40 lines. Nesting depth <= 4.
- No logic in widgets: parsing, date/time math, formatting, filtering live in `domain/` with unit tests.
- No interface with a single implementation. Tests fake a repository with `implements`.
- No new packages (state management, DI, codegen included) without the user's approval.
  `ChangeNotifier` + `ListenableBuilder` + `InheritedWidget` are the state toolkit.

Errors:
- Map bridge errors to a user message in one place (`Backend.errMsg` until typed errors land).
- No empty `catch`. A best-effort `catch` carries a one-line reason comment and never hides data loss.
- Every write path shows feedback: success (short snackbar, Undo where reversible) or the error.

Tests (definition of done):
- Bug fix: a failing test first (widget, controller, domain or Rust), then the fix.
- New domain function: unit test. New controller: test with a fake repository. New screen/flow: widget test
  that taps the main path. New Rust fn in `api.rs`: Rust test in the same file.
- `fvm flutter test` includes `architecture_test.dart`; when you fix a legacy file, delete its baseline entry.

## Performance budget ("the app flies")

Measured in `--profile` mode on a real device or the emulator, DevTools Performance tab.

- Cold start to first frame < 600 ms: only `RustLib.init` + `initStorage` before `runApp`;
  reminders, permission prompts and conflict scans run after the first frame.
- No frame > 16 ms (aim for 8 ms) while switching tabs, paging months, typing in Capture, scrolling 500 notes.
- Tab switch with a valid cache does zero bridge calls.
- One bridge call per screen state; no bridge calls in loops (ask for a range/batch API instead).
- Lists of unbounded size use `ListView.builder`/slivers; no `shrinkWrap: true` for them.
- `const` everywhere it compiles. `RepaintBoundary` around anything that animates continuously.
- No endless `AnimationController` unless visible; honor `MediaQuery.disableAnimationsOf(context)`.
- Fonts are bundled assets with `GoogleFonts.config.allowRuntimeFetching = false`; the app needs no network.
- `TextStyle`s come from the theme (`ThemeExtension`), not constructed per build via `GoogleFonts.*()`.
- Release build stays small: check `fvm flutter build apk --release --analyze-size` after adding assets.
