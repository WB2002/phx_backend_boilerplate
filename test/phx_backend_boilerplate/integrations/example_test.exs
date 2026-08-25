defmodule PhxBackendBoilerplate.Integrations.ExampleTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Integrations.Example

  @stub __MODULE__.Stub

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, Example, [])

    Application.put_env(
      :phx_backend_boilerplate,
      Example,
      Keyword.merge(previous,
        base_url: "https://example.test",
        api_token: "test-token",
        req_options: [plug: {Req.Test, @stub}]
      )
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Example, previous)
      Example.reset()
    end)

    :ok
  end

  test "get_widget/1 returns ok response" do
    Req.Test.stub(@stub, fn conn ->
      assert conn.request_path == "/widgets/42"
      assert ["Bearer test-token"] = Plug.Conn.get_req_header(conn, "authorization")
      Req.Test.json(conn, %{"id" => 42, "name" => "widget"})
    end)

    assert {:ok, %Req.Response{status: 200, body: %{"id" => 42, "name" => "widget"}}} =
             Example.get_widget(42)
  end

  test "get_widget/1 returns http error for 404 without exhausting retries" do
    Req.Test.stub(@stub, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not_found"}))
    end)

    assert {:error, {:http, 404, %Req.Response{status: 404}}} = Example.get_widget("missing")
  end

  test "get_widget/1 returns RetriesExhausted after transient failures" do
    Req.Test.stub(@stub, fn conn ->
      Plug.Conn.send_resp(conn, 503, "unavailable")
    end)

    assert {:error, %ExternalService.RetriesExhausted{}} =
             Example.call([max_attempts: 2, base: 1, cap: 1], fn ->
               PhxBackendBoilerplate.Integrations.through_req(fn ->
                 PhxBackendBoilerplate.HTTP.get("/widgets/1",
                   base_url: "https://example.test",
                   plug: {Req.Test, @stub}
                 )
               end)
             end)
  end
end
