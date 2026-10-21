---
name: incident-to-intent
description: Turn an alert, log excerpt or ticket into a new intent.md
disable-model-invocation: true
---
Given the pasted alert, log, ticket or metric breach: diagnose read-only (do not
change application code).

1. Write `docs/incidents/<kebab-slug>.md` from `docs/incidents/_template.md`. Include
   the evidence (what was observed, when, where).
2. Write `intent/<kebab-slug>/intent.md` from the intent template with Status: draft.
   Include the evidence, the proposed outcome, affected systems, and open questions.
3. Recommend an eval case under `evals/cases/<category>/` so this class of problem
   is caught next time. Category is architecture, security, coding, or regression.
