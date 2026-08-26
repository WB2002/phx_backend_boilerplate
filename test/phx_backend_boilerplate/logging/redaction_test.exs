defmodule PhxBackendBoilerplate.Logging.RedactionTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Logging.Redaction

  test "keys/0 is the union of redacted and pii" do
    keys = Redaction.keys()

    assert "password" in keys
    assert "email" in keys
    refute "user_id" in keys
    refute "request_id" in keys
    refute "correlation_id" in keys
  end

  test "redactors/0 wires LoggerJSON.RedactKeys" do
    assert [{LoggerJSON.Redactors.RedactKeys, keys}] = Redaction.redactors()
    assert keys == Redaction.keys()
  end

  test "redact/1 replaces matching atom and string keys" do
    assert Redaction.redact(%{"email" => "a@b.com", password: "secret", user_id: "u-1"}) == %{
             "email" => "[REDACTED]",
             password: "[REDACTED]",
             user_id: "u-1"
           }
  end

  test "redact/1 walks nested maps, keywords, and lists" do
    input = %{
      user: [email: "a@b.com", id: 1],
      nested: %{"password" => "x", "ok" => true},
      items: [%{token: "t"}, %{name: "keep"}]
    }

    assert Redaction.redact(input) == %{
             user: [email: "[REDACTED]", id: 1],
             nested: %{"password" => "[REDACTED]", "ok" => true},
             items: [%{token: "[REDACTED]"}, %{name: "keep"}]
           }
  end

  test "redact/1 leaves structs intact" do
    uri = URI.parse("https://example.com/path")
    assert Redaction.redact(%{uri: uri, password: "x"}) == %{uri: uri, password: "[REDACTED]"}
    assert Redaction.redact(uri) == uri
  end
end
