defmodule PhxBackendBoilerplate.IntegrationsTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.Integrations

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
    :ok
  end

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

  test "through_req/1 does not retry on :deadline_exceeded" do
    assert {:error, :deadline_exceeded} =
             Integrations.through_req(fn -> {:error, :deadline_exceeded} end)
  end

  test "sleep_respecting_deadline/1 caps sleep to remaining" do
    Deadline.start(30)
    started = System.monotonic_time(:millisecond)
    Integrations.sleep_respecting_deadline(5_000)
    elapsed = System.monotonic_time(:millisecond) - started

    assert elapsed < 200
  end

  test "sleep_respecting_deadline/1 is no-op when expired" do
    Deadline.start_at(System.monotonic_time(:millisecond) - 1)
    started = System.monotonic_time(:millisecond)
    Integrations.sleep_respecting_deadline(1_000)
    elapsed = System.monotonic_time(:millisecond) - started

    assert elapsed < 50
  end
end
