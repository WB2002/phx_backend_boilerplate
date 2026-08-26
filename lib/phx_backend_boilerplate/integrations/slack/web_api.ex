defmodule PhxBackendBoilerplate.Integrations.Slack.WebAPI do
  @moduledoc """
  Slack Web API client for `chat.postMessage`.

  Uses `ExternalService` for retries/circuit breaker and
  `PhxBackendBoilerplate.HTTP` for transport. HTTP 200 with
  `{"ok": false}` is a non-retryable Slack API error.
  """

  use ExternalService,
    circuit_breaker: [
      tolerate: 5,
      within: :timer.seconds(30),
      reset: :timer.seconds(60)
    ],
    retry: [
      max_attempts: 3,
      backoff: :exponential,
      base: 100,
      jitter: true,
      cap: 5_000
    ],
    sleep_function: &PhxBackendBoilerplate.Integrations.sleep_respecting_deadline/1

  alias PhxBackendBoilerplate.HTTP
  alias PhxBackendBoilerplate.Integrations

  @doc false
  def post_message(text, channel, opts)
      when is_binary(text) and is_binary(channel) and is_list(opts) do
    bot_token = Keyword.fetch!(opts, :bot_token)
    api_url = Keyword.fetch!(opts, :api_url)
    req_options = Keyword.get(opts, :req_options, [])

    call(fn ->
      case Integrations.through_req(fn ->
             HTTP.post(
               api_url,
               Keyword.merge(req_options,
                 json: %{channel: channel, text: text},
                 headers: [
                   {"authorization", "Bearer #{bot_token}"},
                   {"content-type", "application/json; charset=utf-8"}
                 ]
               )
             )
           end) do
        {:ok, response} ->
          interpret_ok_body(response)

        other ->
          other
      end
    end)
  end

  defp interpret_ok_body(%{body: body} = response) do
    case normalize_body(body) do
      %{"ok" => true} ->
        {:ok, response}

      %{"ok" => false, "error" => error} when is_binary(error) ->
        {:error, {:slack, error}}

      %{"ok" => false} ->
        {:error, {:slack, "unknown_error"}}

      _ ->
        {:error, {:slack, "invalid_response"}}
    end
  end

  defp normalize_body(body) when is_map(body), do: body

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp normalize_body(_), do: %{}
end
