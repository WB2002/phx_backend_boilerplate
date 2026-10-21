#!/bin/bash
set -euo pipefail

# TODO: confirm the CLI binary, any flags beyond -p, and the API-key variable name:
# https://cursor.com/docs/cli/headless
# https://cursor.com/docs/cli/installation
# Public docs currently show binary `agent` and env `CURSOR_API_KEY`.
# This script uses `cursor-agent -p` as specified. Do not treat the doc names as confirmed.
# TODO: set the API key variable before running this in CI.

fail=0
while IFS= read -r case_file; do
  [ -z "$case_file" ] && continue
  id=$(jq -r '.id' "$case_file")
  prompt=$(jq -r '.prompt' "$case_file")
  check=$(jq -r '.check' "$case_file")
  echo "== eval: $id =="
  if ! cursor-agent -p "$prompt"; then
    echo "FAIL $id: agent"
    fail=1
    continue
  fi
  if ! "$check"; then
    echo "FAIL $id: check"
    fail=1
    continue
  fi
done < <(find evals/cases -name '*.json' -type f | sort)

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "evals: OK"
