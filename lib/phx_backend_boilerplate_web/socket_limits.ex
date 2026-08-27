defmodule PhxBackendBoilerplateWeb.SocketLimits do
  @moduledoc """
  Budgets for WebSocket upgrades, frames, connect params, and channel joins.
  """

  @max_frame_size 65_536
  @max_fragmented_message_size 262_144
  @max_connections 4_096
  @max_token_bytes 8_192
  @idle_timeout_ms 60_000
  @max_channels_per_socket 8
  @max_connects_per_minute 30
  @connect_scale_ms 60_000

  @channel_counts_table __MODULE__.ChannelCounts

  @spec max_frame_size() :: pos_integer()
  def max_frame_size, do: fetch(:max_frame_size, @max_frame_size)

  @spec max_fragmented_message_size() :: pos_integer()
  def max_fragmented_message_size,
    do: fetch(:max_fragmented_message_size, @max_fragmented_message_size)

  @spec max_connections() :: pos_integer()
  def max_connections, do: fetch(:max_connections, @max_connections)

  @spec max_token_bytes() :: pos_integer()
  def max_token_bytes, do: fetch(:max_token_bytes, @max_token_bytes)

  @spec idle_timeout_ms() :: pos_integer()
  def idle_timeout_ms, do: fetch(:idle_timeout_ms, @idle_timeout_ms)

  @spec max_channels_per_socket() :: pos_integer()
  def max_channels_per_socket, do: fetch(:max_channels_per_socket, @max_channels_per_socket)

  @spec max_connects_per_minute() :: pos_integer()
  def max_connects_per_minute, do: fetch(:max_connects_per_minute, @max_connects_per_minute)

  @doc """
  Bandit/Thousand Island HTTP options for frame size, connection count, and idle read timeout.
  """
  @spec http_options() :: keyword()
  def http_options do
    [
      websocket_options: [
        max_frame_size: max_frame_size(),
        max_fragmented_message_size: max_fragmented_message_size()
      ],
      thousand_island_options: [
        num_connections: max_connections(),
        read_timeout: idle_timeout_ms()
      ]
    ]
  end

  @doc """
  Phoenix `socket` transport options (timeout + connect_info for peer IP).
  """
  @spec websocket_transport_options() :: keyword()
  def websocket_transport_options do
    [
      connect_info: [:peer_data, :x_headers],
      timeout: idle_timeout_ms()
    ]
  end

  @doc """
  Rate-limits WebSocket connects per peer IP. Missing peer data is allowed (tests).
  """
  @spec rate_limit_connect(map()) :: :ok | :error
  def rate_limit_connect(connect_info) when is_map(connect_info) do
    case peer_ip(connect_info) do
      nil ->
        :ok

      ip ->
        key = "ws_connect:ip:#{ip}"

        case PhxBackendBoilerplate.RateLimit.hit(
               key,
               @connect_scale_ms,
               max_connects_per_minute()
             ) do
          {:allow, _count} -> :ok
          {:deny, _retry_after_ms} -> :error
        end
    end
  end

  @doc """
  Reserves one channel join slot for this socket's transport process.
  """
  @spec checkout_channel(Phoenix.Socket.t()) :: :ok | {:error, :too_many_channels}
  def checkout_channel(%Phoenix.Socket{transport_pid: pid}) when is_pid(pid) do
    ensure_channel_counts_table!()
    count = :ets.update_counter(@channel_counts_table, pid, {2, 1}, {pid, 0})

    if count == 1 do
      spawn_monitor_cleanup(pid)
    end

    if count > max_channels_per_socket() do
      :ets.update_counter(@channel_counts_table, pid, {2, -1})
      {:error, :too_many_channels}
    else
      :ok
    end
  end

  def checkout_channel(_socket), do: :ok

  @doc """
  Releases one channel join slot (call from channel terminate).
  """
  @spec checkin_channel(Phoenix.Socket.t()) :: :ok
  def checkin_channel(%Phoenix.Socket{transport_pid: pid}) when is_pid(pid) do
    ensure_channel_counts_table!()

    case :ets.lookup(@channel_counts_table, pid) do
      [{^pid, count}] when count > 0 ->
        :ets.update_counter(@channel_counts_table, pid, {2, -1})
        :ok

      _ ->
        :ok
    end
  end

  def checkin_channel(_socket), do: :ok

  @spec peer_ip(map()) :: String.t() | nil
  def peer_ip(%{peer_data: %{address: address}}) when is_tuple(address) do
    address |> :inet.ntoa() |> to_string()
  end

  def peer_ip(_), do: nil

  defp spawn_monitor_cleanup(pid) do
    spawn(fn ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          if :ets.whereis(@channel_counts_table) != :undefined do
            :ets.delete(@channel_counts_table, pid)
          end
      end
    end)
  end

  defp ensure_channel_counts_table! do
    case :ets.whereis(@channel_counts_table) do
      :undefined ->
        try do
          :ets.new(@channel_counts_table, [
            :named_table,
            :public,
            :set,
            write_concurrency: true
          ])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  defp fetch(key, default) do
    :phx_backend_boilerplate
    |> Application.get_env(:socket_limits, [])
    |> Keyword.get(key, default)
  end
end
