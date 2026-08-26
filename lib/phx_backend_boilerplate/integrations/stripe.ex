defmodule PhxBackendBoilerplate.Integrations.Stripe do
  @moduledoc """
  Stripe Checkout integration facade.

  Creates Stripe Customers and Checkout Sessions via the configured adapter
  (`Api` or `Fake`). Set `:skip` to `true` in dev to avoid real API calls.

  ## Config

  Under `PhxBackendBoilerplate.Integrations.Stripe`:

    * `:secret_key` — Stripe secret key (`sk_…`)
    * `:webhook_secret` — Stripe webhook signing secret (`whsec_…`)
    * `:api_base` — API base URL (default `https://api.stripe.com`)
    * `:skip` — when `true`, API calls return `{:error, :skipped}`
    * `:adapter` — `Api` (default) or `Fake` (tests)

  Env (see `config/runtime.exs`): `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
  `STRIPE_SKIP`, `STRIPE_PRICE_LIFETIME`, `STRIPE_PRICE_PRO`,
  `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`.
  """

  @type checkout_params :: map()

  @doc """
  Creates a Stripe Customer for `email`.

  Optional `:idempotency_key` in opts is forwarded to Stripe.

  Returns `{:ok, customer_map}` or `{:error, reason}`.
  """
  @spec create_customer(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_customer(email, opts \\ []) when is_binary(email) and is_list(opts) do
    if skip?() do
      {:error, :skipped}
    else
      with {:ok, secret_key} <- fetch_secret_key() do
        idempotency_key = Keyword.get(opts, :idempotency_key)

        adapter().create_customer(
          email,
          merged_opts(secret_key: secret_key, idempotency_key: idempotency_key)
        )
      end
    end
  end

  @doc """
  Creates a Stripe Checkout Session.

  `params` is a flat map of Stripe form fields (see `Api.encode_form/1`).
  Optional `:idempotency_key` in opts is forwarded to Stripe.
  """
  @spec create_checkout_session(checkout_params(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_checkout_session(params, opts \\ []) when is_map(params) and is_list(opts) do
    if skip?() do
      {:error, :skipped}
    else
      with {:ok, secret_key} <- fetch_secret_key() do
        idempotency_key = Keyword.get(opts, :idempotency_key)

        adapter().create_checkout_session(
          params,
          merged_opts(secret_key: secret_key, idempotency_key: idempotency_key)
        )
      end
    end
  end

  @doc """
  Retrieves a Stripe Subscription by id.
  """
  @spec retrieve_subscription(String.t()) :: {:ok, map()} | {:error, term()}
  def retrieve_subscription(subscription_id) when is_binary(subscription_id) do
    if skip?() do
      {:error, :skipped}
    else
      with {:ok, secret_key} <- fetch_secret_key() do
        adapter().retrieve_subscription(subscription_id, merged_opts(secret_key: secret_key))
      end
    end
  end

  @doc """
  Retrieves a Stripe Event by id.
  """
  @spec retrieve_event(String.t()) :: {:ok, map()} | {:error, term()}
  def retrieve_event(event_id) when is_binary(event_id) do
    if skip?() do
      {:error, :skipped}
    else
      with {:ok, secret_key} <- fetch_secret_key() do
        adapter().retrieve_event(event_id, merged_opts(secret_key: secret_key))
      end
    end
  end

  @doc """
  Returns the configured webhook signing secret.
  """
  @spec webhook_secret() :: {:ok, String.t()} | {:error, :misconfigured}
  def webhook_secret do
    case Keyword.get(config(), :webhook_secret) do
      secret when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> {:error, :misconfigured}
    end
  end

  defp fetch_secret_key do
    case Keyword.get(config(), :secret_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :misconfigured}
    end
  end

  defp merged_opts(extra) do
    cfg = config()

    [
      secret_key: Keyword.get(extra, :secret_key),
      api_base: Keyword.get(cfg, :api_base, "https://api.stripe.com"),
      idempotency_key: Keyword.get(extra, :idempotency_key),
      req_options: Keyword.get(cfg, :req_options, [])
    ]
  end

  defp skip? do
    Keyword.get(config(), :skip, false) == true
  end

  defp adapter do
    Keyword.get(config(), :adapter, PhxBackendBoilerplate.Integrations.Stripe.Api)
  end

  defp config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
