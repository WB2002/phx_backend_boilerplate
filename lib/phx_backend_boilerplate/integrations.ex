defmodule PhxBackendBoilerplate.Integrations do
  @moduledoc """
  Shared helpers for dependency-specific HTTP integration clients.

  Circuit breakers and retries are **not** shared — each client module
  `use ExternalService` with its own service name. This module only
  classifies Req results into ExternalService retry/success/error shapes.

  Deadline propagation lives in `PhxBackendBoilerplate.HTTP`, not here.
  Use `sleep_respecting_deadline/1` as ExternalService `:sleep_function` so
  backoff cannot outlive the request budget.
  """

  alias PhxBackendBoilerplate.Deadline

  @doc """
  Runs `fun` (expected to return a Req / HTTP result) and maps it for
  ExternalService.

  Classification order (mandatory):

  1. `{:error, :deadline_exceeded}` → return as-is (no retry, no breaker melt)
  2. `{:error, reason}` → `{:retry, reason}` (transport / dependency failure)
  3. HTTP 408 / 429 / 5xx → `{:retry, {:http, status}}`
  4. HTTP 2xx → `{:ok, response}`
  5. other HTTP → `{:error, {:http, status, response}}` (no retry)
  """
  def through_req(fun) when is_function(fun, 0) do
    case fun.() do
      {:error, :deadline_exceeded} ->
        {:error, :deadline_exceeded}

      {:error, reason} ->
        {:retry, reason}

      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status}} when status in [408, 429] or status in 500..599 ->
        {:retry, {:http, status}}

      {:ok, %{status: status} = response} ->
        {:error, {:http, status, response}}
    end
  end

  @doc """
  Sleep helper for ExternalService that never sleeps past the remaining deadline.
  """
  def sleep_respecting_deadline(ms) when is_integer(ms) and ms >= 0 do
    case Deadline.remaining() do
      nil ->
        Process.sleep(ms)

      remaining when remaining <= 0 ->
        :ok

      remaining ->
        Process.sleep(min(ms, remaining))
    end
  end
end
