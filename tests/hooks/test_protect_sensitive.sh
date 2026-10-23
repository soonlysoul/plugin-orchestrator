#!/usr/bin/env bash
# protect-sensitive: simulated inputs, no session. PreToolUse hook on Edit|Write|NotebookEdit.
# In a project that has .forge/, asks the user before a write to signing material, entitlements,
# CI workflows or the plugin's configuration; .forge/config.yaml is protected everywhere; silent
# outside that context. Fail-closed when it must decide.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_protect_sensitive
HOOK="$PLUGIN_ROOT/hooks/scripts/protect-sensitive.sh"

work=$(mktemp -d)
trap 'rm -r "$work"' EXIT
forge="$work/forge_app"
plain="$work/plain_app"
mkdir -p "$forge/.forge" "$plain"

echo "# contrat du squelette (entrées qui nomment un fichier sensible, le contexte du hook)"
run_hook "$HOOK" 'pas du json, mais key.properties'
expect_blocked "squelette : entrée illisible bloquée"
no_jq=$(mktemp -d)
run_hook "$HOOK" '{"x": "key.properties"}' PATH="$no_jq"
rm -rf "$no_jq"
expect_blocked "squelette : jq absent bloqué"

# write_input <file_path> [tool] [content] [cwd]
write_input() {
  local key=file_path
  [[ ${2:-Write} == NotebookEdit ]] && key=notebook_path
  jq -nc --arg p "$1" --arg t "${2:-Write}" --arg c "${3:-x}" --arg d "${4:-$forge}" --arg k "$key" \
    '{session_id: "test", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t,
      tool_input: ({($k): $p} + (if $t == "Write" then {content: $c} else {old_string: "a", new_string: $c} end))}'
}

# expect_ask <label> <needle>: exit 0 and a PreToolUse "ask" decision whose reason holds the needle.
expect_ask() {
  local reason
  reason=$(jq -r 'select(.hookSpecificOutput.hookEventName == "PreToolUse"
                         and .hookSpecificOutput.permissionDecision == "ask")
                  | .hookSpecificOutput.permissionDecisionReason // empty' <<<"$HOOK_STDOUT" 2>/dev/null)
  if [[ $HOOK_STATUS == 0 && $reason == *plugin-orchestrator* && $reason == *"$2"* ]]; then
    pass "$1"
  else
    fail "$1" "exit $HOOK_STATUS ; stdout : ${HOOK_STDOUT:0:300} ; stderr : ${HOOK_STDERR:0:200}"
  fi
}

# check <ask|allow> <label> <input> [needle] [env...]
check() {
  local expected=$1 label=$2 input=$3 needle=${4-}
  shift 4 2>/dev/null || shift $#
  run_hook "$HOOK" "$input" CLAUDE_PROJECT_DIR="$forge" "$@"
  if [[ $expected == ask ]]; then expect_ask "$label" "$needle"; else expect_silent_allow "$label"; fi
}

echo "# les fichiers sensibles d'un projet .forge/ demandent d'abord"
check ask "android/key.properties" "$(write_input "$forge/android/key.properties")" android/key.properties
check ask "un keystore d'upload (.jks)" "$(write_input "$forge/android/app/upload.jks")" upload.jks
check ask "un .keystore édité" "$(write_input "$forge/android/release.keystore" Edit)" release.keystore
check ask "des entitlements iOS" "$(write_input "$forge/ios/Runner/Runner.entitlements")" Runner.entitlements
check ask "des entitlements macOS" "$(write_input "$forge/macos/Runner/Release.entitlements" Edit)" Release.entitlements
check ask "un workflow de CI" "$(write_input "$forge/.github/workflows/ci.yml")" .github/workflows/ci.yml
check ask "un workflow de CI par NotebookEdit" "$(write_input "$forge/.github/workflows/x.ipynb" NotebookEdit)" .github/workflows
check ask ".forge/config.yaml" "$(write_input "$forge/.forge/config.yaml" Edit)" .forge/config.yaml
check ask "un chemin relatif est reconnu aussi" "$(write_input android/key.properties)" key.properties
run_hook "$HOOK" "$(write_input "$forge/.github/workflows/ci.yml")" CLAUDE_PROJECT_DIR="$forge"
reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$HOOK_STDOUT" 2>/dev/null)
[[ $reason == *"workflow"* && $reason == *"autrement"* ]] && pass "la raison dit ce qu'est le fichier et de ne pas contourner un refus" \
  || fail "la raison dit ce qu'est le fichier et de ne pas contourner un refus" "$reason"
