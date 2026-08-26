defmodule PhxBackendBoilerplateWeb.Graphql.Middleware.RequireAuth do
  @moduledoc """
  Absinthe middleware that requires `context.current_user_id`.

  Applied to root query, mutation, and subscription fields so every operation
  is authenticated even if the HTTP plug or socket connect path is misconfigured.
  """

  @behaviour Absinthe.Middleware

  @impl true
  def call(%{context: %{current_user_id: user_id}} = resolution, _config)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    resolution
  end

  def call(resolution, _config) do
    Absinthe.Resolution.put_result(resolution, {:error, "Unauthorized"})
  end
end
