defmodule PhxBackendBoilerplate.Accounts.ExpiredSessions do
  @moduledoc """
  Redis-backed deny list for recently logged-out sessions.

  Each revoked session id is stored under `expired_sessions:<id>` with a TTL
  aligned to `PhxBackendBoilerplate.Accounts` `deny_list_ttl` so in-flight
  access tokens fail the auth guard without hitting Postgres on every request.

  Redis is a cache: logout always succeeds after the Postgres session delete;
  deny-list writes are best-effort. When Redis has no deny entry (`{:ok, nil}`),
  the session is treated as active — access JWT expiry is the other revocation
  boundary.

  On Redis read errors, falls back to Postgres: missing session rows are treated
  as revoked (fail-closed for logged-out sessions).
  """

  require Logger

  alias PhxBackendBoilerplate.Accounts.Config
  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Repo

  @prefix "expired_sessions:"

  @doc """
  Marks a session id as expired in Redis.

  Returns `:ok` even when Redis is unavailable (best-effort cache write).
  """
  @spec revoke(String.t()) :: :ok
  def revoke(session_id) when is_binary(session_id) do
    key = @prefix <> session_id

    case safe_cache_put(key, true, ttl: deny_list_ttl_ms()) do
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
  Returns true when the session id was revoked via logout (deny-list entry present).
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

        revoked_via_postgres?(session_id)
    end
  end

  defp revoked_via_postgres?(session_id) do
    case Repo.get(Session, session_id) do
      %Session{} -> false
      nil -> true
    end
  end

  defp deny_list_ttl_ms do
    Config.deny_list_ttl_ms()
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
