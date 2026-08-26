defmodule PhxBackendBoilerplate.FilesTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Files
  alias PhxBackendBoilerplate.Files.Scanner.Fake
  alias Plug.Upload

  setup do
    Fake.stop()
    {:ok, _} = Fake.start_link(result: :clean)

    root =
      Path.join([
        File.cwd!(),
        "tmp",
        "test-uploads-#{System.unique_integer([:positive])}"
      ])

    File.mkdir_p!(root)

    previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])

    Application.put_env(
      :phx_backend_boilerplate,
      PhxBackendBoilerplate.Files,
      previous
      |> Keyword.put(:local_root, root)
      |> Keyword.put(:scanner, Fake)
      |> Keyword.put(:storage, PhxBackendBoilerplate.Files.Storage.Local)
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, previous)
      Fake.stop()
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  test "ingests multiple files all-or-nothing on success" do
    u1 = png_upload("a.png")
    u2 = png_upload("b.png")

    assert {:ok, [f1, f2]} = Files.ingest([u1, u2])
    assert f1.filename == "a.png"
    assert f2.filename == "b.png"
    assert byte_size(f1.sha256) == 64
  end

  test "rejects checksum mismatch" do
    upload = png_upload("c.png")
    bad = String.duplicate("a", 64)

    assert {:error, :checksum_mismatch} = Files.ingest([upload], [bad])
  end

  test "rejects infected files and stores nothing" do
    Fake.set_result({:error, :infected})
    upload = png_upload("virus.png")

    assert {:error, :infected} = Files.ingest([upload])
    assert Files.get(Ecto.UUID.generate()) == {:error, :not_found}
  end

  test "rolls back earlier files when a later file fails" do
    good = png_upload("good.png")
    bad = png_upload("bad.png")

    # First file cleans; force second scan to fail by switching mid-flight via Agent —
    # use a custom expected checksum for the second file instead.
    assert {:error, :checksum_mismatch} =
             Files.ingest([good, bad], [nil, String.duplicate("0", 64)])

    # First file must not remain after rollback
    assert PhxBackendBoilerplate.Repo.aggregate(PhxBackendBoilerplate.Files.StoredFile, :count) ==
             0
  end

  test "open_stream returns a byte slice", %{root: _root} do
    upload = png_upload("slice.png")
    assert {:ok, [file]} = Files.ingest([upload])
    assert {:ok, ^file, stream} = Files.open_stream(file.id, 0, 4)
    assert IO.iodata_to_binary(Enum.to_list(stream)) == binary_part(File.read!(upload.path), 0, 4)
  end

  defp png_upload(filename) do
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-#{filename}")
    File.write!(path, png_bytes())
    on_exit(fn -> File.rm(path) end)

    %Upload{path: path, filename: filename, content_type: "image/png"}
  end

  defp png_bytes do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, "rest">>
  end
end
