---
name: bootstrap-stack
description: Scaffold the walking skeleton, wire build/test/lint and CI checks, and activate baseline architecture policies from an accepted stack ADR.
disable-model-invocation: true
---

# Bootstrap Stack & Walking Skeleton (`/bootstrap-stack`)

Use this workflow immediately after accepting `docs/adr/0001-stack.md` to initialize a working development harness and walking skeleton.

## Prerequisites & Gates
1. `docs/adr/0001-stack.md` must exist and have `Status: accepted`. Stop if missing or still draft.
2. Creating and modifying build scripts (`scripts/verify.sh`, `scripts/verify-full.sh`, `AGENTS.md`, `.github/workflows/ci.yml`) is protected. The human owner must create `.cursor/.guardrails-edit` before running this workflow. Stop and remind the human if `.cursor/.guardrails-edit` is missing.

---

## Step 1: Ingest Accepted Stack Architecture
Read `docs/adr/0001-stack.md`, `docs/nfr.md`, `docs/architecture.md`, and `docs/threat-model.md`. Identify:
- Primary language & runtime (e.g., TypeScript/Node, Python, Go, Rust)
- Package manager & manifest format (e.g., `pnpm`, `npm`, `uv`, `cargo`)
- Test runner & assertion framework (e.g., `vitest`, `pytest`, `go test`)
- Linter & formatter (e.g., `eslint` / `biome`, `ruff`, `golangci-lint`)
- Primary web/API framework and entry point directory structure
- Cloud platform / deployment target (e.g., Cloudflare Workers/Pages, Fly.io, AWS, container)

## Step 2: Initialize Walking Skeleton & Tooling
1. Scaffold the minimal application directory structure following `docs/architecture.md` (e.g., `src/`, `tests/` or stack equivalent).
2. Create the package manifest and lockfile using the project package manager (or via `/add-dependency` principles).
3. Add configuration files for compiler, linter, and test runner (e.g., `tsconfig.json`, `eslint.config.js` / `biome.json`, test runner config).
4. Implement a minimal walking skeleton entry point (e.g., a simple health probe endpoint or CLI entry) and a corresponding automated test.

## Step 3: Wire Deterministic Local Verification
Replace the failing TODO stubs with exact stack commands:
1. **`AGENTS.md`**: Update the commands under `## Commands`:
   - `Build: <exact command>`
   - `Test: <exact command>`
   - `Lint: <exact command>`
   - `Run: <exact command>`
2. **`scripts/verify.sh`**:
   - Replace `TODO: configure build`, `TODO: configure test`, and `TODO: configure lint` with the real build, test, and lint commands.
   - Ensure the script exits 0 when all three pass, and fails fast on error (`set -euo pipefail`).
3. **`scripts/verify-full.sh`**:
   - Configure integration/e2e test command.

## Step 4: Wire Continuous Integration & Policies
1. **`.github/workflows/ci.yml`**:
   - Replace the `static-analysis` and `dependency-audit` TODO stubs with the chosen stack's linters, typecheckers, and vulnerability audit commands (e.g., `npm audit`, `cargo audit`, `uv pip check`).
2. **`.cursor/policies/architecture.yaml` & `quality.yaml`**:
   - Transition deferred rules to `enforced` or `advisory` with concrete mechanisms (e.g., boundary linter rule, test coverage threshold).

## Step 5: Execute & Verify Green Build
1. Execute `scripts/verify.sh` in the terminal and verify that build, test, and lint exit `0`.
2. Execute `scripts/check-skills.sh` and `scripts/check-docs.sh`.
3. Report the raw verification logs.
4. **Lockdown reminder:** Prompt the human owner to remove `.cursor/.guardrails-edit` now that the bootstrap is complete.
