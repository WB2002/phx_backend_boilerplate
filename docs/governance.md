# Governance

No change reaches production unless it is verified by CI, reviewed by a human in proportion to its risk tier, documented in the same change, and reversible.

## Risk tiers

Numeric tiers stay so existing "tier 2" instructions still apply. The v2 name is the class.

| Tier | Class | Meaning | Required before implementation and merge |
| --- | --- | --- | --- |
| 0 | LOW | Docs, formatting, isolated tests | AI review, then CI |
| 1 | MEDIUM | Standard features, internal APIs, UI | Independent review, CI, and one human approval |
| 2 | HIGH | Auth, payments, PII, data migrations, infra, public API contracts | Human design review before `/plan`, an accepted architecture gate, an ADR, `security-reviewer`, a threat-model update, a rollback plan, a feature flag, staged rollout, and CODEOWNERS approval |
| — | CRITICAL | Security perimeters, production credentials, destructive data operations | A human owns the design and the plan. The orchestrator stops until that human has accepted both. AI does not draft the plan alone. |

## Autonomy

Autonomy is earned per repository and risk class. The default for this repo is L2.

| Level | Behavior |
| --- | --- |
| L0 | Human plans, implements, and verifies. The orchestrator may suggest and must not write application code. |
| L1 | AI suggests the plan and the change. A human executes. The orchestrator must not write application code. |
| L2 | AI implements one bounded task. A human reviews. Default. |
| L3 | AI implements, the verifier reports raw logs, and AI may open a PR only after that report. |
| L4 | Auto-merge of low-risk changes. Not enabled. Coverage and branch protection automation are not in place. |
| L5 | Autonomous remediation and canary deploy. Not enabled. Canary and rollback automation wait on an accepted stack ADR. |

The orchestrator must not merge or deploy at any level.

## Lifecycle

Status and lifecycle are separate. Status is `draft`, `accepted`, or `closed`. Only a human sets `accepted`.

Lifecycle stages are `DRAFT`, `READY_FOR_REVIEW`, `APPROVED`, `IN_PROGRESS`, `VERIFIED`, `MERGED`, `CANARY`, `OBSERVED`, and `BLOCKED`.

An agent may move a stage forward only when the evidence exists: an accepted spec, a verifier log, or a review report. It may set `BLOCKED` and must then stop. It must not set `APPROVED`, `MERGED`, or `CANARY`.

## Human leverage

These stay human decisions:

- Intent, business framing, and non-goals.
- User journeys, interaction behavior, and UX trade-offs.
- Novel architecture and data-boundary decisions.
- Security and privacy concessions.
- Accepting documented technical debt.

A person accepts the intent; for changes to information a user sees or actions a
user takes, that person also accepts `experience.md` after readonly UX review.
The person accepts the spec, accepts the architecture gate when the class is
HIGH, accepts ADRs, approves the plan, merges, and promotes to production. For
CRITICAL, that person also writes or accepts the design and the plan before any
agent plans or builds. Agents must not set Status to `accepted`.

## GitHub settings checklist

Apply these in GitHub. This repository does not change those settings.

- Require a pull request before merge.
- Require at least one approval from CODEOWNERS.
- Require status checks: `verify-full`, `secret-scan`, `static-analysis`, `dependency-audit`, `docs-check`, `pr-size`.
- Dismiss stale approvals when new commits are pushed.
- Require conversation resolution before merge.
- Block force pushes.
- Do not allow admin bypass.
- Protect the `production` environment and require reviewers.
- Turn on secret scanning and push protection.
- Turn on Dependabot alerts.
- Enable Bugbot for the repository.
- The agent's credentials cannot merge or approve, and they hold no production secrets.

## Hooks are not a security boundary

Hooks catch mistakes early. They are not a security boundary. An agent with shell access can bypass a Write hook. The backstops are CI, CODEOWNERS, and branch protection.
