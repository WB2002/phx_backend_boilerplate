---
name: ship-check
description: Run a comprehensive pre-merge release readiness check combining deterministic verification, differential security blast-radius review, migration/rollback safety, and doc-sync audit.
disable-model-invocation: true
---

# Pre-Merge Release Readiness Gate (`/ship-check [<slug>]`)

Argument: optional intent slug (`<slug>`).

Read-only verification and release-readiness gate (except when you explicitly ask it to run `/doc-sync`). Does not commit, push, merge, deploy, or mark artifacts `accepted`.

## Purpose
Give a solo builder a single pre-flight command before merging or releasing that combines deterministic test/skill checks, Trail of Bits differential blast-radius review, database migration and rollback verification, and documentation synchronization check.

---

## Step 1: Artifact & Human Gate Audit
1. If `<slug>` is provided (or inferred from modified `intent/<slug>/` files), inspect `intent/<slug>/intent.md`, `experience.md` (when user-visible), `spec.md`, `architecture-gate.md` (when Tier 2 HIGH), and `plan.md`.
2. Verify that every required upstream artifact has `Status: accepted` set by the human owner and that every `REQ-NNN` and `UX-NNN` in `spec.md` is covered by the implementation and tests.
3. Verify independent review separation: confirm that required readonly review reports exist under `intent/<slug>/reports/` (e.g., `qa-bug-report.md`, `ux-reviewer` report for visible work, `security-baseline-review.md` / `security-audit-report.md` for Tier 2 HIGH) and have zero unresolved blocking findings.

## Step 2: Deterministic Verification Suite
Execute the repository's verification commands and capture raw outputs and exit codes (`verification-before-completion`):
1. `scripts/check-skills.sh`
2. `scripts/check-docs.sh`
3. `scripts/verify.sh` (report exit code 1 honestly if `docs/adr/0001-stack.md` is not yet accepted; otherwise require exit code 0).

## Step 3: Differential Security & Blast-Radius Audit (Trail of Bits `differential-review` Pattern)
Inspect `git status` and `git diff` against the base branch:
1. **Trust Boundary & Blast Radius:** List every modified route, auth check, tenant query, external egress/AI call, dependency manifest, or infrastructure config.
2. **Sharp Edges & Secrets Scan:** Check the diff for any hardcoded credentials, fallback secrets (`|| 'default'`), fail-open catch blocks, missing tenant scoping, or unparameterized queries (`security-baseline` and `security-sharp-edges`).
3. **PR Size & Scope Discipline:** Check whether changed lines exceed the 400-line CI `pr-size` threshold or include out-of-scope drive-by edits not traced to `plan.md`.

## Step 4: Migration, Observability & Rollback Readiness
1. **Database Migrations (`database`):** Confirm any schema change follows expand-migrate-contract, sets lock/statement timeouts, and has a tested rollback or forward-repair path.
2. **Observability (`observability`):** Confirm structured logs (zero `PII`/`PHI`), metrics, and error tracking match `plan.md`.
3. **Rollback & Feature Flags (`operations`):** Confirm the rollback command and recovery time (`RTO`) are documented, and Tier 2 changes are gated behind a feature flag.
4. **Documentation Sync (`doc-sync`):** Check whether `README.md`, `docs/architecture.md`, `docs/ai-sdlc.md`, runbooks, or `CHANGELOG.md` require updates to match the diff.

## Step 5: Release Readiness Scorecard Output
Output this structured scorecard in chat:

```markdown
# Ship-Check Release Readiness Scorecard: <slug or branch>
Risk Tier: <0 LOW | 1 MEDIUM | 2 HIGH | CRITICAL>
Overall Verdict: READY FOR HUMAN MERGE | BLOCKED (<N> blockers)

| Gate | Status (PASS / FAIL / N/A) | Evidence / Notes |
| --- | --- | --- |
| 1. Artifact Acceptance (`intent`, `experience`, `spec`, `plan`) | | |
| 2. Independent Review Reports (`qa`, `ux`, `security`, `code`) | | |
| 3. Deterministic Checks (`check-skills`, `check-docs`, `verify.sh`) | | |
| 4. Differential Security & Sharp-Edges Diff Audit | | |
| 5. Migration Safety, Observability & Rollback Readiness | | |
| 6. Documentation & `CHANGELOG.md` Sync | | |

## Raw Verification Output
```text
<exact command output and exit codes>
```

## Blocking Items (If Any)
1. ...
```
