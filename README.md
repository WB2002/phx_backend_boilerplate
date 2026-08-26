# PhxBackendBoilerplate

To start your Phoenix server:

* Run `docker compose up -d` to start Redis and Postgres (required for rate limiting and the database; Postgres is on host port `5433`)
* Optionally `docker compose --profile observability up -d` for LocalStack + OTel Collector + Jaeger (see Observability below)
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

`POST /api/demo/login` — **5 attempts/minute per IP**. On success returns `user_id` and a `socket_token` for the websocket:

```bash
curl -i -X POST http://localhost:4000/api/demo/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"password123"}'
```

Demo credentials: `demo@example.com` / `password123`. Identity: `user_id` `demo-user`.

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

`POST /api/demo/comments` — request DTO validation + HTML sanitization (**60/min per IP**). Successful creates also broadcast `comment_created` on PubSub topic `demo:lobby`:

```bash
curl -i -X POST http://localhost:4000/api/demo/comments \
  -H "Content-Type: application/json" \
  -d '{"title":"<b>Hi</b>","body":"<p>ok</p><script>alert(1)</script>","email":"demo@example.com","parent_id":1}'
```

Valid payloads return `200` with sanitized fields (`title` stripped of tags, `body` BasicHTML-scrubbed). Invalid payloads return `422` with `errors.fields`.

### WebSockets, PubSub, and socket auth

Reusable pieces:

| Module | Role |
| --- | --- |
| `PhxBackendBoilerplate.PubSub` | `subscribe/1`, `unsubscribe/1`, `broadcast/2` — tagged messages `{PhxBackendBoilerplate.PubSub, topic, payload}` |
| `PhxBackendBoilerplateWeb.SocketAuth` | `sign/1` / `verify/1` via `Phoenix.Token` (salt `"user socket"`, 24h) |
| `PhxBackendBoilerplateWeb.UserSocket` | Mounted at `/socket`; requires connect param `token` |
| `PhxBackendBoilerplateWeb.DemoChannel` | Topics under `demo:*` with join-time auth |

**Connect-time auth:** the websocket closes unless `token` verifies. **Join-time auth:**

| Topic | Rule |
| --- | --- |
| `demo:lobby` | Any authenticated socket |
| `demo:user:{id}` | Only when `id` equals `socket.assigns.current_user_id` |
| other `demo:*` | Rejected |

```bash
# 1. Mint a token
TOKEN=$(curl -s -X POST http://localhost:4000/api/demo/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"password123"}' \
  | jq -r '.data.socket_token')

# 2. Connect (query string works for wscat; phoenix.js uses params: {token})
#    ws://localhost:4000/socket/websocket?token=$TOKEN&vsn=2.0.0
```

Phoenix JS client:

```javascript
import {Socket} from "phoenix"

const socket = new Socket("/socket", {params: {token: socketToken}})
socket.connect()

const channel = socket.channel("demo:lobby", {})
channel.join()
  .receive("ok", () => console.log("joined lobby"))
  .receive("error", (resp) => console.log("join failed", resp))

channel.on("comment_created", (payload) => console.log(payload))
channel.push("ping", {hello: "world"})
  .receive("ok", (resp) => console.log("pong", resp))
```

Domain → channel fan-out:

```elixir
PhxBackendBoilerplate.PubSub.broadcast("demo:lobby", %{
  "event" => "comment_created",
  "title" => "Hi"
})
```

Use `PhxBackendBoilerplateWeb.Endpoint.broadcast/3` when you need Phoenix's built-in push to sockets already joined on a channel topic.

### Request DTOs, HTML sanitization, and injection hardening

JSON APIs use **Ecto embedded schemas** as request DTOs (the Phoenix equivalent of class-validator / Joi). Controllers validate with `PhxBackendBoilerplateWeb.Params.validate/2` and set `action_fallback PhxBackendBoilerplateWeb.FallbackController` for `422` field errors.

```elixir
defmodule MyAppWeb.Demo.CommentDTO do
  use Ecto.Schema
  import Ecto.Changeset
  alias PhxBackendBoilerplate.Sanitize

  @primary_key false
  embedded_schema do
    field :title, :string
    field :body, :string
    field :email, :string
    field :parent_id, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:title, :body, :email, :parent_id])
    |> validate_required([:title, :body, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> Sanitize.strip_tags(:title)  # plain text
    |> Sanitize.html(:body)         # BasicHTML allowlist
  end
end
```

**XSS / malicious HTML:** opt-in per field via `PhxBackendBoilerplate.Sanitize` (`html_sanitize_ex`). Do **not** strip HTML globally — that breaks passwords, tokens, and code. Apply `Sanitize.html/2` to rich text and `Sanitize.strip_tags/2` to titles/names that may contain pasted markup.

**SQL injection:** Ecto parameterizes queries. Protection is typed DTO fields (`:integer`, `:id`, `:binary_id`) plus bound parameters (`where(id == ^id)`). Do **not** scrub SQL keywords from strings, and never interpolate user input into SQL.

```elixir
# Good — bound parameter after DTO cast
from(c in Comment, where: c.id == ^dto.parent_id)

# Bad — never do this
Repo.query("SELECT * FROM comments WHERE id = #{user_input}")
```

### Feature flags (FunWithFlags)

Flags persist in Postgres (`fun_with_flags_toggles`), cache in ETS, and sync across nodes via `Phoenix.PubSub`. Prefer `PhxBackendBoilerplate.Flags` over calling `FunWithFlags` from controllers.

```elixir
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: PhxBackendBoilerplate.Repo

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: PhxBackendBoilerplate.PubSub
```

`FunWithFlags.Supervisor` starts in `Application` **after** PubSub (`runtime: false` on the dep avoids a PubSub race).

Demo flags:

