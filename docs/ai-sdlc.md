# AI-SDLC runbook

AI generates implementation. Correctness stays in artifacts, tests, and policies. Humans accept intent, experience, spec, the architecture gate, ADRs, and the plan. Agents may prepare evidence and must not manufacture an approval.

## How to use this

1. Copy this setup into a new product repo. Do not build the product in this config repo.
2. Run `/project-brief` first. You accept `docs/adr/0001-stack.md`. Until that ADR is accepted, build, test, lint, and the audit jobs stay as failing TODOs.
3. Create `.cursor/.guardrails-edit` or `.agents/.guardrails-edit` yourself before anyone replaces those TODOs. The agent is blocked from editing `scripts/verify.sh` and the CI workflow without it.
4. For each feature: `/new-intent`, then you accept its product scope. If the
   change alters information a user sees or an action a user takes, run
   `/design-experience`, start `ux-reviewer`, and accept `experience.md`. Then
   run `/spec`, accept it, run `/architecture-gate` when HIGH, and run `/plan`.
   For CRITICAL work you write the design and plan. Agents mark nothing accepted.
5. `/orchestrate` only writes `intent/<slug>/orchestration.md` and names the next role. You still start the builder, the verifier, and the reviewers. The builder does not review its own change.
6. You merge. L4 and L5 stay off. A policy line set to `enforced` does nothing until a CI check or hook implements it. Staging and canary do not exist until you add a deploy workflow.

## Slash commands

- `/new-intent` — discover the user, evidence, Must/Should/Later scope, and
  outcome; write `intent.md` with Status: draft and stop.
- `/design-experience <slug>` — from an accepted intent, write the draft user
  journey, states, screens, trade-offs, and UX-NNN criteria; stop for review and
  human acceptance.
- `/spec <slug>` — turn accepted product artifacts into `spec.md`. Each
  requirement is REQ-NNN with Given, When, Then and `Experience: UX-NNN | none`.
  No application code.
- `/architecture-gate <slug>` — recommend PASS or FAIL in `intent/<slug>/architecture-gate.md`. Do not set Status to accepted.
- `/plan <slug>` — in Plan mode, write `plan.md` only after you approve it. HIGH (tier 2) stops until the architecture gate Status is accepted. CRITICAL stops and the human writes the plan. Each task cites `REQ-NNN` ids. Do not implement until you say go.
- `/orchestrate <slug>` — write `intent/<slug>/orchestration.md` and name the next role. Does not implement, review, merge, or deploy.
- `/fix-bug` — failing test first, then freeze tests with `.cursor/.fix-mode` or `.agents/.fix-mode`, then fix code only.
- `/incident-to-intent` — read-only diagnosis, then `docs/incidents/<slug>.md` and a new draft intent.
- `/record-debt` — write a proposed entry in `docs/debt/`. Accepted debt is tracked, not hidden.



## Built-in Cursor skills

- `/review` — review the change before you merge.
- `/review-bugbot` — Bugbot pass using `.cursor/BUGBOT.md`.
- `/autopilot` — babysit a PR until CI is green.

 

## Hooks

Hooks enforce guardrails in both Cursor (`.cursor/hooks.json`) and Antigravity (`.agents/hooks.json`):
- `protect-tests.sh` — while `.cursor/.fix-mode` or `.agents/.fix-mode` exists, blocks writes to test files.
- `protect-guardrails.sh` — blocks writes to guardrail files unless `.cursor/.guardrails-edit` or `.agents/.guardrails-edit` exists.
- `manifest-guard.sh` — blocks direct editing of dependency manifests (`package.json`, etc.); directs to `/add-dependency`.
- `production-gate.sh` — asks a human before a command that looks like a production deploy, release, apply, upgrade, or publish.
- `install-guard.sh` — asks a human before package installation commands (`npm install`, `pip install`, etc.).
- `block-secrets.sh` — blocks reads of `*/.env`, `*/.env.*`, `secrets/`, `*.pem`, and `*.key`. Example env files stay readable.
- `verify-on-stop.sh` — runs `scripts/verify.sh` on stop when source files have been changed.



## Human gates

A person accepts the intent, accepts experience.md for user-visible work, accepts
the spec, accepts the architecture gate when HIGH, accepts ADRs, approves the
plan, merges the PR, and approves production deploys. For CRITICAL, that person
owns the design and plan before any agent plans or builds. Product scope, UX
trade-offs, novel architecture and data boundaries, security and privacy
concessions, and accepting debt stay human decisions.

Must, Should, and Later prioritize product capabilities only. Security, privacy,
data integrity, accessibility, and essential failure handling remain mandatory.

