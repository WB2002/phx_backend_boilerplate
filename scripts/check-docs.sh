#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

body=""
base=""
if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  body=$(jq -r '.pull_request.body // empty' "$GITHUB_EVENT_PATH")
  base=$(jq -r '.pull_request.base.sha // empty' "$GITHUB_EVENT_PATH")
fi

if [ -n "$base" ]; then
  files=$(git diff --name-only "${base}...HEAD")
else
  files=$(git status --porcelain -uall | sed 's/^...//; s/.* -> //')
fi

source_changed=0
docs_changed=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    docs/*|docs|intent/*|intent|CHANGELOG.md)
      docs_changed=1
      ;;
    *)
      source_changed=1
      ;;
  esac
done <<< "$files"

if [ "$source_changed" -eq 0 ]; then
  echo "check-docs: no source changes"
  exit 0
fi

if [ "$docs_changed" -eq 1 ]; then
  echo "check-docs: docs updated"
  exit 0
fi

if printf '%s\n' "$body" | grep -Eq 'Docs impact: none:[[:space:]]*[^[:space:]]'; then
  echo "check-docs: Docs impact none with a reason"
  exit 0
fi

echo "check-docs: source files changed without docs/, intent/, or CHANGELOG.md."
echo "Update those files, or include 'Docs impact: none:' followed by a reason in the PR body."
exit 1
