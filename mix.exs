defmodule PhxBackendBoilerplate.MixProject do
  use Mix.Project

  def project do
    [
      app: :phx_backend_boilerplate,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      listeners: [Phoenix.CodeReloader],
      releases: [
        phx_backend_boilerplate: [
          applications: [
            opentelemetry: :temporary,
            fun_with_flags: :load
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PhxBackendBoilerplate.Application, []},
      extra_applications: [:logger, :runtime_tools, :fuse]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.13"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:external_service, "~> 2.8"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics_cloudwatch, "~> 1.1"},
      {:ex_aws, "~> 2.6.0"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_aws_kms, "~> 2.5"},
      {:ex_aws_cloudwatch, "~> 2.0"},
      {:ex_aws_cloudwatch_logs, "~> 1.0"},
      {:aws_encryption_sdk, "~> 0.7"},
      {:argon2_elixir, "~> 4.1"},
      # aws_encryption_sdk pins hackney ~> 1.20; ex_aws 2.7 wants ~> 4.0 (optional for us — we use Req).
      {:hackney, "~> 1.20"},
      {:logger_json, "~> 7.0"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_bandit, "~> 0.3"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_xray, "~> 0.7"},
      {:opentelemetry_logger_metadata, "~> 0.2"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:joken, "~> 2.6"},
      {:html_sanitize_ex, "~> 1.4"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:cors_plug, "~> 3.0"},
      {:hammer_backend_redis, "~> 7.0"},
      {:regulator, "~> 0.6"},
      {:nebulex, "~> 3.0"},
      {:nebulex_local, "~> 3.0"},
      {:nebulex_redis_adapter, "~> 3.0"},
      {:nebulex_distributed, "~> 3.0"},
      {:fun_with_flags, "~> 1.13", runtime: false},
      {:fun_with_flags_ui, "~> 1.1", only: :dev, runtime: false},
      {:oban, "~> 2.19"},
      # Available at compile time in all envs (router `import`); mount stays behind :dev_routes.
      {:oban_web, "~> 2.11"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": [
        "compile",
        "tailwind phx_backend_boilerplate",
        "esbuild phx_backend_boilerplate"
      ],
      "assets.deploy": [
        "tailwind phx_backend_boilerplate --minify",
        "esbuild phx_backend_boilerplate --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --min-priority high",
        "gitleaks",
        "test"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit, :fun_with_flags, :fun_with_flags_ui],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end