| Flag | Gate | Demo route |
| --- | --- | --- |
| `:demo_preview` | Global boolean | `GET /api/demo/flags/preview` → `404` when off, `200` when on |
| `:demo_beta` | Per-guest actor | `GET /api/demo/flags/beta` → `403` when off, `200` when on for that guest |

`mix ecto.setup` / seeds enable `:demo_preview`. Toggle in IEx or the HTML UI at [`/dev/feature-flags`](http://localhost:4000/dev/feature-flags) (dev only, same as LiveDashboard).

```elixir
# IEx
FunWithFlags.enable(:demo_preview)
FunWithFlags.disable(:demo_preview)

guest = PhxBackendBoilerplate.Flags.guest("your-guest-uuid")
FunWithFlags.enable(:demo_beta, for_actor: guest)
```

```bash
# Global kill-switch / unreleased endpoint
curl -i http://localhost:4000/api/demo/flags/preview

# Per-guest beta (mint or pass X-Guest-Id)
curl -i http://localhost:4000/api/demo/flags/beta \
  -H "X-Guest-Id: 11111111-1111-1111-1111-111111111111"
```

Group and %-of-actors gates are supported by the library; add them when you need rollouts beyond these two demos.

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

## Observability (CloudWatch + X-Ray)

Production-shaped signals:

| Signal | Mechanism | Local without AWS credentials |
| --- | --- | --- |
| Logs | JSON stdout (`logger_json` in prod) + optional batched `PutLogEvents` | LocalStack Logs |
| Metrics | Existing `Telemetry.Metrics` via `telemetry_metrics_cloudwatch` | LocalStack CloudWatch |
| Traces | OpenTelemetry (Bandit/Phoenix/Ecto) + X-Ray IDs/propagator, OTLP export | OTel Collector → Jaeger (`:16686`). LocalStack X-Ray is **Pro-only** — not used |

### Environment variables

| Variable | Purpose | Example |
| --- | --- | --- |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (dummy `test`/`test` for LocalStack) | |
| `AWS_ENDPOINT_URL` | Custom ExAws endpoint (LocalStack) | `http://localhost:4566` |
| `CLOUDWATCH_LOGS_ENABLED` | Attach CloudWatch Logs Logger handler | `true` |
| `CLOUDWATCH_LOG_GROUP` | Log group name | `/phx-backend-boilerplate/dev` |
| `CLOUDWATCH_LOG_STREAM` | Optional stream name (default: host-pid) | |
| `CLOUDWATCH_METRICS_ENABLED` | Start CloudWatch metrics reporter | `true` |
| `CLOUDWATCH_METRICS_NAMESPACE` | Metric namespace | `PhxBackendBoilerplate` |
| `CLOUDWATCH_METRICS_PUSH_INTERVAL_MS` | Push interval (defaults to 5s with LocalStack, 60s otherwise) | `5000` |
| `OTEL_TRACES_ENABLED` | Install OTel instrumentation + OTLP export | `true` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector HTTP endpoint | `http://localhost:4318` |

On ECS/Fargate you can keep JSON logs on stdout (agent → CloudWatch) and leave `CLOUDWATCH_LOGS_ENABLED` off to avoid duplicate log groups. Point `OTEL_EXPORTER_OTLP_ENDPOINT` at an ADOT sidecar; the collector’s `awsxray` exporter sends to X-Ray.

### IAM (application / task role)

* `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`, `logs:DescribeLogStreams`
* `cloudwatch:PutMetricData`
* X-Ray permissions belong on the **collector/ADOT** role (`xray:PutTraceSegments`, `xray:PutTelemetryRecords`)

### Local verification (LocalStack + Jaeger)

```bash
docker compose --profile observability up -d

export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export CLOUDWATCH_LOGS_ENABLED=true
export CLOUDWATCH_METRICS_ENABLED=true
export CLOUDWATCH_LOG_GROUP=/phx-backend-boilerplate/dev
export OTEL_TRACES_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

mix observability.setup
mix phx.server
```

Generate traffic, then inspect:

```bash
aws --endpoint-url http://localhost:4566 logs filter-log-events \
  --log-group-name /phx-backend-boilerplate/dev

aws --endpoint-url http://localhost:4566 cloudwatch list-metrics \
  --namespace PhxBackendBoilerplate

# Traces: open http://localhost:16686 (Jaeger UI)
```

Tagged ExUnit tests (skipped by default):

```bash
AWS_ENDPOINT_URL=http://localhost:4566 mix test --only localstack
```

### HTTP streaming and SSE (native Plug)

No third-party streaming libraries — use `Plug.Conn.send_chunked/2` and `Plug.Conn.chunk/2`. The controller process owns the connection for the stream lifetime. These demos are on `:api_stream` (accepts `json`, `sse`, `ndjson`) so browser `EventSource` (`Accept: text/event-stream`) is not rejected with 406.

`GET /api/demo/stream/chunks` — newline-delimited JSON (`application/x-ndjson`). Optional `count` (default 3, max 10) and `interval_ms` (default 0, max 200):

```bash
curl -N "http://localhost:4000/api/demo/stream/chunks?count=3&interval_ms=100"
```

`GET /api/demo/stream/sse` — Server-Sent Events (`text/event-stream`) with `tick` events then `done`:

```bash
curl -N -H "Accept: text/event-stream" \
  "http://localhost:4000/api/demo/stream/sse?count=3&interval_ms=100"
```

For long-lived PubSub streams, keep the `receive`/`chunk` loop in the connection process and consider raising Bandit `idle_timeout` on the endpoint if connections stay open for minutes.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
* Regulator: https://hexdocs.pm/regulator
* Nebulex: https://hexdocs.pm/nebulex
* FunWithFlags: https://hexdocs.pm/fun_with_flags
