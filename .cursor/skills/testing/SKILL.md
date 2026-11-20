---
name: testing
description: Apply when writing or changing tests, verifying UI flows in a browser, writing property-based invariant checks, or implementing behavior that needs proof.
---

# Testing, Browser Verification & Property-Based Invariants

## Purpose
Prove behavior against falsifiable requirements (`REQ-NNN` and `UX-NNN`) using the right test layers—combining Red-Green-Refactor TDD, Playwright E2E browser verification, and property-based invariant testing.

## Inputs
- `intent/<slug>/spec.md`, `intent/<slug>/experience.md` (when present), and `intent/<slug>/plan.md`

## Execution

### Invariants
- **Order of Execution:** Spec first (`REQ-NNN` / `UX-NNN`), then a test that fails (`RED`), then minimal implementation (`GREEN`), then refactor. Never weaken, skip, or modify a failing test to make broken code pass. (Enforced during bug fixes by `.cursor/hooks/protect-tests.sh` when `.cursor/.fix-mode` exists).
- **Observable Outcome Assertions:** Assert the observable contract defined in `spec.md` (outputs, persisted state, HTTP status/error shape, emitted events, rendered accessible DOM)—never assert internal mock call counts that merely mirror implementation details.
- **Zero Flakiness Tolerance:** Never use arbitrary `sleep` / fixed-duration timers in tests. Use deterministic clocks, explicit condition polling, or event-driven synchronization.

### Defaults
- **Select Only the Required Layers:**
  - **Unit & Domain Invariant Tests:** Fast, isolated tests for pure domain logic, calculations, and state machines.
  - **Property-Based & Invariant Testing (Trail of Bits Pattern):** Use property-based testing (`fast-check`, `Hypothesis`, `proptest`, or stack equivalent) for parsers, serializers/deserializers, financial/billing math, pagination cursors, and authorization/tenant invariants (testing roundtrip `decode(encode(x)) == x`, idempotency `f(f(x)) == f(x)`, and invariant preservation across randomized edge-case inputs).
  - **Integration & Contract Tests:** Verify real database queries, migrations (up/down/data integrity), and API boundary schemas against real or containerized test dependencies rather than mocked SQL.
  - **Playwright Browser E2E Verification (Anthropic `webapp-testing` Pattern):** For user-visible changes (`Experience: UX-NNN`), verify the live rendered application using semantic/accessible locators (`getByRole`, `getByLabel`, `getByText`), exercise all applicable accepted states (`Loading`, `Empty`, `Success`, `Validation`, `System error`, `Partial failure`, `Permission denied`), and assert zero uncaught console errors or unexpected `4xx`/`5xx` network failures.
  - **Security & Negative Tests:** Include explicit negative tests for unauthenticated access (`401`), cross-tenant/unauthorized access (`403`/`404`), and malformed payloads (`400`/`422`).

### Decisions
- **Mocking boundary:** Mock only external third-party network services at the adapter boundary (using recorded fixtures or contract stubs); prefer real local/ephemeral instances for the project's primary datastore.

### Exceptions
- Any temporarily unautomated manual verification step must be documented in `intent/<slug>/plan.md` under `Proof` with exact reproduction commands and recorded in `docs/debt/` if deferred beyond the current release.
