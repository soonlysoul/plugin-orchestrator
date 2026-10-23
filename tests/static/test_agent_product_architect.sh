#!/usr/bin/env bash
# agents/product-architect.md: present, strict header, tools Read, Grep, Glob, Write, Edit, model inherit.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=../headers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../headers.sh"
SUITE=test_agent_product_architect
FILE="$PLUGIN_ROOT/agents/product-architect.md"

if [[ ! -f $FILE ]]; then
  fail "agents/product-architect.md présent" "absent"
  finish
  exit
fi
pass "agents/product-architect.md présent"
errors=$(agent_structure_errors "$FILE")
[[ -z $errors ]] && pass "en-tête strict" || fail "en-tête strict" "$errors"
read_frontmatter "$FILE"
tools=$(tr ',' '\n' <<<"${FM[tools]-}" | sed 's/ //g' | sort | paste -sd, -)
[[ $tools == "Edit,Glob,Grep,Read,Write" ]] && pass "outils : Read, Grep, Glob, Write, Edit" || fail "outils : Read, Grep, Glob, Write, Edit" "$tools"
[[ ${FM[model]-} == inherit ]] && pass "modèle : inherit" || fail "modèle : inherit" "${FM[model]-absent}"
jq -e --arg a plugin-orchestrator:product-architect '.[$a] == {write: ["docs/product/"], bash: []}' "$PLUGIN_ROOT/hooks/agent-scope.json" >/dev/null 2>&1 \
  && pass "portée déclarée au garde" || fail "portée déclarée au garde"

finish
