defmodule PhxBackendBoilerplate.HealthTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Health

  describe "live/0" do
    test "returns :ok" do
      assert Health.live() == :ok
    end
  end

  describe "ready/0" do
    test "returns :ok when postgres and redis are reachable" do
      assert Health.ready() == :ok
    end
  end

  describe "ready/1" do
    test "returns :ok when all injected checks pass" do
      assert Health.ready(postgres: fn -> :ok end, redis: fn -> :ok end) == :ok
    end

    test "returns error when postgres check fails" do
      assert {:error, %{postgres: :error, redis: :ok}} =
               Health.ready(postgres: fn -> :error end, redis: fn -> :ok end)
    end

    test "returns error when redis check fails" do
      assert {:error, %{postgres: :ok, redis: :error}} =
               Health.ready(postgres: fn -> :ok end, redis: fn -> :error end)
    end

    test "returns error when both checks fail" do
      assert {:error, %{postgres: :error, redis: :error}} =
               Health.ready(postgres: fn -> :error end, redis: fn -> :error end)
    end

    test "treats raised check as error" do
      assert {:error, %{postgres: :error, redis: :ok}} =
               Health.ready(
                 postgres: fn -> raise "boom" end,
                 redis: fn -> :ok end
               )
    end
  end
end
