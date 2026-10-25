---
name: pre-commit-quality-review
description: Use when the user asks to commit, amend, or squash code, or requests a pre-commit structural quality review.
---

# Pre-commit Quality Review

Check that iterative edits converged into a clear, cohesive, maintainable implementation before they become a
commit. `AGENTS.md` and `.agents/rules.md` apply throughout. This skill grants no authority: commit, push, and
history rewrites stay under the user's existing authorization, and silence is not consent.

## Triage

Most commits stop here. Decide from the change summary, the diff, and the local context it needs; never start
with a repository-wide scan.

- **Skip**: formatting, mechanical renames, generated output, copy changes, and simple local fixes.
  They go through the normal commit flow without confirmation. Say the review was skipped, never that it passed.
- **Review**: a core implementation is replaced; responsibilities, dependency direction, or public abstractions
  change materially; accumulated patches added branches, duplicate paths, or indirection; or new code draws
  responsibility boundaries. A small change can move a critical responsibility, so line count is not a trigger.

Snapshot: regular commit vs `HEAD`; amend vs the parent of the replaced commit; squash vs the range start.

## What qualifies as a finding

Only all three at once:

- Before/after code and the needed call relationships show this change introduced or worsened it.
- The cost is concrete (one rule updated in two places, touching an unrelated layer for one responsibility).
  Elegance or taste alone is not a finding.
- A minimal proposal fits the existing constraints without new coupling.

With no qualifying finding — scope and conclusion in a sentence or two, continue under the existing authorization.
Do not ask for confirmation because a review happened, and do not collect optional improvements into a list.

With findings — finish the read-only review and independent checks first, merge same-cause ones. For each: file,
symbol, location + how the change introduced it; the concrete cost; the smallest proposal with scope and
behavioral impact. Then **pause: ask whether to fix before committing; do not edit or commit until the user
answers.**

## Resolve and Finish

Once authorized — minimal edits for the accepted findings, no behavior or scope change. Verify only them and
their direct effects; no new hunt for improvements.

Before committing, recheck status and the staged diff (review what gets committed), review the delta of later
edits separately. Run the `AGENTS.md` gates for this change; reuse still-valid results, rerun invalidated ones;
never present results from an older snapshot as verification of the staged one. Format and commit-msg hooks apply.

Report: scope, completed fixes or accepted tradeoffs, check results, verification limits. Claim done only once
the commit exists.
