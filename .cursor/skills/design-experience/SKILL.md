---
name: design-experience
description: Use when an accepted feature intent changes information a user sees or an action a user takes, and the journey or interaction behavior is not approved.
disable-model-invocation: true
---
# Design an experience

Argument: the intent slug. Read `intent/<slug>/intent.md`. Stop unless its
Status is `accepted`.

Interview me one focused question at a time when the answer changes the journey,
information priority, permissions, destructive behavior, or recovery. Separate:

- accepted product facts
- design recommendations
- assumptions and open product decisions

For each consequential interaction, compare reasonable approaches and recommend
one with its trade-off. Do not convert an "obvious" choice into an approved
requirement.

Write `intent/<slug>/experience.md` from the template. Define the primary
journey, screens and information priority, applicable interaction states,
confirmation and recovery, navigation, accessibility, responsive behavior, a
Mermaid flow, and falsifiable `UX-NNN` criteria. Omit an inapplicable state with
a reason.

This artifact defines product experience, not technical architecture, APIs, or
implementation code. Preserve unresolved policy as an open question.

Set `Status: draft`, show the artifact, and stop. Do not set `accepted`, write a
spec, plan, or code.
