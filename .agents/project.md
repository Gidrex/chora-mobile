# Project

`chora-mobile` — serverless Android app (Flutter + Material 3), Rust backend over
`flutter_rust_bridge`. Sync is external: the user points `chora_dir` at a folder synced by another app
(e.g. Syncthing-Fork); the app only detects `.sync-conflict-` copies.

## Stack and versions

- Flutter 3.47.8 via FVM (commit `.fvmrc`, never `.fvm/`). Bare `flutter`/`dart` is forbidden.
- `flutter_rust_bridge 2.13.0`, bridge built via `rust_builder` (cargokit). Dart output — `lib/src/rust/`.
- Rust crate `chora_mobile_rust` depends on `chora` from crates.io, pinned (`=0.1.1`). The repo builds on its
  own. Storage logic lives in `chora` (`../chora`, its own `AGENTS.md`); change it there, release, then bump
  the pin here and rerun all gates.
- Only `android/` is generated. JDK 17.

## Key facts

- Storage `chora_dir`: `index.md` (read-only), `notes/<project>/`, `to-agent/`, `events/YYYY-MM-DD.md`,
  `events/repeatable/<weekday>.md`, `events/backlog/`. See `SPEC.md` for details.
- Entry points: `lib/main.dart` → `RustLib.init` → `AppServices.boot` (prefs + `Vault.open`) → `runApp`;
  reminders and sync checks start after the first frame (`lib/app/shell.dart`).
- `android/app/src/main/kotlin/dev/gidrex/chora_mobile/MainActivity.kt`: storage MethodChannel
  (all-files access, folder picker).
- Release builds are signed with the debug key (`android/app/build.gradle.kts`). Replace before any release.
- No CI. Remote is GitLab.
