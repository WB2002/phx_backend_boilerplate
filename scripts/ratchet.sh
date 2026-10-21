#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" = "--update" ]; then
  echo "TODO: configure ratchet --update — see docs/adr/0001-stack.md"
  exit 1
fi

echo "skip: mutation_score (optional, unset until docs/adr/0001-stack.md)"
echo "skip: bundle_size (optional, unset until docs/adr/0001-stack.md)"

required=$(jq -r '
  .metrics
  | to_entries[]
  | select(.key != "mutation_score" and .key != "bundle_size")
  | select(.value == null)
  | .key
' quality/baseline.json)

if [ -n "$required" ]; then
  while IFS= read -r metric; do
    echo "TODO: configure ${metric} — see docs/adr/0001-stack.md"
  done <<< "$required"
  exit 1
fi

echo "TODO: configure ratchet measurement — see docs/adr/0001-stack.md"
exit 1
