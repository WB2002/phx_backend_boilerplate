# Banned Identifier Names (Lint Guardrails) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce rejection of vague/placeholder local identifiers in `lib/` (and optionally `test/`) the same way Go (`forbidigo`), FastAPI (`python-banned-variable-names` Semgrep), and NestJS (`id-denylist`) do—wired into `mix credo`, `mix precommit`, `scripts/verify.sh`, and CI.

**Architecture:** A single denylist lives in `PhxBackendBoilerplate.Lint.BannedIdentifiers` (unit-tested). A custom Credo check walks Elixir AST and flags **variable bindings and parameters** only (not map/string keys, not tuple tags like `{:data, chunk}`). A small Semgrep ruleset mirrors the same names for defense-in-depth and matches the FastAPI `scripts/ci/run-semgrep.sh` pattern. No new Hex dependencies.

**Tech Stack:** Elixir 1.20 / OTP 27, Credo 1.7, Semgrep 1.151.0 (already pinned in `.github/workflows/security.yml`), Mix aliases, Bash.

## Global Constraints

- Do **not** hand-edit `mix.exs` deps or `mix.lock`; use `/add-dependency` if a dependency is ever required (this plan adds none).
- CI and local verification use `mix credo --min-priority high` (see `AGENTS.md`, `.github/workflows/ci.yml`, `scripts/verify.sh`).
- `mix precommit` must remain the one-shot developer gate (`mix.exs` `precommit` alias).
- HTTP client policy unchanged; tests use `Process.monitor` / `:sys.get_state/1`, not `Process.sleep`.
- Definition of done: `scripts/verify.sh` passes with DB up; paste output in the implementation report.
- Escape hatch: `# credo:disable-next-line CredoChecks.BannedIdentifierNames -- <reason>` only for unavoidable external API shapes (document the reason).

### Canonical denylist (union of NestJS, Go, FastAPI — Elixir `snake_case`)

| Source | Names / patterns |
|--------|------------------|
| NestJS `id-denylist` | `data`, `result`, `item`, `temp`, `obj`, `val` |
| Go `forbidigo` | `tmp`, `foo`, `bar`, `baz`, `qux`, `thing`, `stuff`, `test_var`, `my_var`, `my_func`, `do_something`, `handle_stuff`, `process_data`, `dummy_func`, plus regex `^var\d+$` |
| FastAPI `python-banned-variable-names` | `dummy` (already covered) |

Tuple tags, map **keys** (`"data"` strings, `:data` keys), and module attributes (`@data`) are **not** bindings and must not be flagged.

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/phx_backend_boilerplate/lint/banned_identifiers.ex` | Denylist + `banned?/1` |
| `lib/credo_checks/banned_identifier_names.ex` | Credo check delegating to `BannedIdentifiers` |
| `.credo.exs` | Register check + `requires` (if needed) |
| `test/phx_backend_boilerplate/lint/banned_identifiers_test.exs` | Unit tests for denylist |
| `test/credo_checks/banned_identifier_names_test.exs` | Integration test via on-disk fixture + `mix credo` |
| `test/fixtures/credo/banned_sample.ex` | Fixture source with intentional violations |
| `scripts/ci/semgrep-guardrails.yaml` | Semgrep rules (Elixir) |
| `scripts/ci/run-semgrep-guardrails.sh` | Local/CI runner (FastAPI parity) |
| `lib/mix/tasks/semgrep.guardrails.ex` | `mix semgrep.guardrails` Mix task |
| `mix.exs` | Add `semgrep.guardrails` to `precommit` alias |
| `scripts/verify.sh` | Optional explicit guardrails step (Credo already covers primary path) |
| `.github/workflows/ci.yml` | Semgrep guardrails job step (or extend quality job) |
| `.github/workflows/security.yml` | Add `--config /src/scripts/ci/semgrep-guardrails.yaml` alongside `auto` |
| `.cursor/rules/elaborate-naming.mdc` | Agent/human naming contract (NestJS parity) |
| `AGENTS.md` | Document commands and denylist pointer |
| `docs/security-pipeline.md` | Document Semgrep guardrails config |

---

### Task 1: Denylist module

**Files:**
- Create: `lib/phx_backend_boilerplate/lint/banned_identifiers.ex`
- Test: `test/phx_backend_boilerplate/lint/banned_identifiers_test.exs`

**Interfaces:**
- Produces: `PhxBackendBoilerplate.Lint.BannedIdentifiers.banned?/1` :: `(atom() | String.t()) => boolean()`, `PhxBackendBoilerplate.Lint.BannedIdentifiers.message/1` :: `(atom()) => String.t()`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule PhxBackendBoilerplate.Lint.BannedIdentifiersTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Lint.BannedIdentifiers

  describe "banned?/1" do
    test "rejects NestJS placeholder names" do
      for name <- ~w(data result item temp obj val)a do
        assert BannedIdentifiers.banned?(name)
      end
    end

    test "rejects Go/FastAPI placeholder names" do
      for name <- ~w(tmp foo bar baz qux thing stuff dummy test_var my_var)a do
        assert BannedIdentifiers.banned?(name)
      end
    end

    test "rejects numbered varN pattern" do
      assert BannedIdentifiers.banned?(:var1)
      assert BannedIdentifiers.banned?("var99")
    end

    test "allows descriptive domain names" do
      refute BannedIdentifiers.banned?(:user_id)
      refute BannedIdentifiers.banned?(:checkout_session)
      refute BannedIdentifiers.banned?(:stripe_event)
    end

    test "message/1 includes the rejected name" do
      assert BannedIdentifiers.message(:foo) =~ "foo"
      assert BannedIdentifiers.message(:foo) =~ "domain"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/phx_backend_boilerplate/lint/banned_identifiers_test.exs`
