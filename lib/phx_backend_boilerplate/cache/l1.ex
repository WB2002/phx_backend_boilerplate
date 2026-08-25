defmodule PhxBackendBoilerplate.Cache.L1 do
  @moduledoc """
  Node-local generational cache (ETS). Shorter hard TTL than L2 so remote
  nodes converge to refreshed L2 values without PubSub invalidation.
  """

  use Nebulex.Cache,
    otp_app: :phx_backend_boilerplate,
    adapter: Nebulex.Adapters.Local
end
