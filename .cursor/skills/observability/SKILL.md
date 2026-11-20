---
name: observability
description: Apply when adding or changing production behavior, endpoints, background jobs, logs, metrics, traces, alerts, or dashboards.
---

# Observability, Telemetry & Operational Readiness

## Purpose
Ensure operators and a solo founder can immediately detect whether a feature works, is slow, is failing, or is impacting users—and can diagnose and roll it back safely without exposing sensitive data.

## Inputs
- `docs/observability.md`, `docs/nfr.md`, `docs/threat-model.md`, and `intent/<slug>/plan.md`

## Execution

### Invariants
- Read `docs/observability.md`. Before production, the plan's **Observability** section must state how operators know the feature works, is slow, is failing, and affects users, and how to roll it back.
- **Zero Sensitive Data in Telemetry:** Never emit `PII`, `PHI`, passwords, API keys, session tokens, raw request bodies containing secrets, or full payment details in logs, span attributes, metrics labels, or error trackers (`security-baseline`).
- **Correlation & Trace Propagation:** Every inbound request, background job, and outbound dependency call must propagate a correlation/trace ID (`traceparent` / `request_id`) and a non-sensitive `tenant_id` / `actor_id` context in structured JSON logs.
- **Bounded Metric Cardinality:** Never use unbounded values (user IDs, email addresses, request IDs, raw URLs, timestamps) as metric labels/tags.

### Defaults
- Where a feature runs in production, include:
  1. **Structured Logs:** Event name, severity, correlation ID, latency `duration_ms`, and stable error code.
  2. **RED Metrics on Services/Endpoints:** Request **R**ate, **E**rror rate (`4xx` vs. `5xx`), and **D**uration histograms (`p50`, `p95`, `p99`) matched to `docs/nfr.md` SLOs.
  3. **USE Metrics on Queues/Resources:** **U**tilization, **S**aturation (queue depth/lag), and **E**rrors (dead-letter count, retry exhaustion).
  4. **Business Outcome Metric:** At least one counter/gauge proving the domain action succeeded or failed.
  5. **Actionable Alert & Runbook:** Every paging alert links to a runbook in `docs/runbooks/` with triage commands and the rollback procedure.

### Decisions
- **Sampling strategy:** Sample 100% of error traces and high-latency outliers; apply head or tail sampling to routine successful requests as defined in `docs/observability.md`.

### Exceptions
- Skip an observability item only when `intent/<slug>/plan.md` explicitly records why it does not apply (e.g., build-time-only type or static documentation change).
