# Roadmap

Ordered work queue for coding agents. Rules: `.agents/architecture.md`, `.agents/design.md`.

How to work a task:
1. Take the first unchecked task whose dependencies are checked. One task = one commit.
2. Read the files it names before editing. If it needs more than ~8 files beyond those, stop and ask.
3. Bug tasks: write the failing test first. Every task ends with its "Accept" items true.
4. Gates from `AGENTS.md`. UI tasks also run the design review checklist on the emulator.
5. Tick the box in this file in the same commit. New findings go to the end of the right phase, not into the diff.

## Phase 0 — guardrails

- [ ] **T0.1 Strict analyzer.** Replace `analysis_options.yaml` with flutter_lints +
  `strict-casts`, `strict-inference`, `strict-raw-types`, exclude `lib/src/rust/**`, and rules:
  `always_declare_return_types avoid_dynamic_calls avoid_slow_async_io avoid_void_async cancel_subscriptions
  close_sinks discarded_futures prefer_const_constructors prefer_const_declarations prefer_final_locals
  unawaited_futures unnecessary_lambdas use_build_context_synchronously use_super_parameters`.
  Fix all findings (~48; mostly fire-and-forget futures -> `unawaited(...)` with intent, or await).
  Accept: `fvm flutter analyze` clean.
- [ ] **T0.2 Offline fonts.** Bundle Onest, Golos Text, Martian Mono, IBM Plex Mono (regular + semibold)
  under `assets/fonts/` per google_fonts docs, set `GoogleFonts.config.allowRuntimeFetching = false` in
  `main()`, remove `INTERNET` from `AndroidManifest.xml`. Accept: airplane-mode first launch renders the
  chosen font; APK size growth noted in the commit body.

## Phase 1 — bugs users hit

- [x] **T1.1 Event date change overwrites another event.** `_EventFormState._save` calls
  `updateSingleEvent(dateIso: _iso /* new date */, sectionIndex: initial.index /* old day's index */)`.
  Fix in `api.rs`: `update_single_event` takes `original_date_iso`; when it differs, remove from the old day
  and append to the new one (switch to `move_event` once C2 lands). Accept: Rust test "move 2nd event of day A
  to day B keeps B's events intact"; manual check on emulator.
- [x] **T1.2 Unsaved note edits are lost.** `NoteViewer` edit mode: `PopScope` asks Save / Discard / Cancel
  when the text differs from the loaded one. Accept: widget test types, presses back, sees the dialog.
- [x] **T1.3 Calendar cell overflow + weekday header.** Today's cell overflows (border + dots in
  `cellW * 0.72`), hiding event dots; there is no S M T W T F S header. Accept: `grid_overflow_test.dart`
  covers a today cell with both dots at 320 dp and 1080 dp widths and text scale 1.3; header row rendered.
- [ ] **T1.4 Starfield burns frames.** `lib/stars.dart` ticks at 60 fps forever, also in light mode, and
  regenerates stars every frame. Run the controller only when dark and animations are enabled, precompute
  stars per size, wrap in `RepaintBoundary`. Accept: in light mode DevTools shows no repaint while idle.
- [ ] **T1.5 Reminders horizon.** Reminders are planned only for days -1..+2 and only when the app opens.
  Plan 14 days ahead in one bridge call (C7, or a Dart loop until it lands), and after the first frame instead
  of before `runApp`. Accept: domain unit test for the planner (pure function: events + now -> schedule).
- [x] **T1.6 Gated content leaks through Capture.** `@` autocomplete lists headers of `restricted/critical`
  files without unlock. Show only file names for gated files until unlocked this session; appending into a
  gated file asks `unlock()` first. Accept: controller test with a fake repository.
- [ ] **T1.7 Session relock.** `appUnlocked` and `fileUnlocked` reset when the app is paused > 60 s.
  Accept: unit test on the timing logic.

## Phase 2 — layering (each removes entries from `architecture_test.dart` baselines)

- [ ] **T2.1 Skeleton.** `lib/app/app_scope.dart` (InheritedWidget), `lib/data/models.dart`
  (DTO-only re-export), move `notifications.dart`, `storage_access.dart`, `auth.dart` platform calls to
  `lib/platform/`. Accept: app runs; no behavior change.
- [ ] **T2.2 Notes.** `NotesRepository` (list projects, read/save note, toggle checkbox, cache + revision),
  `NotesController`, `features/notes/` widgets. Accept: `screens/notes.dart` deleted, baseline entries gone,
  controller test.
- [ ] **T2.3 Capture.** `CaptureRepository`, `CaptureController` (draft, target, token parsing in `domain/`).
  Reminder side effects move out of the widget. Accept: `continuedMarker` and token parsing unit-tested in
  `domain/`, baseline entries gone.
- [ ] **T2.4 Events.** `EventsRepository` (month grid cached per month, day events, repeatables, revision),
  `EventsController`; split into `features/events/widgets/{calendar_grid,day_sheet,event_list,event_form,
  repeatable_panel}.dart`. Accept: every file <= 300 lines, baseline entries gone.
- [ ] **T2.5 Settings.** `SettingsStore` with typed enums; appearance split so only it rebuilds
  `MaterialApp`; `ThemeData` cached. Conflict resolution and demo seeding go through Rust (C10).
  Accept: toggling "Square cells" does not rebuild `MaterialApp` (debug print or test).
- [ ] **T2.6 Shell.** Replace `GlobalKey<State>` reloads in `main.dart` with repository revisions;
  `invalidate()` on resume. Accept: `_globalStateKeyBaseline` and `main.dart` io baseline gone; switching tabs
  with no writes makes zero bridge calls.

## Phase 3 — UI/UX polish (each: before/after screenshots in the report)

- [ ] **T3.1 Navigation.** One settings entry point: notification settings move from the Events gear into
  Settings; Notes gear becomes `Icons.visibility_outlined` "Visible projects"; calendar options move to an
  "Events" section in Settings. Back on a non-Capture tab goes to Capture. Calendar/List choice persists.
- [ ] **T3.2 Capture.** Title field looks like a field (label "Title"); Save disabled when empty; suggestions
  open below the caret area without pushing the body; file icon for files; snackbar "Saved to
  home/shopping.md" + "Open" action; arrows become icons; event mode keeps one duration control; content
  is padded above the floating nav bar.
- [ ] **T3.3 Notes.** Security shown only when not `open`, as lock icon; "(files)" renamed "Loose notes";
  file count per project; heading hierarchy in preview (`#` vs `##` clearly different).
- [ ] **T3.4 Events.** Day details in a bottom sheet titled "Sun, Oct 25" (no floating popover); one time and
  duration format app-wide; week strip shows day numbers; event form fields never truncate; field-level
  validation; FAB uses `primaryContainer`; alarm options disabled while the alarm switch is off.
- [ ] **T3.5 Settings.** One-line explanation per security level; warn when a gated level is chosen without a
  PIN; font options rendered in their own font; "Change chora_dir path" -> "Storage folder"; demo data only in
  debug builds.
- [ ] **T3.6 Brand.** App icon and splash (no Flutter logo), `pubspec.yaml` description.
- [ ] **T3.7 Accessibility pass.** Tooltips/Semantics everywhere, 48 dp targets, text scale 2.0 widget tests
  per screen.

## Phase 4 — speed proof

- [ ] **T4.1 Profile run.** `fvm flutter run --profile` on the emulator; record in the commit body: cold start
  to first frame, worst frame while switching tabs / paging months / typing / scrolling 500 notes
  (generate them with demo data). Fix anything over the budget in `architecture.md`.
