defmodule PhxBackendBoilerplateWeb.EndpointSocketsTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplateWeb.Endpoint
  alias PhxBackendBoilerplateWeb.SocketLimits

  test "does not mount LiveView socket when dev_routes are disabled" do
    refute Application.get_env(:phx_backend_boilerplate, :dev_routes, false)

    paths = Enum.map(Endpoint.__sockets__(), fn {path, _mod, _opts} -> path end)
    refute "/live" in paths
    assert "/socket" in paths
    assert "/graphql" in paths
  end

  test "endpoint HTTP config bounds WebSocket frames and connections" do
    http = Endpoint.config(:http)
    ws = Keyword.fetch!(http, :websocket_options)
    island = Keyword.fetch!(http, :thousand_island_options)

    assert ws[:max_frame_size] == SocketLimits.max_frame_size()
    assert ws[:max_fragmented_message_size] == SocketLimits.max_fragmented_message_size()
    assert island[:num_connections] == SocketLimits.max_connections()
  end
end
