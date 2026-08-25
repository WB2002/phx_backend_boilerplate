defmodule PhxBackendBoilerplateWeb.Plugs.LoadShedTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.Plugs.LoadShed

  setup do
    name = :"load_shed_test_#{:erlang.unique_integer([:positive])}"
    on_exit(fn -> Regulator.uninstall(name) end)
    {:ok, regulator: name}
  end

  test "allows requests under the concurrency limit", %{regulator: name} do
    {:ok, _} = Regulator.install(name, {Regulator.Limit.Static, [limit: 5]})
    opts = LoadShed.init(regulator: name)

    conn = build_conn() |> LoadShed.call(opts)

    refute conn.halted
    assert conn.status == nil
  end

  test "returns 503 JSON when the concurrency limit is reached", %{regulator: name} do
    {:ok, _} = Regulator.install(name, {Regulator.Limit.Static, [limit: 1]})
    opts = LoadShed.init(regulator: name)
    parent = self()

    holder =
      spawn(fn ->
        {:ok, ctx} = Regulator.ask(name)
        send(parent, :held)

        receive do
          :release -> Regulator.ok(ctx)
        end
      end)

    assert_receive :held, 1_000

    conn = build_conn() |> LoadShed.call(opts)

    assert conn.halted
    assert conn.status == 503
    assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
    assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Service Unavailable"}}

    send(holder, :release)
  end

  test "checks the token back in after a successful response", %{regulator: name} do
    {:ok, _} = Regulator.install(name, {Regulator.Limit.Static, [limit: 1]})
    opts = LoadShed.init(regulator: name)

    conn =
      build_conn()
      |> LoadShed.call(opts)
      |> send_resp(200, "ok")

    refute conn.halted
    assert conn.status == 200

    assert {:ok, ctx} = Regulator.ask(name)
    Regulator.ok(ctx)
  end

  test "marks 5xx responses as regulator errors", %{regulator: name} do
    {:ok, _} = Regulator.install(name, {Regulator.Limit.Static, [limit: 1]})
    opts = LoadShed.init(regulator: name)

    _conn =
      build_conn()
      |> LoadShed.call(opts)
      |> send_resp(500, "err")

    assert {:ok, ctx} = Regulator.ask(name)
    Regulator.ok(ctx)
  end

  test "requires :regulator option" do
    assert_raise KeyError, fn ->
      LoadShed.init([])
    end
  end
end
