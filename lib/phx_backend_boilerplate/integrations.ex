defmodule PhxBackendBoilerplate.Integrations do
  @moduledoc """
  Shared helpers for dependency-specific HTTP integration clients.

  Circuit breakers and retries are **not** shared — each client module
  `use ExternalService` with its own service name. This module only
  classifies Req results into ExternalService retry/success/error shapes.
  """

  @doc """
  Runs `fun` (expected to return a Req result) and maps it for ExternalService.

  * `{:ok, %{status: 2xx}}` → `{:ok, response}`
  * `408`, `429`, or `5xx` → `{:retry, {:http, status}}` (melts breaker)
  * other HTTP statuses → `{:error, {:http, status, response}}` (no retry)
  * `{:error, reason}` → `{:retry, reason}` (transport/timeout)
  """
  def through_req(fun) when is_function(fun, 0) do
    case fun.() do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status}} when status in [408, 429] or status in 500..599 ->
        {:retry, {:http, status}}

      {:ok, %{status: status} = response} ->
        {:error, {:http, status, response}}

      {:error, reason} ->
        {:retry, reason}
    end
  end
end
