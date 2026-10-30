# Project

`chora-mobile` — serverless Android app (Flutter + Material 3), Rust backend over
`flutter_rust_bridge`. Sync is external: the user points `chora_dir` at a folder synced by another app
(e.g. Syncthing-Fork); the app only detects `.sync-conflict-` copies.

## Stack and versions

- Flutter 3.47.8 via FVM (commit `.fvmrc`, never `.fvm/`). Bare `flutter`/`dart` is forbidden.
- `flutter_rust_bridge 2.13.0`, bridge built via `rust_builder` (cargokit). Dart output — `lib/src/rust/`.
- Rust crate `chora_mobile_rust` depends on `chora = { path = ../../chora }` (sibling repo). Change it only
  through `.agents/backend-tasks.md`, in a session opened in that repo under its own `AGENTS.md`.
- Only `android/` is generated. JDK 17.

## Key facts

- Storage `chora_dir`: `index.md` (read-only), `notes/<project>/`, `to-agent/`, `events/YYYY-MM-DD.md`,
  `events/repeatable/<weekday>.md`, `events/backlog/`. See `SPEC.md` for details.
- Entry points: `lib/main.dart` → `Backend.init()` → `Reminders` → `runApp`.
- `android/app/src/main/kotlin/dev/gidrex/chora_mobile/MainActivity.kt`: storage MethodChannel
  (all-files access, folder picker).
- Release builds are signed with the debug key (`android/app/build.gradle.kts`). Replace before any release.
- No CI. Remote is GitLab.
