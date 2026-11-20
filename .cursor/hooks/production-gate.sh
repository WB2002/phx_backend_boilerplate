#!/bin/bash
cmd=$(jq -r '.command // empty')

# 1. Matches commands explicitly targeting production
if echo "$cmd" | grep -Eiq '(deploy|release|apply|upgrade|publish).*(prod|production)|(prod|production).*(deploy|release|apply|upgrade|publish)'; then
  echo '{"permission":"ask","user_message":"Production change: explicit human approval required.","agent_message":"This looks like a production deploy. Wait for the human to approve."}'
  exit 0
fi

# 2. Matches mutating infrastructure, deployment, or publishing commands
MUTATING_DEPLOY_PATTERN='(^|[[:space:];|&(])(terraform|tofu|terragrunt)[[:space:]]+apply([[:space:]]|$)|(^|[[:space:];|&(])pulumi[[:space:]]+up([[:space:]]|$)|(^|[[:space:];|&(])kubectl[[:space:]]+(apply|delete|patch|replace)([[:space:]]|$)|(^|[[:space:];|&(])helm[[:space:]]+(upgrade|install|rollback|uninstall)([[:space:]]|$)|(^|[[:space:];|&(])wrangler[[:space:]]+(deploy|pages[[:space:]]+deploy)([[:space:]]|$)|(^|[[:space:];|&(])fly([[:space:]]+deploy|[[:space:]]+ctl[[:space:]]+deploy)([[:space:]]|$)|(^|[[:space:];|&(])vercel[[:space:]]+.*--prod([[:space:]]|$)|(^|[[:space:];|&(])(npm|pnpm|yarn|cargo)[[:space:]]+publish([[:space:]]|$)|(^|[[:space:];|&(])twine[[:space:]]+upload([[:space:]]|$)|(^|[[:space:];|&(])gh[[:space:]]+release[[:space:]]+create([[:space:]]|$)|(^|[[:space:];|&(])(prisma[[:space:]]+migrate[[:space:]]+deploy|supabase[[:space:]]+db[[:space:]]+push|alembic[[:space:]]+upgrade)([[:space:]]|$)'

if echo "$cmd" | grep -Eq "$MUTATING_DEPLOY_PATTERN"; then
  echo '{"permission":"ask","user_message":"Deployment/Infrastructure change: explicit human approval required.","agent_message":"This command mutates infrastructure, deploys code, publishes packages, or applies database migrations. Wait for the human to approve."}'
  exit 0
fi

echo '{"permission":"allow"}'