[[ -z $HOOK_STDERR ]] && pass "une décision ask n'écrit rien sur stderr" || fail "une décision ask n'écrit rien sur stderr" "$HOOK_STDERR"

echo "# les autres fichiers d'un projet .forge/"
check allow "src/ n'est pas sensible" "$(write_input "$forge/src/main.ts")"
check allow ".forge/checkpoint.md est l'état du workflow" "$(write_input "$forge/.forge/checkpoint.md")"
check allow "un document qui mentionne key.properties" "$(write_input "$forge/docs/SIGNING.md" Write 'Keep android/key.properties out of Git.')"
check allow ".github/ hors de workflows/" "$(write_input "$forge/.github/dependabot.yml")"
check allow "un Read ne regarde pas ce hook" '{"tool_name": "Read", "tool_input": {"file_path": "/x/android/key.properties"}, "cwd": "/x"}'

echo "# hors d'un projet .forge/ : silencieux"
run_hook "$HOOK" "$(write_input "$plain/.github/workflows/ci.yml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_silent_allow "un workflow d'un projet sans .forge/ passe"
run_hook "$HOOK" "$(write_input "$plain/android/key.properties" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_silent_allow "les fichiers de signature d'un projet sans .forge/ passent"
run_hook "$HOOK" "$(write_input "$plain/sub/.forge/config.yaml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_ask "un .forge/config.yaml est protégé partout" .forge/config.yaml
run_hook "$HOOK" "$(write_input "$forge/.github/workflows/ci.yml" Write x "$forge")"
expect_ask "sans CLAUDE_PROJECT_DIR, le cwd de l'entrée est la racine" ci.yml
nojq=$(restricted_path)
run_hook "$HOOK" "$(write_input "$plain/.github/workflows/ci.yml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain" PATH="$nojq"
expect_silent_allow "hors d'un projet .forge/, jq absent ne change rien"
run_hook "$HOOK" "$(write_input "$forge/src/main.ts")" CLAUDE_PROJECT_DIR="$forge" PATH="$nojq"
expect_silent_allow "un fichier ordinaire passe sans jq"

echo "# une app .forge/ sous la racine de session, et d'autres fichiers de CI ou de signature"
parent="$work/parent"
mkdir -p "$parent/app/.forge"
run_hook "$HOOK" "$(write_input "$parent/app/.github/workflows/ci.yml" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_ask "le projet .forge/ est trouvé depuis le fichier, pas depuis la racine de session" app/.github/workflows/ci.yml
run_hook "$HOOK" "$(write_input "$parent/app/android/key.properties" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_ask "les fichiers de signature d'une app .forge/ sous la racine de session" key.properties
run_hook "$HOOK" "$(write_input "$parent/other/.github/workflows/ci.yml" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_silent_allow "un projet voisin sans .forge/ n'est pas protégé"
check ask "une action composite sous .github/actions/" "$(write_input "$forge/.github/actions/setup/action.yml")" .github/actions/setup/action.yml
check ask "un certificat de distribution iOS (.p12)" "$(write_input "$forge/ios/dist.p12")" dist.p12
check ask "un certificat .pfx" "$(write_input "$forge/windows/sign.pfx")" sign.pfx

echo "# fail-closed"
run_hook "$HOOK" "$(write_input "$forge/android/key.properties")" CLAUDE_PROJECT_DIR="$forge" PATH="$nojq"
expect_blocked "jq absent bloque une écriture qui peut être sensible"
[[ $HOOK_STDERR == *jq* ]] && pass "jq absent : nommé dans la raison" || fail "jq absent : nommé dans la raison" "$HOOK_STDERR"
rm -r "$nojq"
run_hook "$HOOK" '{"tool_name": "Write", "tool_input": {"file_path": "/x/android/key.properties"' CLAUDE_PROJECT_DIR="$forge"
expect_blocked "une entrée malformée qui peut être sensible : bloquée"
run_hook "$HOOK" '{"tool_name": "Write", "tool_input": {"file_path": 7, "content": "key.properties"}}' CLAUDE_PROJECT_DIR="$forge"
expect_blocked "un chemin non textuel : bloqué"

finish
