defmodule PhxBackendBoilerplateWeb.Graphql.Pipeline do
  @moduledoc false

  alias PhxBackendBoilerplateWeb.Graphql.Phase.DocumentByteLimit
  alias PhxBackendBoilerplateWeb.Graphql.Phase.MaxDepth

  @doc """
  Absinthe.Plug pipeline callback (`apply(mod, fun, [config, opts])`).
  """
  def for_plug(%{schema_mod: schema}, options) do
    for_document(schema, options)
  end

  @doc """
  Absinthe.Phoenix.Channel pipeline callback (`apply(mod, fun, [schema, opts])`).
  """
  def for_socket(schema, options) do
    for_document(schema, options)
  end

  defp for_document(schema, options) do
    schema
    |> Absinthe.Pipeline.for_document(options)
    |> Absinthe.Pipeline.insert_before(Absinthe.Phase.Parse, DocumentByteLimit)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Parse, MaxDepth)
  end
end
