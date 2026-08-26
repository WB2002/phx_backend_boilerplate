defmodule PhxBackendBoilerplate.Repo do
  use Ecto.Repo,
    otp_app: :phx_backend_boilerplate,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Attaches the current request/correlation context to Ecto query telemetry.
  """
  def default_options(_operation) do
    [telemetry_options: PhxBackendBoilerplate.RequestContext.current()]
  end
end
