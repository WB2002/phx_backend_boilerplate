#!/bin/bash
set -euo pipefail
input=$(cat)
if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  root=$(cd .. && pwd)
fi

f=$(echo "$input" | jq -r '.toolCall.args.TargetFile // .toolCall.args.file_path // .toolCall.args.path // .tool_input.file_path // .file_path // empty')

GUARD_PATTERN='(^|/)\.cursor/hooks\.json$|(^|/)\.cursor/hooks/|(^|/)\.cursor/BUGBOT\.md$|(^|/)\.cursorignore$|(^|/)\.agents/hooks\.json$|(^|/)\.agents/hooks/|(^|/)\.agents/skills\.json$|(^|/)scripts/verify[^/]*\.sh$|(^|/)scripts/ratchet\.sh$|(^|/)quality/|(^|/)\.github/|(^|/)CODEOWNERS$'

if ! { [ -f "$root/.cursor/.guardrails-edit" ] || [ -f "$root/.agents/.guardrails-edit" ]; } && echo "$f" | grep -Eq "$GUARD_PATTERN"; then
  jq -n '{
    decision: "deny",
    reason: "Blocked: this path is a guardrail. Stop and ask the user. Only the user may create .cursor/.guardrails-edit or .agents/.guardrails-edit before this file can change."
  }'
  exit 0
fi

echo '{"decision":"allow"}'
