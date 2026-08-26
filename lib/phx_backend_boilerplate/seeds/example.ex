defmodule PhxBackendBoilerplate.Seeds.Example do
  @moduledoc """
  Template seeder showing data + logic.

  Replace `@data` and the body of `run/0` with `Repo.insert!` of your schemas.
  Bump `version:` when the data or logic changes so the next `mix seed` re-runs
  this module. Keep `run/0` idempotent (safe to re-apply).

  Sample guest UUID for `:demo_beta` (documented demo identity):

      11111111-1111-1111-1111-111111111111
  """

  use PhxBackendBoilerplate.Seeds.Seeder, version: 1

  alias PhxBackendBoilerplate.Flags

  # Example seed rows — swap for real domain attrs when you add schemas.
  @data [
    %{guest_id: "11111111-1111-1111-1111-111111111111", note: "demo beta guest"}
  ]

  @impl true
  def run do
    Enum.each(@data, fn %{guest_id: guest_id} ->
      guest = Flags.guest(guest_id)

      case FunWithFlags.enable(:demo_beta, for_actor: guest) do
        {:ok, true} -> :ok
        other -> raise "failed to enable :demo_beta for #{guest_id}: #{inspect(other)}"
      end
    end)

    :ok
  end
end
