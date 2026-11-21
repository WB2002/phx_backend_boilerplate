#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CONFIG="$ROOT/scripts/ci/semgrep-guardrails.yaml"

if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --config "$CONFIG" --error lib/
elif command -v docker >/dev/null 2>&1; then
  # Docker Desktop on macOS often cannot mount ~/Documents; stage into /tmp.
  WORKDIR="$(mktemp -d /tmp/phx-semgrep.XXXXXX)"
  trap 'rm -rf "$WORKDIR"' EXIT
  mkdir -p "$WORKDIR/scripts/ci"
  cp "$CONFIG" "$WORKDIR/scripts/ci/semgrep-guardrails.yaml"
  rsync -a "$ROOT/lib/" "$WORKDIR/lib/"
  docker run --rm -v "$WORKDIR:/src" semgrep/semgrep:1.151.0 semgrep scan \
    --config /src/scripts/ci/semgrep-guardrails.yaml --error /src/lib/
else
  echo "error: install semgrep (brew install semgrep) or Docker" >&2
  exit 1
fi

echo "semgrep guardrails: OK"
