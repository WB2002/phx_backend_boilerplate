defmodule PhxBackendBoilerplateWeb.Demo.CommentDTO do
  @moduledoc """
  Example request DTO for `POST /api/demo/comments`.

  Shows class-validator-style input validation with Ecto embedded schemas,
  opt-in HTML sanitization, and typed IDs (SQL-safe binds later).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PhxBackendBoilerplate.Sanitize

  @primary_key false
  embedded_schema do
    field :title, :string
    field :body, :string
    field :email, :string
    field :parent_id, :integer
  end

  @email_format ~r/^[^\s]+@[^\s]+$/

  def changeset(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:title, :body, :email, :parent_id])
    |> validate_required([:title, :body, :email])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:body, min: 1, max: 10_000)
    |> validate_format(:email, @email_format)
    |> Sanitize.strip_tags(:title)
    |> Sanitize.html(:body)
  end
end
