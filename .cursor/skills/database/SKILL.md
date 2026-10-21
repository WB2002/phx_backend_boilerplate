---
name: database
description: Apply when changing schema, queries, migrations, retention, or data ownership.
---
- Name the owning context for each entity, the consistency requirement, and the retention rule.
- Migrations follow expand, migrate, contract, as in `docs/release.md`. Each migration is reversible and tested on production-like data.
- Do not log personal or sensitive data. See the security-baseline skill.
