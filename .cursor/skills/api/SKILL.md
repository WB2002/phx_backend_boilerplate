---
name: api
description: Apply when adding or changing endpoints, commands, queries, events, webhooks, or public contracts.
---

# API & Contract Design

## Purpose
Ensure every external and internal API surface has a verifiable schema, explicit authz/authn contract, idempotency semantics, bounded resource usage, and backward-compatible evolution.

## Inputs
- `intent/<slug>/spec.md`, `docs/architecture.md`, `docs/nfr.md`, and `docs/threat-model.md`

## Execution

### Invariants
- State whether the surface is a **command** (state-mutating), a **query** (side-effect-free read), or an **event/webhook** (asynchronous notification).
- Authenticate every non-public endpoint and enforce object-level and tenant-level authorization (`BOLA`/`IDOR` check) before executing business logic. Follow `security-baseline` and `security-sharp-edges`.
- Validate and parse all untrusted inputs (params, query, headers, body, webhook signatures) against a strict schema at the boundary; reject unexpected fields or malformed payloads before domain execution.
- A breaking or public contract change is Tier 2 (HIGH) and requires an ADR via `/record-decision` and an expand-migrate-contract deprecation plan before implementation.
- Never leak internal stack traces, SQL errors, filesystem paths, or internal identifiers in error responses.

### Defaults
- Use standard structured error contracts (such as RFC 9457 Problem Details: `type`, `title`, `status`, `detail`, `instance`, plus request correlation ID).
- Require an idempotency key or natural idempotency guarantee on all state-mutating `POST`/`PATCH` command endpoints and webhook consumers.
- Bound every collection query with cursor or limit/offset pagination, a maximum page size cap, and explicit timeout budgets.
- Enforce per-route rate limits and payload size limits at the edge/ingress boundary.

### Decisions
- **Versioning strategy (URI path, header, or additive evolution):** Settled in `docs/adr/`. Default to additive, backward-compatible evolution (new optional fields/endpoints) before introducing a breaking version bump.
- **Transport style (REST/HTTP, GraphQL, RPC, SSE/WebSockets):** Settled by `docs/adr/0001-stack.md` and `intent/<slug>/spec.md`.

### Exceptions
- Unauthenticated public endpoints (e.g., health probes, public webhooks) must be explicitly listed in `docs/threat-model.md` with signature verification or strict rate-limiting controls.
