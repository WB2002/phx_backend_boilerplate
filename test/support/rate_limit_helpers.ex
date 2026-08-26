defmodule PhxBackendBoilerplate.Test.RateLimitHelpers do
  @moduledoc false

  @prefix "phx_backend_boilerplate:rate_limit:"

  @doc """
  Deletes Hammer rate-limit keys for the given bucket id (test isolation).
  """
  @spec clear_id(String.t()) :: :ok
  def clear_id(id) when is_binary(id) do
    pattern = "#{@prefix}#{id}:*"

    with {:ok, url} <- redis_url(),
         {:ok, conn} <- Redix.start_link(url) do
      try do
        case Redix.command(conn, ["KEYS", pattern]) do
          {:ok, []} ->
            :ok

          {:ok, keys} when is_list(keys) ->
            _ = Redix.command(conn, ["DEL" | keys])
            :ok

          _ ->
            :ok
        end
      after
        Redix.stop(conn)
      end
    else
      _ -> :ok
    end
  end

  defp redis_url do
    case Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.RateLimit, []) do
      opts when is_list(opts) ->
        case Keyword.get(opts, :url) do
          url when is_binary(url) and url != "" -> {:ok, url}
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
