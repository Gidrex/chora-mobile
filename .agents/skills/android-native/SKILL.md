---
name: android-native
description: Use when changing the FRB bridge (rust/src/api) or the chora crate it wraps, native Kotlin, storage opening, reminders or system alarms in this repository.
---

# Android Native

## When To Use

Changes in `rust/src/**`, `lib/data/vault_session.dart`, `lib/platform/**`, `lib/app/reminders.dart`,
`android/app/src/main/kotlin/`, `AndroidManifest.xml`, `build.gradle.kts`.

## Read First

- `.agents/architecture.md`: Rust adapter vs `chora` split, checked writes, revision flow.
- `.agents/rules.md`: state ownership and generated code are binding.
- `.agents/commands.md`: codegen and gates.

## Owners

Every behavior has one owner; a change lands there:

- Bridge handle and error mapping: `lib/data/vault_session.dart` (`VaultSession`, `AppFailure`).
- Bridge surface: `rust/src/api/vault.rs` (one-line methods), DTOs in `api/types.rs`, errors in `api/error.rs`.
- Storage logic: the `chora` crate (`../chora`: `fsx`, `edit`, `conflict`, `store`), released to crates.io;
  bump the `=x.y.z` pin in `rust/Cargo.toml` after a release.
- Storage access and folder picker: `MainActivity` (MethodChannel) + `lib/platform/storage_access.dart`.
- Reminders/alarms: plan in `lib/domain/reminders.dart`, schedule in `lib/platform/notifications.dart`,
  orchestration in `lib/app/reminders.dart`. PIN/biometric gate: `lib/features/lock/` + `lib/app/session_lock.dart`.

## Verification

- `cargo test` in `rust/` for the backend. `fvm flutter test` for Dart.
- After `rust/src/api/**`: regenerate the bridge, `cargo build`, run both suites.
- After Kotlin: `cd android && ./gradlew :app:compileDebugKotlin` (JDK 17).
- Manual on device only: biometrics, exact alarm delivery, all-files access prompt.

## Pitfalls

- Edits must pass the event exactly as read (`original`) and notes the text they started from (`base`);
  the backend locates the event by content and refuses with `ErrorKind.changed` when sync moved it.
- `u64` crosses the bridge as `BigInt` (only `Vault.stamp`); indexes and minutes are `u32` -> `int`.
- `flutter test` does not bundle the Rust lib: rebuild `rust/target/debug/libchora_mobile_rust.so` with
  `cargo build` after any Rust change, or widget tests run against a stale backend.
