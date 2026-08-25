defmodule PhxBackendBoilerplate.Integrations.Example do
  @moduledoc """
  Template outbound API client.

  Copy this module for real dependencies (GitHub, Stripe, Slack, …). Each
  client owns its own ExternalService circuit breaker and retry policy;
  HTTP transport goes through `PhxBackendBoilerplate.HTTP` (Req with
  retries disabled).

  Configure under `PhxBackendBoilerplate.Integrations.Example`:

      config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Example,
        base_url: "https://api.example.com",
        api_token: "…"
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

  @doc """
  Fetches a widget by id from the example API.

  Returns:

  * `{:ok, %Req.Response{}}`
  * `{:error, %ExternalService.CircuitBreakerOpen{}}`
  * `{:error, %ExternalService.RetriesExhausted{}}`
  * `{:error, :deadline_exceeded}`
  * `{:error, {:http, status, response}}`
  """
  def get_widget(id) do
    call(fn ->
      Integrations.through_req(fn ->
        HTTP.get(
          "/widgets/#{id}",
          Keyword.merge(req_options(),
            base_url: base_url(),
            headers: auth_headers()
          )
        )
      end)
    end)
  end

  defp base_url do
    config() |> Keyword.fetch!(:base_url)
  end

  defp auth_headers do
    case Keyword.get(config(), :api_token) do
      nil -> []
      token -> [{"authorization", "Bearer #{token}"}]
    end
  end

  defp req_options do
    Keyword.get(config(), :req_options, [])
  end

  defp config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
