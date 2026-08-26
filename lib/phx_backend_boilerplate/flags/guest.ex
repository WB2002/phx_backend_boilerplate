defmodule PhxBackendBoilerplate.Flags.Guest do
  @moduledoc """
  Actor used for per-guest feature flag gates (e.g. `:demo_beta`).

  Identity is the guest UUID from `EnsureGuestId` / `x-guest-id`.
  """

  defstruct [:id]

  @type t :: %__MODULE__{id: String.t()}
end

defimpl FunWithFlags.Actor, for: PhxBackendBoilerplate.Flags.Guest do
  def id(%{id: id}) when is_binary(id) do
    "guest:#{id}"
  end
end
