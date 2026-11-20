---
name: database
description: Apply when changing schema, queries, migrations, transactions, retention, backups, or data ownership.
---

# Database, Schema & Migration Safety

## Purpose
Protect data integrity, multi-tenant isolation, query performance, zero-downtime migration safety, and verified backup recovery.

## Inputs
- `docs/architecture.md`, `docs/release.md`, `docs/nfr.md`, `docs/threat-model.md`, and `intent/<slug>/spec.md`

## Execution

### Invariants
- Name the owning bounded context for each entity, its transaction/consistency boundary, and its retention and deletion rule.
- All production schema changes follow **expand, migrate, contract** (`docs/release.md`):
  1. **Expand:** Add nullable columns, new tables, or non-blocking indexes compatible with currently running code.
  2. **Migrate:** Backfill data in bounded batches with throttling and idempotency.
  3. **Contract:** Remove deprecated columns/constraints only in a subsequent release after all active code paths stop reading/writing them.
- Every migration must define a verification check and a tested rollback or forward-repair path. Never rewrite or delete an already-merged migration file.
- Enforce multi-tenant isolation at the data layer (Row-Level Security or mandatory tenant-scoped repository context; see `security-sharp-edges`). Never rely on callers remembering an optional `tenant_id` filter.
- Never store plaintext passwords, raw API secrets, or unencrypted crown-jewel credentials. Do not log personal, health (`PHI`), or sensitive (`PII`) data in query logs.

### Defaults
- Set explicit statement and lock timeouts on migrations (`lock_timeout`, `statement_timeout`) so a schema change fails fast rather than queueing behind long transactions and taking down production traffic.
- Build indexes concurrently (`CREATE INDEX CONCURRENTLY` or stack equivalent) on existing tables.
- Verify every new query access path has supporting index coverage (`EXPLAIN` / query plan check), avoids `N+1` query loops, and selects only required columns.
- Wrap multi-step state mutations in an explicit ACID transaction or outbox pattern when cross-service events are emitted.

### Decisions
- **Soft delete vs. hard delete / cryptographic erasure:** Settled by `intent/<slug>/spec.md` and compliance/retention rules in `docs/nfr.md`.
- **Isolation level & locking (`READ COMMITTED` vs. `SERIALIZABLE` / `SELECT ... FOR UPDATE`):** Choose explicit row locking or serializable isolation for financial, inventory, quota, or clinical concurrency invariants.

### Exceptions
- Destructive contract-phase drops in production require an accepted migration plan, a verified backup/PITR snapshot prior to execution, and explicit human approval via `production-gate.sh`.
