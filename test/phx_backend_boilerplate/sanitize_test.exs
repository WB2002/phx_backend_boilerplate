defmodule PhxBackendBoilerplate.SanitizeTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias PhxBackendBoilerplate.Sanitize

  defmodule Sample do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :title, :string
      field :body, :string
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:title, :body])
    end
  end

  test "html/2 keeps basic markup and removes script tags" do
    changeset =
      Sample.changeset(%{
        "body" => "<p>ok</p><script>alert(1)</script>"
      })
      |> Sanitize.html(:body)

    body = get_change(changeset, :body)
    assert body =~ "<p>ok</p>"
    refute body =~ "<script"
    refute body =~ "</script>"
  end

  test "html/2 strips javascript URLs and event-handler attributes" do
    malicious = ~s|<a href="javascript:alert(1)" onclick="evil()">click</a>|

    changeset =
      Sample.changeset(%{"body" => malicious})
      |> Sanitize.html(:body)

    body = get_change(changeset, :body)
    refute String.contains?(body, "javascript:")
    refute body =~ "onclick"
    assert body =~ "click"
  end

  test "html/2 removes img onerror payloads" do
    malicious = ~s|<img src=x onerror="alert(1)">|

    changeset =
      Sample.changeset(%{"body" => malicious})
      |> Sanitize.html(:body)

    body = get_change(changeset, :body)
    refute body =~ "onerror"
  end

  test "strip_tags/2 removes all markup and keeps text" do
    changeset =
      Sample.changeset(%{"title" => "<b>Hi</b>"})
      |> Sanitize.strip_tags(:title)

    assert get_change(changeset, :title) == "Hi"
  end

  test "helpers leave non-string changes untouched" do
    changeset =
      %Sample{}
      |> change(%{title: nil})
      |> Sanitize.strip_tags(:title)

    assert get_change(changeset, :title) == nil
  end
end
