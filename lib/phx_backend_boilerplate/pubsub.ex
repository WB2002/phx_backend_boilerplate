defmodule PhxBackendBoilerplate.PubSub do
  @moduledoc """
  Thin wrapper around the application's `Phoenix.PubSub` server.

  The OTP child is started as `{Phoenix.PubSub, name: PhxBackendBoilerplate.PubSub}`;
  this module uses the same atom as the server name (Phoenix convention).

  Broadcast messages are tagged as `{PhxBackendBoilerplate.PubSub, topic, payload}`
  so receivers can pattern-match without colliding with other `handle_info` traffic.

  For Phoenix Channel fan-out to sockets already joined on a topic, prefer
  `PhxBackendBoilerplateWeb.Endpoint.broadcast/3`.
  """

  @server __MODULE__

  @type topic :: Phoenix.PubSub.topic()
  @type payload :: term()
  @type message :: {__MODULE__, topic(), payload()}

  @doc """
  Subscribes the calling process to `topic`.
  """
  @spec subscribe(topic()) :: :ok | {:error, term()}
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(@server, topic)
  end

  @doc """
  Unsubscribes the calling process from `topic`.
  """
  @spec unsubscribe(topic()) :: :ok
  def unsubscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.unsubscribe(@server, topic)
  end

  @doc """
  Broadcasts a tagged message to all subscribers of `topic`.

  Subscribers receive `{PhxBackendBoilerplate.PubSub, topic, payload}`.
  """
  @spec broadcast(topic(), payload()) :: :ok | {:error, term()}
  def broadcast(topic, payload) when is_binary(topic) do
    Phoenix.PubSub.broadcast(@server, topic, {__MODULE__, topic, payload})
  end

  @doc """
  Same as `broadcast/2` but raises on failure.
  """
  @spec broadcast!(topic(), payload()) :: :ok
  def broadcast!(topic, payload) when is_binary(topic) do
    Phoenix.PubSub.broadcast!(@server, topic, {__MODULE__, topic, payload})
  end
end
