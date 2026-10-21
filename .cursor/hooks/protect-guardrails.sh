#!/bin/bash
input=$(cat)
f=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty')
GUARD_PATTERN='(^|/)\.cursor/hooks\.json$|(^|/)\.cursor/hooks/|(^|/)\.cursor/BUGBOT\.md$|(^|/)\.cursorignore$|(^|/)scripts/verify[^/]*\.sh$|(^|/)scripts/ratchet\.sh$|(^|/)quality/|(^|/)\.github/|(^|/)CODEOWNERS$'
if [ ! -f "${CURSOR_PROJECT_DIR:-.}/.cursor/.guardrails-edit" ] && echo "$f" | grep -Eq "$GUARD_PATTERN"; then
  echo '{"permission":"deny","user_message":"Guardrail files are protected.","agent_message":"Blocked: this path is a guardrail. Stop and ask the user. Only the user may create .cursor/.guardrails-edit before this file can change."}'
  exit 2
fi
echo '{"permission":"allow"}'