## Where the control plane lives

- Constitution → `.cursor/skills/` and `.agents/skills/` (`architecture`, `testing`, `observability`, `database`, `api`, `operations`, `dependency-policy`, `security-baseline`, `constraint-driven-development`, `source-driven-development`, `code-simplification`). Engineering principles stay in `AGENTS.md` (and `GEMINI.md`).
- Product workflow skills → `.cursor/skills/new-intent/` and
  `.cursor/skills/design-experience/` (mirrored in `.agents/skills/`).
- Role and review agents → `.cursor/agents/` and `.agents/agents/` (`orchestrator`, `architect`,
  `backend-engineer`, `frontend-engineer`, `ux-reviewer`, `security-reviewer`,
  `test-engineer`, `performance-reviewer`, `code-reviewer`, plus
  `plan-auditor`, `doc-auditor`, `verifier`).
- Policy declarations → `.cursor/policies/` and `.agents/policies/` (`architecture.yaml`, `security.yaml`, `quality.yaml`, `deployment.yaml`). Levels are `enforced`, `advisory`, or `deferred`.
- Rules → `.cursor/rules/*.mdc` (Cursor) and `.agents/rules/*.md` (Antigravity).
- Lifecycle Hooks → `.cursor/hooks.json` (Cursor) and `.agents/hooks.json` (Antigravity).
- Evals → `evals/cases/{architecture,security,coding,regression}/`.
- Debt ledger → `docs/debt/`.
- Engineering memory → `docs/adr/`, `docs/runbooks/`, `docs/incidents/`, `docs/postmortems/`, `docs/lessons/`, `docs/constraints/`.



## Policy skills

Add `.cursor/skills/<name>/SKILL.md` with `name` equal to the folder. Omit `disable-model-invocation` so the description can auto-apply. Workflow skills set `disable-model-invocation: true` and run only when you type `/name`.

Constitution skills apply from their descriptions. `.cursor/policies/` records what is already enforced, what is advisory, and what waits on an accepted stack ADR.

## Same mistake twice

Add a line under **Things the agent gets wrong** in `AGENTS.md`. A repeated lesson can also become a skill or a policy. See `docs/lessons/`.

## More slash commands

- `/idea-to-blueprint` — walk a high-level product idea down a 7-level zoom ladder (vision, core loop, journey, screens/states, rules/data, hit details, build plan) via recommended options into a buildable Product Blueprint.
- `/project-brief` — interview, then write the product brief, NFRs, an architecture stub, and a proposed stack ADR.
- `/record-decision` — write the next ADR and index it.
- `/doc-sync` — update docs from the diff and the plan's Docs impact.
- `/add-dependency` — justify, check the registry, and install only after approval.
- `/debt-sweep` — read-only debt list; skip items already in `docs/debt/`; draft intents for the top untracked items.



## Architecture gate

Before `/plan` on a HIGH (tier 2) spec, `/architecture-gate` writes a checklist and recommends PASS or FAIL. It is a gate, not a numeric score. A human sets Status to accepted. LOW skips this gate. CRITICAL does not reach `/plan` until a human has accepted the design and the plan.

## Orchestration

`/orchestrate` sequences roles and writes the evidence log. Before `/spec`, a
draft experience goes to `ux-reviewer`, then stops for human acceptance. After
`/plan`: one builder task (`backend-engineer` or `frontend-engineer`),
`verifier`, `ux-reviewer` for user-visible work, then `architect`,
`security-reviewer`, `test-engineer`, `performance-reviewer`, and
`code-reviewer`. The builder is never a reviewer. The orchestrator is never the
builder or approver.

Default autonomy is L2: one bounded task, then a human review. L0 and L1 suggest only. L4 and L5 are not enabled. No level may merge or deploy.

Lifecycle is separate from Status: `DRAFT`, `READY_FOR_REVIEW`, `APPROVED`, `IN_PROGRESS`, `VERIFIED`, `MERGED`, `CANARY`, `OBSERVED`, and `BLOCKED`. An agent may advance a stage only with evidence. It must not set `APPROVED`, `MERGED`, or `CANARY`.

## Review separation

The agent that implements a change does not review it. UX, architecture,
security, tests, performance, and code quality go to readonly agents. Those
reviews look for requirement violations before they suggest improvements.

## Risk tiers

Tier 0 is LOW: AI review, then CI. Tier 1 is MEDIUM: independent review, CI, and one human approval. Tier 2 is HIGH: design review before implementation. CRITICAL is human-owned design and plan.
Full rules, autonomy levels, and the GitHub checklist are in [governance.md](governance.md).