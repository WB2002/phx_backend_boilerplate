#!/bin/bash
set -euo pipefail
input=$(cat)

f=$(echo "$input" | jq -r '.toolCall.args.TargetFile // .toolCall.args.file_path // .toolCall.args.path // .tool_input.file_path // .file_path // empty')

MANIFEST_PATTERN='(^|/)(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pyproject\.toml|uv\.lock|poetry\.lock|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock)$|(^|/)requirements[^/]*\.txt$|(^|/)Gemfile[^/]*$|(^|/)composer\.[^/]+$'

if echo "$f" | grep -Eq "$MANIFEST_PATTERN"; then
  jq -n '{
    decision: "deny",
    reason: "Use /add-dependency. Do not hand-edit dependency manifests or lockfiles."
  }'
  exit 0
fi

echo '{"decision":"allow"}'
