defmodule PhxBackendBoilerplateWeb.Graphql.Complexity do
  @moduledoc """
  Absinthe complexity helpers for list/connection fields.

  Prefer `limit` / `first` page args so nested lists amplify complexity
  instead of counting as `1` per field.
  """

  alias PhxBackendBoilerplateWeb.Graphql.Config

  @doc """
  Complexity for a list field: `page_size * max(child_complexity, 1)`.

  Uses `args[:first]` or `args[:limit]`. When the arg is missing, uses
  `Config.max_list_page_size/0` as the default page size. Oversized
  requested pages still count at the requested size so complexity fails
  before resolve.
  """
  @spec list(map(), non_neg_integer()) :: pos_integer()
  def list(args, child_complexity) when is_map(args) and is_integer(child_complexity) do
    page = page_size(args)
    page * max(child_complexity, 1)
  end

  defp page_size(args) do
    cond do
      is_integer(args[:first]) and args[:first] > 0 -> args[:first]
      is_integer(args[:limit]) and args[:limit] > 0 -> args[:limit]
      true -> Config.max_list_page_size()
    end
  end
end
