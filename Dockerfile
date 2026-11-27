# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1: Builder
# =============================================================================
FROM elixir:otp-27-slim@sha256:4b347e1107b4530c1722afbbcd7d908995557ec9188f2fe362c04d407ddcdd63 AS builder

# Install build dependencies for C-NIFs (argon2) and git dependencies
# hadolint ignore=DL3008
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN --mount=type=cache,target=/root/.hex \
    mix deps.get --only prod

# Copy compile-time configs
COPY config/config.exs config/prod.exs config/redaction_keys.exs config/

# Compile dependencies
RUN --mount=type=cache,target=/root/.hex \
    mix deps.compile

# Copy application assets and source code
COPY assets assets
COPY priv priv
COPY lib lib
COPY rel rel
COPY config/runtime.exs config/

# Compile application code, build assets, and package release
RUN mix compile && \
    mix assets.deploy && \
    mix release && \
    rm -f /app/_build/prod/rel/phx_backend_boilerplate/releases/COOKIE

# =============================================================================
# Stage 2: Minimal Hardened Runtime
# =============================================================================
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS runtime

# Install minimal shared runtime libraries (no compilers, git, curl, or dev packages)
# hadolint ignore=DL3005,DL3008
RUN apt-get update -y && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Strip setuid/setgid bits across the image filesystem
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

# Create unprivileged runtime user and group (10001:10001) without shell access
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /usr/sbin/nologin -M -d /app appuser

WORKDIR /app

# Copy compiled release with root ownership; revoke non-root write access for immutability
COPY --from=builder --chown=root:root --chmod=0755 /app/_build/prod/rel/phx_backend_boilerplate /app
RUN chmod -R go-w /app

# Runtime environment settings
ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    RELEASE_TMP=/tmp \
    ERL_CRASH_DUMP=/tmp/erl_crash.dump \
    HOME=/tmp

# Switch to unprivileged non-root user
USER 10001:10001

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD ["/app/bin/healthcheck"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/app/bin/server"]
