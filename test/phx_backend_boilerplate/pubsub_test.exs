defmodule PhxBackendBoilerplate.PubSubTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.PubSub

  test "subscribe and broadcast deliver a tagged message" do
    topic = "test:pubsub:#{System.unique_integer([:positive])}"
    payload = %{"hello" => "world"}

    assert :ok = PubSub.subscribe(topic)
    assert :ok = PubSub.broadcast(topic, payload)

    assert_receive {PubSub, ^topic, ^payload}
  end

  test "unsubscribe stops receiving broadcasts" do
    topic = "test:pubsub:#{System.unique_integer([:positive])}"

    assert :ok = PubSub.subscribe(topic)
    assert :ok = PubSub.unsubscribe(topic)
    assert :ok = PubSub.broadcast(topic, %{})

    refute_receive {PubSub, ^topic, _}, 100
  end

  test "broadcast! delivers the same tagged message" do
    topic = "test:pubsub:#{System.unique_integer([:positive])}"
    payload = :ok_payload

    assert :ok = PubSub.subscribe(topic)
    assert :ok = PubSub.broadcast!(topic, payload)

    assert_receive {PubSub, ^topic, ^payload}
  end

  test "rejects oversized broadcast payloads" do
    topic = "test:pubsub:#{System.unique_integer([:positive])}"
    payload = String.duplicate("a", PubSub.max_payload_bytes() + 1)

    assert {:error, :payload_too_large} = PubSub.broadcast(topic, payload)

    assert_raise ArgumentError, fn ->
      PubSub.broadcast!(topic, payload)
    end
  end
end
