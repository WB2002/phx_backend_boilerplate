defmodule PhxBackendBoilerplate.Repo do
  use Ecto.Repo,
    otp_app: :phx_backend_boilerplate,
    adapter: Ecto.Adapters.Postgres
end
