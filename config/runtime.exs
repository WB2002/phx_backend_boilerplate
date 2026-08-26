import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/phx_backend_boilerplate start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint, server: true
end

config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

redis_url =
  case config_env() do
    :prod ->
      System.get_env("REDIS_URL") ||
        raise """
        environment variable REDIS_URL is missing.
        For example: redis://localhost:6379
        """

    :test ->
      System.get_env("REDIS_URL") || "redis://localhost:6379/1"

    _ ->
      System.get_env("REDIS_URL") || "redis://localhost:6379"
  end

config :phx_backend_boilerplate, PhxBackendBoilerplate.RateLimit, url: redis_url

# Nebulex L2 (Redis). Same REDIS_URL as Hammer; Hammer uses its own key prefix.
config :phx_backend_boilerplate, PhxBackendBoilerplate.Cache.L2, conn_opts: [url: redis_url]

# ---------------------------------------------------------------------------
# CORS (comma-separated exact origins; never "*")
# ---------------------------------------------------------------------------

cors_origins =
  case System.get_env("CORS_ORIGINS") do
    nil ->
      case config_env() do
        :prod -> []
        :test -> ["http://localhost:3000", "http://127.0.0.1:3000"]
        _ -> ["http://localhost:3000", "http://127.0.0.1:3000"]
      end

    "" ->
      []

    raw ->
      raw
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
  end

config :phx_backend_boilerplate, :cors, origins: cors_origins

# ---------------------------------------------------------------------------
# reCAPTCHA v3
# ---------------------------------------------------------------------------

truthy? = fn
  value when value in ~w(true 1 yes on) -> true
  _ -> false
end

recaptcha_skip? =
  case config_env() do
    :prod ->
      false

    :test ->
      false

    _ ->
      # Dev defaults to skip so curl demos work without a Google key.
      case System.get_env("RECAPTCHA_SKIP") do
        nil -> true
        value -> truthy?.(value)
      end
  end

recaptcha_secret =
  case {config_env(), System.get_env("RECAPTCHA_SECRET_KEY")} do
    {:prod, nil} ->
      raise """
      environment variable RECAPTCHA_SECRET_KEY is missing.
      Set it to your Google reCAPTCHA v3 secret.
      """

    {_, nil} ->
      nil

    {_, key} ->
      key
  end

recaptcha_min_score =
  case System.get_env("RECAPTCHA_MIN_SCORE") do
    nil ->
      0.5

    raw ->
      case Float.parse(raw) do
        {score, _} -> score
        :error -> 0.5
      end
  end

config :phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha,
  secret_key: recaptcha_secret,
  min_score: recaptcha_min_score,
  skip: recaptcha_skip?

# ---------------------------------------------------------------------------
# Observability (CloudWatch Logs/Metrics + OpenTelemetry → X-Ray via collector)
# ---------------------------------------------------------------------------

aws_region = System.get_env("AWS_REGION") || "us-east-1"

config :ex_aws,
  region: aws_region,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID") || "test",
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY") || "test"

# Point ExAws at LocalStack (or any custom endpoint) when AWS_ENDPOINT_URL is set.
case System.get_env("AWS_ENDPOINT_URL") do
  nil ->
    :ok

  endpoint ->
    uri = URI.parse(endpoint)
    scheme = (uri.scheme || "http") <> "://"
    host = uri.host || "localhost"
    port = uri.port || if(uri.scheme == "https", do: 443, else: 80)

    service_opts = [
      scheme: scheme,
      host: host,
      port: port,
      region: aws_region
    ]

    config :ex_aws, :cloudwatch, service_opts
    config :ex_aws, :logs, service_opts
    config :ex_aws, :s3, service_opts
    config :ex_aws, :kms, service_opts
end

# KMS key for Crypto.KMS / Crypto.Envelope (optional; ops fail with :key_id_missing).
# Do not overwrite test.exs Memory adapter / wrapping_key when unset.
case System.get_env("KMS_KEY_ID") do
  key_id when is_binary(key_id) and key_id != "" ->
    config :phx_backend_boilerplate, PhxBackendBoilerplate.Crypto, key_id: key_id

  _ ->
    :ok
