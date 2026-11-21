defmodule CredoFixtures.BannedSample do
  @moduledoc false

  defp bad_assign do
    result = 1
    result
  end

  defp bad_param(foo) do
    foo
  end
end
