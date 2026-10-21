---
name: record-decision
description: Write the next architecture decision record and index it
disable-model-invocation: true
---
Argument: the decision title.

1. Read `docs/adr/` and take the next sequential number.
2. Write `docs/adr/NNNN-<slug>.md` with Status, Context, Decision, Alternatives
   considered, and Consequences. Link the related intent and spec.
3. Add the ADR to `docs/adr/README.md`.
4. Do not mark Status accepted. I do that.
