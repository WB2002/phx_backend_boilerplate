defmodule PhxBackendBoilerplate.RecaptchaTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Recaptcha

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, Recaptcha, [])

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Recaptcha, previous)
    end)

    :ok
  end

  test "skip: true always returns :ok without calling Google" do
    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: true,
      adapter: PhxBackendBoilerplate.Recaptcha.Google,
      secret_key: "unused"
    )

    assert Recaptcha.verify(nil) == :ok
    assert Recaptcha.verify("") == :ok
  end

  test "missing token fails when not skipped" do
    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Fake,
      secret_key: "test"
    )

    assert Recaptcha.verify(nil) == {:error, :missing_token}
    assert Recaptcha.verify("") == {:error, :missing_token}
  end

  test "Google adapter accepts success with score above min" do
    stub_name = :"recaptcha_ok_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      assert conn.method == "POST"
      Req.Test.json(conn, %{"success" => true, "score" => 0.9})
    end)

    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Google,
      secret_key: "test-secret",
      min_score: 0.5,
      siteverify_url: "https://www.google.com/recaptcha/api/siteverify",
      req_options: [plug: {Req.Test, stub_name}]
    )

    assert Recaptcha.verify("valid-token") == :ok
  end

  test "Google adapter rejects low score" do
    stub_name = :"recaptcha_low_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.json(conn, %{"success" => true, "score" => 0.1})
    end)

    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Google,
      secret_key: "test-secret",
      min_score: 0.5,
      siteverify_url: "https://www.google.com/recaptcha/api/siteverify",
      req_options: [plug: {Req.Test, stub_name}]
    )

    assert Recaptcha.verify("token") == {:error, :low_score}
  end

  test "Google adapter maps non-200 to :http_error" do
    stub_name = :"recaptcha_500_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.text("error")
    end)

    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Google,
      secret_key: "test-secret",
      min_score: 0.5,
      siteverify_url: "https://www.google.com/recaptcha/api/siteverify",
      req_options: [plug: {Req.Test, stub_name}]
    )

    assert Recaptcha.verify("token") == {:error, :http_error}
  end

  test "Fake adapter respects configured result" do
    Application.put_env(:phx_backend_boilerplate, Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Fake,
      secret_key: "test"
    )

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
      result: {:error, :verification_failed}
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
        result: :ok
      )
    end)

    assert Recaptcha.verify("token") == {:error, :verification_failed}
  end
end
