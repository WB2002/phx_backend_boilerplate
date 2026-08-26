defmodule PhxBackendBoilerplateWeb.Demo.CommentController do
  @moduledoc """
  Demo endpoint illustrating request DTOs, HTML sanitization, and typed params.

  Stateless echo of a validated `CommentDTO` — no database table.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplateWeb.Demo.CommentDTO
  alias PhxBackendBoilerplateWeb.Params

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  def create(conn, params) do
    with {:ok, dto} <- Params.validate(CommentDTO, params) do
      json(conn, %{
        data: %{
          title: dto.title,
          body: dto.body,
          email: dto.email,
          parent_id: dto.parent_id
        }
      })
    end
  end
end
