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

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Named Regulator concurrency limiters (capacity / load shedding).
# Demo uses a small Static limit so parallel requests can trigger 503.
# For production resource classes prefer AIMD/Gradient with a realistic
# target_avg_latency (or :timeout) for that workload.
config :phx_backend_boilerplate, PhxBackendBoilerplate.LoadShed,
  regulators: [
    demo_expensive: {Regulator.Limit.Static, [limit: 2]}
  ]

# Request deadline budget (monotonic). Propagated as x-request-timeout-ms.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Deadline, timeout: 15_000

# Shared outbound HTTP transport (Req). Retry is always forced off in code;
# ExternalService owns retry/circuit-breaker policy per integration client.
config :phx_backend_boilerplate, PhxBackendBoilerplate.HTTP, receive_timeout: 15_000

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
