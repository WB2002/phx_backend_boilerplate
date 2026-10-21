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
  `/design-experience`. A draft experience goes to `ux-reviewer`. After that
  review, set `BLOCKED` until a human accepts the experience. Non-interactive
  work records `Experience: none` and skips UX review.
- Class CRITICAL: stop until a human has accepted the design and the plan. Do not call `/plan`.
- Class HIGH: stop until `intent/<slug>/architecture-gate.md` exists and its Status is `accepted`. Planner is `/plan`.
- Class LOW: the architecture gate is not required. Planner is `/plan`.
- Class MEDIUM: Planner is `/plan`. One human approval is required before merge.
- After an approved plan, the builder is `backend-engineer` or `frontend-engineer` for one `TASK-NNN` only.
- Then `verifier` runs commands and does not patch.
- For user-visible work, `ux-reviewer` follows `verifier`.
- Then the independent reviewers: `architect`, `security-reviewer`,
  `test-engineer`, `performance-reviewer`, and `code-reviewer`. The builder is
  never one of them.
- Merge stays a human gate at every autonomy level.
