defmodule PhxBackendBoilerplateWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  Controllers that use DTO validation should set:

      action_fallback PhxBackendBoilerplateWeb.FallbackController
  """

  use PhxBackendBoilerplateWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: PhxBackendBoilerplateWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
