# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog.

## [Unreleased]

### Added
- Google Antigravity support: `.agents/` workspace configuration bridging skills, rules, agent personas, policies, and lifecycle hooks with `.cursor/` for dual Cursor and Antigravity compatibility.
- `.agents/skills.json` and `.agents/skills` symlink exposing all 25 skills to Antigravity.
- `.agents/rules/` exposing markdown rules (`intent-artifacts.md`, `review-separation.md`) to Antigravity.
- `.agents/hooks.json` and `.agents/hooks/*.sh` implementing Antigravity lifecycle hooks with identical guardrails.
- Root `GEMINI.md` symlinked to `AGENTS.md`.
- `constraint-driven-development` skill: a draft quality bar with an enforcement point for every check.
- `source-driven-development` skill: cite current official documentation before writing a library or runtime call.
- `code-simplification` skill: cleanup must keep observable behavior, including return type and status codes.
- Root `README.md` and `scripts/check-skills.sh` for skill frontmatter, folder names, and relative references.
- Constitution skills, architecture gate, review agents, policy declarations, debt ledger, and engineering-memory templates for the Phase 1 control plane.
- Orchestrator, lifecycle stages, risk classes (LOW, MEDIUM, HIGH, CRITICAL), and autonomy levels L0–L5 for the Phase 2 control plane.
- How to use this setup, in `docs/ai-sdlc.md`.
- Product discovery fields for users, evidence, Must/Should/Later scope,
  assumptions, validation, and product risks in intent creation.
- `design-experience` skill and experience template for user journeys,
  interaction states, wireframes, trade-offs, and UX acceptance criteria.
- Readonly `ux-reviewer` for failure-focused review before experience acceptance
  and after verification.
- UX traceability from accepted `UX-NNN` criteria into specs and plans, with
  `Experience: none` for non-interactive work.
- Language-agnostic GitHub Actions security scanning pipeline (`.github/workflows/security.yml`) integrating Gitleaks, Trivy (SCA & Misconfig), and Semgrep (SAST).
- Active GitHub Dependabot configuration (`.github/dependabot.yml`) for `hex` and `github-actions` with 7-day cooldown protection.
- Vulnerability baseline file (`.trivyignore`) tracking accepted risks with policy rationale.
- Static analysis ignore file (`.semgrepignore`) filtering build, vendor, and ephemeral directories.
- Security documentation: `docs/security-pipeline.md` and expanded `docs/threat-model.md`.
### Changed
- `scripts/check-skills.sh` updated to verify both Cursor and Antigravity skills.
- `.gitignore` updated to track `.agents/.fix-mode` and `.agents/.guardrails-edit`.
- `AGENTS.md`, `README.md`, and `docs/ai-sdlc.md` updated to document dual Cursor and Antigravity workflow.
- `.github/workflows/ci.yml` pinned all third-party GitHub Actions to verified commit SHAs.
- `.cursor/policies/security.yaml` updated to reference CI security scanning workflows.
### Deprecated
### Removed
### Fixed
- Fixed CI test database connection failure by mapping port 5433 to the PostgreSQL service container in `.github/workflows/ci.yml` and supporting `DATABASE_URL` / `PGPORT` overrides in `config/test.exs`.
### Security
- Added automated CI secret scanning via Gitleaks, SCA and IaC misconfiguration scanning via Trivy, and SAST via Semgrep.
- Baselined known Hackney 1.25.0 timeout vulnerability (`CVE-2026-47071`) in `.trivyignore` with rationale and monitoring plan.
- Pinned mutable GitHub Actions tags in `ci.yml` to mitigate tag-mutation supply chain risks.
