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
  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # Skip module attributes (@data, @type, @spec) and their inner AST nodes
  defp traverse({:@, _meta, _args}, issues, _issue_meta) do
    {nil, issues}
  end

  # Elixir variable AST nodes are {name, meta, context} where context is an atom (usually nil)
  defp traverse({name, meta, context} = ast, issues, issue_meta)
       when is_atom(name) and is_list(meta) and is_atom(context) do
    issues =
      if BannedIdentifiers.banned?(name) do
        [
          format_issue(
            issue_meta,
            message: BannedIdentifiers.message(name),
            trigger: Atom.to_string(name),
            line_no: meta[:line],
            column: meta[:column],
            severity: :error
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}
end
