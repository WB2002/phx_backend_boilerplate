---
name: architecture
description: Apply architecture, boundary, and error-handling rules when designing modules, service boundaries, data flow, or making a structural choice.
---

# Architecture & System Boundaries

## Purpose
Preserve clean module boundaries, explicit trust boundaries, domain isolation, and deterministic error handling across the system.

## Inputs
- `docs/architecture.md`, `docs/nfr.md`, `docs/threat-model.md`, and `docs/adr/`
- `intent/<slug>/spec.md` and `intent/<slug>/architecture-gate.md` (when Tier 2 HIGH)

## Execution

### Invariants
- Read `docs/architecture.md` before changing system structure, module boundaries, or data ownership.
- Name what is inside the system and what stays outside: explicit bounded contexts, aggregates, trust boundaries, and domain invariants.
- Domain and business rules must not import or depend directly on HTTP transport, UI components, or low-level database/vendor SDK details.
- A consequential structural choice (datastore, service boundary, sync vs. async messaging, auth model, public API style, or a new core library) requires an ADR via `/record-decision` (`Status: proposed`) before implementation. Never decide it silently in code.
- Enforce circuit breaking, explicit timeouts, bounded retries with full jitter, and bulkhead isolation on all external network dependencies and queue boundaries (`resilience`).
- Never swallow errors silently or return ambiguous boolean failure flags across boundaries. Classify errors explicitly into domain/validation errors, transient/retryable failures, and fatal/system faults.

### Defaults
- Prefer deep modules (simple, narrow public interfaces hiding complex internal implementation) over shallow pass-through wrappers.
- Enforce idempotency and explicit timeouts on every cross-service, webhook, or background-job boundary.
- Fail closed when an upstream policy, permission, or configuration check cannot be verified.

### Decisions
- **Modular monolith vs. separate deployable service:** Default to a modular monolith with enforced module boundaries unless an accepted ADR in `docs/adr/` documents independent scaling, compliance isolation, or deployment cadence requirements.
- **Synchronous call vs. asynchronous queue/event:** Settled in `intent/<slug>/spec.md` and `docs/nfr.md` based on latency budgets, failure isolation, and eventual consistency tolerance.

### Exceptions
- Any temporary boundary violation must be recorded as a proposed debt entry via `/record-debt` (`docs/debt/TD-NNN-<slug>.md`) with an owner and resolution condition.
- Skipping an ADR on a Tier 2 (HIGH) structural change or failing open across a trust boundary can never be an exception.
