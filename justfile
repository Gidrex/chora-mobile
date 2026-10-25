@_default:
    just --list --unsorted

# Apply formatting (Dart + Rust).
fmt:
    fvm dart format lib test
    cd rust && cargo fmt --all

# Static checks: format gate, analyze, clippy, Kotlin compile.
lint:
    fvm dart format --output=none --set-exit-if-changed lib test
    fvm flutter analyze
    cd rust && cargo fmt --all -- --check
    cd rust && cargo clippy --all-targets -- -D warnings
    cd android && ./gradlew :app:compileDebugKotlin

# Tests only (Flutter + Rust).
test:
    fvm flutter test
    cd rust && cargo test

# Full pipeline: lint + tests.
qa: lint test

# Hot-reload debug run on the connected device/emulator.
debug:
    fvm flutter run

# Release APK for arm64-v8a only (still signed with the debug key,
# see android/app/build.gradle.kts).
release: qa
    fvm flutter build apk --release --target-platform android-arm64
