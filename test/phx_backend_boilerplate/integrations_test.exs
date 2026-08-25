defmodule PhxBackendBoilerplate.IntegrationsTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Integrations

  test "through_req/1 returns ok for 2xx" do
    response = %Req.Response{status: 200, body: %{"id" => 1}}

    assert {:ok, ^response} = Integrations.through_req(fn -> {:ok, response} end)
  end

  test "through_req/1 retries on 408, 429, and 5xx" do
    for status <- [408, 429, 500, 503] do
      response = %Req.Response{status: status}

      assert {:retry, {:http, ^status}} =
               Integrations.through_req(fn -> {:ok, response} end)
    end
  end

  test "through_req/1 returns error without retry for other 4xx" do
    response = %Req.Response{status: 404, body: "missing"}

    assert {:error, {:http, 404, ^response}} =
             Integrations.through_req(fn -> {:ok, response} end)
  end

  test "through_req/1 retries on transport errors" do
    assert {:retry, :timeout} = Integrations.through_req(fn -> {:error, :timeout} end)
  end
end
