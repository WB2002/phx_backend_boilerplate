defmodule PhxBackendBoilerplate.Files.Scanner.FakeTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Files.Scanner.Fake

  setup do
    _ = Fake.stop()
    {:ok, _} = Fake.start_link(result: :clean)

    on_exit(fn ->
      _ = Fake.stop()
    end)

    :ok
  end

  test "returns configured clean result" do
    assert :clean = Fake.scan_file("/tmp/x")
  end

  test "can return infected" do
    Fake.set_result({:error, :infected})
    assert {:error, :infected} = Fake.scan_file("/tmp/x")
  end

  test "can return scanner unavailable" do
    Fake.set_result({:error, :scanner_unavailable})
    assert {:error, :scanner_unavailable} = Fake.scan_file("/tmp/x")
  end
end
