defmodule PhxBackendBoilerplateWeb.Plugs.ParsersLimitTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  @default_length Application.compile_env!(:phx_backend_boilerplate, [:parsers, :length])

  test "returns 413 when JSON body exceeds default parser length" do
    over = @default_length + 1
    body = Jason.encode!(%{"password" => String.duplicate("a", over)})

    conn =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/auth/login", body)

    assert json_response(conn, 413) == %{
             "errors" => %{"detail" => "Request Entity Too Large"}
           }
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 4, rem(div(n, 256), 256), rem(n, 256)}
  end

  test "multipart upload_length matches max file size times max files" do
    files = Application.fetch_env!(:phx_backend_boilerplate, PhxBackendBoilerplate.Files)
    parsers = Application.fetch_env!(:phx_backend_boilerplate, :parsers)

    assert Keyword.fetch!(parsers, :upload_length) ==
             Keyword.fetch!(files, :max_file_bytes) *
               Keyword.fetch!(files, :max_files_per_request)
  end
end
