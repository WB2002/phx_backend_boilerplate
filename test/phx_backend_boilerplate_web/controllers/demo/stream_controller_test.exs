defmodule PhxBackendBoilerplateWeb.Demo.StreamControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  setup %{conn: conn} do
    {:ok, conn: Map.put(conn, :remote_ip, unique_ip())}
  end

  test "chunks streams NDJSON lines", %{conn: conn} do
    conn = get(conn, ~p"/api/demo/stream/chunks?count=3&interval_ms=0")

    assert conn.status == 200
    assert response_content_type(conn, :ndjson) =~ "application/x-ndjson"

    body = response(conn, 200)

    lines =
      body
      |> String.trim()
      |> String.split("\n", trim: true)

    assert length(lines) == 3

    for {line, idx} <- Enum.with_index(lines, 1) do
      assert %{"seq" => ^idx, "t" => t} = Jason.decode!(line)
      assert is_integer(t)
    end
  end

  test "chunks caps count at 10", %{conn: conn} do
    conn = get(conn, ~p"/api/demo/stream/chunks?count=99&interval_ms=0")
    body = response(conn, 200)

    lines =
      body
      |> String.trim()
      |> String.split("\n", trim: true)

    assert length(lines) == 10
  end

  test "sse streams tick events then done", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/event-stream")
      |> get(~p"/api/demo/stream/sse?count=2&interval_ms=0")

    assert conn.status == 200
    assert response_content_type(conn, :sse) =~ "text/event-stream"
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
    assert get_resp_header(conn, "x-accel-buffering") == ["no"]

    body = response(conn, 200)

    assert body =~ "event: tick"
    assert body =~ "id: 1"
    assert body =~ "id: 2"
    assert body =~ "event: done"
    assert body =~ "data: {}"

    assert length(Regex.scan(~r/^event: tick$/m, body)) == 2
  end

  test "sse accepts event-stream Accept header without 406", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/event-stream")
      |> get(~p"/api/demo/stream/sse?count=1&interval_ms=0")

    refute conn.status == 406
    assert conn.status == 200
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 4, rem(div(n, 256), 256), rem(n, 256)}
  end
end
