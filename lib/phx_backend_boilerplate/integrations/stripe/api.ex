defmodule PhxBackendBoilerplate.Integrations.Stripe.Api do
  @moduledoc """
  Stripe REST API client (Checkout, Customers, Subscriptions).

  Uses `ExternalService` for retries/circuit breaker and
  `PhxBackendBoilerplate.HTTP` for transport. Stripe expects
  `application/x-www-form-urlencoded` bodies.
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
  def create_customer(email, opts) when is_binary(email) and is_list(opts) do
    secret_key = Keyword.fetch!(opts, :secret_key)
    api_base = Keyword.fetch!(opts, :api_base)
    req_options = Keyword.get(opts, :req_options, [])

    call(fn ->
      Integrations.through_req(fn ->
        HTTP.post(
          "#{api_base}/v1/customers",
          Keyword.merge(req_options,
            form: [email: email],
            headers: stripe_headers(secret_key)
          )
        )
      end)
      |> interpret_json()
    end)
  end

  @doc false
  def create_checkout_session(params, opts) when is_map(params) and is_list(opts) do
    secret_key = Keyword.fetch!(opts, :secret_key)
    api_base = Keyword.fetch!(opts, :api_base)
    req_options = Keyword.get(opts, :req_options, [])
    idempotency_key = Keyword.get(opts, :idempotency_key)

    headers =
      secret_key
      |> stripe_headers()
      |> maybe_put_idempotency(idempotency_key)

    call(fn ->
      Integrations.through_req(fn ->
        HTTP.post(
          "#{api_base}/v1/checkout/sessions",
          Keyword.merge(req_options,
            form: encode_form(params),
            headers: headers
          )
        )
      end)
      |> interpret_json()
    end)
  end

  @doc false
  def retrieve_subscription(subscription_id, opts)
      when is_binary(subscription_id) and is_list(opts) do
    secret_key = Keyword.fetch!(opts, :secret_key)
    api_base = Keyword.fetch!(opts, :api_base)
    req_options = Keyword.get(opts, :req_options, [])

    call(fn ->
      Integrations.through_req(fn ->
        HTTP.get(
          "#{api_base}/v1/subscriptions/#{subscription_id}",
          Keyword.merge(req_options,
            headers: stripe_headers(secret_key)
          )
        )
      end)
      |> interpret_json()
    end)
  end

  defp stripe_headers(secret_key) do
    [
      {"authorization", "Bearer #{secret_key}"},
      {"content-type", "application/x-www-form-urlencoded"}
    ]
  end

  defp maybe_put_idempotency(headers, key) when is_binary(key) and key != "" do
    headers ++ [{"idempotency-key", key}]
  end

  defp maybe_put_idempotency(headers, _), do: headers

  defp encode_form(params) when is_map(params) do
    params
    |> Enum.flat_map(&encode_pair/1)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  defp encode_pair({key, value}) when is_binary(key) and is_binary(value) do
    [{key, value}]
  end

  defp encode_pair({key, value}) when is_binary(key) and is_integer(value) do
    [{key, Integer.to_string(value)}]
  end

  defp encode_pair({key, value}) when is_binary(key) and is_boolean(value) do
    [{key, if(value, do: "true", else: "false")}]
  end

  defp encode_pair({key, map}) when is_binary(key) and is_map(map) do
    Enum.flat_map(map, fn {nested_key, nested_value} ->
      encode_pair({"#{key}[#{nested_key}]", nested_value})
    end)
  end

  defp encode_pair({key, list}) when is_binary(key) and is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} when is_map(item) ->
      Enum.flat_map(item, fn {nested_key, nested_value} ->
        encode_pair({"#{key}[#{index}][#{nested_key}]", nested_value})
      end)
    end)
  end

  defp interpret_json({:ok, %{body: body}}) do
    case normalize_body(body) do
      %{"error" => error} ->
        {:error, {:stripe, error}}

      map when is_map(map) ->
        {:ok, map}
    end
  end

  defp interpret_json(other), do: other

  defp normalize_body(body) when is_map(body), do: body

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp normalize_body(_), do: %{}
end
