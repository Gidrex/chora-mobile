# Skills

Skills live in `.agents/skills/*/SKILL.md`. Trigger is `name` + `description`; the full text loads only
on a task match.

## Available skills

- `android-native`: FRB bridge, native Kotlin, reminders and alarms.
- `pre-commit-quality-review`: pre-commit triage — skip mechanics, review only responsibility changes.
- `ui-ux`: user-visible UI rules — theme-adaptive text, Material icons only, English only, empty by default.

## Authoring new ones

- Lowercase hyphenated name, description starts with `Use when...` and states trigger conditions, not workflow.
- Keep the skill lean; large reference material goes to `.agents/*.md` by link, not copy-paste.
- A new repeatable workflow is a new `SKILL.md`. Retire obsolete ones by deleting them whole.
