defmodule PhxBackendBoilerplate.Recaptcha do
  @moduledoc """
  Google reCAPTCHA v3 server-side verification.

  Posts the client token to Google's siteverify endpoint via
  `PhxBackendBoilerplate.HTTP` (Req). Success requires `success == true`
  and `score >= min_score` (default `0.5`).

  Adapters:

  * `PhxBackendBoilerplate.Recaptcha.Google` — real siteverify (default)
  * `PhxBackendBoilerplate.Recaptcha.Fake` — test double (configurable pass/fail)

  When `skip: true` (dev default via `RECAPTCHA_SKIP`), `verify/2` always
  returns `:ok` without calling the adapter.
  """

  @type verify_opts :: [
          remote_ip: String.t() | nil,
          secret_key: String.t() | nil,
          min_score: float(),
          req_options: keyword()
        ]

  @doc """
  Verifies a reCAPTCHA response token.

  Returns `:ok` or `{:error, reason}` where reason is one of
  `:missing_token`, `:skipped` is not used (skip returns `:ok`),
  `:low_score`, `:verification_failed`, `:http_error`, `:deadline_exceeded`,
  or `:misconfigured`.
  """
  @spec verify(String.t() | nil, verify_opts()) :: :ok | {:error, atom()}
  def verify(token, opts \\ [])

  def verify(token, opts) when is_list(opts) do
    if skip?() do
      :ok
    else
      do_verify(token, opts)
    end
  end

  defp do_verify(token, _opts) when token in [nil, ""] do
    {:error, :missing_token}
  end

  defp do_verify(token, opts) when is_binary(token) do
    adapter().verify(String.trim(token), merge_opts(opts))
  end

  defp merge_opts(opts) do
    cfg = config()

    [
      secret_key: Keyword.get(opts, :secret_key) || Keyword.get(cfg, :secret_key),
      min_score: Keyword.get(opts, :min_score) || Keyword.get(cfg, :min_score, 0.5),
      remote_ip: Keyword.get(opts, :remote_ip),
      siteverify_url:
        Keyword.get(opts, :siteverify_url) ||
          Keyword.get(cfg, :siteverify_url, "https://www.google.com/recaptcha/api/siteverify"),
      req_options: Keyword.get(opts, :req_options, Keyword.get(cfg, :req_options, []))
    ]
  end

  defp skip? do
    Keyword.get(config(), :skip, false) == true
  end

  defp adapter do
    Keyword.get(config(), :adapter, PhxBackendBoilerplate.Recaptcha.Google)
  end

  defp config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
