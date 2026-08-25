defmodule PhxBackendBoilerplate.Integrations.IsolationAlpha do
  @moduledoc false

  use ExternalService,
    name: :isolation_alpha,
    circuit_breaker: [
      tolerate: 1,
      within: 5_000,
      reset: 60_000
    ],
    retry: [
      max_attempts: 3,
      backoff: :exponential,
      base: 1,
      jitter: false,
      cap: 1
    ]

  def fail do
    call(fn -> {:retry, :forced} end)
  end

  def ok do
    call(fn -> :ok end)
  end
end
