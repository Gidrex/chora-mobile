# Project

`chora-mobile` — serverless Android app (Flutter + Material 3), Rust backend over
`flutter_rust_bridge`, folder sync via bundled Syncthing (`libsyncthing.so`).

## Stack and versions

- Flutter 3.47.8 via FVM (commit `.fvmrc`, never `.fvm/`). Bare `flutter`/`dart` is forbidden.
- `flutter_rust_bridge 2.13.0`, bridge built via `rust_builder` (cargokit). Dart output — `lib/src/rust/`.
- Rust crate `chora_mobile_rust` depends on `chora = { path = ../../chora }` (sibling repo, do not touch).
- Only `android/` is generated. JDK 17, `useLegacyPackaging=true` for `libsyncthing.so`.

## Key facts

- Storage `chora_dir`: `index.md` (read-only), `notes/<project>/`, `to-agent/`, `events/YYYY-MM-DD.md`,
  `events/repeatable/<weekday>.md`, `events/backlog/`. See `SPEC.md` for details.
- Entry points: `lib/main.dart` → `Backend.init()` → `Reminders` → optionally `Syncthing.start()`.
- `android/app/src/main/kotlin/dev/gidrex/chora_mobile/`: `MainActivity` (MethodChannel) + `SyncthingService`
  (foreground service, own `config.xml` in app-private `syncthing_home`, single `chora-root` folder).
- `libsyncthing.so` is **missing** from the repo (no `jniLibs/`) — the Syncthing feature is dead until the
  binary ships. Degradation is graceful: `NO_BINARY` → the toggle switches itself off.
- Release builds are signed with the debug key (`android/app/build.gradle.kts`). Replace before any release.
- No CI, no commits yet. Remote is GitLab.
