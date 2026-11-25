defmodule PhxBackendBoilerplate.Contracts.ApiContractTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  @moduletag :contract

  import PhxBackendBoilerplateWeb.GraphqlCase

  alias PhxBackendBoilerplateWeb.Graphql.Schema

  @manifest_path Path.expand("../../boilerplate.manifest.json", __DIR__)

  test "boilerplate.manifest.json satisfies the polyglot conformance manifest contract" do
    raw_manifest = File.read!(@manifest_path)
    manifest = Jason.decode!(raw_manifest)

    assert manifest["name"] == "phx-backend-boilerplate"
    assert manifest["language"] == "elixir"

    capabilities = Map.fetch!(manifest, "capabilities")
    assert get_in(capabilities, ["health", "method"]) == "GET"
    assert get_in(capabilities, ["health", "path"]) == "/health"

    assert get_in(capabilities, ["auth", "register", "path"]) == "/api/auth/register"
    assert get_in(capabilities, ["auth", "login", "path"]) == "/api/auth/login"
    assert get_in(capabilities, ["auth", "me", "path"]) == "/api/auth/me"
    assert get_in(capabilities, ["auth", "refresh", "path"]) == "/api/auth/refresh"
    assert get_in(capabilities, ["websockets", "enabled"]) == true
  end

  test "Absinthe GraphQL schema exposes required root operations" do
    query_type = Absinthe.Schema.lookup_type(Schema, :query)
    mutation_type = Absinthe.Schema.lookup_type(Schema, :mutation)
    subscription_type = Absinthe.Schema.lookup_type(Schema, :subscription)

    assert Map.has_key?(query_type.fields, :ping)
    assert Map.has_key?(query_type.fields, :hello)
    assert Map.has_key?(query_type.fields, :echoes)
    assert Map.has_key?(mutation_type.fields, :echo)
    assert Map.has_key?(subscription_type.fields, :echoed)
  end

  test "GraphQL HTTP endpoint enforces authentication and returns expected payload shape" do
    unauth_conn =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")
      |> graphql_post("{ ping }")

    assert json_response(unauth_conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}

    {auth_conn, _auth_session} = authenticated_graphql_conn()
    ok_conn = graphql_post(auth_conn, "{ ping hello }")

    assert json_response(ok_conn, 200) == %{
             "data" => %{
               "ping" => "pong",
               "hello" => "Hello, world!"
             }
           }
  end

  test "health probe contract returns minimal ok payload without leaking internals", %{conn: conn} do
    probe_conn = get(conn, ~p"/health")
    body = json_response(probe_conn, 200)

    assert body == %{"status" => "ok"}
    refute Map.has_key?(body, "system_stats")
    refute Map.has_key?(body, "version")
  end
end
