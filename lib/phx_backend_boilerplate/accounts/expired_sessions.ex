defmodule PhxBackendBoilerplate.Accounts.ExpiredSessions do
  @moduledoc """
  Redis-backed deny list for recently logged-out sessions.

  Each revoked session id is stored under `expired_sessions:<id>` with a 15-minute
  TTL so in-flight access tokens fail the auth guard without hitting Postgres.

  Redis is a cache: logout always succeeds after the Postgres session delete;
  deny-list writes are best-effort. When Redis is unavailable, `revoked?/1`
  falls back to checking whether the session row still exists.
  """

  require Logger

  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Repo

  @prefix "expired_sessions:"
  @ttl :timer.minutes(15)

  @doc """
  Marks a session id as expired in Redis.

  Returns `:ok` even when Redis is unavailable (best-effort cache write).
  """
  @spec revoke(String.t()) :: :ok
  def revoke(session_id) when is_binary(session_id) do
    key = @prefix <> session_id

    case safe_cache_put(key, true, ttl: @ttl) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "expired_sessions revoke failed session_id=#{session_id} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  @doc """
  Returns true when the session id was recently revoked via logout.
  """
  @spec revoked?(String.t()) :: boolean()
  def revoked?(session_id) when is_binary(session_id) do
    key = @prefix <> session_id

    case safe_cache_get(key) do
      {:ok, nil} ->
        false

      {:ok, _} ->
        true

      nil ->
        false

      {:error, reason} ->
        Logger.warning(
          "expired_sessions get failed session_id=#{session_id} reason=#{inspect(reason)}"
        )

        session_revoked_in_postgres?(session_id)
    end
  end

  defp session_revoked_in_postgres?(session_id) do
    case Repo.get(Session, session_id) do
      nil -> true
      %Session{} -> false
    end
  end

  defp safe_cache_put(key, value, opts) do
    try do
      case cache().put(key, value, opts) do
        :ok -> :ok
        other -> {:error, other}
      end
    rescue
      exception -> {:error, exception}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp safe_cache_get(key) do
    try do
      cache().get(key)
    rescue
      exception -> {:error, exception}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp cache do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:cache, L2)
  end
end
