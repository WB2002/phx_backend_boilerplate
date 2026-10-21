---
name: security-baseline
description: Apply baseline security rules. Use when creating or changing endpoints, auth, data handling, config or dependencies.
---
- Read `docs/threat-model.md` when the change crosses a trust boundary or handles sensitive data. Call out any abuse case you did not mitigate.
- Never put secrets, tokens or credentials in code, tests, logs or fixtures.
- Every non-public endpoint requires authentication; check authorization too.
- Validate and reject unexpected input at the boundary.
- Never log personal or sensitive data.
- Do not add or upgrade dependencies without saying so explicitly.
Mention which of these you checked, including the threat model, in your summary.
