defmodule PhxBackendBoilerplateWeb.ParamsTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias PhxBackendBoilerplateWeb.Params

  defmodule SampleDTO do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :email, :string
      field :parent_id, :integer
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:email, :parent_id])
      |> validate_required([:email])
      |> validate_format(:email, ~r/@/)
    end
  end

  test "validate/2 returns ok struct when changeset is valid" do
    assert {:ok, dto} =
             Params.validate(SampleDTO, %{"email" => "a@b.com", "parent_id" => 3})

    assert dto.email == "a@b.com"
    assert dto.parent_id == 3
  end

  test "validate/2 returns error changeset when invalid" do
    assert {:error, changeset} = Params.validate(SampleDTO, %{"email" => "nope"})
    refute changeset.valid?
    assert %{email: ["has invalid format"]} = errors_on(changeset)
  end

  test "validate/2 rejects non-integer parent_id at cast" do
    assert {:error, changeset} =
             Params.validate(SampleDTO, %{
               "email" => "a@b.com",
               "parent_id" => "1; DROP TABLE comments"
             })

    refute changeset.valid?
    assert %{parent_id: [_ | _]} = errors_on(changeset)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
