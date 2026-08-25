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

  pipeline :rate_limit_demo_login do
    plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
      id: "demo_login",
      scale: :timer.minutes(1),
      limit: 5,
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

  pipeline :load_shed_demo_expensive do
    plug PhxBackendBoilerplateWeb.Plugs.LoadShed, regulator: :demo_expensive
  end

  scope "/api", PhxBackendBoilerplateWeb do
    scope "/demo" do
      pipe_through :api
      pipe_through :rate_limit_demo_login

      post "/login", Demo.SessionController, :create
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
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phx_backend_boilerplate, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: PhxBackendBoilerplateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
