defmodule PhxBackendBoilerplate.Files.Storage.LocalTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Files.Storage.Local

  setup do
    root =
      Path.join(System.tmp_dir!(), "local-storage-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])

    Application.put_env(
      :phx_backend_boilerplate,
      PhxBackendBoilerplate.Files,
      Keyword.put(previous, :local_root, root)
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, previous)
      File.rm_rf!(root)
    end)

    src = Path.join(root, "src.bin")
    File.write!(src, "abcdefghij")
    %{root: root, src: src, key: "2026-01-01/test-key.bin"}
  end

  test "put then stream a byte slice", %{src: src, key: key} do
    assert :ok = Local.put(key, src)
    assert {:ok, stream} = Local.stream(key, 2, 4)
    assert IO.iodata_to_binary(Enum.to_list(stream)) == "cdef"
  end

  test "local_path returns absolute path under root", %{key: key, root: root, src: src} do
    assert :ok = Local.put(key, src)
    path = Local.local_path(key)
    assert String.starts_with?(path, root)
    assert File.exists?(path)
  end

  test "delete removes object", %{src: src, key: key} do
    assert :ok = Local.put(key, src)
    assert :ok = Local.delete(key)
    assert {:error, :not_found} = Local.stream(key, 0, :eof)
  end
end
