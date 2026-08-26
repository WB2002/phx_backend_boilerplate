defmodule PhxBackendBoilerplateWeb.Demo.CommentController do
  @moduledoc """
  Demo endpoint illustrating request DTOs, HTML sanitization, and typed params.

  Stateless echo of a validated `CommentDTO` — no database table.
  After a successful create, broadcasts `comment_created` on `demo:lobby`
  so websocket subscribers can observe REST → PubSub fan-out.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.PubSub
  alias PhxBackendBoilerplateWeb.Demo.CommentDTO
  alias PhxBackendBoilerplateWeb.Params

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  def create(conn, params) do
    with {:ok, dto} <- Params.validate(CommentDTO, params) do
      :ok =
        PubSub.broadcast("demo:lobby", %{
          "event" => "comment_created",
          "title" => dto.title,
          "email" => dto.email
        })

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
