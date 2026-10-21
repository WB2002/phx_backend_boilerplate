---
name: architecture-gate
description: Recommend PASS or FAIL for a tier's architecture before planning
disable-model-invocation: true
---
Argument: the intent slug.

1. Read `intent/<slug>/intent.md` and `intent/<slug>/spec.md`. If the spec is missing, stop.
2. Read `docs/architecture.md`, `docs/threat-model.md`, `docs/nfr.md`, and `docs/adr/`.
3. Write `intent/<slug>/architecture-gate.md` from `intent/_templates/architecture-gate.md`.
   Set Recommendation to `PASS` or `FAIL`. Set Status to `draft`.
4. Do not implement. Do not set Status to `accepted`.
