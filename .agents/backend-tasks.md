# Backend tasks (`chora` crate + `rust/src/api.rs`)

`chora` lives in `/home/gidrex/Projects/chora` (path dependency `../../chora`). Work on a `C*` task only in a
session opened in that repo, following its own `AGENTS.md` (sandbox `DEBUG_DIR`, isolated `HOME`, its gates).
Then come back here, adapt `api.rs`, regenerate the bridge if signatures changed, and run both gates.

Principle: domain logic lives in `chora`; `api.rs` only maps DTOs and errors. Every task below either moves
logic out of `api.rs` or adds what the mobile UI needs. Each task: unit tests in `chora`, a Rust test in
`api.rs` for the mobile path, smallest diff.

## Correctness (do first)

- [ ] **C1 Atomic writes.** Add `store::write_atomic(path, text)` (temp file in the same dir + fsync + rename).
  Use it for every write in `chora` (`store.rs`, `note.rs`) and every `fs::write` in `api.rs`.
  Accept: no `fs::write` on user files left (`rg "fs::write" src rust/src`), test that a failed write leaves
  the old file intact.
- [ ] **C2 Event identity.** Events are addressed by positional index today; a sync between read and write
  edits the wrong event. Add `event::replace_checked(text, index, expected: &Event, updated)` and
  `remove_checked(...)` that fail with a typed `EventChanged` error when the section at `index` no longer
  equals `expected`. Add `store::move_event(from_date, index, expected, to_date, updated)` for date changes.
  Accept: tests for changed-underneath, out-of-range, move across days; `api.rs` `update_single_event`
  takes `original_date_iso` + `original` DTO and uses these.
- [ ] **C3 Note append in the library.** Move the `## title\n\nbody` block building and header insertion
  from `api.rs` `submit_capture`/`append_block` and CLI `cmd_note_add` (`main.rs`) into one
  `note::append(root, rel_path, header: Option<&str>, title, body)`. Both callers use it.
  Accept: the duplicated "no file + header -> error" rule exists once; existing e2e tests pass.
- [ ] **C4 Checkbox toggle in the library.** Move `toggle_markdown_checkbox` into
  `note::toggle_checkbox(text, line) -> Result<String>`: only `- [ ]`/`- [x]` at line start (after indent),
  ignores fenced code blocks, preserves `\r\n`. Document that `line` is the 0-based raw line number; the
  Dart preview must use the same numbering. Accept: tests for fences, CRLF, nested indent, non-checkbox line.
- [ ] **C5 Repeatables by weekday.** Add `store::read_weekday(Weekday)` and `store::write_weekday(Weekday,
  &[Event])` that keep plain-text sections. Drop the `weekday_to_date` hack and the hand-built file in
  `api.rs` `save_repeatable_weekday`. Accept: round-trip test with a plain-text section that survives.

## Shape and speed

- [ ] **C6 Typed errors.** Public `chora` fns used by mobile return `ChoraError` (not `anyhow`).
  `api.rs` exposes `ChoraErrorKind` (enum) + message to Dart. Accept: Dart can `switch` on the kind;
  `Backend.errMsg` string-stripping is deleted.
- [ ] **C7 Range reads.** Add `api.rs` `get_events_in_range(from_iso, to_iso) -> Vec<DayEventsDto>`
  (one call) for reminders and the list view. Accept: `lib/notifications.dart` makes one bridge call.
- [ ] **C8 Single-pass project listing.** `list_all_projects` reads each note once (headers + about in the
  same pass). Accept: the code path has one `read_to_string` per file; existing listing tests pass.
- [ ] **C9 Storage stamp.** `api.rs` `storage_stamp(root) -> u64`: hash of (path, mtime, len) over
  `notes/` and `events/`, stat-only. Dart repositories skip reloads on resume when the stamp is unchanged.
- [ ] **C10 Conflicts in Rust.** `list_conflicts(root)` and `resolve_conflict(path, keep_mine)` move from
  `lib/backend.dart`/`settings.dart` into `api.rs` (atomic). Day-file conflict copies are reported, not
  silently skipped (`store.rs` `list_days`).
- [ ] **C11 Policy enum.** `sweep_old_events` takes the `OldEventPolicy` enum through the bridge instead of
  parsing a string.

## Later (ask the user first)

- Content search across notes (`search(query) -> Vec<Hit>`), needed for a real Notes search.
- PIN hashing (salted, slow hash) in Rust — needs a new crate, requires approval.
