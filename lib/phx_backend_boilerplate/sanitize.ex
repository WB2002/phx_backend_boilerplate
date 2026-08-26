defmodule PhxBackendBoilerplate.Sanitize do
  @moduledoc """
  Opt-in HTML sanitization for Ecto changesets.

  Call these helpers on specific fields after `cast/3`. Do **not** apply them
  globally to passwords, tokens, or other opaque strings.

  * `html/2` — BasicHTML allowlist (`p`, `a`, `strong`, …). Drops `script`,
    event handlers, and non-http(s)/mailto URIs.
  * `strip_tags/2` — removes all tags; keeps text content.
  """

  import Ecto.Changeset

  @doc """
  Sanitizes `field` with `HtmlSanitizeEx.basic_html/1` when the change is a binary.
  """
  def html(changeset, field) when is_atom(field) do
    update_change(changeset, field, &sanitize_html/1)
  end

  @doc """
  Strips all HTML tags from `field` when the change is a binary.
  """
  def strip_tags(changeset, field) when is_atom(field) do
    update_change(changeset, field, &strip_all_tags/1)
  end

  defp sanitize_html(value) when is_binary(value), do: HtmlSanitizeEx.basic_html(value)
  defp sanitize_html(value), do: value

  defp strip_all_tags(value) when is_binary(value), do: HtmlSanitizeEx.strip_tags(value)
  defp strip_all_tags(value), do: value
end
