# Review instructions

Run these passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, subtle regressions.
- **Security**: injection, auth gaps, secrets, personal data in logs.
- **Compliance**: if the PR touches intent/<slug>/, check the change matches that
  slug's spec.md and plan.md, and that plan departures are recorded.

## Severity
Important = would break behavior, leak data, or breach a policy. Style and naming are nits.
Report at most five nits; summarize the rest as a count.

## Do not report
Generated files and anything CI already enforces.

## Guardrails and debt
Flag these:
- Edits to guardrail paths (`.cursor/hooks.json`, `.cursor/hooks/`, `.cursor/BUGBOT.md`, `.cursorignore`, `scripts/verify*.sh`, `scripts/ratchet.sh`, `quality/`, `.github/`, `CODEOWNERS`).
- A new dependency without an ADR.
- A behavior change without docs, an ADR, or a CHANGELOG entry.
- Tests deleted or weakened.
- A `TODO` without an intent or issue reference.
- Changes outside the plan's scope.
- A tier-2 change missing rollback, a feature flag, or security review evidence.