Expected: FAIL — module `PhxBackendBoilerplate.Lint.BannedIdentifiers` undefined

- [ ] **Step 3: Write minimal implementation**

```elixir
defmodule PhxBackendBoilerplate.Lint.BannedIdentifiers do
  @moduledoc """
  Shared denylist for vague/placeholder identifiers aligned with NestJS, Go, and FastAPI boilerplates.
  """

  @exact ~w(
    data result item temp tmp obj val
    foo bar baz qux thing stuff dummy
    test_var my_var my_func
    do_something handle_stuff process_data dummy_func
  )a

  @var_numbered ~r/^var\d+$/

  @exact_strings Enum.map(@exact, &Atom.to_string/1)

  @spec banned?(atom() | String.t()) :: boolean()
  def banned?(name) when is_atom(name) do
    name in @exact || Regex.match?(@var_numbered, Atom.to_string(name))
  end

  def banned?(name) when is_binary(name) do
    name in @exact_strings || Regex.match?(@var_numbered, name)
  end

  @spec message(atom()) :: String.t()
  def message(name) do
    "Generic or placeholder identifier #{inspect(name)} rejected. Use a domain-specific descriptive name."
  end
end
```

**Note:** Do not use `String.to_atom/1` or `String.to_existing_atom/1` on user input (AGENTS.md memory-leak rule). Membership is string compare against `@exact_strings`.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/phx_backend_boilerplate/lint/banned_identifiers_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/phx_backend_boilerplate/lint/banned_identifiers.ex \
  test/phx_backend_boilerplate/lint/banned_identifiers_test.exs
git commit -m "feat(lint): add shared banned identifier denylist"
```

---

### Task 2: Credo check

**Files:**
- Create: `lib/credo_checks/banned_identifier_names.ex`
- Create: `test/fixtures/credo/banned_sample.ex`
- Create: `test/credo_checks/banned_identifier_names_test.exs`
- Modify: `.credo.exs` (enable check in `checks.enabled`)

**Interfaces:**
- Consumes: `PhxBackendBoilerplate.Lint.BannedIdentifiers.banned?/1`, `.message/1`
- Produces: `CredoChecks.BannedIdentifierNames` check registered in `.credo.exs` as `{CredoChecks.BannedIdentifierNames, []}`

- [ ] **Step 1: Write fixture file** (`test/fixtures/credo/banned_sample.ex`)

```elixir
defmodule CredoFixtures.BannedSample do
  defp bad_assign do
    result = 1
    result
  end

  defp bad_param(foo) do
    foo
  end
end
```

- [ ] **Step 2: Write failing integration test**

```elixir
defmodule CredoChecks.BannedIdentifierNamesTest do
  use ExUnit.Case, async: false

  @tag :capture_log
  test "mix credo reports banned_sample.ex violations" do
    root = File.cwd!()
    fixture = Path.join(root, "test/fixtures/credo/banned_sample.ex")

    {output, exit_code} =
      System.cmd(
        "mix",
        ["credo", fixture, "--only", "CredoChecks.BannedIdentifierNames"],
        cd: root,
        env: [{"MIX_ENV", "test"}]
      )

    assert exit_code != 0
    assert output =~ "BannedIdentifierNames"
    assert output =~ "result"
    assert output =~ "foo"
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/credo_checks/banned_identifier_names_test.exs`
Expected: FAIL — check module missing or credo passes

- [ ] **Step 4: Implement check**

```elixir
defmodule CredoChecks.BannedIdentifierNames do
  @moduledoc false

  use Credo.Check,
    base_priority: :high,
    category: :readability,
    explanations: [
      check: "Flags vague placeholder variable and parameter names."
    ]

  alias PhxBackendBoilerplate.Lint.BannedIdentifiers

  @doc false
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({name, meta, context} = ast, issues, issue_meta)
       when is_atom(name) and is_list(meta) and not is_nil(context) do
    if BannedIdentifiers.banned?(name) do
      [
        format_issue(issue_meta, meta[:line], meta[:column], name)
        | issues
      ]
    else
      issues
    end
    |> then(&{ast, &1})
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp format_issue(issue_meta, line, column, name) do
    format_issue(
      issue_meta,
      message: BannedIdentifiers.message(name),
      trigger: Atom.to_string(name),
      line_no: line,
      column: column,
      severity: :error
    )
  end
