defmodule PhxBackendBoilerplate.Files.Scanner.AlwaysClean do
  @moduledoc """
  No-op scanner that always returns `:clean`.

  Used when `CLAMAV_SKIP=true` (e.g. local arm64 where the ClamAV image
  has no native manifest). Production should use ClamAV (fail-closed).
  """

  @behaviour PhxBackendBoilerplate.Files.Scanner

  @impl true
  def scan_file(_path), do: :clean
end
