defmodule PhxBackendBoilerplateWeb.Demo.FlagsController do
  @moduledoc """
  Demo endpoints for FunWithFlags.

    * `GET /api/demo/flags/preview` — global boolean `:demo_preview` (404 when off)
    * `GET /api/demo/flags/beta` — per-guest actor `:demo_beta` (403 when off)
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Flags

  def preview(conn, _params) do
    if Flags.enabled?(:demo_preview) do
      json(conn, %{data: %{feature: "preview", enabled: true}})
    else
      conn
      |> put_status(:not_found)
      |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  def beta(conn, _params) do
    guest_id = conn.assigns.guest_id
    guest = Flags.guest(guest_id)

    if Flags.enabled?(:demo_beta, guest) do
      json(conn, %{
        data: %{
          feature: "beta",
          guest_id: guest_id,
          enabled: true
        }
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: %{detail: "Forbidden"}})
    end
  end
end
