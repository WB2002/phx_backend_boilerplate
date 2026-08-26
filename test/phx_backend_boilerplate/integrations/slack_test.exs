defmodule PhxBackendBoilerplate.Integrations.SlackTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Integrations.Slack
  alias PhxBackendBoilerplate.Integrations.Slack.Fake
  alias PhxBackendBoilerplate.Integrations.Slack.WebAPI

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, Slack, [])
    fake_previous = Application.get_env(:phx_backend_boilerplate, Fake, [])
    Fake.reset()

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Slack, previous)
      Application.put_env(:phx_backend_boilerplate, Fake, fake_previous)
      WebAPI.reset()
    end)

    :ok
  end

  test "notify/2 returns skipped when skip is true" do
    put_slack_env(skip: true, adapter: Fake, bot_token: "xoxb-test")

    assert {:ok, :skipped} = Slack.notify("hello", channel: "C123")
    assert Fake.calls() == []
  end

  test "notify/2 returns missing_text for blank text" do
    put_slack_env(skip: false, adapter: Fake, bot_token: "xoxb-test")

    assert {:error, :missing_text} = Slack.notify("", channel: "C123")
    assert {:error, :missing_text} = Slack.notify(nil, channel: "C123")
  end

  test "notify/2 returns missing_channel when channel and default are unset" do
    put_slack_env(skip: false, adapter: Fake, bot_token: "xoxb-test", default_channel: nil)

    assert {:error, :missing_channel} = Slack.notify("hello")
  end

  test "notify/2 uses default_channel when channel omitted" do
    put_slack_env(
      skip: false,
      adapter: Fake,
      bot_token: "xoxb-test",
      default_channel: "CDEFAULT"
    )

    assert {:ok, :fake} = Slack.notify("hello")
    assert [{"hello", "CDEFAULT", _opts}] = Fake.calls()
  end

  test "notify/2 returns misconfigured without bot token" do
    put_slack_env(skip: false, adapter: Fake, bot_token: nil, default_channel: "C123")

    assert {:error, :misconfigured} = Slack.notify("hello", channel: "C123")
  end

  test "notify/2 with Fake records the call" do
    put_slack_env(skip: false, adapter: Fake, bot_token: "xoxb-test")

    assert {:ok, :fake} = Slack.notify("done", channel: "C999")
    assert [{"done", "C999", opts}] = Fake.calls()
    assert Keyword.get(opts, :bot_token) == "xoxb-test"
  end

  test "notify/2 surfaces Fake errors" do
    put_slack_env(skip: false, adapter: Fake, bot_token: "xoxb-test")

    Application.put_env(:phx_backend_boilerplate, Fake,
      result: {:error, {:slack, "channel_not_found"}}
    )

    assert {:error, {:slack, "channel_not_found"}} =
             Slack.notify("done", channel: "Cmissing")
  end

  describe "WebAPI" do
    @stub __MODULE__.WebAPIStub

    setup do
      put_slack_env(
        skip: false,
        adapter: WebAPI,
        bot_token: "xoxb-webapi",
        api_url: "https://slack.test/api/chat.postMessage",
        req_options: [plug: {Req.Test, @stub}]
      )

      :ok
    end

    test "posts chat.postMessage and returns ok response" do
      Req.Test.stub(@stub, fn conn ->
        assert conn.method == "POST"
        assert ["Bearer xoxb-webapi"] = Plug.Conn.get_req_header(conn, "authorization")
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"channel" => "C111", "text" => "hi"}
        Req.Test.json(conn, %{"ok" => true, "ts" => "1.2"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"ok" => true}}} =
               Slack.notify("hi", channel: "C111")
    end

    test "maps ok:false to non-retryable slack error" do
      Req.Test.stub(@stub, fn conn ->
        Req.Test.json(conn, %{"ok" => false, "error" => "channel_not_found"})
      end)

      assert {:error, {:slack, "channel_not_found"}} =
               Slack.notify("hi", channel: "Cmissing")
    end
  end

  defp put_slack_env(overrides) do
    previous = Application.get_env(:phx_backend_boilerplate, Slack, [])
    Application.put_env(:phx_backend_boilerplate, Slack, Keyword.merge(previous, overrides))
  end
end
