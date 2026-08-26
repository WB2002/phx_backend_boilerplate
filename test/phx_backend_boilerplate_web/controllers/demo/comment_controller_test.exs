defmodule PhxBackendBoilerplateWeb.Demo.CommentControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.PubSub

  @valid_payload %{
    "title" => "<b>Hi</b>",
    "body" => "<p>ok</p><script>alert(1)</script>",
    "email" => "demo@example.com",
    "parent_id" => 1
  }

  setup %{conn: conn} do
    ip = unique_ip()
    {:ok, conn: Map.put(conn, :remote_ip, ip)}
  end

  test "returns sanitized DTO fields on success", %{conn: conn} do
    conn = post(conn, ~p"/api/demo/comments", @valid_payload)

    assert %{
             "data" => %{
               "title" => "Hi",
               "body" => body,
               "email" => "demo@example.com",
               "parent_id" => 1
             }
           } = json_response(conn, 200)

    assert body =~ "<p>ok</p>"
    refute body =~ "<script"
  end

  test "broadcasts comment_created on demo:lobby after success", %{conn: conn} do
    :ok = PubSub.subscribe("demo:lobby")

    conn = post(conn, ~p"/api/demo/comments", @valid_payload)
    assert json_response(conn, 200)

    assert_receive {PubSub, "demo:lobby",
                    %{
                      "event" => "comment_created",
                      "title" => "Hi",
                      "email" => "demo@example.com"
                    }}
  end

  test "returns 422 with field errors when required fields are missing", %{conn: conn} do
    conn = post(conn, ~p"/api/demo/comments", %{"title" => "only"})

    assert %{
             "errors" => %{
               "detail" => "Unprocessable Entity",
               "fields" => fields
             }
           } = json_response(conn, 422)

    assert Map.has_key?(fields, "body")
    assert Map.has_key?(fields, "email")
  end

  test "rejects SQL-injection-style parent_id at the DTO boundary", %{conn: conn} do
    payload = Map.put(@valid_payload, "parent_id", "1; DROP TABLE comments")

    conn = post(conn, ~p"/api/demo/comments", payload)

    assert %{
             "errors" => %{
               "detail" => "Unprocessable Entity",
               "fields" => %{"parent_id" => [_ | _]}
             }
           } = json_response(conn, 422)
  end

  test "rejects invalid email format", %{conn: conn} do
    payload = Map.put(@valid_payload, "email", "not-an-email")

    conn = post(conn, ~p"/api/demo/comments", payload)

    assert %{
             "errors" => %{
               "fields" => %{"email" => [_ | _]}
             }
           } = json_response(conn, 422)
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 0, rem(div(n, 256), 256), rem(n, 256)}
  end
end
