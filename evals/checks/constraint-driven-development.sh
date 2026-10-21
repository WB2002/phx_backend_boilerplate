#!/bin/bash
set -euo pipefail
skill=".cursor/skills/constraint-driven-development/SKILL.md"
test -f "$skill"
grep -q "Status: draft" "$skill"
grep -q "Open questions" "$skill"
grep -q "enforcement point" "$skill"
grep -q "Do not set Status to \`accepted\`" "$skill"
