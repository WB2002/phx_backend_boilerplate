---
name: plan
description: Produce an implementation plan from an approved spec (use in Plan mode)
disable-model-invocation: true
---
Argument: the intent slug. Read intent.md, spec.md, and experience.md when
present in intent/<slug>/.
If the spec class is CRITICAL, stop and tell the human to write the plan.
If the spec Risk tier is 2 (HIGH), stop unless intent/<slug>/architecture-gate.md
exists and its Status is `accepted`.
Read the codebase. Propose tasks as TASK-NNN with goal, requirements (one or more
REQ-NNN ids), `Experience: UX-NNN | none`, applicable states covered, files,
dependencies, acceptance criteria, tests, and risks. User-visible tasks must
trace to accepted UX-NNN criteria; unresolved UX stops planning. A task with no
requirement is debt, not scope. Also cover order of work, risks, proof, rollback,
flag and rollout, observability, docs impact, and the definition of done.
Visible-change proof includes browser or end-to-end evidence, accessibility
evidence, and screenshots when visual presentation changes. Other proof names
tests or commands.
Then interrogate the plan: what could this break, which step is riskiest, what
alternatives did you reject.
Iterate with me until someone who never saw this chat could implement it from the
plan alone. Only after I approve, write intent/<slug>/plan.md.
Do not implement until I say go. If implementation later departs from the plan,
update plan.md in the same change.
