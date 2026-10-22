#!/bin/bash
set -euo pipefail

# Ensure PATH includes standard docker binaries
for p in /usr/local/bin /Applications/Docker.app/Contents/Resources/bin /opt/homebrew/bin "$HOME/.local/bin"; do
  if [ -d "$p" ]; then
    export PATH="$p:$PATH"
  fi
done

IMAGE="${1:-phx_backend_boilerplate:verify}"
NET_NAME="verify-net-$(openssl rand -hex 4)"
PG_NAME="verify-pg-$(openssl rand -hex 4)"
REDIS_NAME="verify-redis-$(openssl rand -hex 4)"
APP_NAME="verify-app-$(openssl rand -hex 4)"

cleanup() {
  echo "==> Cleaning up test containers and network..."
  docker rm -f "$APP_NAME" "$PG_NAME" "$REDIS_NAME" 2>/dev/null || true
  docker network rm "$NET_NAME" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "========================================================================"
echo "Running Docker Verification against $IMAGE"
echo "========================================================================"

# -----------------------------------------------------------------------------
# Assertion 1: Build context audit (no *.md, .agents, .cursor, docs, tests, etc.)
# -----------------------------------------------------------------------------
echo "==> [1/9] Auditing build context exclusions..."
CTX_IMG="verify-ctx-$(openssl rand -hex 4)"
cat << 'EOF' | docker build -t "$CTX_IMG" -f - . >/dev/null
FROM busybox:1.37.0@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e
COPY . /ctx
EOF

LEAKED_FILES=$(docker run --rm "$CTX_IMG" find /ctx -type f \
  \( -name "*.md" \
  -o -path "*/.agents/*" \
  -o -path "*/.cursor/*" \
  -o -path "*/docs/*" \
  -o -path "*/intent/*" \
  -o -path "*/evals/*" \
  -o -path "*/test/*" \
  -o -path "*/scripts/*" \
  -o -path "*/.git/*" \
  -o -name ".env*" \
  -o -name "erl_crash.dump" \) 2>/dev/null || true)

docker rmi -f "$CTX_IMG" >/dev/null 2>&1 || true

if [ -n "$LEAKED_FILES" ]; then
  echo "Discovered disallowed files in build context:"
  echo "$LEAKED_FILES"
  fail "Build context contains excluded developer or AI-assistant files"
fi
echo "PASSED: Context hygiene verified (zero leaked files)."

# -----------------------------------------------------------------------------
# Assertion 2: User configuration (10001:10001)
# -----------------------------------------------------------------------------
echo "==> [2/9] Checking runtime user configuration..."
IMG_USER=$(docker image inspect "$IMAGE" --format '{{.Config.User}}')
if [ "$IMG_USER" != "10001:10001" ]; then
  fail "Expected image user to be 10001:10001, got: $IMG_USER"
fi
echo "PASSED: Runtime user is 10001:10001."

# -----------------------------------------------------------------------------
# Assertion 3: Dev tools and compilers absent in runtime
# -----------------------------------------------------------------------------
echo "==> [3/9] Verifying absence of development tooling in runtime..."
for cmd in gcc cc make git curl wget mix; do
  if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $cmd" 2>/dev/null; then
    fail "Development tool '$cmd' should not exist in runtime image"
  fi
done
echo "PASSED: No compilers, git, curl, or mix in runtime."

# -----------------------------------------------------------------------------
# Assertion 4: No setuid or setgid binaries
# -----------------------------------------------------------------------------
echo "==> [4/9] Verifying removal of setuid/setgid bits..."
SETUID_BINS=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "find / -xdev -perm /6000 -type f 2>/dev/null" || true)
if [ -n "$SETUID_BINS" ]; then
  fail "Found setuid/setgid binaries in image: $SETUID_BINS"
fi
echo "PASSED: No setuid/setgid binaries present."

# -----------------------------------------------------------------------------
# Assertion 5: Read-only app directory immutability
# -----------------------------------------------------------------------------
echo "==> [5/9] Testing code directory immutability..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "touch /app/probe 2>/dev/null"; then
  fail "Application user was able to write to /app directory (expected read-only)"
fi
echo "PASSED: Code directory /app is immutable for unprivileged user."

# -----------------------------------------------------------------------------
# Assertion 6: Secret leak detection in image history
# -----------------------------------------------------------------------------
echo "==> [6/9] Checking image history for hardcoded secrets..."
LEAKED_HISTORY=$(docker history --no-trunc "$IMAGE" | grep -Ei "SECRET|TOKEN|PASSWORD|COOKIE=" || true)
if [ -n "$LEAKED_HISTORY" ]; then
  fail "Discovered potential secrets in image layer history: $LEAKED_HISTORY"
fi
echo "PASSED: No secret values embedded in image history."

