---
name: doubt-driven-development
description: Use when making high-stakes architectural, security, concurrency, data-migration, or unfamiliar codebase decisions to force an in-flight adversarial self-check before locking in code.
---

# Doubt-Driven Development (Epistemic Self-Interrogation)

## Overview
AI agents default to confident, sycophantic first-pass generation—even when an underlying assumption about concurrency, tenant isolation, failure recovery, or existing codebase behavior is flawed. When the cost of a wrong assumption is high, stop and run an explicit adversarial self-check **before** locking in the design or implementation.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use
- Modifying authentication, authorization, cryptography, or multi-tenant data boundaries.
- Writing database migrations, backfills, destructive state transitions, or concurrency/locking logic.
- Debugging an intermittent failure or touching an unfamiliar/legacy module with subtle invariants.
- Whenever the user proposes a shortcut that feels plausible on the surface but could break an invariant under load or partial failure.

## The Core Loop: `CLAIM → EXTRACT → DOUBT → RECONCILE → STOP`

Before writing or finalizing high-stakes code, walk through these five steps explicitly:

1. **CLAIM:** State the proposed implementation or fix in one sentence.
2. **EXTRACT:** List the 2–4 hidden assumptions required for that claim to be safe (e.g., *"Assumes webhook events arrive in order"*, *"Assumes `user.orgId` always matches the requested resource's `orgId`"*, *"Assumes the table is small enough to lock during migration"*).
3. **DOUBT:** Attack each assumption adversarially:
   - What happens if two requests arrive concurrently?
   - What happens if the network call fails halfway through after the DB write?
   - What happens if an authenticated user passes another tenant's UUID?
   - What evidence in the repository or official docs actually proves this assumption?
4. **RECONCILE:** Replace any unverified or fragile assumption with a deterministic control (e.g., idempotency key + unique constraint, `SELECT ... FOR UPDATE`, tenant-scoped query context, expand-migrate-contract migration) or verify it directly in source/docs.
5. **STOP (When Unresolved):** If reconciling the doubt requires a product, security, or compliance trade-off not settled by `intent.md`, `spec.md`, or `docs/adr/`, stop and surface the exact question to the human owner instead of guessing.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "That edge case is unlikely in practice." | In production, concurrent retries, duplicate webhooks, and partial network failures happen daily. Design for them upfront. |
| "The user asked for a quick implementation, not an interrogation." | Shipping a silent race condition or tenant leak takes 10x longer to unwind than a 30-second `CLAIM → DOUBT → RECONCILE` check. |
| "The existing tests pass, so the assumption holds." | Passing happy-path unit tests rarely exercise concurrency, malicious IDs, or partial outage states. |

## Red Flags
- Implementing a payment, authz, quota, or state-mutation flow without checking concurrency and idempotency
- Assuming an external webhook or queue delivers messages exactly once and in order
- Agreeing with a user's technical assumption when the codebase or threat model contradicts it
