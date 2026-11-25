defmodule PhxBackendBoilerplate.SemgrepFixtures.ObfuscatedExfil do
  @moduledoc false

  def bad_shell_exec(command) do
    # ruleid: elixir.obfuscated-exfil.shell-cmd
    _ = :os.cmd(String.to_charlist(command))
    # ruleid: elixir.obfuscated-exfil.shell-cmd
    _ = System.shell(command)
    # ruleid: elixir.obfuscated-exfil.shell-cmd
    _ = System.cmd("sh", ["-c", command])
    # ruleid: elixir.obfuscated-exfil.shell-cmd
    _ = System.cmd("bash", ["-c", command])
  end

  def ok_direct_exec do
    # ok: elixir.obfuscated-exfil.shell-cmd
    System.cmd("elixir", ["--version"])
  end

  def bad_base64_exec(encoded) do
    # ruleid: elixir.obfuscated-exfil.base64-to-exec
    decoded = Base.decode64!(encoded)
    System.cmd("echo", [decoded])
  end

  def bad_base64_eval(encoded) do
    # ruleid: elixir.obfuscated-exfil.base64-to-exec
    decoded = Base.decode64!(encoded)
    Code.eval_string(decoded)
  end

  def bad_env_exfil(endpoint) do
    # ruleid: elixir.obfuscated-exfil.env-exfil-http
    env_vars = System.get_env()
    Req.post(endpoint, json: env_vars)
  end
end
