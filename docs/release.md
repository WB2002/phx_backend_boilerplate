# Release

## Pipeline stages

1. PR checks
2. Merge
3. Staging deploy
4. Smoke and end-to-end
5. Human approval
6. Progressive production rollout
7. Post-deploy smoke
8. Automatic rollback trigger

## Promotion rules by tier

- Tier 0: merge after CI and AI review.
- Tier 1: merge after CI and one human approval.
- Tier 2: staged rollout with a feature flag, a rollback plan, and CODEOWNERS approval. See [governance.md](governance.md).

## Migration policy

Expand, migrate, contract. Every migration is reversible and tested on production-like data.

## Rollback command

TODO: configure the rollback command — see docs/adr/0001-stack.md

## Flag policy

Tier 2 changes name a feature flag and rollout stages in `plan.md` before production.

## Rollback drill

Run a rollback drill every month.
