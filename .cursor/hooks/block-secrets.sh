#!/bin/bash
f=$(jq -r '.file_path // empty')
case "$f" in
  *.env.example|*.env.sample) echo '{"permission":"allow"}' ;;
  */.env|*/.env.*|*/secrets/*|*.pem|*.key)
    echo '{"permission":"deny","user_message":"Blocked: sensitive file.","agent_message":"This file is blocked to keep secrets out of context. Ask the user if you need a value from it."}'; exit 2 ;;
  *) echo '{"permission":"allow"}' ;;
esac
