#!/bin/bash
set -euo pipefail
input=$(cat)

f=$(echo "$input" | jq -r '.toolCall.args.AbsolutePath // .toolCall.args.file_path // .file_path // empty')

case "$f" in
  *.env.example|*.env.sample)
    echo '{"decision":"allow"}'
    ;;
  */.env|*/.env.*|*/secrets/*|*.pem|*.key|.env|.env.*|secrets/*)
    jq -n '{
      decision: "deny",
      reason: "Blocked: sensitive file. This file is blocked to keep secrets out of context. Ask the user if you need a value from it."
    }'
    ;;
  *)
    echo '{"decision":"allow"}'
    ;;
esac
