#!/bin/bash
set -euo pipefail

skill=".cursor/skills/market-opportunity-research/SKILL.md"
template_dir=".cursor/skills/market-opportunity-research/templates"
report_tpl="$template_dir/research-report.md"
ledger_tpl="$template_dir/evidence-ledger.md"
experiments_tpl="$template_dir/validation-experiments.md"
case_file="evals/cases/coding/market-opportunity-research.json"

test -f "$skill"
test -f "$report_tpl"
test -f "$ledger_tpl"
test -f "$experiments_tpl"
test -f "$case_file"

test "$(awk '/^name:/{print $2; exit}' "$skill")" = "$(basename "$(dirname "$skill")")"
grep -q '^description: Use when ' "$skill"
grep -q '^disable-model-invocation: true$' "$skill"

# Check subagent definitions
agents=(
  market-problem-analyst
  competitor-analyst
  customer-dissatisfaction-analyst
  positioning-strategist
  unit-economics-analyst
  gtm-strategist
  technical-defensibility-analyst
  opportunity-red-team
)

for agent in "${agents[@]}"; do
  agent_file=".cursor/agents/${agent}.md"
  test -f "$agent_file"
  grep -q "^name: ${agent}$" "$agent_file"
  grep -q '^readonly: true$' "$agent_file"
  grep -q '^model: inherit$' "$agent_file"
done

# Check core principle and rules in skill
grep -q "Never confuse an interesting hypothesis with a verified finding" "$skill"
grep -q "verified fact" "$skill"
grep -q "customer-reported evidence" "$skill"
grep -q "inference" "$skill"
grep -q "estimate" "$skill"
grep -q "hypothesis" "$skill"
grep -q "independent red team" "$skill"
grep -q "critical blocker" "$skill"

# Check report template sections (all 17 sections)
grep -q "## 1. Executive recommendation" "$report_tpl"
grep -q "## 2. Research scope, assumptions, geography, and limitations" "$report_tpl"
grep -q "## 3. Customer problem evidence and existing workarounds" "$report_tpl"
grep -q "## 4. Competitor landscape and comparison matrix" "$report_tpl"
grep -q "## 5. Pricing and packaging comparison" "$report_tpl"
grep -q "## 6. Customer dissatisfaction patterns and potential unmet needs" "$report_tpl"
grep -q "## 7. Opportunity shortlist" "$report_tpl"
grep -q "## 8. Recommended positioning and differentiation" "$report_tpl"
grep -q "## 9. Business model, pricing hypotheses, and unit economics" "$report_tpl"
grep -q "## 10. Go-to-market strategy and route to first customers" "$report_tpl"
grep -q "## 11. MVP scope and core user journey" "$report_tpl"
grep -q "## 12. Technical feasibility and regulatory considerations" "$report_tpl"
grep -q "## 13. Validation experiments with success and failure thresholds" "$report_tpl"
grep -q "## 14. Red-team findings and reasons not to build" "$report_tpl"
grep -q "## 15. Decision gates" "$report_tpl"
grep -q "## 16. Evidence gaps and recommended next steps" "$report_tpl"
grep -q "## 17. Deduplicated source register" "$report_tpl"

# Check ledger template
grep -q "FND-" "$ledger_tpl"
grep -q "Classification" "$ledger_tpl"
grep -q "Source URLs" "$ledger_tpl"

# Check experiments template
grep -qi "Falsifiable hypothesis" "$experiments_tpl"

echo "market opportunity research: OK"
