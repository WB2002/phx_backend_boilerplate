defmodule PhxBackendBoilerplate.Integrations.Stripe.SignatureTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Integrations.Stripe.Signature

  @secret "whsec_test_secret"
  @payload ~s({"id":"evt_test","type":"checkout.session.completed"})

  test "verify/3 accepts a valid signature" do
    now = 1_700_000_000
    header = sign(@payload, @secret, now)

    assert :ok = Signature.verify(@payload, header, secret: @secret, now: now)
  end

  test "verify/3 rejects missing header" do
    assert {:error, :missing_header} = Signature.verify(@payload, nil, secret: @secret)
  end

  test "verify/3 rejects invalid signature" do
    now = 1_700_000_000
    header = sign(@payload, "wrong-secret", now)

    assert {:error, :invalid_signature} =
             Signature.verify(@payload, header, secret: @secret, now: now)
  end

  test "verify/3 rejects expired timestamp" do
    now = 1_700_000_000
    old = now - 600
    header = sign(@payload, @secret, old)

    assert {:error, :timestamp_out_of_tolerance} =
             Signature.verify(@payload, header, secret: @secret, now: now, tolerance: 300)
  end

  defp sign(payload, secret, timestamp) do
    signature =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end
end
