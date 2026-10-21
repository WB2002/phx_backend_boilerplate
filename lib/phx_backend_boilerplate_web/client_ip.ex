defmodule PhxBackendBoilerplateWeb.ClientIp do
  @moduledoc """
  Resolves the client IP for rate limiting and abuse controls.

  `X-Forwarded-For` is only trusted when `trust_x_forwarded_for` is enabled
  in application config (set via `TRUST_X_FORWARDED_FOR` in runtime.exs).
  Otherwise `conn.remote_ip` / peer data is used so clients cannot spoof
  rate-limit keys.
  """

  @doc """
  Returns a string IP for the connecting client, or `"unknown"`.
  """
  @spec from_conn(Plug.Conn.t()) :: String.t()
  def from_conn(conn) do
    cond do
      trust_x_forwarded_for?() ->
        xff_first_hop(conn) || direct_ip(conn)

      true ->
        direct_ip(conn)
    end
  end

  @doc """
  Returns a string IP from Phoenix WebSocket `connect_info`, or `"unknown"`.
  """
  @spec from_connect_info(map()) :: String.t()
  def from_connect_info(connect_info) when is_map(connect_info) do
    cond do
      trust_x_forwarded_for?() ->
        xff_from_connect_info(connect_info) || peer_data_ip(connect_info) || "unknown"

      true ->
        peer_data_ip(connect_info) || "unknown"
    end
  end

  defp xff_first_hop(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> List.first()
    |> parse_xff_first_hop()
  end

  defp xff_from_connect_info(%{x_headers: headers}) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"x-forwarded-for", value} -> parse_xff_first_hop(value)
      _ -> nil
    end)
  end

  defp xff_from_connect_info(_connect_info), do: nil

  defp parse_xff_first_hop(value) do
    value
    |> present_or_nil()
    |> case do
      nil ->
        nil

      forwarded ->
        forwarded
        |> String.split(",", trim: true)
        |> List.first()
        |> String.trim()
        |> present_or_nil()
    end
  end

  defp direct_ip(conn) do
    case conn.remote_ip do
      ip when is_tuple(ip) -> ip |> :inet.ntoa() |> to_string()
      _ -> "unknown"
    end
  end

  defp peer_data_ip(%{peer_data: %{address: address}}) when is_tuple(address) do
    address |> :inet.ntoa() |> to_string()
  end

  defp peer_data_ip(_connect_info), do: nil

  defp trust_x_forwarded_for? do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:trust_x_forwarded_for, false)
  end

  defp present_or_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp present_or_nil(_), do: nil
end
