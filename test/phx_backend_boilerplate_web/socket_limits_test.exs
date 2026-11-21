defmodule PhxBackendBoilerplateWeb.SocketLimitsTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplateWeb.SocketLimits

  test "rate_limit_connect allows connect when rate limit backend errors" do
    previous = Application.get_env(:phx_backend_boilerplate, SocketLimits, [])

    Application.put_env(
      :phx_backend_boilerplate,
      SocketLimits,
      Keyword.put(previous, :hit, fn _, _, _ -> {:error, :redis_down} end)
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, SocketLimits, previous) end)

    connect_info = %{peer_data: %{address: {198, 51, 100, 10}}, x_headers: []}

    assert :ok = SocketLimits.rate_limit_connect(connect_info)
  end
end
