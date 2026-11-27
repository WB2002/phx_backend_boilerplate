defmodule PhxBackendBoilerplateWeb.Plugs.RateLimitTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.Plugs.RateLimit

  test "allows requests under the limit and denies when exceeded" do
    id = "plug_test_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 2)
    ip = unique_ip()

    conn1 = call_with_ip(ip, opts)
    refute conn1.halted
    assert conn1.status == nil

    conn2 = call_with_ip(ip, opts)
    refute conn2.halted

    conn3 = call_with_ip(ip, opts)
    assert conn3.halted
    assert conn3.status == 429
    assert get_resp_header(conn3, "retry-after") != []
    assert Jason.decode!(conn3.resp_body) == %{"errors" => %{"detail" => "Too Many Requests"}}
  end

  test "isolates limits by remote IP" do
    id = "plug_ip_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1)

    conn_a = call_with_ip(unique_ip(), opts)
    refute conn_a.halted

    conn_b = call_with_ip(unique_ip(), opts)
    refute conn_b.halted
  end

  test "uses independent buckets per attribute" do
    id = "plug_multi_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:ip, :user_id])
    ip = unique_ip()

    conn1 =
      build_conn()
      |> Map.put(:remote_ip, ip)
      |> put_req_header("x-user-id", "user-a")
      |> RateLimit.call(opts)

    refute conn1.halted

    # Same IP, different user — IP bucket is already exhausted, so deny
    conn2 =
      build_conn()
      |> Map.put(:remote_ip, ip)
      |> put_req_header("x-user-id", "user-b")
      |> RateLimit.call(opts)

    assert conn2.halted
    assert conn2.status == 429
  end

  test "does not share user_id buckets across different users on different IPs" do
    id = "plug_user_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:user_id])

    conn_a =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("x-user-id", "user-#{:erlang.unique_integer([:positive])}")
      |> RateLimit.call(opts)

    conn_b =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("x-user-id", "user-#{:erlang.unique_integer([:positive])}")
      |> RateLimit.call(opts)

    refute conn_a.halted
    refute conn_b.halted
  end

  test "skips missing optional attributes" do
    id = "plug_skip_#{:erlang.unique_integer([:positive])}"

    opts =
      RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:user_id, :fingerprint])

    conn =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> RateLimit.call(opts)

    refute conn.halted
  end

  test "denies when fingerprint bucket is exceeded" do
    id = "plug_fp_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:fingerprint])
    fingerprint = "fp-#{:erlang.unique_integer([:positive])}"

    conn1 =
      build_conn()
      |> put_req_header("x-device-fingerprint", fingerprint)
      |> RateLimit.call(opts)

    conn2 =
      build_conn()
      |> put_req_header("x-device-fingerprint", fingerprint)
      |> RateLimit.call(opts)

    refute conn1.halted
    assert conn2.halted
    assert conn2.status == 429
  end

  test "guest_id bucket uses assign only" do
    id = "plug_guest_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:guest_id])
    guest_id = Ecto.UUID.generate()

    conn1 =
      build_conn()
      |> assign(:guest_id, guest_id)
      |> RateLimit.call(opts)

    conn2 =
      build_conn()
      |> assign(:guest_id, guest_id)
      |> RateLimit.call(opts)

    refute conn1.halted
    assert conn2.halted
    assert conn2.status == 429
  end

  test "guest_id header without assign is skipped" do
    id = "plug_guest_skip_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:guest_id])

    conn =
      build_conn()
      |> put_req_header("x-guest-id", Ecto.UUID.generate())
      |> RateLimit.call(opts)

    refute conn.halted
  end

  test "stripe_signature absent bucket is shared for unsigned requests" do
    id = "plug_stripe_absent_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:stripe_signature])

    conn1 = build_conn() |> RateLimit.call(opts)
    conn2 = build_conn() |> RateLimit.call(opts)

    refute conn1.halted
    assert conn2.halted
    assert conn2.status == 429
  end

  test "stripe_signature present skips the absent bucket" do
    id = "plug_stripe_present_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1, by: [:stripe_signature])

    conn1 =
      build_conn()
      |> put_req_header("stripe-signature", "t=1,v1=abc")
      |> RateLimit.call(opts)

    conn2 =
      build_conn()
      |> put_req_header("stripe-signature", "t=2,v1=def")
      |> RateLimit.call(opts)

    refute conn1.halted
    refute conn2.halted
  end

  test "allows request when rate limit backend returns error" do
    id = "rate_limit_redis_error_#{System.unique_integer()}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1)

    previous = Application.get_env(:phx_backend_boilerplate, RateLimit, [])

    Application.put_env(
      :phx_backend_boilerplate,
      RateLimit,
      Keyword.put(previous, :hit, fn _, _, _ -> {:error, :redis_down} end)
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, RateLimit, previous) end)

    conn = call_with_ip(unique_ip(), opts)
    refute conn.halted
  end

  test "respects runtime :limits override for a bucket id" do
    id = "plug_override_#{:erlang.unique_integer([:positive])}"
    opts = RateLimit.init(id: id, scale: :timer.minutes(1), limit: 1)
    ip = unique_ip()

    previous = Application.get_env(:phx_backend_boilerplate, RateLimit, [])

    Application.put_env(
      :phx_backend_boilerplate,
      RateLimit,
      Keyword.put(previous, :limits, %{id => 3})
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, RateLimit, previous) end)

    refute call_with_ip(ip, opts).halted
    refute call_with_ip(ip, opts).halted
    refute call_with_ip(ip, opts).halted

    denied = call_with_ip(ip, opts)
    assert denied.halted
    assert denied.status == 429
  end

  defp call_with_ip(ip, opts) do
    build_conn()
    |> Map.put(:remote_ip, ip)
    |> RateLimit.call(opts)
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {127, 0, rem(div(n, 256), 256), rem(n, 256)}
  end
end
