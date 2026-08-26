defmodule PhxBackendBoilerplateWeb.Demo.SessionController do
  @moduledoc """
  Demo login endpoint used to illustrate Redis rate limiting and socket tokens.

  Valid credentials (hardcoded for the example):

    * email: `demo@example.com`
    * password: `password123`

  On success, returns a `socket_token` signed by `PhxBackendBoilerplateWeb.SocketAuth`
  for connecting to `PhxBackendBoilerplateWeb.UserSocket`.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplateWeb.SocketAuth

  @demo_email "demo@example.com"
  @demo_password "password123"
  @demo_user_id "demo-user"

  def create(conn, params) do
    email = Map.get(params, "email") || Map.get(params, :email)
    password = Map.get(params, "password") || Map.get(params, :password)

    if email == @demo_email and password == @demo_password do
      socket_token =
        SocketAuth.sign(%{"sub" => @demo_user_id, "email" => email})

      json(conn, %{
        data: %{
          message: "Logged in",
          email: email,
          user_id: @demo_user_id,
          socket_token: socket_token
        }
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: %{detail: "Invalid email or password"}})
    end
  end
end
