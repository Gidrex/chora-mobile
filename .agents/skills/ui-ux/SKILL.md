---
name: ui-ux
description: Use when changing any user-visible UI, text, icon, theme, or empty/demo state in this repository.
---

# UI/UX

Distilled from user feedback. Normative for every visible pixel.

## Hard rules

- Text follows the active theme: never hardcode text colors. Derive from
  `Theme.of(context).textTheme`; font helpers (e.g. `GoogleFonts.*TextTheme()`)
  must receive the brightness-matching base theme, else dark mode gets black-on-black.
- No emoji anywhere in UI — only Material `Icons.*`. Also banned: unicode
  pictographs and box-glyphs (`☑ ⟳ 🔒 ├─ └─ ▸`); draw with widgets or drop.
- English only: every user-visible string in English — labels, hints, tooltips,
  snackbars, dialogs, notifications, lock screen.
- Empty by default: no auto-seeded content on startup. Demo data only via an
  explicit user action or emulator-side setup, never in the startup path.
- Hint texts are spec: implement the exact wording given, no paraphrase.

## Bar

- Judge like a dumb demanding user: tap everything, check contrast in light AND
  dark, keyboard overlap, empty states, dead buttons. Ship only what survives nitpicking.
- Design refs (read before restyling): `tmp/calendar.png` (Timepage agenda),
  `tmp/events.jpg` (day blocks, week strip, timeline), `tmp/ambience.jpg`
  (starfield, radii, glow), `tmp/settings.jpg` (grouped rows).

## Maintenance (anti-bloat)

- When the user gives new UI feedback, append it here as one line under Hard rules.
- Keep this file under ~30 lines: merge duplicates, delete obsolete lines whole, no examples.
