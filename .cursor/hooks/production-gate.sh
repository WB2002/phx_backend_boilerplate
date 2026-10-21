#!/bin/bash
cmd=$(jq -r '.command // empty')
if echo "$cmd" | grep -Eiq '(deploy|release|apply|upgrade|publish).*(prod|production)|(prod|production).*(deploy|release|apply|upgrade|publish)'; then
  echo '{"permission":"ask","user_message":"Production change: explicit human approval required.","agent_message":"This looks like a production deploy. Wait for the human to approve."}'
else
  echo '{"permission":"allow"}'
fi
