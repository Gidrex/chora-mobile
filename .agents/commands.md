# Commands

Everything through FVM from the repo root.

## Development

```bash
fvm flutter pub get
fvm flutter run
fvm flutter test
```

## Codegen

After any edit to `rust/src/api/**`:

```bash
PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" flutter_rust_bridge_codegen generate
```

Without that `PATH` the generator fails with `flutter: command not found`. Never hand-edit:
`rust/src/frb_generated.rs`, `lib/src/rust/frb_generated*.dart`. No `build_runner`/`freezed` in this project.

## Gates (in order)

```bash
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
cargo fmt --all -- --check      # from rust/
cargo clippy --all-targets -- -D warnings
cargo test
```

## Widget tests with the real backend

`flutter test` does not bundle the Rust lib, and `testWidgets` swallows native
completions (FakeAsync): bridge futures only resolve inside `tester.runAsync`.

- Build once after every Rust change: `cargo build` in `rust/`
  (provides `rust/target/debug/libchora_mobile_rust.so`).
- `test/test_backend.dart:testServices()` loads that `.so` and returns `AppServices` over a temp
  storage; `harness(services, child)` wraps a screen. Call it inside `tester.runAsync`; seed/read via `tester.runAsync(...)`; wrap loads
  triggered by pumped widgets in `runAsync` + bounded `pump()` instead of
  `pumpAndSettle` while a load is pending.

For Kotlin edits, verify by compiling the modules (JDK 17):

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

No device/emulator in CI: VPN permissions, biometrics, exact alarm delivery, and daemon start/stop are
manual-only. If a toolchain is missing on the machine, say which check was skipped instead of staying silent.
