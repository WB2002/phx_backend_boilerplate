defmodule PhxBackendBoilerplate.Flags do
  @moduledoc """
  Thin wrapper around [FunWithFlags](https://hexdocs.pm/fun_with_flags) for this app.

  Prefer this module over calling `FunWithFlags` directly from controllers so
  flag names and actor construction stay consistent.

  ## Demo flag names

    * `:demo_preview` — global boolean (kill-switch / unreleased endpoint)
    * `:demo_beta` — per-guest actor gate

  ## Examples

      PhxBackendBoilerplate.Flags.enabled?(:demo_preview)

      guest = PhxBackendBoilerplate.Flags.guest("uuid-here")
      PhxBackendBoilerplate.Flags.enabled?(:demo_beta, guest)

  Toggle in IEx or the `/dev/feature-flags` UI:

      FunWithFlags.enable(:demo_preview)
      FunWithFlags.enable(:demo_beta, for_actor: PhxBackendBoilerplate.Flags.guest(id))
  """

  alias PhxBackendBoilerplate.Flags.Guest

  @doc """
  Returns whether `flag` is enabled globally.
  """
  @spec enabled?(atom()) :: boolean()
  def enabled?(flag) when is_atom(flag) do
    FunWithFlags.enabled?(flag)
  end

  @doc """
  Returns whether `flag` is enabled for the given actor (e.g. `%Guest{}`).
  """
  @spec enabled?(atom(), term()) :: boolean()
  def enabled?(flag, actor) when is_atom(flag) do
    FunWithFlags.enabled?(flag, for: actor)
  end

  @doc """
  Builds a guest actor for per-guest feature gates.
  """
  @spec guest(String.t()) :: Guest.t()
  def guest(id) when is_binary(id) do
    %Guest{id: id}
  end
end
