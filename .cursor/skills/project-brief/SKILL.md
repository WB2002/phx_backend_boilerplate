---
name: project-brief
description: Interview for a product brief, NFRs, an architecture stub, and a proposed stack ADR
disable-model-invocation: true
---
Interview me, one or two questions at a time, about the concept: problem, users,
success metrics, scope and non-goals, scale assumptions, data sensitivity,
availability and latency expectations, compliance needs.

Then write:
- `docs/product-brief.md`
- `docs/nfr.md` with measurable targets (SLOs, latency budgets, retention, compliance)
- a stub `docs/architecture.md` using the headings System boundaries, Domain, Data, APIs, Infrastructure, and Non-functional requirements. Measurable targets stay in `docs/nfr.md`. Sensitivity stays in `docs/threat-model.md`.
- `docs/adr/0001-stack.md` with Status: proposed, for me to approve

Do not mark the ADR accepted. Recommend the first intent: a walking skeleton
(repo, CI, staging deploy, logging and metrics, and one end-to-end test) before
any feature work.
