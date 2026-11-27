defmodule PhxBackendBoilerplateWeb.OpenAPIController do
  @moduledoc """
  Serves the OpenAPI 3.0.3 JSON specification when enabled.

  Enabled by default in `:dev` and `:test`, and disabled in `:prod` unless
  `ENABLE_OPENAPI=true` is set at runtime.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplateWeb.OpenAPISpec

  def show(conn, _params) do
    if Application.get_env(:phx_backend_boilerplate, :openapi, [])[:enabled] do
      json(conn, OpenAPISpec.spec())
    else
      conn
      |> put_status(:not_found)
      |> json(%{errors: %{detail: "Not Found"}})
    end
  end
end
