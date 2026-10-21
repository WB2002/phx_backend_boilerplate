---
name: observability
description: Apply when adding or changing production behavior, logs, metrics, traces, alerts, or dashboards.
---
Read `docs/observability.md`. Before production, the plan's Observability section must say how operators know the feature works, is slow, is failing, and affects users, and how to roll it back.

Where the feature runs in production, include structured logs, metrics, traces, a business metric, an error metric, a latency metric, an alert, a dashboard, a runbook, and a rollback procedure.

Skip a line only when the plan states why it does not apply.
