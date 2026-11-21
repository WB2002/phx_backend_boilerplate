defmodule PhxBackendBoilerplate.Lint.BannedIdentifiers do
  @moduledoc """
  Shared denylist for vague/placeholder identifiers aligned with NestJS, Go, and FastAPI boilerplates.
  """

  @exact ~w(
    data result item temp tmp obj val
    foo bar baz qux thing stuff dummy
    test_var my_var my_func
    do_something handle_stuff process_data dummy_func
  )a

  @var_numbered ~r/^var\d+$/

  @exact_strings Enum.map(@exact, &Atom.to_string/1)

  @spec banned?(atom() | String.t()) :: boolean()
  def banned?(name) when is_atom(name) do
    name in @exact || Regex.match?(@var_numbered, Atom.to_string(name))
  end

  def banned?(name) when is_binary(name) do
    name in @exact_strings || Regex.match?(@var_numbered, name)
  end

  @spec message(atom()) :: String.t()
  def message(name) do
    "Generic or placeholder identifier #{inspect(name)} rejected. Use a domain-specific descriptive name."
  end
end
