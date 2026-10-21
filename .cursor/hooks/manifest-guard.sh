#!/bin/bash
input=$(cat)
f=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty')
MANIFEST_PATTERN='(^|/)(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pyproject\.toml|uv\.lock|poetry\.lock|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock)$|(^|/)requirements[^/]*\.txt$|(^|/)Gemfile[^/]*$|(^|/)composer\.[^/]+$'
if echo "$f" | grep -Eq "$MANIFEST_PATTERN"; then
  echo '{"permission":"deny","user_message":"Use /add-dependency.","agent_message":"Use /add-dependency. Do not hand-edit dependency manifests or lockfiles."}'
  exit 2
fi
echo '{"permission":"allow"}'
