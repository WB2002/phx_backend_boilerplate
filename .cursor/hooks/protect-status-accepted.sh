#!/bin/bash
input=$(cat)
f=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty')

case "$f" in
  intent/*.md|intent/**/*.md|docs/adr/*.md)
    content=$(echo "$input" | jq -r '.tool_input.content // .content // empty')
    if echo "$content" | grep -Eiq '^[[:space:]]*([#*-][[:space:]]*)?(Status|Lifecycle):[[:space:]]*accepted'; then
      # Check if file on disk already had accepted
      if [ -f "$f" ] && grep -Eiq '^[[:space:]]*([#*-][[:space:]]*)?(Status|Lifecycle):[[:space:]]*accepted' "$f"; then
        echo '{"permission":"allow"}'
        exit 0
      fi
      # If not, the edit is introducing 'accepted' which is forbidden for agents
      echo '{"permission":"deny","user_message":"Agents cannot mark Status as accepted. Only the human owner does.","agent_message":"Blocked: do not set Status or Lifecycle to accepted. Only the human owner sets accepted."}'
      exit 2
    fi
    ;;
esac

echo '{"permission":"allow"}'
