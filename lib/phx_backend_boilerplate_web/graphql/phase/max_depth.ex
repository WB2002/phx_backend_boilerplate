defmodule PhxBackendBoilerplateWeb.Graphql.Phase.MaxDepth do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Language
  alias Absinthe.Phase
  alias PhxBackendBoilerplateWeb.Graphql.Config

  @impl Absinthe.Phase
  def run(input, _options) do
    max_depth = Config.max_depth()
    depth = document_depth(input)

    if is_integer(depth) and depth > max_depth do
      error = %Phase.Error{
        phase: __MODULE__,
        message: "GraphQL query exceeds maximum depth of #{max_depth}"
      }

      blueprint =
        input
        |> to_blueprint()
        |> put_in([Access.key(:execution), Access.key(:validation_errors)], [error])

      {:jump, blueprint, Absinthe.Phase.Document.Result}
    else
      {:ok, input}
    end
  end

  defp to_blueprint(%Blueprint{} = blueprint), do: blueprint
  defp to_blueprint(input), do: %Blueprint{input: input}

  defp document_depth(%Blueprint{input: %Language.Source{body: body}}) when is_binary(body),
    do: brace_depth(body)

  defp document_depth(%Blueprint{input: %Language.Document{} = doc}), do: ast_depth(doc)

  defp document_depth(%Language.Document{} = doc), do: ast_depth(doc)

  defp document_depth(%Language.Source{body: body}) when is_binary(body), do: brace_depth(body)

  defp document_depth(query) when is_binary(query), do: brace_depth(query)

  defp document_depth(_), do: 0

  defp ast_depth(%Language.Document{definitions: defs}) do
    defs
    |> Enum.map(&selection_depth/1)
    |> Enum.max(fn -> 0 end)
  end

  defp selection_depth(%{selection_set: %{selections: selections}}) when is_list(selections) do
    nested =
      selections
      |> Enum.map(&selection_depth/1)
      |> Enum.max(fn -> 0 end)

    nested + 1
  end

  defp selection_depth(_), do: 0

  # Fallback before the parser has replaced the source with an AST.
  defp brace_depth(query) do
    query
    |> String.graphemes()
    |> Enum.reduce({0, 0}, fn
      "{", {cur, max} -> {cur + 1, max(max, cur + 1)}
      "}", {cur, max} when cur > 0 -> {cur - 1, max}
      _, acc -> acc
    end)
    |> elem(1)
  end
end
