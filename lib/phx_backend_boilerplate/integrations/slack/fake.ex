defmodule PhxBackendBoilerplate.Integrations.Slack.Fake do
  @moduledoc """
  Test double for Slack `chat.postMessage`.

  Defaults to `{:ok, :fake}`. Configure failure with:

      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Slack.Fake,
        result: {:error, {:slack, "channel_not_found"}}
      )

  Successful calls append `{text, channel, opts}` to the `:calls` list in the
  Fake config (for assertions).
  """

  @doc false
  def post_message(text, channel, opts)
      when is_binary(text) and is_binary(channel) and is_list(opts) do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    calls = Keyword.get(cfg, :calls, [])
    configured_reply = Keyword.get(cfg, :result, {:ok, :fake})

    Application.put_env(
      :phx_backend_boilerplate,
      __MODULE__,
      Keyword.put(cfg, :calls, calls ++ [{text, channel, opts}])
    )

    configured_reply
  end

  @doc """
  Returns recorded `{text, channel, opts}` calls (test helper).
  """
  def calls do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:calls, [])
  end

  @doc """
  Clears recorded calls and optional result override.
  """
  def reset do
    Application.put_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
