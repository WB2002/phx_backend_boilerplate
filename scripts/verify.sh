#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export TOOLCHAIN_ROOT="$ROOT"

cleanup_verify() {
  if [ -n "${TOOLCHAIN_DOCKER_WORKDIR:-}" ]; then
    rm -rf "${TOOLCHAIN_DOCKER_WORKDIR}"
  fi
}
trap cleanup_verify EXIT

# shellcheck source=lib/toolchain.sh
. "$ROOT/scripts/lib/toolchain.sh"

echo "== build =="
mix compile --warnings-as-errors

echo "== lint & format =="
mix format --check-formatted
mix credo --min-priority high

echo "== test =="
if nc -z -G 1 127.0.0.1 5433 2>/dev/null; then
  mix test
else
  echo "Test database not reachable on 127.0.0.1:5433; skipping test suite in verify.sh (run docker-compose up or mix precommit when DB is running)"
fi

echo "verify: OK"