end
```

- [ ] **Step 5: Register in `.credo.exs`**

Add after `{Credo.Check.Readability.VariableNames, []}`:

```elixir
{CredoChecks.BannedIdentifierNames, []},
```

Ensure `lib/credo_checks/` is compiled (default `elixirc_paths` includes `lib/`).

- [ ] **Step 6: Run integration test**

Run: `mix test test/credo_checks/banned_identifier_names_test.exs`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/credo_checks/banned_identifier_names.ex .credo.exs \
  test/fixtures/credo/banned_sample.ex test/credo_checks/banned_identifier_names_test.exs
git commit -m "feat(lint): add Credo check for banned identifier names"
```

---

### Task 3: Baseline remediation in `lib/`

**Files:**
- Modify: all `lib/**/*.ex` files reported by `mix credo --only CredoChecks.BannedIdentifierNames`

**Interfaces:**
- Consumes: `mix credo --only CredoChecks.BannedIdentifierNames` output (source of truth; do not grep-rename blindly)

- [ ] **Step 1: List violations**

Run: `mix credo --only CredoChecks.BannedIdentifierNames`
Expected: non-zero issues (common renames: `result` → `fetch_outcome` / `coalesce_outcome`, `data` → `chunk` / `body`, `item` → `line_item` / `entry`, `val` → `value` is still banned—use `value` only if not in denylist; **`val` is banned** → `parsed_value`, `config_value`).

- [ ] **Step 2: Rename bindings file-by-file**

Example (`lib/phx_backend_boilerplate/cache/coalescer.ex` pattern):

```elixir
# before
result = fun.()
notify_waiters(waiters, result)

# after
coalesced_value = fun.()
notify_waiters(waiters, coalesced_value)
```

Do **not** rename Stripe/GraphQL **map keys** (`"data"`, `"object"`) in tests or fixtures.

- [ ] **Step 3: Run full credo gate**

Run: `mix credo --min-priority high`
Expected: no `BannedIdentifierNames` issues; exit 0

- [ ] **Step 4: Run compile + tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "refactor: rename placeholder identifiers for lint guardrails"
```

---

### Task 4: Semgrep guardrails (FastAPI parity)

**Files:**
- Create: `scripts/ci/semgrep-guardrails.yaml`
- Create: `scripts/ci/run-semgrep-guardrails.sh`
- Create: `lib/mix/tasks/semgrep.guardrails.ex`

**Interfaces:**
- Produces: `mix semgrep.guardrails` → runs `scripts/ci/run-semgrep-guardrails.sh`, exit non-zero on match

- [ ] **Step 1: Write rules file**

```yaml
rules:
  - id: elixir-banned-variable-binding
    languages: [elixir]
    severity: ERROR
    message: "Generic or placeholder identifier '$VAR' rejected. Use a domain-specific descriptive name."
    patterns:
      - pattern-either:
          - pattern: $VAR = $EXPR
          - pattern: def $F(..., $VAR, ...), do: ...
          - pattern: defp $F(..., $VAR, ...), do: ...
          - pattern: fn $VAR -> ...
          - pattern: fn ..., $VAR -> ...
      - metavariable-regex:
          metavariable: $VAR
          regex: ^(data|result|item|temp|tmp|obj|val|foo|bar|baz|qux|thing|stuff|dummy|test_var|my_var|my_func|do_something|handle_stuff|process_data|dummy_func|var[0-9]+)$

```

- [ ] **Step 2: Write runner script**

```bash
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CONFIG="$ROOT/scripts/ci/semgrep-guardrails.yaml"

if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --config "$CONFIG" --error lib/
elif command -v docker >/dev/null 2>&1; then
  docker run --rm -v "$ROOT:/src" semgrep/semgrep:1.151.0 semgrep scan \
    --config /src/scripts/ci/semgrep-guardrails.yaml --error /src/lib/
else
  echo "error: install semgrep (brew install semgrep) or Docker" >&2
  exit 1
fi