# -----------------------------------------------------------------------------
# Assertion 7: Refuses to boot without RELEASE_COOKIE
# -----------------------------------------------------------------------------
echo "==> [7/9] Verifying container aborts without RELEASE_COOKIE..."
set +e
docker run --rm "$IMAGE" >/dev/null 2>&1
COOKIE_STATUS=$?
set -e
if [ "$COOKIE_STATUS" -eq 0 ]; then
  fail "Expected container to exit non-zero when RELEASE_COOKIE is missing"
fi
echo "PASSED: Container refuses to run without RELEASE_COOKIE."

# -----------------------------------------------------------------------------
# Assertion 8: Migration & live healthcheck on read-only root FS
# -----------------------------------------------------------------------------
echo "==> [8/9] Booting services and testing health probe on read-only root FS..."
docker network create "$NET_NAME" >/dev/null

# Start disposable Postgres & Redis
docker run -d --name "$PG_NAME" --network "$NET_NAME" \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=app_test \
  postgres:16-alpine >/dev/null

docker run -d --name "$REDIS_NAME" --network "$NET_NAME" \
  redis:7-alpine >/dev/null

echo "Waiting for Postgres and Redis readiness..."
for i in $(seq 1 30); do
  if docker exec "$PG_NAME" pg_isready -U postgres >/dev/null 2>&1 && \
     docker exec "$REDIS_NAME" redis-cli ping >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

SECRET_KEY_BASE=$(openssl rand -hex 64)
ACCESS_SECRET=$(openssl rand -hex 32)
REFRESH_SECRET=$(openssl rand -hex 32)
COOKIE=$(openssl rand -hex 32)

COMMON_ENV=(
  -e "DATABASE_URL=ecto://postgres:postgres@$PG_NAME:5432/app_test"
  -e "REDIS_URL=redis://$REDIS_NAME:6379"
  -e "SECRET_KEY_BASE=$SECRET_KEY_BASE"
  -e "ACCESS_TOKEN_SECRET=$ACCESS_SECRET"
  -e "REFRESH_TOKEN_SECRET=$REFRESH_SECRET"
  -e "RELEASE_COOKIE=$COOKIE"
  -e "PHX_HOST=localhost"
  -e "PORT=4000"
  -e "RECAPTCHA_SECRET_KEY=dummy"
  -e "STRIPE_SECRET_KEY=sk_test_dummy"
  -e "STRIPE_WEBHOOK_SECRET=whsec_dummy"
  -e "STORAGE_BACKEND=s3"
)

echo "Running /app/bin/migrate..."
docker run --rm --network "$NET_NAME" "${COMMON_ENV[@]}" --entrypoint /app/bin/migrate "$IMAGE" >/dev/null

echo "Starting application with --read-only and dropped capabilities..."
docker run -d --name "$APP_NAME" --network "$NET_NAME" \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  "${COMMON_ENV[@]}" \
  "$IMAGE" >/dev/null

echo "Polling /health and /ready endpoints..."
HEALTHY=0
for i in $(seq 1 40); do
  # Probe via a throwaway curl in the same network
  STATUS=$(docker run --rm --network "$NET_NAME" curlimages/curl:8.12.1 \
    -s -o /dev/null -w "%{http_code}" "http://$APP_NAME:4000/health" 2>/dev/null || true)
  if [ "$STATUS" = "200" ]; then
    HEALTHY=1
    break
  fi
  sleep 1
done

if [ "$HEALTHY" -ne 1 ]; then
  docker logs "$APP_NAME"
  fail "Health probe failed to return 200 within 40 seconds"
fi

READY_STATUS=$(docker run --rm --network "$NET_NAME" curlimages/curl:8.12.1 \
  -s -o /dev/null -w "%{http_code}" "http://$APP_NAME:4000/ready" 2>/dev/null || true)
if [ "$READY_STATUS" != "200" ]; then
  docker logs "$APP_NAME"
  fail "Ready probe failed with status $READY_STATUS"
fi
echo "PASSED: Application started, migrated, and passed /health and /ready on read-only FS."

# -----------------------------------------------------------------------------
# Assertion 9: Graceful SIGTERM shutdown
# -----------------------------------------------------------------------------
echo "==> [9/9] Testing graceful SIGTERM shutdown..."
docker stop -t 30 "$APP_NAME" >/dev/null
EXIT_CODE=$(docker inspect "$APP_NAME" --format '{{.State.ExitCode}}')
if [ "$EXIT_CODE" -ne 0 ]; then
  fail "Expected clean shutdown exit code 0, got $EXIT_CODE"
fi
echo "PASSED: Container terminated gracefully with code 0."

echo "========================================================================"
echo "docker-verify: OK (All 9 security assertions passed)"
echo "========================================================================"
