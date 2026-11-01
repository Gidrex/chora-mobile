# Architecture

Binding for every change in `lib/` and `rust/`. `test/architecture_test.dart` enforces the mechanical rules
(no baselines: every rule holds for every file); the rest is checked in review.

## Big picture

```
Flutter UI ──> Controller ──> Repository ──> VaultSession ──> Vault (Rust, FRB opaque) ──> chora crate ──> disk
```

The app is self-contained: the Rust crate depends on `chora` from crates.io (pinned). All storage logic
(atomic writes, checked edits, conflicts, stamp) lives in `chora` itself (`fsx`, `edit`, `conflict`); this
repo keeps only the bridge adapter. Dart never touches user files.

## Rust (`rust/src/`)

```
api/        bridge surface, scanned by flutter_rust_bridge (rust_input: crate::api)
  vault.rs    `Vault` opaque handle: one method per use case, mapping DTOs onto `chora` calls
  types.rs    DTOs and enums (plain data)
  error.rs    `ApiError { kind: ErrorKind, message }`, the only error crossing the bridge
  convert.rs  DTO <-> chora types, input validation (private, not exported)
  demo.rs     sample content for debug builds (private)
```

- Every overwrite goes through `chora::fsx::write_atomic`.
- Writes are checked against what the UI read: notes take `base` text, events take the `original` DTO.
  A mismatch is `ErrorKind::Changed` (sync changed the file); the UI reloads, never overwrites.
- Event moves (date or weekly/day change) write the new copy before removing the old one: a failure
  duplicates, never loses.
- Error messages show paths relative to the storage root.
- New use case: logic + test in `chora` (release it, bump the pin here), then a `Vault` method with a
  mobile-path test, then regenerate the bridge. Pure mapping may live here; decisions about files may not.

## Dart (`lib/`)

```
main.dart     boot only: RustLib.init, prefs, AppServices.boot, runApp. Nothing else before the first frame.
app/          composition root and shell
  services.dart       AppServices: every long-lived object, created once (add new services here)
  app_scope.dart      InheritedWidget handing out AppServices
  app.dart            MaterialApp (rebuilds on appearance only) + whole-app lock gate
  shell.dart          4 tabs (IndexedStack + NavigationBar), back -> Capture, resume -> sync check + relock
  session_lock.dart   session clearance (unlock grants a level; relock after 60 s in background)
  reminders.dart      plans notifications from storage revision + settings; auto alarm after save
  boot_error.dart     storage cannot be opened: retry / fall back to the app folder
data/         the ONLY Dart code that calls the bridge
  vault_session.dart  holds the bridge Vault, maps ApiError -> AppFailure, one app-wide `revision`
  *_repository.dart   typed facades with read caches dropped on every revision bump
  settings_store.dart SharedPreferences, typed; appearance split out
  models.dart         DTO re-exports for the UI
platform/     Android side effects: notifications/alarm, biometrics, PIN store, storage access, paths
domain/       pure Dart (no Flutter import): dates/durations, reminder planning, security gate, parsers
features/<x>/ <x>_screen.dart, <x>_controller.dart, widgets/*.dart; imports only itself and `lock`
ui/           theme, palette extension, starfield, shared widgets
```

## Data flow and state

- `Widget -> Controller -> Repository -> VaultSession -> Vault`. Never skip a layer.
- One storage revision: `VaultSession.write` bumps it after every write; `refreshIfChanged()` bumps it when
  the metadata stamp moved (app resume, pull-to-refresh). Repositories clear caches on a bump; controllers
  reload on a bump. Cross-screen refresh needs nothing else.
- Controller: `ChangeNotifier` per screen, takes repositories + `Listenable revision`, exposes state and
  intent methods, no `BuildContext`, errors as values (`AppFailure.message`, branch on `kind`).
- Widget state: only ephemeral UI state (text controllers, focus, animations).
- Settings: `SettingsStore` over `SharedPreferences`; only `AppearanceSettings` rebuilds `MaterialApp`.
  Pref keys are stable; renaming one needs a migration.
- Static mutable state: none.

## Rules (MUST / MUST NOT)

- Only `lib/data/**`, `lib/platform/**` and `lib/main.dart` import `src/rust/` or `dart:io`.
- `lib/domain/**` imports no Flutter.
- Features never import other features (except `lock`). Shared code goes to `domain/` or `ui/`.
- Typed enums, not strings, everywhere (prefs store `.name`).
- File <= 300 lines, `build()` <= 60 lines, function <= 40 lines, nesting <= 4. Extract widgets, not
  `_buildFoo()` helpers.
- No logic in widgets: parsing, date math, formatting, filtering live in `domain/` with unit tests.
- No interface with a single implementation; tests fake a repository with `implements`.
- No new packages without the user's approval. Toolkit: `ChangeNotifier`, `ListenableBuilder`, `InheritedWidget`.
- No empty `catch`; a best-effort catch names its exception type and logs why it is safe.
- Every write path shows feedback: short snackbar, Undo where reversible, or the error.

## Tests (definition of done)

- Rust: logic is tested in `chora`; `api/vault.rs` tests cover the mobile path end to end.
- Dart domain fn: unit test. Controller: test with a fake repository or the real backend
  (`test/test_backend.dart: testServices()`). Screen: widget test tapping the main path.
- Bug fix: failing test first.

## Performance budget

- Cold start to first frame < 600 ms: only `RustLib.init`, prefs and `Vault.open` before `runApp`.
- No frame > 16 ms while switching tabs, paging months, typing, scrolling 500 notes.
- Tab switch does zero bridge calls (IndexedStack + cached repositories).
- One bridge call per screen state; ranges via `Vault.range`, never a loop of `day` calls.
- Unbounded lists use builders/slivers. `const` wherever it compiles. Starfield ticks only in dark mode
  with animations enabled.
- Fonts are bundled; the app has no INTERNET permission.
