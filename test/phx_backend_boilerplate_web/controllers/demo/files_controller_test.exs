defmodule PhxBackendBoilerplateWeb.Demo.FilesControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.Files.Scanner.Fake
  alias Plug.Upload

  setup %{conn: conn} do
    Fake.stop()
    {:ok, _} = Fake.start_link(result: :clean)

    root =
      Path.join([
        File.cwd!(),
        "tmp",
        "ctrl-uploads-#{System.unique_integer([:positive])}"
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

    {:ok, conn: Map.put(conn, :remote_ip, unique_ip()), root: root}
  end

  test "uploads multiple files and returns metadata", %{conn: conn} do
    u1 = png_upload("one.png")
    u2 = png_upload("two.png")

    conn = post(conn, ~p"/api/demo/files", %{"files" => [u1, u2]})

    assert %{
             "data" => [
               %{"id" => id1, "filename" => "one.png", "sha256" => sha1},
               %{"id" => id2, "filename" => "two.png", "sha256" => sha2}
             ]
           } = json_response(conn, 201)

    assert is_binary(id1) and is_binary(id2)
    assert byte_size(sha1) == 64
    assert byte_size(sha2) == 64
  end

  test "HEAD returns accept-ranges", %{conn: conn} do
    upload = png_upload("head.png")
    create = post(conn, ~p"/api/demo/files", %{"files" => [upload]})
    assert %{"data" => [%{"id" => id}]} = json_response(create, 201)

    conn = head(conn, ~p"/api/demo/files/#{id}")
    assert response(conn, 200) == ""
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
  end

  test "GET with Range returns 206 and partial body", %{conn: conn} do
    upload = png_upload("range.png")
    create = post(conn, ~p"/api/demo/files", %{"files" => [upload]})
    assert %{"data" => [%{"id" => id}]} = json_response(create, 201)

    conn =
      conn
      |> put_req_header("range", "bytes=0-3")
      |> get(~p"/api/demo/files/#{id}")

    assert response(conn, 206)
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert [content_range] = get_resp_header(conn, "content-range")
    assert content_range =~ "bytes 0-3/"
    assert byte_size(response(conn, 206)) == 4
  end

  test "returns 422 on checksum mismatch", %{conn: conn} do
    upload = png_upload("badhash.png")

    conn =
      post(conn, ~p"/api/demo/files", %{
        "files" => [upload],
        "sha256" => [String.duplicate("0", 64)]
      })

    assert %{"errors" => %{"detail" => "Checksum mismatch"}} = json_response(conn, 422)
  end

  test "returns 503 when scanner is unavailable", %{conn: conn} do
    Fake.set_result({:error, :scanner_unavailable})
    upload = png_upload("noscan.png")

    conn = post(conn, ~p"/api/demo/files", %{"files" => [upload]})
    assert %{"errors" => %{"detail" => "Virus scanner unavailable"}} = json_response(conn, 503)
  end

  test "returns 422 when infected", %{conn: conn} do
    Fake.set_result({:error, :infected})
    upload = png_upload("eicar.png")

    conn = post(conn, ~p"/api/demo/files", %{"files" => [upload]})
    assert %{"errors" => %{"detail" => "File failed virus scan"}} = json_response(conn, 422)
  end

  defp png_upload(filename) do
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-#{filename}")
    File.write!(path, png_bytes())
    on_exit(fn -> File.rm(path) end)
    %Upload{path: path, filename: filename, content_type: "image/png"}
  end

  defp png_bytes do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, "body">>
  end

  defp unique_ip do
    {Enum.random(1..254), Enum.random(1..254), Enum.random(1..254), Enum.random(1..254)}
  end
end
