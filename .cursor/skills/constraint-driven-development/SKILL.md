---
name: constraint-driven-development
description: Use when no written quality bar exists, a check is being silenced, or a test is being weakened, skipped, or deleted to get green.
---

# Constraint-driven development

## Overview

A quality bar is a draft constraint whose every check names where it is enforced. Unanswered policy stays an open question. An agent does not invent it or accept it.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

- No file in `docs/constraints/` applies to this change.
- A lint, typecheck, or CI check is being silenced.
- A test is being weakened, skipped, or deleted so the run turns green.

When an applicable constraint exists and its Status is `accepted`, follow that file.

## Required document

Write `docs/constraints/<slug>.md` with these parts, in order:

1. `Status: draft`
2. `Open questions` — one question per unknown policy. If the human cannot answer now, stop after the draft.
3. `Checks` — every check names one enforcement point: test, hook, CI, review agent, or advisory policy.

Do not replace an open question with a guessed rule. Do not set Status to `accepted`.

## Stop

Stop before implementation when any check has no enforcement point, any open question is unanswered, or the request is to silence a check or change a test to get green. Fix the product code, not the test.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "No questions. Produce the quality bar tonight." | Unanswered policy stays in Open questions. A deadline does not invent the bar. |
| "The quality bar removes one gap." | A self-authored draft is not accepted. Each check still needs an enforcement point. |

## Red flags

- A constraint with no `Status: draft`
- A check with no enforcement point
- Guessed auth, storage, or rollout rules while the owner is offline
- Status set to `accepted`

All of these mean: restore the required document and stop.
