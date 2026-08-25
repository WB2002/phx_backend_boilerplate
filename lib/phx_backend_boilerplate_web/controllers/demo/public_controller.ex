defmodule PhxBackendBoilerplateWeb.Demo.PublicController do
  @moduledoc """
  Demo public endpoint illustrating guest_id + multi-attribute rate limiting.
  """

  use PhxBackendBoilerplateWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      data: %{
        message: "Public demo",
        guest_id: conn.assigns[:guest_id]
      }
    })
  end
end
