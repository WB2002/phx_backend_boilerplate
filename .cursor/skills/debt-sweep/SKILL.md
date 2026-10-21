---
name: debt-sweep
description: Read-only scan for technical debt and draft intents for the top items
disable-model-invocation: true
---
Read only. Do not change application code.

Read `docs/debt/` first. Skip debt already recorded there.

Scan for duplication, dead code, TODOs without references, oversized files or
functions, dependency-boundary violations, stale docs, and regressions against
`quality/baseline.json`.

Output a ranked list. For the top untracked items, write `intent/<slug>/intent.md`
with Status: draft. Do not draft an intent for an item already in `docs/debt/`.
