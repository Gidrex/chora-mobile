# Design system

Reference for `.agents/skills/ui-ux/SKILL.md`. Material 3 first: use stock M3 components before custom ones.

## Tokens

- Spacing: 4, 8, 12, 16, 24, 32. Screen gutter 16. Nothing else.
- Radius: 8 (chips, small), 12 (inputs, buttons), 16 (tiles), 20 (cards), 28 (nav pill, sheets).
- Touch target >= 48x48 dp, including icon buttons, calendar cells, checkbox rows.
- Motion: 150–250 ms, `Curves.easeOutCubic` (enter) / `easeInCubic` (exit). No bounce on content.
- Type: `textTheme` roles only (`titleLarge` screen titles, `titleMedium` sections, `bodyLarge` content,
  `labelMedium` metadata). Mono only for raw markdown editing.
- Color: `ColorScheme` roles, `EventPalette` and `Tones` extensions only (raw values live in
  `lib/ui/palettes.dart`/`theme.dart`). Contrast >= 4.5:1 in light AND dark.
- Text tones (`Tones.of(context)`): every kind of text has its own color on every screen — `file` names/paths,
  `heading` note titles (h1), `folder` projects, `time` starts, `duration` lengths/counts, `section` `#`
  sections/tags, `weekly` repeating events, `muted` metadata. Other presets derive the same roles from their
  accents, so a widget colored by role looks right everywhere.
- Feel (Ambient Night reference): soft charcoal night, borderless rounded cards (24) with faint shadows,
  pastel accents, starfield with a dim moon; decorative art (`lib/ui/cloud.dart`) is drawn in code from
  theme colors, never images.
- Size: users scale text (`textScale` 0.8–1.6) and the whole UI (`uiScale` 0.8–1.3) in Settings; layouts must
  survive both extremes.

## Interaction rules

- One primary action per screen. It is disabled until valid (empty Capture cannot be saved).
- Feedback within 100 ms for every tap: ripple, state change, or progress. Async > 300 ms shows progress.
- Destructive or lossy actions: Undo snackbar, or a confirm dialog when undo is impossible.
- Leaving a screen with unsaved edits asks "Discard changes?" (`PopScope`). Never drop input silently.
- Validation errors render on the field (`errorText`), not in a snackbar behind a dialog.
- Snackbars are one short line. Paths shown relative to the notes root (`home/shopping.md`), never `/data/...`.
- Empty states: one sentence + the action that fills them.
- Back on a non-first tab returns to Capture; back on Capture leaves the app.
- Overlays: bottom sheets for contextual detail (day events, filters), dialogs only for decisions.

## Content

- Dates in UI: locale format via `MaterialLocalizations` ("Sun, Oct 25"); ISO only in files.
- Times: `MaterialLocalizations.formatTimeOfDay` with `MediaQuery.alwaysUse24HourFormatOf`. One format app-wide.
- Durations: "15 min", "1 h 30 min" everywhere (list, popover, form).
- No internal jargon in UI: no `chora_dir`, `(files)`, `[open]`, `-> to-agent/`, `events/*.md`.
  Security level is shown only when it is not `open`, as a lock icon + label.
- No ASCII art arrows or bracket tags (`->`, `[x]`); use icons.

## Accessibility

- Every `IconButton` has a `tooltip`; custom tappables (`GestureDetector`, `InkWell`) get `Semantics(label:)`.
- Layout survives text scale 2.0 and a 320 dp wide screen without overflow (widget test with
  `tester.view` + `MediaQuery(textScaler:)`).
- Calendar has a weekday header row; selected/today states are not color-only.

## Review checklist (run on the emulator via mobile-mcp before reporting UI work done)

Light + dark; text scale 1.0 + 2.0; keyboard open over every input; empty state; error state;
back button from every screen; no debug overflow stripes; screenshots of changed screens in the report.
