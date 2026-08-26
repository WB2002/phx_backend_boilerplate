defmodule PhxBackendBoilerplate.FlagsTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Flags

  setup do
    _ = FunWithFlags.clear(:demo_preview)
    _ = FunWithFlags.clear(:demo_beta)
    :ok
  end

  test "boolean flag defaults to disabled and can be enabled" do
    refute Flags.enabled?(:demo_preview)

    assert {:ok, true} = FunWithFlags.enable(:demo_preview)
    assert Flags.enabled?(:demo_preview)

    assert {:ok, false} = FunWithFlags.disable(:demo_preview)
    refute Flags.enabled?(:demo_preview)
  end

  test "actor flag is enabled only for the targeted guest" do
    guest_a = Flags.guest(Ecto.UUID.generate())
    guest_b = Flags.guest(Ecto.UUID.generate())

    refute Flags.enabled?(:demo_beta, guest_a)
    refute Flags.enabled?(:demo_beta, guest_b)

    assert {:ok, true} = FunWithFlags.enable(:demo_beta, for_actor: guest_a)

    assert Flags.enabled?(:demo_beta, guest_a)
    refute Flags.enabled?(:demo_beta, guest_b)
  end

  test "guest/1 builds an actor with namespaced id" do
    id = Ecto.UUID.generate()
    guest = Flags.guest(id)

    assert %Flags.Guest{id: ^id} = guest
    assert FunWithFlags.Actor.id(guest) == "guest:#{id}"
  end
end
