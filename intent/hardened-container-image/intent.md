# Intent: Hardened Production Container Image
Author: User · Status: accepted · Date: 2026-10-22
Lifecycle: DRAFT

## Problem
The repository provides an enterprise-ready Phoenix backend boilerplate with comprehensive edge defense, observability, and security hardening, but lacks a production-grade container image definition (`Dockerfile` / `.dockerignore`). There is currently no reproducible way to package and deploy the OTP release into cloud container runtimes (AWS ECS/EKS, Fly.io, Render, Kubernetes) while preserving security standards (minimal attack surface, non-root execution, read-only root filesystem, absence of development/AI artifacts).

## User and evidence
Primary user: Platform engineer / Backend developer deploying the service to production.
Job to be done: Package the Phoenix application into an immutable, minimal, secure OCI container image running a compiled Elixir OTP release.
Current workaround: Running bare metal or local `docker compose` with development auxiliary services.
Evidence: observed

## Proposed outcome
A multi-stage, BuildKit-compatible `Dockerfile` and a deny-by-default `.dockerignore` producing an OTP release image based on Debian bookworm-slim. The build context and resulting runtime image strictly exclude all developer tools, AI/agent configs, documentation, markdown files, and build-time caches.

## Why now
The backend boilerplate core is ready for production evaluation, but cannot be deployed to standard container orchestrators without a containerization pipeline.

## Scope
Must:
- Multi-stage build (builder stage with build tooling -> minimal runtime stage with runtime dependencies only).
- Strict deny-by-default `.dockerignore` re-including only required sources (`mix.exs`, `mix.lock`, `config/`, `lib/`, `priv/`, `assets/`, `rel/`) and explicitly excluding all AI-assistant files (`.agents/`, `.cursor/`), documentation, tests, markdown files (`*.md`), scripts, and secrets.
- Run as non-root user (`10001:10001`) with no login shell.
- Read-only root filesystem compatibility with `/tmp` mounted via tmpfs.
- Automated verification script (`scripts/docker-verify.sh`) verifying security properties (UID, no compiler/package tools in runtime, no setuid/setgid, context exclusion audit, health check probe).
- Dependabot configuration for automated Docker base image updates.

Should:
- Security CI integration in `.github/workflows/security.yml` using Trivy and Hadolint.
- Explicit `Release` module (`PhxBackendBoilerplate.Release`) for running database migrations in containers before boot.

Later:
- Multi-arch automated matrix build in production release pipeline (currently targeting `linux/amd64`).
- Distroless or minimal base image migration if Elixir release scripts remove `/bin/sh` requirement.

Explicit exclusions:
- Live traffic deployment, push to public registries, or CI/CD deployment execution (Autonomy L2 limit).
- Modification of application business logic or external dependencies.

## Outcome
Behavioral success metric:
- Container builds cleanly via `docker buildx build`.
- Container boots with required runtime environment and serves `200` on `/health` and `/ready` probes.
- `scripts/docker-verify.sh` passes all security assertions.
- Hadolint reports zero warnings at or above `warning` level; Trivy reports zero HIGH or CRITICAL container vulnerabilities.

Product risks:
- Misconfigured `.dockerignore` could omit required static asset or config file causing release failure.
- Incompatibility with local file upload storage when running on a read-only root filesystem (addressed via documentation requiring S3 or mounted volume).

Assumptions requiring validation:
- Elixir 1.20 and Erlang/OTP 27 on Debian bookworm provide all native dependencies needed for runtime NIFs (e.g., argon2).

## Affected systems
- Root directory (`Dockerfile`, `.dockerignore`)
- `rel/` (OTP release overlays and `env.sh.eex`)
- `lib/phx_backend_boilerplate/release.ex` (migration tasks)
- `scripts/docker-verify.sh`
- `.github/workflows/security.yml`
- `.github/dependabot.yml`

## Constraints
- Base images must be pinned by SHA-256 digest.
- No secrets in `ARG`, `ENV`, or image history.
- Non-root user `10001:10001`.
- Exclude all `.md` files, `.agents/`, `.cursor/`, tests, and docs from the build context.

## Open questions
- None.
