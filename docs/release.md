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

1. **Application Code Rollback**:
   Redeploy the previous container image **digest** (e.g. `IMAGE@sha256:...`). Because migrations follow the expand-contract pattern, the N-1 image remains compatible with the N database schema.

2. **Database Migration Rollback (Emergency last resort)**:
   ```bash
   docker run --rm -it --network host \
     -e DATABASE_URL="$DATABASE_URL" \
     -e RELEASE_COOKIE="$RELEASE_COOKIE" \
     <image:tag> /app/bin/phx_backend_boilerplate eval \
     "PhxBackendBoilerplate.Release.rollback(PhxBackendBoilerplate.Repo, <target_version>)"
   ```

## Flag policy

Tier 2 changes name a feature flag and rollout stages in `plan.md` before production.

## Rollback drill

Run a rollback drill every month.
