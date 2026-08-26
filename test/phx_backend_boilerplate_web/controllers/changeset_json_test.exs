defmodule PhxBackendBoilerplateWeb.ChangesetJSONTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias PhxBackendBoilerplateWeb.ChangesetJSON

  defmodule Sample do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :title, :string
      field :email, :string
    end
  end

  test "error/1 renders detail and fields map" do
    changeset =
      %Sample{}
      |> cast(%{}, [:title, :email])
      |> validate_required([:title, :email])

    assert %{
             errors: %{
               detail: "Unprocessable Entity",
               fields: %{
                 title: ["can't be blank"],
                 email: ["can't be blank"]
               }
             }
           } = ChangesetJSON.error(%{changeset: changeset})
  end
end
