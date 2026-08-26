defmodule PhxBackendBoilerplate.Health do
  @moduledoc """
  Liveness and readiness checks for orchestrator probes.

  * `live/0` — process is up; no dependency checks.
  * `ready/0` — Postgres and Redis are reachable (fail closed).
  """

  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Repo

  @check_timeout 1_000

  @doc """
  Liveness probe. Always returns `:ok` when the BEAM process can respond.
  """
  def live, do: :ok

  @doc """
  Readiness probe. Returns `:ok` when Postgres and Redis are reachable,
  otherwise `{:error, checks}` with `:ok` or `:error` per dependency.
  """
  def ready do
    ready(postgres: &check_postgres/0, redis: &check_redis/0)
  end

  @doc false
  def ready(checks) when is_list(checks) do
    results =
      Enum.map(checks, fn {name, fun} ->
        {name, run_check(fun)}
      end)
      |> Map.new()

    if Enum.all?(results, fn {_name, status} -> status == :ok end) do
      :ok
    else
      {:error, results}
    end
  end

  defp run_check(fun) do
    fun.()
  rescue
    _ -> :error
  catch
    :exit, _ -> :error
  end

  defp check_postgres do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", [], timeout: @check_timeout) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp check_redis do
    with {:ok, conn} <- L2.fetch_conn(),
         {:ok, "PONG"} <- Redix.command(conn, ["PING"], timeout: @check_timeout) do
      :ok
    else
      _ -> :error
    end
  end
end
