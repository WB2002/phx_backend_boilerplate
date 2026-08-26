defmodule PhxBackendBoilerplateWeb.SocketLimits do
  @moduledoc """
  Budgets for WebSocket upgrades, frames, and connect params.
  """

  @max_frame_size 65_536
  @max_fragmented_message_size 262_144
  @max_connections 4_096
  @max_token_bytes 8_192

  @spec max_frame_size() :: pos_integer()
  def max_frame_size, do: fetch(:max_frame_size, @max_frame_size)

  @spec max_fragmented_message_size() :: pos_integer()
  def max_fragmented_message_size,
    do: fetch(:max_fragmented_message_size, @max_fragmented_message_size)

  @spec max_connections() :: pos_integer()
  def max_connections, do: fetch(:max_connections, @max_connections)

  @spec max_token_bytes() :: pos_integer()
  def max_token_bytes, do: fetch(:max_token_bytes, @max_token_bytes)

  @spec http_options() :: keyword()
  def http_options do
    [
      websocket_options: [
        max_frame_size: max_frame_size(),
        max_fragmented_message_size: max_fragmented_message_size()
      ],
      thousand_island_options: [
        num_connections: max_connections()
      ]
    ]
  end

  defp fetch(key, default) do
    :phx_backend_boilerplate
    |> Application.get_env(:socket_limits, [])
    |> Keyword.get(key, default)
  end
end
