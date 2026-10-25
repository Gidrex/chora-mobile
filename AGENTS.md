# AGENTS.md

Entry point for coding agents. Details live in `.agents/`, workflows in `.agents/skills/*/SKILL.md`.

## Read first

- `.agents/project.md` — stack, versions, storage layout.
- `.agents/commands.md` — build, codegen, tests.
- `.agents/rules.md` — commits, generated code, state ownership.

Only by zone:

- `.agents/skills.md` — skill index.
- `.agents/skills/android-native/SKILL.md` — FRB, Syncthing service, native code.
- `.agents/skills/pre-commit-quality-review/SKILL.md` — pre-commit check.

## Top rules

- Scoped task — implement directly, no plans, design docs, or repeated questions. Ask only on ambiguity,
  destructive actions, or scope growth.
- The request sets the scope. A nearby bug/refactor is a follow-up in the summary, not part of the diff.
- FVM only: `fvm flutter ...`, `fvm dart ...`. Bare `flutter`/`dart` is forbidden. For
  `flutter_rust_bridge_codegen` — `PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"`.
- `flutter test`, not `dart test`.
- After editing `rust/src/api.rs` — regenerate the bridge, never hand-edit `frb_generated*`.
- `Backend.init()` runs once per launch; UI/providers request transitions but never become a second source
  of truth about the service.
- Commits are Conventional Commits, no `Co-authored-by` from agents. See `.agents/rules.md`.
- Before reporting done: `fvm dart format`, `fvm flutter analyze`, `fvm flutter test`, plus
  `cargo fmt --check/clippy/test` when `rust/` was touched. Say plainly what you skipped.
