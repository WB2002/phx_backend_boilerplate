# AGENTS.md

Phoenix backend (Elixir). App modules: `PhxBackendBoilerplate` / `PhxBackendBoilerplateWeb`.
Cursor (`.cursor/`) and Antigravity (`.agents/`) share the same skills, rules, policies, and personas. Edit both or neither.

## Commands
- Run server: `mix phx.server`
- One test file: `mix test test/path/to_test.exs` · rerun failures: `mix test --failed`
- Format & lint fixes: `mix format` · check: `mix format --check-formatted && mix credo --min-priority high`
- Precommit check: `mix precommit` (compiles with `--warnings-as-errors`, unlocks unused deps, formats, credos, gitleaks, tests)
- Verification script: `scripts/verify.sh` (builds with `--warnings-as-errors`, checks format, runs credo, runs tests if DB is up on 5433)

## Definition of done
1. `scripts/verify.sh` passes with full test execution (not skipped due to unreachable DB). Paste its output in your report.
2. Every behavior change has an automated test that fails without it.
3. Public behavior change → docs updated in the same change (plan.md "Docs impact").
4. Implementation departs from plan.md → update plan.md in the same change.
5. Hand off to the readonly review agents. Never review your own change.

## Hard limits
- Never merge, push, or deploy (autonomy L2).
- Never set `Status: accepted` or write any approval on a human's behalf.
- Never edit, skip, or delete a failing test to get green. Fix the code.
- Never hand-edit `mix.exs` deps or `mix.lock`. Use `/add-dependency`.
- Never invent product scope or user-visible behavior. If a human gate is missing, stop and name it.

## SDLC workflow
Slash command (`/new-intent`, `/spec`, `/plan`, `/fix-bug`, …) → read and follow `.agents/skills/<name>/SKILL.md` (or `.cursor/skills/<name>/SKILL.md`) before doing anything else.

Gates for `intent/<slug>/`, in order:
1. `intent.md`: human accepts scope.
2. `experience.md`: only when user-facing interactions change. `/design-experience` drafts, `ux-reviewer` reports gaps, human accepts. Otherwise spec states `Experience: none`.
3. `spec.md`: `/spec`, only after 1–2 are accepted.
4. `architecture-gate.md`: HIGH (tier 2) only; must be accepted before any plan is written or code changed.
5. `plan.md`: `/plan` in Plan mode. CRITICAL: the human writes design and plan, not AI.
6. `/orchestrate`: writes `orchestration.md` naming the next role. It never implements, reviews, merges, or deploys.

Risk tiers and autonomy rules: defined in `docs/governance.md` (LOW tier 0, MEDIUM tier 1, HIGH tier 2, CRITICAL) and `.agents/policies/`.

## Code rules
- Search for existing utilities before writing new ones.
- Stay inside plan.md scope. Scope must grow → update plan, then stop.
- No drive-by refactors. Out-of-scope findings become a new intent.
- No abstraction until two real callers. Prefer deleting code.
- No commented-out or dead code. `TODO` only with an intent/issue reference.
- HTTP: `Req` only. Never use HTTPoison, Tesla, or `:httpc`.
- Date/time: Elixir stdlib only (`date_time_parser` allowed for parsing).

## Phoenix / Web & API
- Router `scope` already prefixes module aliases. Do not duplicate aliases inside route scopes.
- Public & internal endpoints: use dedicated pipelines (`:probe`, `:api`, `:api_public`, `:api_stream`).
- No `Phoenix.View` (use JSON views / components with `use Phoenix.Controller, formats: [:json]`).
- Error and fallback handling: use `PhxBackendBoilerplateWeb.FallbackController` and `ChangesetJSON` / `ErrorJSON`.

## Elixir / Ecto / tests
- Bind block results: `socket = if connected?(socket), do: ..., else: socket`. Rebinding inside the block is lost.
- No `list[i]` (use `Enum.at`/pattern match). No `struct[:field]` (use `struct.field` or `get_field`).
- No `String.to_atom/1` on user input (memory leak risk).
- Predicates end in `?`; `is_` prefix only for guards.
- One module per file.
- Preload associations in queries when accessed in controllers/views.
- Never `cast` programmatic fields (`user_id`, etc.); set them on the struct.
- Text columns are `:string` in schemas. `validate_number` has no `:allow_nil`.
- Migrations: `mix ecto.gen.migration name_with_underscores`.
- Tests: `start_supervised!/1` for supervised processes. No `Process.sleep`/`Process.alive?`; use `Process.monitor` + `assert_receive {:DOWN, ^ref, ...}` or `:sys.get_state/1`.

## Known agent mistakes
<!-- Add a line when the same mistake happens twice. Remove lines that no longer happen. -->