---
name: fast-track
description: Single-pass discovery, experience, spec, and plan generator for low/medium-risk (Tier 0 and Tier 1) changes, stopping at one unified human acceptance gate before coding.
disable-model-invocation: true
---

# Solo Fast-Track Planning (`/fast-track <slug>`)

Argument: the feature or change slug (`<slug>`).

## Purpose
Give a solo builder maximum planning speed on **Tier 0 (`LOW`)** and **Tier 1 (`MEDIUM`)** work by drafting `intent.md`, `experience.md` (when user-visible), `spec.md`, and `plan.md` in one cohesive pass with a 3-lens self-challenge (`gstack /autoplan` pattern), stopping at a **single unified human acceptance gate** before implementation begins.

> **Hard Safety Boundary:** `/fast-track` is strictly forbidden for **Tier 2 (`HIGH`)** and **`CRITICAL`** changes. If the change touches authentication, authorization, cryptography, multi-tenant isolation boundaries, public API breaking contracts, destructive schema migrations, payment/billing flows, or regulated `PHI`/`PII` boundaries, **STOP immediately** and use the full multi-stage workflow (`/new-intent` → `/design-experience` → `/spec` → `/architecture-gate` → `/plan`).

---

## Step 1: Risk Tier Triage & Focused Interview
1. Read `AGENTS.md`, `docs/architecture.md`, `docs/threat-model.md`, and `docs/governance.md`.
2. Classify the requested change's Risk Tier (`0 LOW`, `1 MEDIUM`, `2 HIGH`, or `CRITICAL`).
   - If `2 HIGH` or `CRITICAL`: stop and tell the human owner why this change requires the full multi-gate SDLC and `/architecture-gate`.
3. If product scope, primary user outcome, or visible interaction behavior has consequential unknowns, ask at most **1–2 focused questions at a time** until the scope is clear. Do not invent product requirements silently.

## Step 2: 3-Lens Internal Challenge (`/autoplan` Gear)
Before writing the artifacts, challenge the proposal across three lenses and include the conclusions in the drafts:
1. **Product Wedge Lens (CEO):** What is the smallest coherent release (`Must`), and what can be deferred (`Should` / `Later`) without compromising trust?
2. **UX & States Lens (Design):** Does this change information a user sees or an action a user takes? If yes, map all applicable states (`Loading`, `Empty`, `Success`, `Validation`, `System error`, `Partial failure`, `Permission denied`) as `UX-NNN`. If non-interactive, record `Experience: none` with a reason.
3. **Architecture & Security Lens (Engineering):** Which existing utilities/modules will be reused? Which test layers (`REQ-NNN` → failing test first) and rollback steps apply?

## Step 3: Draft the Unified Artifact Bundle in `intent/<slug>/`
Using the templates in `intent/_templates/`, write all required files with **`Status: draft`**:
1. `intent/<slug>/intent.md` (`Status: draft`)
2. `intent/<slug>/experience.md` (`Status: draft`) — *required when the change is user-visible; omit only when `Experience: none` applies.*
3. `intent/<slug>/spec.md` (`Status: draft`) — falsifiable `REQ-NNN` with `Given / When / Then` and `Experience: UX-NNN | none`.
4. `intent/<slug>/plan.md` (`Status: draft`) — `TASK-NNN` traced to `REQ-NNN` and `UX-NNN`, files to touch, failing-first tests, proof commands, rollback, observability, and docs impact.

## Step 4: Single Human Acceptance Gate (STOP)
- Present a concise summary table of the drafted artifacts (`intent.md`, `experience.md`, `spec.md`, `plan.md`), the risk tier (`LOW` or `MEDIUM`), and any trade-offs or open assumptions.
- **Do not set `Status: accepted` on any artifact.** Only the human owner sets `Status: accepted`.
- **Do not write application code.** Once the human owner accepts the bundle and says go, execute tasks one `TASK-NNN` at a time via TDD and independent verification (`qa` and `code-reviewer`).
