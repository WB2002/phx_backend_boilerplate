defmodule PhxBackendBoilerplateWeb.Graphql.Phase.DocumentByteLimit do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint
  alias Absinthe.Language
  alias Absinthe.Phase
  alias PhxBackendBoilerplateWeb.Graphql.Config

  @impl Absinthe.Phase
  def run(input, _options) do
    max_bytes = Config.max_query_bytes()
    query = query_string(input)

    if is_binary(query) and byte_size(query) > max_bytes do
      error = %Phase.Error{
        phase: __MODULE__,
        message: "GraphQL query exceeds maximum size of #{max_bytes} bytes"
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

  defp query_string(%Blueprint{input: %Language.Source{body: body}}) when is_binary(body),
    do: body

  defp query_string(%Blueprint{input: input}) when is_binary(input), do: input

  defp query_string(%Language.Source{body: body}) when is_binary(body), do: body

  defp query_string(input) when is_binary(input), do: input

  defp query_string(_), do: nil
end
