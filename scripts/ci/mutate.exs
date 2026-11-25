# Lightweight targeted mutation runner for changed Elixir source files.
# Applies single-site operator/boolean mutations one at a time, runs the
# corresponding test file (or full test suite fallback), restores the file,
# and fails if mutation score falls below MUTATION_MIN_SCORE (default: 50%).

min_score =
  System.get_env("MUTATION_MIN_SCORE", "50")
  |> String.to_integer()

max_mutants_per_file =
  System.get_env("MUTATION_MAX_PER_FILE", "8")
  |> String.to_integer()

files = System.argv()

mutations = [
  {" == ", " != "},
  {" != ", " == "},
  {" >= ", " < "},
  {" <= ", " > "},
  {" > ", " <= "},
  {" < ", " >= "},
  {" and ", " or "},
  {" or ", " and "}
]

find_test_file = fn source_file ->
  candidate =
    source_file
    |> String.replace_prefix("lib/", "test/")
    |> String.replace_suffix(".ex", "_test.exs")

  if File.exists?(candidate), do: candidate, else: nil
end

generate_mutants = fn content ->
  lines = String.split(content, "\n")

  {candidates, _in_doc} =
    lines
    |> Enum.with_index()
    |> Enum.reduce({[], false}, fn {line, idx}, {acc, in_doc} ->
      trimmed = String.trim(line)
      toggles = String.contains?(trimmed, ~s("""))
      next_in_doc = if toggles, do: not in_doc, else: in_doc

      skip =
        in_doc or toggles or String.starts_with?(trimmed, "#") or
          String.starts_with?(trimmed, "@")

      if skip do
        {acc, next_in_doc}
      else
        line_mutants =
          Enum.flat_map(mutations, fn {from, to} ->
            if String.contains?(line, from) do
              mutated_line = String.replace(line, from, to, global: false)
              [{idx, from, to, List.replace_at(lines, idx, mutated_line) |> Enum.join("\n")}]
            else
              []
            end
          end)

        {acc ++ line_mutants, next_in_doc}
      end
    end)

  Enum.take(candidates, max_mutants_per_file)
end

{total, killed} =
  Enum.reduce(files, {0, 0}, fn file, {acc_total, acc_killed} ->
    original = File.read!(file)
    mutants = generate_mutants.(original)
    test_target = find_test_file.(file)

    IO.puts("=== #{file} (#{length(mutants)} mutants, target: #{test_target || "full suite"}) ===")

    Enum.reduce(mutants, {acc_total, acc_killed}, fn {line_idx, from, to, mutated}, {t, k} ->
      try do
        File.write!(file, mutated)

        args =
          if test_target do
            ["test", test_target, "--max-failures", "1"]
          else
            ["test", "--max-failures", "1"]
          end

        {_out, status} =
          System.cmd("mix", args, env: [{"MIX_ENV", "test"}], stderr_to_stdout: true)

        if status != 0 do
          IO.puts("  KILLED   #{file}:#{line_idx + 1} (#{String.trim(from)} -> #{String.trim(to)})")
          {t + 1, k + 1}
        else
          IO.puts("  SURVIVED #{file}:#{line_idx + 1} (#{String.trim(from)} -> #{String.trim(to)})")
          {t + 1, k}
        end
      after
        File.write!(file, original)
      end
    end)
  end)

if total == 0 do
  IO.puts("mutation summary: 0 mutants generated (skipped)")
  System.halt(0)
end

score = Float.round(killed * 100.0 / total, 1)
IO.puts("mutation summary: #{killed}/#{total} killed (#{score}%, threshold #{min_score}%)")

if score < min_score do
  System.halt(1)
end
