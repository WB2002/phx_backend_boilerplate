# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :phx_backend_boilerplate,
  ecto_repos: [PhxBackendBoilerplate.Repo],
  generators: [timestamp_type: :utc_datetime]

# Plug.Parsers body limit (must cover max_files_per_request * max_file_bytes).
config :phx_backend_boilerplate, :parsers, length: 500_000_000

# Configure the endpoint
config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PhxBackendBoilerplateWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PhxBackendBoilerplate.PubSub,
  live_view: [signing_salt: "f0oJqila"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  phx_backend_boilerplate: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  phx_backend_boilerplate: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Shared Redacted + PII keys (also loaded by prod.exs for LoggerJSON).
%{redacted: redacted, pii: pii} =
  Path.join(__DIR__, "redaction_keys.exs") |> Code.eval_file() |> elem(0)

config :phx_backend_boilerplate, PhxBackendBoilerplate.Logging.Redaction,
  redacted: redacted,
  pii: pii

# Phoenix request logs (substring match on param names → "[FILTERED]").
config :phoenix, :filter_parameters, Enum.uniq(redacted ++ pii)

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :correlation_id, :user_id, :otel_trace_id, :otel_span_id]

# ExAws uses Req via our Finch pool (no Hackney).
config :ex_aws,
  json_codec: Jason,
  http_client: PhxBackendBoilerplate.AWS.HTTPClient

# Crypto: Argon2 digests + KMS encrypt/decrypt + envelope seal/open.
# `key_id` is set from KMS_KEY_ID in runtime.exs (optional at boot).
config :phx_backend_boilerplate, PhxBackendBoilerplate.Crypto,
  key_id: nil,
  kms: PhxBackendBoilerplate.Crypto.KMS.ExAws

# Observability defaults (overridden in runtime.exs from env).
config :phx_backend_boilerplate, PhxBackendBoilerplate.Observability,
  cloudwatch_logs_enabled: false,
  cloudwatch_metrics_enabled: false,
  otel_traces_enabled: false,
  cloudwatch_logs: [
    log_group: "/phx-backend-boilerplate/dev",
    flush_interval_ms: 2_000,
    max_batch: 50
  ],
  cloudwatch_metrics: [
    namespace: "PhxBackendBoilerplate",
    push_interval: 60_000
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# MIME extensions for streaming demos (`:accepts` on `:api_stream`).
# After changing these, recompile mime: `mix deps.compile mime --force`.
config :mime, :types, %{
  "text/event-stream" => ["sse"],
  "application/x-ndjson" => ["ndjson"]
}

# Named Regulator concurrency limiters (capacity / load shedding).
# Demo uses a small Static limit so parallel requests can trigger 503.
# For production resource classes prefer AIMD/Gradient with a realistic
# target_avg_latency (or :timeout) for that workload.
config :phx_backend_boilerplate, PhxBackendBoilerplate.LoadShed,
  regulators: [
    demo_expensive: {Regulator.Limit.Static, [limit: 2]},
    # Uploads hold connections for a long time; keep concurrency low.
    demo_uploads: {Regulator.Limit.Static, [limit: 4]}
  ]

# File uploads: validation, ClamAV, storage, resumable Range downloads.
# Raise max_file_bytes (and Plug.Parsers :length) for multi-GB uploads.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Files,
  max_file_bytes: 100_000_000,
  max_files_per_request: 5,
  hash_chunk_bytes: 10_485_760,
  allowed_extensions: ~w(.pdf .png .jpg .jpeg .gif .webp .txt .csv .zip),
  allowed_content_types: [
    "application/pdf",
    "image/png",
    "image/jpeg",
    "image/gif",
    "image/webp",
    "text/plain",
    "text/csv",
    "application/zip",
    "application/x-zip-compressed"
  ],
  storage: PhxBackendBoilerplate.Files.Storage.Local,
  local_root: "priv/uploads",
  scanner: PhxBackendBoilerplate.Files.Scanner.ClamAV,
  clamav: [host: "127.0.0.1", port: 3310],
  s3_bucket: nil

# Request deadline budget (monotonic). Propagated as x-request-timeout-ms.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Deadline, timeout: 15_000

# Shared outbound HTTP transport (Req). Retry is always forced off in code;
# ExternalService owns retry/circuit-breaker policy per integration client.
config :phx_backend_boilerplate, PhxBackendBoilerplate.HTTP, receive_timeout: 15_000

# CSP + companion security headers (strict for API; looser for /dev HTML UIs).
config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Plugs.SecurityHeaders,
  api_csp: "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  dev_csp:
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:; frame-ancestors 'none'"

# CORS — origins overridden from CORS_ORIGINS in runtime.exs.
config :phx_backend_boilerplate, :cors,
  origins: [],
  credentials: true,
  methods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: [
    "content-type",
    "authorization",
    "x-request-id",
    "x-correlation-id",
    "x-guest-id",
    "x-device-fingerprint",
    "x-user-id",
    "x-request-timeout-ms"
  ],
  expose: [
    "x-guest-id",
    "x-correlation-id",
    "retry-after",
    "accept-ranges",
    "content-range"
  ],
  max_age: 86_400

# reCAPTCHA v3 — secret / skip / adapter from runtime.exs and env configs.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha,
  secret_key: nil,
  min_score: 0.5,
  skip: false,
  adapter: PhxBackendBoilerplate.Recaptcha.Google,
  siteverify_url: "https://www.google.com/recaptcha/api/siteverify"

# Example integration — copy for real dependencies. base_url is required
# by get_widget/1; override in runtime/test as needed.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Example,
  base_url: "https://api.example.com"

# Multilevel cache topology (Nebulex validates these options strictly).
config :phx_backend_boilerplate, PhxBackendBoilerplate.Cache,
  inclusion_policy: :inclusive,
  levels: [
    {PhxBackendBoilerplate.Cache.L1,
     [
       gc_interval: :timer.hours(12),
       max_size: 100_000
     ]},
    {PhxBackendBoilerplate.Cache.L2, []}
  ]

# SWR defaults: soft_ttl < l1_hard_ttl < l2_hard_ttl. L2 conn_opts in runtime.exs.
config :phx_backend_boilerplate, PhxBackendBoilerplate.SWR,
  soft_ttl: :timer.seconds(30),
  l1_hard_ttl: :timer.minutes(2),
  l2_hard_ttl: :timer.minutes(5),
  lock_ttl: 8_000,
  early_refresh_window: 5_000

# Feature flags (FunWithFlags): Postgres persistence + Phoenix.PubSub cache bust.
# Supervisor is started in PhxBackendBoilerplate.Application after PubSub.
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: PhxBackendBoilerplate.Repo

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: PhxBackendBoilerplate.PubSub

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
