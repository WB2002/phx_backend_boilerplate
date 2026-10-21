#!/bin/bash
set -euo pipefail
input=$(cat)
if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  root=$(cd .. && pwd)
fi
cd "$root" || { echo '{}'; exit 0; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

outside=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  case "$path" in
    *" -> "*) path="${path##* -> }" ;;
  esac
  case "$path" in
    docs/*|docs|intent/*|intent|.cursor/*|.cursor|.agents/*|.agents|evals/*|evals|quality/*|quality) ;;
    *) outside=1 ;;
  esac
done < <(git status --porcelain -uall)

if [ "$outside" -eq 0 ]; then
  echo '{}'
  exit 0
fi

set +e
output=$(scripts/verify.sh 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ]; then
  tail=$(printf '%s\n' "$output" | tail -n 40)
  msg="scripts/verify.sh failed. Fix the code, not the tests, and re-run. Output tail: ${tail}"
  jq -n --arg msg "$msg" '{decision: "continue", reason: $msg}'
  exit 0
fi

echo '{}'
