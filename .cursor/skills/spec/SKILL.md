---
name: spec
description: Use when an accepted feature intent is ready to become falsifiable technical requirements.
disable-model-invocation: true
---
Argument: the intent slug.
1. Read intent/<slug>/intent.md. If Status is not `accepted`, stop and tell me.
2. Read AGENTS.md and apply every relevant skill in .cursor/skills as a constraint.
3. Write intent/<slug>/spec.md from the template. Each requirement is REQ-NNN
   with Given, When, Then, and acceptance criteria. A requirement for
   user-visible behavior cites one or more accepted UX-NNN ids in Experience.
   A non-interactive requirement uses `Experience: none` with a reason.
   Keep Design short.
   A consequential structural choice is an ADR via `/record-decision`, not only
   a Design paragraph. Record which skills you applied, flagged concerns
   (especially where policies conflict), and open questions carried forward.
4. Do not write application code. Do not set Status to `accepted`.
