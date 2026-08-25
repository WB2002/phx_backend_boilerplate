defmodule PhxBackendBoilerplate.Integrations.BreakerIsolationTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Integrations.IsolationAlpha
  alias PhxBackendBoilerplate.Integrations.IsolationBeta

  setup do
    start_supervised!(
      {IsolationAlpha,
       circuit_breaker: [tolerate: 1, within: 5_000, reset: 60_000],
       retry: [max_attempts: 3, base: 1, jitter: false, cap: 1]}
    )

    start_supervised!(IsolationBeta)

    on_exit(fn ->
      IsolationAlpha.reset()
      IsolationBeta.reset()
    end)

    :ok
  end

  test "opening alpha breaker does not affect beta" do
    assert {:error, %ExternalService.CircuitBreakerOpen{}} = IsolationAlpha.fail()
    assert IsolationAlpha.blown?()
    assert IsolationBeta.available?()
    assert :ok = IsolationBeta.ok()
  end
end
