# PhxBackendBoilerplate

To start your Phoenix server:

* Run `docker compose up -d` to start Redis and Postgres (required for rate limiting and the database; Postgres is on host port `5433`)
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Rate limiting

This boilerplate uses [Hammer](https://hexdocs.pm/hammer) with the [Redis backend](https://hexdocs.pm/hammer_backend_redis) for rate limiting. Counters are shared across nodes via Redis.

Configure the Redis URL with `REDIS_URL` (defaults to `redis://localhost:6379` in dev, `redis://localhost:6379/1` in test). Production requires `REDIS_URL`.

### Reusable plug

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

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
