import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "phx_backend_boilerplate_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gwktdXphpy9PBEcxu/1x7ecrFWaM8kCl+F1s5+Us4TVO3WrB5sSY3CwDrj8llYdN",
  server: false

# In test we don't send emails
config :phx_backend_boilerplate, PhxBackendBoilerplate.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Same Static(2) demo limiter as config.exs; plug tests install unique names.
config :phx_backend_boilerplate, PhxBackendBoilerplate.LoadShed,
  regulators: [
    demo_expensive: {Regulator.Limit.Static, [limit: 2]}
  ]

# Fast timeouts for outbound HTTP tests; plug stubs avoid the network.
config :phx_backend_boilerplate, PhxBackendBoilerplate.HTTP, receive_timeout: 1_000

config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Example,
  base_url: "https://example.test",
  api_token: "test-token"

# Short SWR defaults for tests (still soft < l1 < l2).
config :phx_backend_boilerplate, PhxBackendBoilerplate.Cache,
  inclusion_policy: :inclusive,
  levels: [
    {PhxBackendBoilerplate.Cache.L1, [gc_interval: :timer.hours(12), max_size: 10_000]},
    {PhxBackendBoilerplate.Cache.L2, []}
  ]

config :phx_backend_boilerplate, PhxBackendBoilerplate.SWR,
  soft_ttl: 200,
  l1_hard_ttl: 1_000,
  l2_hard_ttl: 5_000,
  lock_ttl: 2_000,
  early_refresh_window: 100
