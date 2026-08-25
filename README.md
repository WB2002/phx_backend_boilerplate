# PhxBackendBoilerplate

To start your Phoenix server:

* Run `docker compose up -d` to start Redis and Postgres (required for rate limiting and the database; Postgres is on host port `5433`)
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Rate limiting and load shedding

This boilerplate uses two complementary gates:

```
REQUEST
   │
   ▼
Hammer (RateLimit) ── "Is this client allowed?" ──► 429 Too Many Requests
   │
   ▼
Regulator (LoadShed) ── "Can the system handle another concurrent request?" ──► 503 Service Unavailable
   │
   ▼
Controller / expensive work
```

| Gate | Library | Question | Typical HTTP |
| --- | --- | --- | --- |
| Fairness | [Hammer](https://hexdocs.pm/hammer) + Redis | Occurrences over time per client attribute | `429` |
| Capacity | [Regulator](https://hexdocs.pm/regulator) | Concurrent in-flight work for a named resource | `503` |

Hammer can still allow traffic when many distinct clients are each under their quota. Regulator sheds excess **concurrency** so your app (DB pool, CPU, downstream APIs) stays within capacity.

### Rate limiting (Hammer)

Counters are shared across nodes via Redis. Configure the Redis URL with `REDIS_URL` (defaults to `redis://localhost:6379` in dev, `redis://localhost:6379/1` in test). Production requires `REDIS_URL`.

#### Reusable plug

Rate limits are enforced as **independent** buckets per attribute. A request is denied if **any** configured bucket exceeds the limit.

```elixir
plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
  id: "demo_public",
  scale: :timer.minutes(1),
  limit: 5,
  by: [:ip, :guest_id, :fingerprint]
```

`:by` defaults to `[:ip]`. Allowed attributes:

| Attribute | Request source | Missing behavior |
| --- | --- | --- |
| `:ip` | `x-forwarded-for` (first IP) or `conn.remote_ip` | Always resolved |
| `:user_id` | `x-user-id` | Skip bucket |
| `:fingerprint` | `x-device-fingerprint` | Skip bucket |
| `:guest_id` | `conn.assigns.guest_id`, `x-guest-id`, or `guest_id` cookie | Skip unless minted |

Keys look like `"#{id}:#{attr}:#{value}"`. Over-limit requests get `429` with a `Retry-After` header.

### Guest ID (public APIs only)

Use `PhxBackendBoilerplateWeb.Plugs.EnsureGuestId` on the **`:api_public`** pipeline (not on authenticated routes). It:

* Prefers `x-guest-id`, then the `guest_id` cookie, otherwise mints a UUID
* Sets `conn.assigns.guest_id`, response header `x-guest-id`, and an HttpOnly `guest_id` cookie (SameSite=Lax)

### Load shedding (Regulator)

Named limiters are installed at boot by `PhxBackendBoilerplate.LoadShed` from config:

```elixir
config :phx_backend_boilerplate, PhxBackendBoilerplate.LoadShed,
  regulators: [
    demo_expensive: {Regulator.Limit.Static, [limit: 2]},
    # Production-style adaptive limit for a heavy resource class:
    # reports: {Regulator.Limit.AIMD, [timeout: 200, min_limit: 5, max_limit: 100]}
  ]
```

Wire a limiter on expensive pipelines **after** Hammer:

```elixir
plug PhxBackendBoilerplateWeb.Plugs.RateLimit, id: "demo_expensive", scale: :timer.minutes(1), limit: 60, by: [:ip]
plug PhxBackendBoilerplateWeb.Plugs.LoadShed, regulator: :demo_expensive
```

Do **not** put one global regulator on every endpoint. Prefer separate names per expensive class (`:reports`, `:provider_x`). Cheap GETs can stay unregulated.

For outbound work (Req, etc.), wrap the call with the same named limiter:

```elixir
case Regulator.ask(:provider_x, fn ->
       case Req.get(url) do
         {:ok, %{status: status}} when status < 500 -> {:ok, :ok}
         _ -> {:error, :upstream}
       end
     end) do
  :dropped -> {:error, :overloaded}
  result -> result
end
```

The demo limiter uses `Static` with limit `2` so parallel curls can actually get `503`. For AIMD/Gradient in production, set `timeout` / `target_avg_latency` to the SLO of that resource class (defaults are far too low for typical HTTP handlers).

### Demo endpoints

`POST /api/demo/login` — **5 attempts/minute per IP**:

```bash
curl -i -X POST http://localhost:4000/api/demo/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"password123"}'
```

Demo credentials: `demo@example.com` / `password123`.

`GET /api/demo/public` — public pipeline with guest minting; **5 requests/minute** across IP, guest_id, and fingerprint buckets:

```bash
curl -i http://localhost:4000/api/demo/public \
  -H "X-Device-Fingerprint: my-device-fp"
```

`GET /api/demo/expensive` — Hammer (60/min per IP) then Regulator (`:demo_expensive`, Static concurrency **2**). Optional `hold_ms` (capped at 5000) keeps the concurrency token while sleeping so you can force load shedding:

```bash
# Hold two slots, then a third request should 503
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:4000/api/demo/expensive?hold_ms=5000" &
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:4000/api/demo/expensive?hold_ms=5000" &
sleep 0.2
curl -i "http://localhost:4000/api/demo/expensive?hold_ms=5000"
```

Expect two `200` responses and one `503` with `{"errors":{"detail":"Service Unavailable"}}`.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
* Regulator: https://hexdocs.pm/regulator
