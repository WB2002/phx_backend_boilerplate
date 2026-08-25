defmodule PhxBackendBoilerplateWeb.Demo.SessionController do
  @moduledoc """
  Demo login endpoint used to illustrate Redis rate limiting.

  Valid credentials (hardcoded for the example):

    * email: `demo@example.com`
    * password: `password123`
  """

  use PhxBackendBoilerplateWeb, :controller

  @demo_email "demo@example.com"
  @demo_password "password123"

  def create(conn, params) do
    email = Map.get(params, "email") || Map.get(params, :email)
    password = Map.get(params, "password") || Map.get(params, :password)

    if email == @demo_email and password == @demo_password do
      json(conn, %{data: %{message: "Logged in", email: email}})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: %{detail: "Invalid email or password"}})
    end
  end
end