echo "semgrep guardrails: OK"
```

Run: `chmod +x scripts/ci/run-semgrep-guardrails.sh`

- [ ] **Step 3: Add Mix task** (mirror `lib/mix/tasks/gitleaks.ex`)

```elixir
defmodule Mix.Tasks.Semgrep.Guardrails do
  @shortdoc "Run Semgrep guardrails (banned identifier names)"
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    script = Path.expand("scripts/ci/run-semgrep-guardrails.sh")

    unless File.exists?(script) do
      Mix.raise("Missing #{script}")
    end

    Mix.shell().info("Running semgrep guardrails…")

    case System.cmd(script, [], into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("semgrep guardrails failed with exit code #{code}")
    end
  end
end
```

- [ ] **Step 4: Wire `mix precommit`**

In `mix.exs`, inside `precommit: [...]`, add after `"credo --min-priority high"`:

```elixir
"semgrep.guardrails",
```

- [ ] **Step 5: Verify locally**

Run: `mix semgrep.guardrails`
Expected: exit 0 after Task 3 remediation

- [ ] **Step 6: Commit**

```bash
git add scripts/ci/semgrep-guardrails.yaml scripts/ci/run-semgrep-guardrails.sh \
  lib/mix/tasks/semgrep.guardrails.ex mix.exs
git commit -m "feat(lint): add Semgrep guardrails for banned identifiers"
```

---

### Task 5: CI and documentation

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/security.yml` (optional second config on SAST job)
- Modify: `AGENTS.md`
- Modify: `docs/security-pipeline.md`
- Create: `.cursor/rules/elaborate-naming.mdc`

- [ ] **Step 1: CI quality job — Semgrep guardrails**

In `.github/workflows/ci.yml`, after the Credo step:

```yaml
      - name: Semgrep guardrails (banned identifiers)
        run: ./scripts/ci/run-semgrep-guardrails.sh
```

Install Semgrep on the runner first:

```yaml
      - name: Install Semgrep
        run: pip install semgrep==1.151.0
```

(pip is available on `ubuntu-latest`; pin matches Docker image in `security.yml`.)

- [ ] **Step 2: Security workflow — add project ruleset to SAST**

In the Docker `semgrep scan` invocation, add:

```text
--config /src/scripts/ci/semgrep-guardrails.yaml \
```

before `/src`, keeping existing `--config auto`.

- [ ] **Step 3: `AGENTS.md` — document lint stack**

Add under format/lint bullets:

```markdown
- Banned placeholder identifiers: enforced by `CredoChecks.BannedIdentifierNames` and `mix semgrep.guardrails` (denylist aligned with NestJS/Go/FastAPI). See `.cursor/rules/elaborate-naming.mdc`.
```

- [ ] **Step 4: Create `.cursor/rules/elaborate-naming.mdc`**

```markdown
---
description: Domain-specific naming; no placeholder identifiers
alwaysApply: true
---

# Elaborate naming

- Do not use placeholder local names: `data`, `result`, `item`, `temp`, `tmp`, `obj`, `val`, `foo`, `bar`, `baz`, `qux`, `thing`, `stuff`, `dummy`, `test_var`, `my_var`, `var1`, etc.
- Booleans: `is_`, `has_`, `can_`, `should_` prefixes (functions and variables).
- Credo enforces banned bindings; Semgrep guardrails duplicate the denylist on `lib/`.
```

- [ ] **Step 5: Update `docs/security-pipeline.md`**

Add subsection under SAST describing `scripts/ci/semgrep-guardrails.yaml` and `mix semgrep.guardrails`.

- [ ] **Step 6: Full verification**

Run: `scripts/verify.sh` (with Postgres on `127.0.0.1:5433`)
Expected: `verify: OK`

Run: `mix precommit` (with DB for tests)
Expected: all steps green including `semgrep.guardrails`

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/security.yml \
  AGENTS.md docs/security-pipeline.md .cursor/rules/elaborate-naming.mdc
git commit -m "chore(ci): wire banned identifier guardrails and document naming policy"
```

---

## Self-review (plan author)

| Requirement | Task |
|-------------|------|
| Go `forbidigo` denylist | Task 1 `@exact` + regex |
| FastAPI Semgrep + precommit hook pattern | Tasks 4–5 |
| NestJS `id-denylist` names | Task 1 |
| No new Hex deps | All tasks |
| `mix credo --min-priority high` / precommit | Tasks 2, 4, 5 |
| AST-safe (no false positives on `"data"` keys / `{:data, x}` tags) | Task 2 Credo vs Task 4 Semgrep limitations—if Semgrep flags tuple tags, tighten patterns or exclude paths in `semgrep-guardrails.yaml` |
| Tests fail without implementation | Tasks 1–2 TDD |
| Placeholder scan | No TBD/TODO steps |

**Known gap:** Semgrep Elixir patterns may be noisier than the Credo AST check. Treat **Credo as authoritative**; adjust Semgrep patterns in Task 4 if CI reports false positives on tuple tags or map keys.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-11-21-banned-identifier-names.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**