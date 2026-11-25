defmodule PhxBackendBoilerplate.Property.InvariantsPropertyTest do
  use ExUnit.Case, async: true

  @moduletag :property

  alias PhxBackendBoilerplate.Crypto.Envelope
  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.Sanitize

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
    :ok
  end

  test "deadline capping property: effective budget never exceeds server cap or client header" do
    :rand.seed(:exsss, {101, 202, 303})

    for _trial <- 1..250 do
      server_cap_ms = :rand.uniform(30_000)
      client_budget_ms = :rand.uniform(60_000) - 1

      conn = %{req_headers: [{"x-request-timeout-ms", Integer.to_string(client_budget_ms)}]}
      :ok = Deadline.start_from_conn(conn, server_cap_ms)

      remaining_ms = Deadline.remaining()
      expected_upper_bound = min(server_cap_ms, client_budget_ms)

      assert is_integer(remaining_ms)
      assert remaining_ms >= 0
      assert remaining_ms <= expected_upper_bound
    end
  end

  test "deadline header parsing property: negative or non-numeric values are always rejected" do
    :rand.seed(:exsss, {404, 505, 606})

    for _trial <- 1..250 do
      negative_ms = -:rand.uniform(100_000)

      assert Deadline.from_headers([{"x-request-timeout-ms", Integer.to_string(negative_ms)}]) ==
               nil

      garbage = "ms_" <> Base.encode16(:crypto.strong_rand_bytes(6))
      assert Deadline.from_headers([{"x-request-timeout-ms", garbage}]) == nil
    end
  end

  test "HTML sanitization property: script tags are removed and strip_tags is idempotent" do
    :rand.seed(:exsss, {707, 808, 909})

    fragments = [
      "hello world",
      "<script>alert(1)</script>",
      "<img src=x onerror=alert(1)>",
      "<a href=\"javascript:alert(1)\">click</a>",
      "<p>safe <strong>text</strong></p>",
      "plain &amp; simple"
    ]

    for _trial <- 1..150 do
      chosen_count = :rand.uniform(4)

      raw_input =
        Enum.map_join(1..chosen_count, " ", fn _index ->
          Enum.at(fragments, :rand.uniform(length(fragments)) - 1)
        end)

      changeset =
        {%{body: nil}, %{body: :string}}
        |> Ecto.Changeset.cast(%{body: raw_input}, [:body])

      sanitized_html =
        changeset
        |> Sanitize.html(:body)
        |> Ecto.Changeset.get_change(:body)

      refute String.downcase(sanitized_html) =~ "<script"
      refute String.downcase(sanitized_html) =~ "onerror="
      refute String.downcase(sanitized_html) =~ "javascript:"

      stripped_once =
        changeset
        |> Sanitize.strip_tags(:body)
        |> Ecto.Changeset.get_change(:body)

      stripped_twice =
        {%{body: nil}, %{body: :string}}
        |> Ecto.Changeset.cast(%{body: stripped_once}, [:body], empty_values: [])
        |> Sanitize.strip_tags(:body)
        |> Ecto.Changeset.get_change(:body)

      assert String.trim(stripped_once) == String.trim(stripped_twice)
    end
  end

  test "envelope encryption property: round-trip preserves arbitrary bytes with distinct ciphertexts" do
    :rand.seed(:exsss, {111, 222, 333})

    for _trial <- 1..50 do
      byte_len = :rand.uniform(512) - 1
      plaintext = :crypto.strong_rand_bytes(byte_len)

      assert {:ok, ciphertext_one} = Envelope.seal(plaintext, context: %{"purpose" => "property"})
      assert {:ok, ciphertext_two} = Envelope.seal(plaintext, context: %{"purpose" => "property"})

      assert ciphertext_one != ciphertext_two
      assert {:ok, ^plaintext} = Envelope.open(ciphertext_one)
      assert {:ok, ^plaintext} = Envelope.open(ciphertext_two)
    end
  end
end
