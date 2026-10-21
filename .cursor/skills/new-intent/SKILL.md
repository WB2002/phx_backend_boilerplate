---
name: new-intent
description: Use when a feature is known only at a high level and its user, evidence, scope, or success criteria are unclear.
disable-model-invocation: true
---
# Discover a feature

Interview me one focused question at a time when the answer changes product
scope. Separate known facts, observed or user-reported evidence, assumptions,
and open questions.

For each proposed capability, name the user problem it solves and the
consequence of omitting it. Classify product capabilities:

- Must: the primary task fails or cannot be trusted without it.
- Should: a meaningful improvement that can wait.
- Later: speculative or advanced.

Security, privacy, data integrity, accessibility, and essential failure handling
are safeguards, not optional product capabilities.

Recommend the smallest coherent release. Do not turn guesses into implementation
defaults because review is near. Leave consequential unknowns open.

When every template section can be filled in the originator's terms, write
`intent/<kebab-slug>/intent.md` with `Status: draft`. Show it and stop. Do not
write an experience, spec, plan, or code.
