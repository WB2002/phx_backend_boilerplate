defmodule PhxBackendBoilerplateWeb.Params do
  @moduledoc """
  Validates request params against an Ecto embedded-schema DTO.

  Each DTO module must expose `changeset/1` that accepts a map of params and
  returns an `%Ecto.Changeset{}`.

      with {:ok, dto} <- Params.validate(CommentDTO, params) do
        json(conn, %{data: %{title: dto.title}})
      end
  """

  @doc """
  Runs `module.changeset/1` and returns `{:ok, struct}` or `{:error, changeset}`.
  """
  def validate(module, params) when is_atom(module) and is_map(params) do
    changeset = module.changeset(params)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
