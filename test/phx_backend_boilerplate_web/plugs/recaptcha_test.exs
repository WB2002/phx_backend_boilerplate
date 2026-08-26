defmodule PhxBackendBoilerplateWeb.Plugs.RecaptchaTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.Plugs.Recaptcha

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha, [])

    fake_previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake, [])

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha,
      skip: false,
      adapter: PhxBackendBoilerplate.Recaptcha.Fake,
      secret_key: "test-secret",
      min_score: 0.5
    )

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
      result: :ok
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha, previous)

      Application.put_env(
        :phx_backend_boilerplate,
        PhxBackendBoilerplate.Recaptcha.Fake,
        fake_previous
      )
    end)

    :ok
  end

  test "allows request when Fake returns :ok" do
    conn =
      build_conn(:post, "/api/demo/login", %{"recaptcha_token" => "ok"})
      |> Map.put(:params, %{"recaptcha_token" => "ok"})
      |> Recaptcha.call([])

    refute conn.halted
  end

  test "halts with 403 when verification fails" do
    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
      result: {:error, :verification_failed}
    )

    conn =
      build_conn(:post, "/api/demo/login", %{"recaptcha_token" => "bad"})
      |> Map.put(:params, %{"recaptcha_token" => "bad"})
      |> Recaptcha.call([])

    assert conn.halted
    assert conn.status == 403

    assert Jason.decode!(conn.resp_body) == %{
             "errors" => %{"detail" => "reCAPTCHA verification failed"}
           }
  end

  test "halts with 403 when token is missing" do
    conn =
      build_conn(:post, "/api/demo/login", %{})
      |> Map.put(:params, %{})
      |> Recaptcha.call([])

    assert conn.halted
    assert conn.status == 403
  end
end
