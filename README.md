# PhxBackendBoilerplate

To start your Phoenix server:

* Run `docker compose up -d` to start Redis and Postgres (required for rate limiting and the database; Postgres is on host port `5433`)
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Rate limiting, load shedding, and deadlines

This boilerplate uses three complementary controls:

```
REQUEST
   │
   ▼
Deadline ── "How much time does this work have left?" ──► 504 Gateway Timeout
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
| Time budget | `PhxBackendBoilerplate.Deadline` | Remaining request budget | `504` |
| Fairness | [Hammer](https://hexdocs.pm/hammer) + Redis | Occurrences over time per client attribute | `429` |
| Capacity | [Regulator](https://hexdocs.pm/regulator) | Concurrent in-flight work for a named resource | `503` |

Hammer can still allow traffic when many distinct clients are each under their quota. Regulator sheds excess **concurrency** so your app (DB pool, CPU, downstream APIs) stays within capacity. Deadline bounds how long any allowed work may run.

### Request deadlines

At the Phoenix edge (`PhxBackendBoilerplateWeb.Plugs.Deadline` on `:api` / `:api_public`), each request gets a local **monotonic** deadline. Default budget is `15_000` ms:

```elixir
config :phx_backend_boilerplate, PhxBackendBoilerplate.Deadline, timeout: 15_000
```

Override per pipeline: `plug PhxBackendBoilerplateWeb.Plugs.Deadline, timeout: 2_000`.

**HTTP propagation** uses remaining budget, not wall-clock time:

* Outbound: `PhxBackendBoilerplate.HTTP` adds `x-request-timeout-ms: <remaining>`
* Inbound: the plug parses that header, caps with the local timeout, and installs a new monotonic deadline
* Malformed headers are ignored (full local budget). Valid `0` means the budget is already exhausted → **504**
* Network transit time is not subtracted; a few milliseconds of inflation in flight is accepted

**Process propagation:** the process dictionary is **not** inherited by spawned processes. Capture the deadline in the parent and wrap the **child** body:

```elixir
deadline = PhxBackendBoilerplate.Deadline.current()

Task.async(fn ->
  PhxBackendBoilerplate.Deadline.with(deadline, fn ->
    do_work()
  end)
end)
```

Or use `PhxBackendBoilerplate.Deadline.async/1`, which does that for you. The same pattern applies to `Task.Supervisor`.

Outbound HTTP through `PhxBackendBoilerplate.HTTP` automatically caps `receive_timeout` and maps deadline-limited timeouts to `{:error, :deadline_exceeded}`. When remaining equals the configured timeout, that counts as deadline exhaustion (not a dependency failure).

**Circuit breaker:** dependency failures (transport errors, 5xx, 408, 429) melt the breaker and may retry. Caller-imposed `{:error, :deadline_exceeded}` and typical 4xx do **not**. Classification in `Integrations.through_req/1` handles `:deadline_exceeded` **before** generic transport retry. Integration clients should use `Integrations.sleep_respecting_deadline/1` as ExternalService `:sleep_function` so backoff cannot outlive the budget.

**Ecto (known limitation):** this pass does **not** auto-wire Repo timeouts. A query can run past the deadline, hold a pool checkout, and yield a discarded result — under load that can exhaust the pool. On deadline-sensitive paths, pass `timeout: Deadline.remaining()` (or skip the query if `Deadline.expired?()`) until a follow-up wires this automatically.

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

### SWR cache (Nebulex + coalescing + stampede protection)

`PhxBackendBoilerplate.SWR.fetch/3` wraps expensive loaders with:

* **Multilevel cache** — L1 local ETS + L2 Redis (same `REDIS_URL` as Hammer)
* **Soft / hard TTLs** — after soft TTL, serve stale immediately and refresh in the background (SWR); Nebulex hard TTL evicts the key
* **Per-node coalescing** — concurrent misses on one VM share one loader
* **Cluster stampede locks** — Redis `put_new` on `swr:lock:<key>`; losers poll L2 (no lock retry)
* **Split hard TTLs** — writes are `L2.put` then `L1.put` with `l1_hard_ttl < l2_hard_ttl` so other nodes miss L1 sooner and see refreshed L2 (per-node eventual consistency; no PubSub invalidation in v1)

```elixir
config :phx_backend_boilerplate, PhxBackendBoilerplate.SWR,
  soft_ttl: :timer.seconds(30),
  l1_hard_ttl: :timer.minutes(2),
  l2_hard_ttl: :timer.minutes(5),
  lock_ttl: 8_000,
  early_refresh_window: 5_000
```

Keys must be strings. Cache only serializable values (maps/lists/primitives), not Ecto graphs. Opt in at call sites — integrations are not auto-wrapped.

`GET /api/demo/cached` — rate-limited; optional `key` and `work_ms` (capped at **2000**). Demo TTLs: soft 2s, L1 hard 5s, L2 hard 15s.

```bash
# Cold miss — one shared origin sleep under parallel load
curl -s "http://localhost:4000/api/demo/cached?key=widget&work_ms=500" &
curl -s "http://localhost:4000/api/demo/cached?key=widget&work_ms=500" &
wait

# After soft TTL (~2s), responses stay fast with "freshness":"stale"
sleep 3
curl -s "http://localhost:4000/api/demo/cached?key=widget&work_ms=500"
```

LiveDashboard metrics include SWR fetch freshness, lock contended, refresh errors, and Nebulex command duration.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
* Regulator: https://hexdocs.pm/regulator
* Nebulex: https://hexdocs.pm/nebulex
