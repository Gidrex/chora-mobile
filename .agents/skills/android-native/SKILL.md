---
name: android-native
description: Use when changing the FRB bridge (rust/src/api.rs), Syncthing service lifecycle, native Kotlin, Backend init, reminders or system alarms in this repository.
---

# Android Native

## When To Use

Changes in `rust/src/api.rs`, `lib/backend.dart`, `lib/syncthing.dart`, `lib/notifications.dart`,
`android/app/src/main/kotlin/`, `AndroidManifest.xml`, `build.gradle.kts`.

## Read First

- `.agents/rules.md`: state ownership and generated code are binding.
- `.agents/commands.md`: codegen and gates.

## Owners

Every behavior has one owner; a change lands there:

- RustLib/storage root: `lib/backend.dart` (`Backend.init`, `root`, `errMsg`).
- FFI layer over `chora`: `rust/src/api.rs`. The `../../chora` path is a sibling repo, do not touch it.
- Service facade: `lib/syncthing.dart`. Start/stop intent: `MainActivity` (MethodChannel).
  Daemon and `config.xml`: `SyncthingService` (app-private `syncthing_home`, single `chora-root` folder).
- Reminders/alarms: `lib/notifications.dart`. PIN/biometric gate: `lib/auth.dart` + `AppState`.

## Verification

- `cargo test` in `rust/` for the backend. `fvm flutter test` for Dart.
- After `api.rs`: regenerate the bridge and run both suites.
- After Kotlin: `cd android && ./gradlew :app:compileDebugKotlin` (JDK 17).
- Manual on device only: VPN permissions, biometrics, exact alarm delivery, daemon start/stop.

## Pitfalls

- No `jniLibs/` with `libsyncthing.so`: service start answers `NO_BINARY` and the toggle switches itself
  off. This is expected — do not work around it, the binary is missing.
- `save_repeatable_weekday` drops handwritten text from the weekday file (documented in code).
  The UI must warn or preserve the text.
- Event indexes: day events use the position in `parse_day` (time-sorted) order, repeatables have their own
  counter. Never mix the namespaces in `update_single_event`/`delete_single_event`.
- Dart passes the checkbox/event index as `BigInt` (FFI `usize`); a plain `int` will not match.
- `patchConfig` wipes all folders and writes a single one — safe, because the home is private and created fresh.
