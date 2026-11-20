---
name: orchestrate
description: Sequence planner, builder, verifier, and independent reviewers for one intent
disable-model-invocation: true
---
Argument: the intent slug.

1. Read `intent/<slug>/intent.md`, `experience.md` when present, `spec.md` when
   present, `docs/governance.md`, and `.cursor/policies/`. Read
   `architecture-gate.md` when the class is HIGH or CRITICAL. Read `plan.md` if
   it exists.
2. Write only `intent/<slug>/orchestration.md` from `intent/_templates/orchestration.md`. Record the risk class, autonomy level, lifecycle stage, next role, and evidence links. Set Status to `draft`.
3. Apply the stop rules, then name the next role. Do not implement. Do not review the diff. Do not merge or deploy. Do not set Status to `accepted`. Do not set lifecycle to `APPROVED`, `MERGED`, or `CANARY`. You may set lifecycle to `BLOCKED` and must then stop.

Stop rules:

- Autonomy L0 or L1: suggest only. Do not write application code. Next role is the human.
- Before `/spec`, user-visible work with no `experience.md` goes to
  `ui-ux-researcher`, `/design-experience`, and `ui-ux-designer`. A draft experience goes to `ux-reviewer`. After that
  review, set `BLOCKED` until a human accepts the experience. Non-interactive
  work records `Experience: none` and skips UX review.
- Class CRITICAL: stop until a human has accepted the design and the plan. Do not call `/plan` or `system-architect`.
- Class HIGH: stop until `intent/<slug>/architecture-gate.md` exists and its Status is `accepted`. Planner is `/plan` (`system-architect`) and `tests-planner`.
- Class LOW: the architecture gate is not required. Planner is `/plan` (`system-architect`) and `tests-planner`.
- Class MEDIUM: Planner is `/plan` (`system-architect`) and `tests-planner`. One human approval is required before merge.
- After an approved plan, `tests-writer` implements planned tests and the builder is `backend-engineer`, `frontend-engineer`, `database-implementer`, `infrastructure`, `devops`, or `observability` for one `TASK-NNN` only.
- Then `qa` (`verifier`) runs verification commands, browser checks, and exploratory testing, and does not patch.
- For user-visible work, `ux-reviewer` follows `verifier` (`qa`).
- Then independent verification and reviews, proportional to risk tier and scoped to the diff:
  - **Tier 0 (LOW):** `qa` (`verifier`) and `code-reviewer` only.
  - **Tier 1 (MEDIUM):** `qa` (`verifier`), `code-reviewer`, `security-reviewer-baseline`, plus specialist reviewers only when their domain appears in `git diff` or task scope (`ux-reviewer` if UI files changed, `database-reviewer` if schema/queries changed, `performance-reviewer` if hot paths/loops/queries changed, `devops` if CI/CD or container configs changed).
  - **Tier 2 (HIGH) & CRITICAL:** Full specialist review suite (`security-reviewer-baseline`, `security-reviewer-hardening`, `database-reviewer`, `performance-reviewer`, `compliance-reviewer`, `tests-planner`, `devops`, `code-reviewer`) and `/ship-check`.
- Approved specialist review reports are remediated by `performance-implementer`,
  `security-implementer`, `database-implementer`, or `compliance-implementer`, followed by
  re-verification by `qa` and the matching reviewer. The builder is never one of the reviewers.
- Merge and production deployment stay human gates at every autonomy level.
