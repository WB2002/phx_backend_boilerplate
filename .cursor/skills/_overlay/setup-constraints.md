## Setup constraints

These rules override the rest of this skill when they conflict.

- Do not set Status to `accepted`. Only the human owner does.
- Do not set lifecycle to `APPROVED`, `MERGED`, or `CANARY`.
- Do not review your own change. Readonly reviewers report failures first.
- Do not merge or deploy.
- Do not commit, push, or open a pull request unless the user explicitly asks in this turn.
- Do not invent product scope or visible interaction behavior. Stop at the missing human gate.
- `/spec` writes `intent/<slug>/spec.md` from an accepted intent. Do not replace that path or treat a draft as accepted.
- ADRs go through `/record-decision` and `docs/adr/0000-template.md`. Leave Status `proposed`.
- Never weaken or delete a test to get green. If `.cursor/.fix-mode` exists, do not edit test files.
- Out-of-scope findings become an intent or a debt record, not part of the current diff.
- Do not edit `scripts/verify.sh`, `scripts/verify-full.sh`, or `.github/` unless the user has created `.cursor/.guardrails-edit`.
