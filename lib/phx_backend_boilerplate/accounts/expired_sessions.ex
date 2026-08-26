defmodule PhxBackendBoilerplate.Accounts.ExpiredSessions do
  @moduledoc """
  Redis-backed deny list for recently logged-out sessions.

  Each revoked session id is stored under `expired_sessions:<id>` with a 15-minute
  TTL so in-flight access tokens fail the auth guard without hitting Postgres.
  """

  alias PhxBackendBoilerplate.Cache.L2

  @prefix "expired_sessions:"
  @ttl :timer.minutes(15)

  @doc """
  Marks a session id as expired in Redis.
  """
  @spec revoke(String.t()) :: :ok
  def revoke(session_id) when is_binary(session_id) do
    :ok = L2.put(@prefix <> session_id, true, ttl: @ttl)
    :ok
  end

  @doc """
  Returns true when the session id was recently revoked via logout.
  """
  @spec revoked?(String.t()) :: boolean()
  def revoked?(session_id) when is_binary(session_id) do
    case L2.get(@prefix <> session_id) do
      {:ok, nil} -> false
      {:ok, _} -> true
      nil -> false
      _ -> true
    end
  end
end
