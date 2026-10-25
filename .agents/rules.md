# Rules

## Generated code

- Never hand-edit: `rust/src/frb_generated.rs`, `lib/src/rust/frb_generated*.dart`, everything under
  `lib/src/rust/` except `api.dart`. Source of truth is `rust/src/api.rs` + `flutter_rust_bridge.yaml`.

## State ownership

- Syncthing service lifecycle belongs to `SyncthingService`/`MainActivity` (native) and the
  `lib/syncthing.dart` facade. Widgets request start/stop but never track "is the daemon running" themselves.
- `Backend.root` is set once in `Backend.init()`. Path changes go only through a re-init with error handling.
- File unlocks (`AppState.fileUnlocked`) are session-scoped; never make them persistent unless asked.

## Style

- `analysis_options.yaml` (`flutter_lints`) is law. Comments only carry what the code cannot show.
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

- Surface errors to the user (`Backend.errMsg` in a snackbar), never swallow with an empty `catch`.
- Validate paths from settings before use; a failed re-init must not crash the app.
