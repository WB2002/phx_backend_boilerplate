defmodule PhxBackendBoilerplate.Cache.EntryTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Cache.Entry

  test "classifies fresh, stale, and miss by age" do
    entry = Entry.new("v", 100, 500, 1_000)

    assert Entry.classify(entry, 1_050) == :fresh
    assert Entry.classify(entry, 1_100) == :stale
    assert Entry.classify(entry, 1_200) == :stale
    assert Entry.classify(entry, 1_500) == :miss
  end

  test "poisoned error values are misses" do
    entry = %Entry{
      value: {:error, :old},
      inserted_at_ms: 0,
      soft_ttl_ms: 100,
      hard_ttl_ms: 500
    }

    assert Entry.classify(entry, 10) == :miss
  end

  test "nil and unknown shapes are misses" do
    assert Entry.classify(nil, 0) == :miss
    assert Entry.classify(%{value: "x"}, 0) == :miss
  end

  test "soft_remaining never goes negative" do
    entry = Entry.new("v", 100, 500, 1_000)
    assert Entry.soft_remaining(entry, 1_050) == 50
    assert Entry.soft_remaining(entry, 1_200) == 0
  end
end
