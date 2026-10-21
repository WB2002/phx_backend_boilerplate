---
name: record-debt
description: Record accepted technical debt in the ledger instead of leaving it untracked
disable-model-invocation: true
---
Argument: a short title for the debt.

1. Read `docs/debt/` and take the next `TD-NNN` number. Skip `_template.md`.
2. Write `docs/debt/TD-NNN-<slug>.md` from `docs/debt/_template.md` with Status `proposed`.
   Fill introduced_by, type, severity, description, reason_accepted, owner, created,
   and resolution_condition.
3. Add the entry to the index in `docs/debt/README.md`.
4. Do not set Status to `accepted`. Do not change application code.
