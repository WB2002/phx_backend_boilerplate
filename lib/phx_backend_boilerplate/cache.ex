defmodule PhxBackendBoilerplate.Cache do
  @moduledoc """
  Inclusive multilevel cache: L1 (local ETS) then L2 (Redis).

  **Reads** go through this module (`get`/`fetch`) so L2 hits replicate back to L1.

  **SWR writes** must call `L2.put` then `L1.put` with different hard TTLs —
  multilevel `put/3` applies a single `:ttl` to every level.
  """

  use Nebulex.Cache,
    otp_app: :phx_backend_boilerplate,
    adapter: Nebulex.Adapters.Multilevel
end
