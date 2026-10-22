# Spec: Hardened Production Container Image
Source: intent/hardened-container-image/intent.md (accepted 2026-10-22)
Lifecycle: APPROVED

## Requirements

### REQ-001: Context Hygiene & Denial-by-Default
Experience: none
Given: A repository containing application code, developer documentation, tests, AI assistant policies (`.agents/`, `.cursor/`), and secret files (`.env*`).
When: `docker build` is executed.
Then: The Docker daemon receives a sanitized build context governed by a deny-by-default `.dockerignore`.
Acceptance criteria:
- All `*.md` files (including `README.md`, `AGENTS.md`, `CHANGELOG.md`), `.agents/`, `.cursor/`, `.github/`, `.githooks/`, `docs/`, `intent/`, `evals/`, `test/`, `scripts/`, `tmp/`, `_build/`, `deps/`, `.elixir_ls/`, and `.env*` are excluded.
- Only required build artifacts (`mix.exs`, `mix.lock`, `config/`, `lib/`, `priv/`, `assets/`, `rel/`) are transmitted into the build context.

### REQ-002: Multi-Stage OTP Release Build
Experience: none
Given: Elixir and Erlang sources with asset pipelines (`assets/`) and native NIF dependencies (`argon2_elixir`).
When: The multi-stage `Dockerfile` is built with `docker buildx build`.
Then: 
- Stage 1 (`builder`) uses `hexpm/elixir:1.20.0-erlang-27.0-debian-bookworm-20240904-slim` (digest pinned), installs minimal build packages (`build-essential git ca-certificates`), fetches prod deps, compiles assets (`mix assets.deploy`), and compiles an OTP release (`MIX_ENV=prod mix release`).
- The build-time generated cookie (`releases/COOKIE`) is deleted from the release directory.
- Stage 2 (`runtime`) uses `debian:bookworm-slim` (digest pinned), copies only the compiled release and required dynamic runtime libraries (`libstdc++6`, `openssl`, `libncurses6`, `ca-certificates`).
- The final image contains no Erlang/Elixir compiler, no `git`, no `make`/`gcc`, no `curl`/`wget`, and no development tooling.

### REQ-003: Non-Root Execution & Hardened Filesystem
Experience: none
Given: The runtime container starts in an orchestrator (Kubernetes, ECS).
When: The process launches.
Then:
- Runs as an unprivileged user with numeric UID/GID `10001:10001` and shell `/usr/sbin/nologin`.
- All setuid/setgid bits in the filesystem are stripped during image construction.
- Code directory `/app` is owned by `root:root` with read-only permissions (`chmod -R go-w /app`) so the application process cannot tamper with its own binary or bytecode.
- The container can execute with `--read-only` root filesystem when `/tmp` is mounted with `tmpfs`.
- Default entrypoint executes `/app/bin/server` (with `PHX_SERVER=true`).

### REQ-004: Release Management & Database Migration Helper
Experience: none
Given: A database schema upgrade needed before deploying the application.
When: An operator or init-container executes `/app/bin/migrate`.
Then:
- It invokes `PhxBackendBoilerplate.Release.migrate/0`, running all pending Ecto migrations idempotently.
- A rollback function `PhxBackendBoilerplate.Release.rollback/2` is available for disaster recovery.

### REQ-005: Automated Security Verification Script
Experience: none
Given: A built container image `phx_backend_boilerplate:verify`.
When: `scripts/docker-verify.sh` is executed.
Then:
- Asserts runtime user UID/GID is `10001:10001`.
- Asserts build context excluded all `*.md`, `.agents/`, `.cursor/`, and test files.
- Asserts development tools (`gcc`, `cc`, `make`, `git`, `curl`, `wget`, `mix`) are missing.
- Asserts no setuid/setgid binaries exist.
- Asserts container exits with error if `RELEASE_COOKIE` is missing.
- Boots container with disposable Postgres and Redis instances under `--read-only --tmpfs /tmp --cap-drop ALL`, verifies HTTP 200 on `/health` and `/ready`, and tests graceful SIGTERM shutdown within 30s.

## Design
- BuildKit syntax `# syntax=docker/dockerfile:1` with cache mounts (`--mount=type=cache,target=/root/.hex`, `--mount=type=cache,target=/root/.mix`) for fast CI/local builds.
- Layer ordering optimized for caching: `mix.exs mix.lock` -> `deps.get` -> `config/` -> `assets/` -> `lib/` -> `mix release`.
- Distribution is disabled by default (`RELEASE_DISTRIBUTION=none` in `rel/env.sh.eex`) unless `DNS_CLUSTER_QUERY` is set, eliminating unnecessary EPMD exposure.
- Architectural decisions are recorded in ADR `docs/adr/0002-container-image.md`.

## Policy check
Skills applied:
- `architecture` (system boundaries, runtime immutability)
- `security-baseline` (least privilege, non-root, read-only FS, secret hygiene)
- `operations` (orchestrator health checks, graceful termination)

## Flagged concerns
- None.

## Open questions carried forward
- None.

## Risk tier
Tier: 2
Class: HIGH
Why: Introduces production container infrastructure and deployment packaging. Requires architecture gate, ADR, security policy validation, and human review before merge.

## Non-functional impact
- **Performance**: Negligible startup overhead; release boots without Mix overhead.
- **Availability**: Graceful `SIGTERM` handling ensures zero-downtime rolling deploys.
- **Security**: Attack surface drastically reduced via minimal Debian runtime, non-root execution, read-only code directory, and context sanitization.
- **Cost**: Compact image size reduces container registry storage and network transfer time.

## Abuse and failure cases
- **Missing runtime cookie**: Application immediately halts rather than starting with an insecure fallback cookie.
- **Container breakout attempt**: Blocked by dropped Linux capabilities (`--cap-drop ALL`), `no-new-privileges`, non-root execution, and read-only root filesystem.
- **Malicious file upload to local root**: Blocked by read-only filesystem; production mandates `STORAGE_BACKEND=s3` or dedicated persistent volume.

## Data impact
- No database schema migrations introduced.
- No personal data impacted.
