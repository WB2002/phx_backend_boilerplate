---
name: operations
description: Apply when configuring CI/CD, containers, cloud/edge infrastructure, rollout, rollback, feature flags, or production operations.
---

# Operations, Infrastructure Hardening & Release Safety

## Purpose
Ensure safe, reversible deployments, hardened runtime and CI/CD infrastructure, and verified disaster recovery for solo production operations.

## Inputs
- `docs/release.md`, `docs/nfr.md`, `docs/threat-model.md`, `.cursor/policies/deployment.yaml`, and `intent/<slug>/plan.md`

## Execution

### Invariants
- Read `docs/release.md`. Do not execute any production deploy, release, infrastructure apply, database migration against production, or package publish without explicit human approval (enforced mechanically by `.cursor/hooks/production-gate.sh`).
- **Rollback First:** Every production change must name its exact rollback command or mechanism and expected recovery time (`RTO`) before rollout.
- **Tier 2 (HIGH) Rollout Controls:** Tier 2 changes require a kill-switch / feature flag, staged rollout criteria (`CANARY` → `OBSERVED`), and explicit abort thresholds in `intent/<slug>/plan.md`.
- **CI/CD Supply-Chain Hardening:**
  - Set `permissions: contents: read` by default on all CI workflows; elevate permissions only per job as needed.
  - Pin third-party GitHub Actions or CI steps to full commit SHAs, never mutable tags (`@main` or `@v1`).
  - Use short-lived workload identity (OIDC) rather than long-lived static cloud credentials.
- **Runtime & Container Hardening:** Run containers/workers as non-root users, enforce read-only root filesystems where supported, drop unnecessary capabilities, pin base image digests, and enforce CPU/memory limits and health/readiness probes.
- **Graceful Shutdown & Drain (`resilience`):** Runtime containers and server processes must trap `SIGTERM`/`SIGINT`, stop accepting new connections, drain in-flight requests and background consumers within a bounded termination period (15–30s), and deterministically close database and cache pools before process exit.

### Defaults
- Separate deployment (shipping dark code behind a flag or expand-phase schema) from release (enabling traffic).
- Automate secret scanning (`gitleaks`), dependency auditing, SAST (`Semgrep`/`CodeQL`), and deterministic build/test verification (`scripts/verify-full.sh`) as required CI merge gates.
- Maintain tested backup restore and break-glass key-rotation runbooks in `docs/runbooks/`.

### Decisions
- **Vendor / Edge Platform Skills:** When `docs/adr/0001-stack.md` is accepted for a specific cloud/edge platform (e.g., Cloudflare Workers/Zero Trust/WAF), install the official platform skills (`npx skills add cloudflare/skills`) in the product repository so infrastructure and WAF/Gateway configs follow current platform idioms.

### Exceptions
- Emergency hotfixes still require a failing regression test (`/fix-bug`), human approval at the production gate, and a follow-up incident record (`docs/incidents/`) and postmortem (`docs/postmortems/`).
