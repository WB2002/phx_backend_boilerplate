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
### Changed
- `scripts/check-skills.sh` updated to verify both Cursor and Antigravity skills.
- `.gitignore` updated to track `.agents/.fix-mode` and `.agents/.guardrails-edit`.
- `AGENTS.md`, `README.md`, and `docs/ai-sdlc.md` updated to document dual Cursor and Antigravity workflow.
### Deprecated
### Removed
### Fixed
### Security
