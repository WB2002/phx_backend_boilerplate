defmodule PhxBackendBoilerplateWeb.Router do
  use PhxBackendBoilerplateWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug PhxBackendBoilerplateWeb.Plugs.Deadline
  end

  # Public APIs only — mints/persists guest_id via cookie + X-Guest-Id
  pipeline :api_public do
    plug :accepts, ["json"]
    plug PhxBackendBoilerplateWeb.Plugs.Deadline
    plug PhxBackendBoilerplateWeb.Plugs.EnsureGuestId
  end

  # Chunked HTTP / SSE — accepts EventSource and NDJSON clients (not json-only).
  # No Regulator: a live stream would hold a concurrency slot for the whole connection.
  pipeline :api_stream do
    plug :accepts, ["json", "sse", "ndjson"]
    plug PhxBackendBoilerplateWeb.Plugs.Deadline
  end

  pipeline :rate_limit_demo_login do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_login",
      scale: :timer.minutes(1),
      limit: 5,
      by: [:ip]
  end

  pipeline :recaptcha do
    plug PhxBackendBoilerplateWeb.Plugs.Recaptcha
  end

  pipeline :rate_limit_demo_comments do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_comments",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :rate_limit_demo_public do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_public",
      scale: :timer.minutes(1),
      limit: 5,
      by: [:ip, :guest_id, :fingerprint]
  end

  pipeline :rate_limit_demo_expensive do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_expensive",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :rate_limit_demo_cached do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_cached",
      scale: :timer.minutes(1),
      limit: 120,
      by: [:ip]
  end

  pipeline :rate_limit_demo_stream do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_stream",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :rate_limit_demo_flags do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_flags",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :rate_limit_demo_uploads do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_uploads",
      scale: :timer.minutes(1),
      limit: 10,
      by: [:ip]
  end

  pipeline :rate_limit_demo_downloads do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_downloads",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :rate_limit_graphql do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "graphql",
      scale: :timer.minutes(1),
      limit: 60,
      by: [:ip]
  end

  pipeline :api_graphql do
    plug :accepts, ["json"]
    plug PhxBackendBoilerplateWeb.Plugs.Deadline
  end

  # Large multipart uploads: long deadline + concurrency cap.
  # Response is JSON; request body is multipart/form-data via Plug.Parsers.
  pipeline :api_uploads do
    plug :accepts, ["json"]
    plug PhxBackendBoilerplateWeb.Plugs.Deadline, timeout: :timer.minutes(30)
  end

  pipeline :load_shed_demo_expensive do
    plug PhxBackendBoilerplateWeb.Plugs.LoadShed, regulator: :demo_expensive
  end

  pipeline :load_shed_demo_uploads do
    plug PhxBackendBoilerplateWeb.Plugs.LoadShed, regulator: :demo_uploads
  end

  scope "/api", PhxBackendBoilerplateWeb do
    scope "/demo" do
      pipe_through [:api, :rate_limit_demo_login, :recaptcha]

      post "/login", Demo.SessionController, :create
    end

    scope "/demo" do
      pipe_through :api
      pipe_through :rate_limit_demo_comments

      post "/comments", Demo.CommentController, :create
    end

    scope "/demo" do
      pipe_through :api_public
      pipe_through :rate_limit_demo_public

      get "/public", Demo.PublicController, :show
    end

    scope "/demo" do
      pipe_through [:api, :rate_limit_demo_expensive, :load_shed_demo_expensive]

      get "/expensive", Demo.ExpensiveController, :show
    end

    scope "/demo" do
      pipe_through [:api, :rate_limit_demo_cached]

      get "/cached", Demo.CachedController, :show
    end

    scope "/demo" do
      pipe_through [:api_stream, :rate_limit_demo_stream]

      get "/stream/chunks", Demo.StreamController, :chunks
      get "/stream/sse", Demo.StreamController, :sse
    end

    scope "/demo" do
      pipe_through [:api_uploads, :rate_limit_demo_uploads, :load_shed_demo_uploads]

      post "/files", Demo.FilesController, :create
    end

    scope "/demo" do
      pipe_through [:api, :rate_limit_demo_downloads]

      get "/files/:id", Demo.FilesController, :show
      head "/files/:id", Demo.FilesController, :head
    end

    scope "/demo/flags" do
      pipe_through [:api, :rate_limit_demo_flags]

      get "/preview", Demo.FlagsController, :preview
    end

    scope "/demo/flags" do
      pipe_through [:api_public, :rate_limit_demo_flags]

      get "/beta", Demo.FlagsController, :beta
    end
  end

  scope "/api" do
    pipe_through [:api_graphql, :rate_limit_graphql]

    forward "/graphql", Absinthe.Plug, schema: PhxBackendBoilerplateWeb.Graphql.Schema
  end

  # Enable LiveDashboard, FunWithFlags UI, GraphiQL, and Swoosh mailbox preview in development
  if Application.compile_env(:phx_backend_boilerplate, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    pipeline :dev_flags_ui do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :put_secure_browser_headers
    end

    pipeline :dev_graphiql do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :put_secure_browser_headers
    end

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: PhxBackendBoilerplateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # FunWithFlags.UI has its own CSRF; do not pipe through protect_from_forgery.
    scope "/dev/feature-flags" do
      pipe_through :dev_flags_ui
      forward "/", FunWithFlags.UI.Router, namespace: "dev/feature-flags"
    end

    # GraphiQL: query / mutation / subscription playground (dev only).
    scope "/" do
      pipe_through :dev_graphiql

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: PhxBackendBoilerplateWeb.Graphql.Schema,
        socket: PhxBackendBoilerplateWeb.GraphqlSocket,
        interface: :simple
    end
  end
end
