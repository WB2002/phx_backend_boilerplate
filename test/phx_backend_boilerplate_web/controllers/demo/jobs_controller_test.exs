defmodule PhxBackendBoilerplateWeb.Demo.JobsControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false
  use Oban.Testing, repo: PhxBackendBoilerplate.Repo

  alias PhxBackendBoilerplate.Workers.DemoJob

  setup %{conn: conn} do
    ip = unique_ip()
    {:ok, conn: Map.put(conn, :remote_ip, ip)}
  end

  test "POST /api/demo/jobs enqueues and returns 202", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/demo/jobs", %{"message" => "hello", "work_ms" => 10})

    assert %{
             "data" => %{
               "id" => id,
               "state" => "available",
               "queue" => "default",
               "worker" => "PhxBackendBoilerplate.Workers.DemoJob",
               "args" => %{"message" => "hello", "work_ms" => 10}
             }
           } = json_response(conn, 202)

    assert is_integer(id)
    assert_enqueued(worker: DemoJob, args: %{"message" => "hello", "work_ms" => 10})
  end

  test "POST /api/demo/jobs returns 422 without message", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/demo/jobs", %{})

    assert %{"errors" => %{"detail" => "Unprocessable Entity", "fields" => fields}} =
             json_response(conn, 422)

    assert Map.has_key?(fields, "message")
  end

  test "POST /api/demo/jobs echoes correlation id and stores it on the job", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-correlation-id", "journey-jobs-1")
      |> post(~p"/api/demo/jobs", %{"message" => "correlated"})

    assert json_response(conn, 202)
    assert get_resp_header(conn, "x-correlation-id") == ["journey-jobs-1"]

    assert_enqueued(
      worker: DemoJob,
      args: %{"message" => "correlated", "correlation_id" => "journey-jobs-1"}
    )
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 5, rem(div(n, 256), 256), rem(n, 256)}
  end
end
