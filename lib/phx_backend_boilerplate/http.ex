defmodule PhxBackendBoilerplate.HTTP do
  @moduledoc """
  Shared Req HTTP transport for outbound API calls.

  Automatically respects `PhxBackendBoilerplate.Deadline` when set: caps
  `receive_timeout`, attaches `x-request-timeout-ms`, and maps deadline-limited
  transport timeouts to `{:error, :deadline_exceeded}`.

  When `PhxBackendBoilerplate.RequestContext` is set, also attaches
  `x-request-id` and `x-correlation-id` for downstream tracing.

  Resilience (retry, circuit breaker) belongs in per-dependency
  `ExternalService` clients under `PhxBackendBoilerplate.Integrations`.
  This module always disables Req's built-in retry so those policies are
  not stacked.
  """

  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.RequestContext

  @finch PhxBackendBoilerplate.Finch
  @default_receive_timeout 15_000

  @doc """
  Builds a `Req.Request` with shared defaults, app config, and `opts`.

  Merge order: built-in defaults → `config :phx_backend_boilerplate, __MODULE__` →
  `opts`. Then `retry: false` is forced. Deadline/context headers and timeout
  capping are applied in `request/1`.
  """
  def new(opts \\ []) do
    opts
    |> merge_opts()
    |> Keyword.put(:retry, false)
    |> Req.new()
  end

  @doc """
  Performs an HTTP request. Returns `{:ok, response}`, `{:error, exception}`,
  or `{:error, :deadline_exceeded}`.
  """
  def request(opts) when is_list(opts) do
    remaining_before = Deadline.remaining()

    if remaining_before == 0 do
      {:error, :deadline_exceeded}
    else
      merged = merge_opts(opts)
      config_timeout = Keyword.fetch!(merged, :receive_timeout)

      merged =
        merged
        |> maybe_put_propagation_headers()
        |> maybe_cap_receive_timeout(remaining_before)
        |> Keyword.put(:retry, false)

      merged
      |> Req.new()
      |> Req.request()
      |> classify_timeout(remaining_before, config_timeout)
    end
  end

  def get(url, opts \\ []) do
    request(Keyword.merge(opts, method: :get, url: url))
  end

  def post(url, opts \\ []) do
    request(Keyword.merge(opts, method: :post, url: url))
  end

  def put(url, opts \\ []) do
    request(Keyword.merge(opts, method: :put, url: url))
  end

  def patch(url, opts \\ []) do
    request(Keyword.merge(opts, method: :patch, url: url))
  end

  def delete(url, opts \\ []) do
    request(Keyword.merge(opts, method: :delete, url: url))
  end

  defp merge_opts(opts) do
    defaults = [
      finch: @finch,
      receive_timeout: @default_receive_timeout
    ]

    app_opts = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])

    defaults
    |> Keyword.merge(app_opts)
    |> Keyword.merge(opts)
  end

  defp maybe_put_propagation_headers(opts) do
    propagation = RequestContext.propagation_headers() ++ Deadline.propagation_headers()

    case propagation do
      [] ->
        opts

      headers ->
        existing = Keyword.get(opts, :headers, [])
        Keyword.put(opts, :headers, merge_headers(existing, headers))
    end
  end

  defp merge_headers(existing, extra) when is_list(existing) do
    existing ++ extra
  end

  defp merge_headers(existing, extra) when is_map(existing) do
    Enum.reduce(extra, existing, fn {k, v}, acc ->
      Map.put(acc, k, v)
    end)
  end

  defp maybe_cap_receive_timeout(opts, nil), do: opts

  defp maybe_cap_receive_timeout(opts, remaining) when is_integer(remaining) do
    config_timeout = Keyword.fetch!(opts, :receive_timeout)
    Keyword.put(opts, :receive_timeout, min(config_timeout, remaining))
  end

  defp classify_timeout(
         {:error, %Req.TransportError{reason: :timeout}} = error,
         remaining_before,
         config_timeout
       )
       when is_integer(remaining_before) do
    if remaining_before <= config_timeout do
      {:error, :deadline_exceeded}
    else
      error
    end
  end

  defp classify_timeout(result, _remaining_before, _config_timeout), do: result
end
