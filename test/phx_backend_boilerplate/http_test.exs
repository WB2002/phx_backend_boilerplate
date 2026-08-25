defmodule PhxBackendBoilerplate.HTTPTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.HTTP

  test "new/1 forces retry: false even when caller asks for retries" do
    request = HTTP.new(retry: :transient)

    assert request.options.retry == false
  end

  test "get/2 returns stubbed response via Req.Test plug" do
    stub_name = :"http_get_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      assert conn.request_path == "/hello"
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, %Req.Response{status: 200, body: %{"ok" => true}}} =
             HTTP.get("/hello",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name}
             )
  end

  test "request/1 returns error tuple for transport failures" do
    stub_name = :"http_err_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Req.TransportError{reason: :timeout}} =
             HTTP.request(
               method: :get,
               url: "https://example.test/timeout",
               plug: {Req.Test, stub_name}
             )
  end
end
