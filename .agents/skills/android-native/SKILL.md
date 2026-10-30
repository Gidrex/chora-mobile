---
name: android-native
description: Use when changing the FRB bridge (rust/src/api.rs), native Kotlin, Backend init, reminders or system alarms in this repository.
---

# Android Native

## When To Use

Changes in `rust/src/api.rs`, `lib/backend.dart`, `lib/notifications.dart`, `lib/storage_access.dart`,
`android/app/src/main/kotlin/`, `AndroidManifest.xml`, `build.gradle.kts`.

## Read First

- `.agents/rules.md`: state ownership and generated code are binding.
- `.agents/commands.md`: codegen and gates.
- `.agents/backend-tasks.md`: before adding logic to `api.rs`, check whether it belongs in `chora`.

## Owners

Every behavior has one owner; a change lands there:

- RustLib/storage root: `lib/backend.dart` (`Backend.init`, `root`, `errMsg`).
- FFI layer over `chora`: `rust/src/api.rs` — DTO and error mapping only; domain logic goes to `chora`
  via `.agents/backend-tasks.md`.
- Storage access and folder picker: `MainActivity` (MethodChannel) + `lib/storage_access.dart`.
- Reminders/alarms: `lib/notifications.dart`. PIN/biometric gate: `lib/auth.dart` + `AppState`.

## Verification

- `cargo test` in `rust/` for the backend. `fvm flutter test` for Dart.
- After `api.rs`: regenerate the bridge and run both suites.
- After Kotlin: `cd android && ./gradlew :app:compileDebugKotlin` (JDK 17).
- Manual on device only: biometrics, exact alarm delivery, all-files access prompt.

## Pitfalls

- `save_repeatable_weekday` drops handwritten text from the weekday file (documented in code).
  The UI must warn or preserve the text (fixed by backend task C5).
- Event indexes: day events use the position in `parse_day` (time-sorted) order, repeatables have their own
  counter. Never mix the namespaces in `update_single_event`/`delete_single_event`, and never apply an index
  read from one day to another day's file.
- Every write is a plain `fs::write` today; Syncthing can change a file between read and write (C1, C2).
- Dart passes the checkbox/event index as `BigInt` (FFI `usize`); a plain `int` will not match.
