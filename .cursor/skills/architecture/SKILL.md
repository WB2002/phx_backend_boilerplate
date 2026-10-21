---
name: architecture
description: Apply architecture rules when designing boundaries, modules, data flow, or making a structural choice.
---
- Read `docs/architecture.md` before changing system structure.
- Name what is inside the system and what stays outside. Name bounded contexts, aggregates, and invariants.
- A consequential choice (datastore, service boundary, sync vs async, public API style, or a new library) needs an ADR via `/record-decision` before implementation. Do not decide it silently in code.
