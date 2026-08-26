defmodule PhxBackendBoilerplateWeb.DemoChannel do
  @moduledoc """
  Demo channel illustrating join-time authorization and PubSub fan-in.

  Topics:

    * `demo:lobby` — any authenticated socket
    * `demo:user:{id}` — only when `id` matches `socket.assigns.current_user_id`
    * anything else under `demo:` — rejected

  On join, subscribes via `PhxBackendBoilerplate.PubSub`. Domain broadcasts
  arrive as `{PhxBackendBoilerplate.PubSub, topic, payload}` and are pushed
  to the client as the payload's `"event"` key (default `"msg"`).
  """

  use PhxBackendBoilerplateWeb, :channel

  alias PhxBackendBoilerplate.PubSub

  @impl true
  def join("demo:lobby", _payload, socket) do
    :ok = PubSub.subscribe("demo:lobby")
    {:ok, socket}
  end

  def join("demo:user:" <> user_id, _payload, socket) do
    if user_id == socket.assigns.current_user_id do
      topic = "demo:user:" <> user_id
      :ok = PubSub.subscribe(topic)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("demo:" <> _rest, _payload, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  @impl true
  def handle_info({PubSub, _topic, payload}, socket) when is_map(payload) do
    event = Map.get(payload, "event") || Map.get(payload, :event) || "msg"
    push(socket, to_string(event), payload)
    {:noreply, socket}
  end

  def handle_info({PubSub, _topic, payload}, socket) do
    push(socket, "msg", %{payload: payload})
    {:noreply, socket}
  end
end
