defmodule PhxBackendBoilerplate.Integrations.IsolationBeta do
  @moduledoc false

  use ExternalService,
    name: :isolation_beta,
    circuit_breaker: [
      tolerate: 5,
      within: :timer.seconds(30),
      reset: :timer.seconds(60)
    ],
    retry: [
      max_attempts: 3,
      backoff: :exponential,
      base: 1,
      jitter: false,
      cap: 1
    ]

  def ok do
    call(fn -> :ok end)
  end
end
