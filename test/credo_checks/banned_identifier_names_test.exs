defmodule CredoChecks.BannedIdentifierNamesTest do
  use ExUnit.Case, async: true

  test "CredoChecks.BannedIdentifierNames reports banned_sample.ex violations" do
    {:ok, _} = Application.ensure_all_started(:credo)
    fixture = Path.expand("../fixtures/credo/banned_sample.ex", __DIR__)
    source_file = Credo.SourceFile.parse(File.read!(fixture), fixture)
    issues = CredoChecks.BannedIdentifierNames.run(source_file)

    messages = Enum.map(issues, & &1.message)
    assert length(issues) == 4
    assert Enum.any?(messages, &(&1 =~ "result"))
    assert Enum.any?(messages, &(&1 =~ "foo"))
  end

  test "guards Credo.Check usage so prod builds without credo dependency compile" do
    source = File.read!(Path.expand("../../lib/credo_checks/banned_identifier_names.ex", __DIR__))
    assert source =~ "Code.ensure_loaded?(Credo.Check)"
  end
end
