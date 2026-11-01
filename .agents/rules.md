# Rules

## Generated code

- Never hand-edit: `rust/src/frb_generated.rs`, `lib/src/rust/frb_generated*.dart`, everything under
  `lib/src/rust/`. Source of truth is `rust/src/api/**` + `flutter_rust_bridge.yaml`.

## State ownership

- Layer ownership (bridge, files, controllers, widgets): `.agents/architecture.md`.
- The storage path changes only through `StorageRepository.moveTo` (reopens the vault, keeps the old one on
  failure); persist the new path only after it succeeded.
- Unlocks (`SessionLock`) are session-scoped; never make them persistent unless asked.

## Style

- `analysis_options.yaml` is law; never add `// ignore:` to pass a gate. Comments only carry what the code cannot show.
  Delete commented-out code.

## Commits

- Conventional Commits: `<type>[(scope)]: <description>`, types
  `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`. All commits in English.
- Description starts lowercase, no trailing period, subject within 100 characters. Scope is lowercase.
- `feat`/`fix`/`perf` carry a user-facing note as a `Changelog: <text>` footer; `Changelog: skip` opts out.
- `!` (breaking) requires a `BREAKING CHANGE: <what breaks>` footer.
- `fixup!`/`squash!`, `Merge`, `Revert` are exempt from the convention.
- No `Co-authored-by` from agents. Human co-authors are fine.
- A follow-up to a commit not contained in a stable `vX.Y.Z` tag lands as `git commit --fixup=<target>`.
  Squash only on request. Anything contained in a stable tag lands as a regular commit.

## Errors in new code

- Surface errors to the user (`AppFailure.message` in a snackbar), never swallow with an empty `catch`.
- Validate paths from settings before use; a failed re-init must not crash the app.
