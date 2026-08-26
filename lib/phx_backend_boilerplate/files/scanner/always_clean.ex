defmodule PhxBackendBoilerplate.Files.Scanner.AlwaysClean do
  @moduledoc """
  No-op scanner that always returns `:clean`.

  Used when `CLAMAV_SKIP=true` in `:dev` only (e.g. local arm64 where the
  ClamAV image has no native manifest). Production and other Mix envs fail
  boot if `CLAMAV_SKIP` is set; use ClamAV (fail-closed) in production.
  """

  @behaviour PhxBackendBoilerplate.Files.Scanner

  @impl true
  def scan_file(_path), do: :clean
end
