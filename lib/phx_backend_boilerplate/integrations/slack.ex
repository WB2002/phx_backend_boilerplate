defmodule PhxBackendBoilerplate.Integrations.Slack do
  @moduledoc """
  Opt-in Slack notifications via `chat.postMessage`.

  Call after processing completes when you want a channel message:

      PhxBackendBoilerplate.Integrations.Slack.notify("Export finished", channel: "C0123456789")

  ## Config

  Under `PhxBackendBoilerplate.Integrations.Slack`:

    * `:bot_token` — Bot User OAuth token (`xoxb-…`)
    * `:default_channel` — optional fallback when `:channel` is omitted
    * `:skip` — when `true`, `notify/2` returns `{:ok, :skipped}` (dev default)
    * `:adapter` — `WebAPI` (default) or `Fake` (tests)

  Env (see `config/runtime.exs`): `SLACK_BOT_TOKEN`, `SLACK_DEFAULT_CHANNEL`, `SLACK_SKIP`.
  """

  @type notify_opts :: [
          channel: String.t() | nil,
          bot_token: String.t() | nil,
          req_options: keyword()
        ]

  @doc """
  Posts `text` to a Slack channel.

  Returns:

  * `{:ok, response}` — Slack accepted the message (`ok: true`)
  * `{:ok, :skipped}` — `:skip` is true
  * `{:error, :missing_text | :missing_channel | :misconfigured | …}`
  """
  @spec notify(String.t() | nil, notify_opts()) :: {:ok, term()} | {:error, term()}
  def notify(text, opts \\ [])

  def notify(text, opts) when is_list(opts) do
    if skip?() do
      {:ok, :skipped}
    else
      do_notify(text, opts)
    end
  end

  defp do_notify(text, _opts) when text in [nil, ""] do
    {:error, :missing_text}
  end

  defp do_notify(text, opts) when is_binary(text) do
    merged = merge_opts(opts)
    channel = Keyword.get(merged, :channel)
    bot_token = Keyword.get(merged, :bot_token)

    cond do
      is_nil(channel) or channel == "" ->
        {:error, :missing_channel}

      is_nil(bot_token) or bot_token == "" ->
        {:error, :misconfigured}

      true ->
        adapter().post_message(String.trim(text), channel, merged)
    end
  end

  defp merge_opts(opts) do
    cfg = config()

    [
      bot_token: Keyword.get(opts, :bot_token) || Keyword.get(cfg, :bot_token),
      channel: Keyword.get(opts, :channel) || Keyword.get(cfg, :default_channel),
      api_url:
        Keyword.get(opts, :api_url) ||
          Keyword.get(cfg, :api_url, "https://slack.com/api/chat.postMessage"),
      req_options: Keyword.get(opts, :req_options, Keyword.get(cfg, :req_options, []))
    ]
  end

  defp skip? do
    Keyword.get(config(), :skip, false) == true
  end

  defp adapter do
    Keyword.get(config(), :adapter, PhxBackendBoilerplate.Integrations.Slack.WebAPI)
  end

  defp config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
