defmodule PhxBackendBoilerplate.RateLimit do
  @moduledoc """
  Redis-backed rate limiter via Hammer.

  Start under the application supervisor with Redix options, typically:

      {PhxBackendBoilerplate.RateLimit, url: "redis://localhost:6379"}

  Use `hit/3` (or `hit/4`) with a string key — Redis requires string keys.
  """

  use Hammer, backend: Hammer.Redis, prefix: "phx_backend_boilerplate:rate_limit:"
end
