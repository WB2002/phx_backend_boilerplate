#!/bin/bash
set -euo pipefail

# Ensure mix and elixir are reachable in non-interactive / hook subshells
for p in /opt/homebrew/bin "$HOME/.asdf/shims" /usr/local/bin "$HOME/.local/bin"; do
  if [ -d "$p" ]; then
    export PATH="$p:$PATH"
  fi
done

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