end

# ---------------------------------------------------------------------------
# File uploads (storage backend, ClamAV, S3 bucket)
# ---------------------------------------------------------------------------

storage_backend =
  case System.get_env("STORAGE_BACKEND") do
    "s3" -> PhxBackendBoilerplate.Files.Storage.S3
    _ -> PhxBackendBoilerplate.Files.Storage.Local
  end

files_runtime = [
  storage: storage_backend,
  clamav: [
    host: System.get_env("CLAMAV_HOST") || "127.0.0.1",
    port: String.to_integer(System.get_env("CLAMAV_PORT") || "3310")
  ]
]

files_runtime =
  case System.get_env("CLAMAV_SKIP") do
    v when v in ~w(true 1 yes on) ->
      Keyword.put(files_runtime, :scanner, PhxBackendBoilerplate.Files.Scanner.AlwaysClean)

    _ ->
      files_runtime
  end

files_runtime =
  case System.get_env("S3_BUCKET") do
    nil -> files_runtime
    "" -> files_runtime
    bucket -> Keyword.put(files_runtime, :s3_bucket, bucket)
  end

config :phx_backend_boilerplate, PhxBackendBoilerplate.Files, files_runtime

cloudwatch_logs_enabled = truthy?.(System.get_env("CLOUDWATCH_LOGS_ENABLED"))
cloudwatch_metrics_enabled = truthy?.(System.get_env("CLOUDWATCH_METRICS_ENABLED"))
otel_traces_enabled = truthy?.(System.get_env("OTEL_TRACES_ENABLED"))

log_group =
  System.get_env("CLOUDWATCH_LOG_GROUP") ||
    "/phx-backend-boilerplate/#{config_env()}"

metrics_namespace =
  System.get_env("CLOUDWATCH_METRICS_NAMESPACE") || "PhxBackendBoilerplate"

push_interval =
  case System.get_env("CLOUDWATCH_METRICS_PUSH_INTERVAL_MS") do
    nil -> if System.get_env("AWS_ENDPOINT_URL"), do: 5_000, else: 60_000
    value -> String.to_integer(value)
  end

log_stream =
  case System.get_env("CLOUDWATCH_LOG_STREAM") do
    nil -> nil
    "" -> nil
    stream -> stream
  end

cloudwatch_logs =
  [
    log_group: log_group,
    flush_interval_ms: String.to_integer(System.get_env("CLOUDWATCH_LOGS_FLUSH_MS") || "2000"),
    max_batch: String.to_integer(System.get_env("CLOUDWATCH_LOGS_MAX_BATCH") || "50"),
    level: String.to_existing_atom(System.get_env("CLOUDWATCH_LOGS_LEVEL") || "info")
  ]
  |> then(fn opts ->
    if log_stream, do: Keyword.put(opts, :log_stream, log_stream), else: opts
  end)

config :phx_backend_boilerplate, PhxBackendBoilerplate.Observability,
  cloudwatch_logs_enabled: cloudwatch_logs_enabled,
  cloudwatch_metrics_enabled: cloudwatch_metrics_enabled,
  otel_traces_enabled: otel_traces_enabled,
  cloudwatch_logs: cloudwatch_logs,
  cloudwatch_metrics: [
    namespace: metrics_namespace,
    push_interval: push_interval
  ]

if otel_traces_enabled do
  otlp_endpoint =
    System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"

  config :opentelemetry,
    span_processor: :batch,
    traces_exporter: :otlp,
    id_generator: :opentelemetry_xray_id_generator,
    propagators: [:opentelemetry_xray_propagator, :baggage]

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: otlp_endpoint
else
  config :opentelemetry, traces_exporter: :none
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :phx_backend_boilerplate, PhxBackendBoilerplate.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :phx_backend_boilerplate, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :phx_backend_boilerplate, PhxBackendBoilerplate.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
