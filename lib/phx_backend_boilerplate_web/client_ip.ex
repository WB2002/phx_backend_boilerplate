defmodule PhxBackendBoilerplateWeb.ClientIp do
  @moduledoc """
  Resolves the client IP for rate limiting and abuse controls.

  `X-Forwarded-For` is only trusted when `trust_x_forwarded_for` is enabled
  in application config (set via `TRUST_X_FORWARDED_FOR` in runtime.exs).
  Otherwise `conn.remote_ip` / peer data is used so clients cannot spoof
  rate-limit keys.

  When trusted, hops are read from the right; trusted proxy IPs/CIDRs and the
  immediate peer are stripped before selecting the client address.
  """

  @doc """
  Returns a string IP for the connecting client, or `"unknown"`.
  """
  @spec from_conn(Plug.Conn.t()) :: String.t()
  def from_conn(conn) do
    cond do
      trust_x_forwarded_for?() ->
        xff_client_ip(conn) || direct_ip(conn)

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

  defp xff_client_ip(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> List.first()
    |> parse_xff_client_ip(direct_ip(conn))
  end

  defp xff_from_connect_info(%{x_headers: headers, peer_data: peer_data}) when is_list(headers) do
    peer_ip =
      case peer_data do
        %{address: address} when is_tuple(address) -> address |> :inet.ntoa() |> to_string()
        _ -> nil
      end

    headers
    |> Enum.find_value(fn
      {"x-forwarded-for", value} -> parse_xff_client_ip(value, peer_ip)
      _ -> nil
    end)
  end

  defp xff_from_connect_info(%{x_headers: headers}) when is_list(headers) do
    Enum.find_value(headers, fn
      {"x-forwarded-for", value} -> parse_xff_client_ip(value, nil)
      _ -> nil
    end)
  end

  defp xff_from_connect_info(_connect_info), do: nil

  defp parse_xff_client_ip(value, peer_ip) do
    value
    |> present_or_nil()
    |> case do
      nil ->
        nil

      forwarded ->
        forwarded
        |> String.split(",", trim: true)
        |> resolve_client_hop(peer_ip)
    end
  end

  defp resolve_client_hop(hops, peer_ip) when is_list(hops) and hops != [] do
    reversed = Enum.reverse(hops)

    case reversed do
      [rightmost | rest] ->
        if is_binary(peer_ip) and String.trim(rightmost) != String.trim(peer_ip) do
          nil
        else
          rest
          |> drop_trusted_hops(peer_ip)
          |> case do
            [] -> nil
            [client | _] -> client |> String.trim() |> validate_ip_string()
          end
        end

      _ ->
        nil
    end
  end

  defp resolve_client_hop(_hops, _peer_ip), do: nil

  defp drop_trusted_hops(hops, peer_ip) do
    Enum.drop_while(hops, &trusted_proxy_hop?(&1, peer_ip))
  end

  defp trusted_proxy_hop?(hop, peer_ip) do
    trimmed = String.trim(hop)

    (is_binary(peer_ip) and trimmed == peer_ip) or
      Enum.any?(trusted_proxy_cidrs(), &cidr_contains?(&1, trimmed))
  end

  defp validate_ip_string(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, _} -> ip
      {:error, _} -> nil
    end
  end

  # Full CIDR matching can be expanded later; bootstrapped entries are exact host IPs.
  defp cidr_contains?(cidr, ip) when is_binary(cidr) and is_binary(ip) do
    case String.split(cidr, "/", parts: 2) do
      [net] -> String.trim(net) == ip
      [net, bits] -> String.trim(net) == ip and bits in ["32", "128"]
      _ -> false
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

  defp trusted_proxy_cidrs do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:trusted_proxy_cidrs, [])
  end

  defp present_or_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp present_or_nil(_), do: nil
end
