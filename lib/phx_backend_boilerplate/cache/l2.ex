defmodule PhxBackendBoilerplate.Cache.L2 do
  @moduledoc """
  Shared Redis cache (source of truth for SWR). Also hosts stampede locks
  via `put_new` on `swr:lock:<key>` keys.
  """

  use Nebulex.Cache,
    otp_app: :phx_backend_boilerplate,
    adapter: Nebulex.Adapters.Redis
end
