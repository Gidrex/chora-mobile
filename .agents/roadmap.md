# Roadmap

Ordered work queue for coding agents. Rules: `.agents/architecture.md`, `.agents/design.md`.

How to work a task:
1. Take the first unchecked task whose dependencies are checked. One task = one commit.
2. Read the files it names before editing. If it needs more than ~8 files beyond those, stop and ask.
3. Bug tasks: write the failing test first. Every task ends with its "Accept" items true.
4. Gates from `AGENTS.md`. UI tasks also run the design review checklist on the emulator.
5. Tick the box in this file in the same commit. New findings go to the end of the right phase.

## Done (architecture rewrite, 2026-11)

- Standalone build: `chora` from crates.io, storage logic moved into `chora` 0.2 (`fsx`, `edit`, `conflict`), one `Vault` bridge handle,
  typed `ApiError`, atomic writes, identity-checked note/event edits, range reads, change stamp,
  conflicts/demo/sweep in Rust (former backend tasks C1–C11).
- Dart layers: `AppServices` composition root, `VaultSession` revision instead of `GlobalKey` reloads,
  cached repositories, pure `domain/`, features isolated, architecture test without baselines.
- All four screens rewritten to `.agents/design.md` (former T1.1–T1.7, T2.x, T3.1–T3.5): Capture modes,
  Notes search/tasks/edit guard, Events month/agenda/weekly + full-screen form with Undo, Settings sections
  with safe storage switch and PIN-first security.

## Phase 1 — polish

- [ ] **T1.1 Brand.** App icon and splash (no Flutter logo), app label, `pubspec.yaml` description.
- [ ] **T1.2 Week start.** Month grid and weekday header follow the locale's first day of week
  (chora's grid is Sunday-first; needs a `first_weekday` arg in `chora::calendar::month_grid`, then a chora release).
  Accept: widget test with a Monday-first locale.
- [x] **T1.3 Hide locked titles.** Locked notes show a lock instead of their h1 in the Notes tree.
- [ ] **T1.4 Markdown package.** `flutter_markdown` is discontinued; move to `flutter_markdown_plus`
  (needs approval: dependency change). Accept: note preview renders unchanged.
- [ ] **T1.5 Test settle helper.** Shared `settle(tester)` in `test/test_backend.dart` (alternate
  `runAsync` + `pump`) replacing per-file copies.

## Phase 2 — features (ask the user first)

- Note creation and rename from Notes (Rust `create_note`, `move_note`).
- Content search across notes (`Vault.search(query) -> Vec<Hit>`).
- Home-screen widget / quick-capture share target (Android `ACTION_SEND` into Capture).
- PIN hashing (salted slow hash) in Rust — new crate, needs approval.

## Phase 3 — speed proof

- [ ] **T3.1 Profile run.** `fvm flutter run --profile` on the emulator; record cold start to first frame and
  worst frame while switching tabs / paging months / typing / scrolling 500 notes. Fix anything over the
  budget in `architecture.md`.
