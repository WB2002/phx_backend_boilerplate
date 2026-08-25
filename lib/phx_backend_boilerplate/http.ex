defmodule PhxBackendBoilerplate.HTTP do
  @moduledoc """
  Shared Req HTTP transport for outbound API calls.

  Resilience (retry, circuit breaker) belongs in per-dependency
  `ExternalService` clients under `PhxBackendBoilerplate.Integrations`.
  This module always disables Req's built-in retry so those policies are
  not stacked.
  """

  @finch PhxBackendBoilerplate.Finch
  @default_receive_timeout 15_000

  @doc """
  Builds a `Req.Request` with shared defaults, app config, and `opts`.

  Merge order: built-in defaults → `config :phx_backend_boilerplate, __MODULE__` →
  `opts`. Then `retry: false` is forced.
  """
  def new(opts \\ []) do
    defaults = [
      finch: @finch,
      receive_timeout: @default_receive_timeout
    ]

    app_opts = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])

    defaults
    |> Keyword.merge(app_opts)
    |> Keyword.merge(opts)
    |> Keyword.put(:retry, false)
    |> Req.new()
  end

  @doc """
  Performs an HTTP request. Returns `{:ok, response}` or `{:error, exception}`.
  """
  def request(opts) when is_list(opts) do
    opts |> new() |> Req.request()
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
end
