defmodule PhxBackendBoilerplateWeb.HealthController do
  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Health

  def health(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    case Health.ready() do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, checks} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", checks: stringify_checks(checks)})
    end
  end

  defp stringify_checks(checks) do
    Map.new(checks, fn {name, status} -> {name, Atom.to_string(status)} end)
  end
end
