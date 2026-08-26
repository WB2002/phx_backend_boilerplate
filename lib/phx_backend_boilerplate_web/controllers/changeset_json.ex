defmodule PhxBackendBoilerplateWeb.ChangesetJSON do
  @moduledoc """
  Renders Ecto changeset errors as a field map for JSON APIs.
  """

  @doc """
  Translates changeset errors into a nested map of field => messages.
  """
  def error(%{changeset: changeset}) do
    %{
      errors: %{
        detail: "Unprocessable Entity",
        fields: translate_errors(changeset)
      }
    }
  end

  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({message, opts}) do
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
