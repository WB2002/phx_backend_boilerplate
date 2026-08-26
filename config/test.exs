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
    demo_expensive: {Regulator.Limit.Static, [limit: 2]},
    demo_uploads: {Regulator.Limit.Static, [limit: 4]}
  ]

config :phx_backend_boilerplate, PhxBackendBoilerplate.Files,
  max_file_bytes: 1_000_000,
  max_files_per_request: 5,
  hash_chunk_bytes: 1024,
  local_root: "tmp/test-uploads",
  storage: PhxBackendBoilerplate.Files.Storage.Local,
  scanner: PhxBackendBoilerplate.Files.Scanner.Fake

config :phx_backend_boilerplate, :parsers, upload_length: 1_000_000 * 5

# Fast timeouts for outbound HTTP tests; plug stubs avoid the network.
config :phx_backend_boilerplate, PhxBackendBoilerplate.HTTP, receive_timeout: 1_000

# reCAPTCHA: Fake adapter; skip off so plug/controller tests exercise verify.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha,
  skip: false,
  adapter: PhxBackendBoilerplate.Recaptcha.Fake,
  secret_key: "test-secret",
  min_score: 0.5

config :phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake, result: :ok

# CORS allowlist for preflight tests.
config :phx_backend_boilerplate, :cors,
  origins: ["http://localhost:3000", "http://127.0.0.1:3000"]

config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Example,
  base_url: "https://example.test",
  api_token: "test-token"

# Slack: Fake adapter; skip off so notify tests exercise the facade.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Slack,
  skip: false,
  adapter: PhxBackendBoilerplate.Integrations.Slack.Fake,
  bot_token: "xoxb-test-token",
  default_channel: nil,
  api_url: "https://slack.com/api/chat.postMessage"

config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Slack.Fake,
  result: {:ok, :fake}

config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Stripe,
  skip: false,
  adapter: PhxBackendBoilerplate.Integrations.Stripe.Fake,
  secret_key: "sk_test_fake",
  webhook_secret: "whsec_test_fake"

config :phx_backend_boilerplate, PhxBackendBoilerplate.Billing,
  success_url: "http://localhost:3000/billing/success?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: "http://localhost:3000/billing/cancel",
  plans: %{
    "lifetime" => %{
      key: "lifetime",
      name: "Lifetime Access",
      description: "One-time payment for permanent access",
      mode: "payment",
      price_id: "price_test_lifetime"
    },
    "pro" => %{
      key: "pro",
      name: "Pro Plan",
      description: "Monthly subscription with recurring billing",
      mode: "subscription",
      price_id: "price_test_pro"
    }
  }

# Short SWR defaults for tests (still soft < l1 < l2).
config :phx_backend_boilerplate, PhxBackendBoilerplate.Cache,
  inclusion_policy: :inclusive,
  levels: [
    {PhxBackendBoilerplate.Cache.L1,
     [gc_interval: :timer.hours(12), max_size: 10_000, allocated_memory: 8_000_000]},
    {PhxBackendBoilerplate.Cache.L2, []}
  ]

config :phx_backend_boilerplate, PhxBackendBoilerplate.SWR,
  soft_ttl: 200,
  l1_hard_ttl: 1_000,
  l2_hard_ttl: 5_000,
  lock_ttl: 2_000,
  early_refresh_window: 100

# Disable ETS cache so SQL sandbox rollback is not shadowed by stale flag values.
config :fun_with_flags, :cache, enabled: false

# Oban: no queue execution in tests; use assert_enqueued / perform_job.
config :phx_backend_boilerplate, Oban, testing: :manual

# Fast Argon2 for tests only — never use these costs in production.
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

config :phx_backend_boilerplate, PhxBackendBoilerplate.Accounts,
  access_secret: "test-access-secret",
  refresh_secret: "test-refresh-secret"

config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.AuthCookies, secure: false

# In-memory KMS for unit tests (AES wrap; no AWS). ARN form required by Encryption SDK.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Crypto,
  key_id: "arn:aws:kms:us-east-1:000000000000:key/00000000-0000-4000-8000-000000000001",
  kms: PhxBackendBoilerplate.Crypto.KMS.Memory,
  wrapping_key: :binary.copy(<<1>>, 32)
