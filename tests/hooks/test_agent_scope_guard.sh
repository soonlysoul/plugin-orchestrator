#!/usr/bin/env bash
# agent-scope-guard: simulated inputs, no session. PreToolUse hook on Edit|Write|NotebookEdit|
# Bash|PowerShell|Monitor. Each agent of the plugin (agent_type plugin-orchestrator:<agent>) is
# held to the scope hooks/agent-scope.json declares for it: write directories, allowlist of
# single shell commands matched word by word as a prefix. The rules are proved on a copy of the
# hook with a fixture scope; the agents the plugin really declares are each checked against
# their own entry. Inert for everything else, the same agent names of another plugin included.
# Fail-closed for the plugin's agents: no scope, no call.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agent_scope_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/agent-scope-guard.sh"
SCOPE_JSON="$PLUGIN_ROOT/hooks/agent-scope.json"
P=plugin-orchestrator

echo "# contrat du squelette (entrées qui portent le préfixe du plugin, le contexte du hook)"
run_hook "$HOOK" "pas du json, mais $P:product-architect"
expect_blocked "squelette : entrée illisible bloquée"
no_jq=$(mktemp -d)
run_hook "$HOOK" "{\"agent_type\": \"$P:product-architect\"}" PATH="$no_jq"
rm -rf "$no_jq"
expect_blocked "squelette : jq absent bloqué"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A copy of the hook and its lexer, with a fixture scope: the rules, proved on agents that
# exist only here.
fixture="$work/fixture"
mkdir -p "$fixture/hooks"
cp -r "$SCRIPTS" "$fixture/hooks/scripts"
cat >"$fixture/hooks/agent-scope.json" <<JSON
{
  "$P:writer": {"write": ["docs/product/"], "bash": []},
  "$P:shell": {"write": [], "bash": ["git status", "git log", "git diff", "git show", "git ls-files", "git rev-parse", "git branch --show-current"]},
  "$P:both": {"write": ["docs/", "test/"], "bash": ["npm test"]},
  "$P:broken": {"write": "docs/"},
  "$P:climber": {"write": ["../elsewhere/"], "bash": []},
  "$P:rooted": {"write": ["/etc/"], "bash": []}
}
JSON
FHOOK="$fixture/hooks/scripts/agent-scope-guard.sh"

# agent_input <agent_type or ""> <tool> <tool_input JSON> [cwd]
agent_input() {
  jq -nc --arg a "$1" --arg t "$2" --argjson i "$3" --arg d "${4-/work/proj}" \
    '{session_id: "test", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t, tool_input: $i}
     + (if $a == "" then {} else {agent_id: "agent-1", agent_type: $a} end)'
}
write_input() {
  local key=file_path
  [[ ${3:-Write} == NotebookEdit ]] && key=notebook_path
  agent_input "$1" "${3:-Write}" "$(jq -nc --arg p "$2" --arg k "$key" '{($k): $p, content: "x"}')"
}
shell_input() { agent_input "$1" "${3:-Bash}" "$(jq -nc --arg c "$2" '{command: $c}')"; }

# check <allow|block> <label> <input> [env...]: against $GUARD.
GUARD=$HOOK
check() {
  local expected=$1 label=$2 input=$3
  shift 3
  run_hook "$GUARD" "$input" "$@"
  if [[ $expected == allow ]]; then expect_silent_allow "$label"; else expect_blocked "$label"; fi
}

echo "# inerte hors des agents du plugin"
check allow "la session principale écrit où elle veut" "$(write_input "" /etc/hosts)"
check allow "le Bash de la session principale n'est pas l'affaire de ce hook" "$(shell_input "" 'rm -rf src')"
check allow "un agent intégré est ignoré" "$(write_input Explore /work/proj/src/a.ts)"
check allow "le même nom d'agent d'un autre plugin est ignoré" "$(write_input plugin-flutter:product-architect /work/proj/lib/a.dart)"
check allow "un agent d'un autre plugin est ignoré" "$(shell_input plugin-flutter:test-engineer 'flutter test')"
check allow "le préfixe dans un contenu n'en fait pas un agent du plugin" \
  "$(agent_input "" Write "{\"file_path\": \"/etc/hosts\", \"content\": \"$P:product-architect\"}")"
check allow "Read n'est pas restreint, même pour un agent sans périmètre" "$(agent_input "$P:nobody" Read '{"file_path": "/work/proj/src/a.ts"}')"

echo "# sans périmètre déclaré, un agent du plugin ne fait rien"
GUARD=$FHOOK
check block "agent du plugin absent de hooks/agent-scope.json : écriture bloquée" "$(write_input "$P:unknown" /work/proj/docs/a.md)"
check block "agent du plugin absent de hooks/agent-scope.json : commande bloquée" "$(shell_input "$P:unknown" 'git status')"
[[ $HOOK_STDERR == *unknown* && $HOOK_STDERR == *agent-scope.json* ]] && pass "le refus nomme l'agent et hooks/agent-scope.json" \
  || fail "le refus nomme l'agent et hooks/agent-scope.json" "$HOOK_STDERR"
check block "périmètre malformé (write n'est pas une liste) : bloqué" "$(write_input "$P:broken" /work/proj/docs/a.md)"
check block "dossier d'écriture qui remonte (..) : bloqué" "$(write_input "$P:climber" /work/proj/docs/a.md)"
check block "dossier d'écriture absolu : bloqué" "$(write_input "$P:rooted" /etc/hosts)"
nojson="$work/nojson"
mkdir -p "$nojson/hooks"
cp -r "$SCRIPTS" "$nojson/hooks/scripts"
run_hook "$nojson/hooks/scripts/agent-scope-guard.sh" "$(write_input "$P:writer" /work/proj/docs/product/PRD.md)"
expect_blocked "hooks/agent-scope.json absent : bloqué pour un agent du plugin"
run_hook "$nojson/hooks/scripts/agent-scope-guard.sh" "$(write_input "" /work/proj/docs/product/PRD.md)"
expect_silent_allow "hooks/agent-scope.json absent : inerte ailleurs"
printf 'pas du json' >"$nojson/hooks/agent-scope.json"
run_hook "$nojson/hooks/scripts/agent-scope-guard.sh" "$(write_input "$P:writer" /work/proj/docs/product/PRD.md)"
expect_blocked "hooks/agent-scope.json illisible : bloqué pour un agent du plugin"

echo "# un agent qui écrit sous docs/product/, sans shell (fixture writer)"
W="$P:writer"
check allow "écrit le PRD" "$(write_input "$W" /work/proj/docs/product/PRD.md)"
check allow "édite un fichier sous docs/product/" "$(write_input "$W" /work/proj/docs/product/notes/brief.md Edit)"
check allow "NotebookEdit sous docs/product/" "$(write_input "$W" /work/proj/docs/product/x.ipynb NotebookEdit)"
check block "écrit docs/technical/" "$(write_input "$W" /work/proj/docs/technical/TRD.md)"
check block "écrit docs/ lui-même" "$(write_input "$W" /work/proj/docs/PRD.md)"
check block "docs/productx/ n'est pas docs/product/" "$(write_input "$W" /work/proj/docs/productx/PRD.md)"
check block "remonte hors de docs/product/ avec .." "$(write_input "$W" /work/proj/docs/product/../technical/TRD.md)"
check block "un . dans le chemin" "$(write_input "$W" /work/proj/docs/product/./PRD.md)"
check block "écrit src/" "$(write_input "$W" /work/proj/src/main.ts)"
check block "écrit hors du projet" "$(write_input "$W" /etc/hosts)"
check block "chemin relatif" "$(write_input "$W" docs/product/PRD.md)"
check block "Write sans file_path" "$(agent_input "$W" Write '{"content": "x"}')"
check block "file_path non textuel" "$(agent_input "$W" Write '{"file_path": 7, "content": "x"}')"
check block "NotebookEdit hors de docs/product/" "$(write_input "$W" /work/proj/notes/x.ipynb NotebookEdit)"
check block "git status (aucun shell)" "$(shell_input "$W" 'git status')"
check block "ls (aucun shell)" "$(shell_input "$W" 'ls docs')"
check block "Monitor (aucun shell)" "$(shell_input "$W" 'tail -f log' Monitor)"
check block "PowerShell (aucun shell)" "$(shell_input "$W" 'Get-ChildItem docs' PowerShell)"
run_hook "$GUARD" "$(write_input "$W" /work/proj/docs/technical/TRD.md)"
[[ $HOOK_STDERR == *writer* && $HOOK_STDERR == *docs/product/* && $HOOK_STDERR == *plugin-orchestrator* ]] \
  && pass "le refus d'écriture nomme le plugin, l'agent et docs/product/" \
  || fail "le refus d'écriture nomme le plugin, l'agent et docs/product/" "$HOOK_STDERR"
[[ $HOOK_STDERR == *OPEN_QUESTIONS* ]] && pass "le refus dit de signaler sous OPEN_QUESTIONS, pas de contourner" \
  || fail "le refus dit de signaler sous OPEN_QUESTIONS, pas de contourner" "$HOOK_STDERR"
run_hook "$GUARD" "$(shell_input "$W" 'git status')"
[[ $HOOK_STDERR == *writer* && $HOOK_STDERR == *"aucune commande"* ]] \
  && pass "le refus de commande dit que l'agent n'a aucun shell" || fail "le refus de commande dit que l'agent n'a aucun shell" "$HOOK_STDERR"

echo "# un agent sans écriture, git en lecture (fixture shell)"
S="$P:shell"
check block "Write" "$(write_input "$S" /work/proj/docs/review.md)"
check block "Edit" "$(write_input "$S" /work/proj/src/a.ts Edit)"
check block "NotebookEdit" "$(write_input "$S" /work/proj/docs/x.ipynb NotebookEdit)"
check allow "git status" "$(shell_input "$S" 'git status --short')"
check allow "git log" "$(shell_input "$S" 'git log --oneline main..HEAD')"
check allow "git diff" "$(shell_input "$S" 'git diff --name-only main...HEAD -- app backend')"
check allow "git show" "$(shell_input "$S" 'git show HEAD:backend/openapi.yaml')"
check allow "git ls-files" "$(shell_input "$S" 'git ls-files -- app/lib')"
check allow "git rev-parse" "$(shell_input "$S" 'git rev-parse --show-toplevel')"
check allow "git branch --show-current" "$(shell_input "$S" 'git branch --show-current')"
check allow "git --no-pager diff compte comme git diff" "$(shell_input "$S" 'git --no-pager diff')"
check allow "un mot cité reste un mot" "$(shell_input "$S" "git log --format='%h %s'")"
check block "git branch <nom> crée une branche" "$(shell_input "$S" 'git branch new-branch')"
check block "git branch -D" "$(shell_input "$S" 'git branch -D main')"
check block "git branch seul n'est pas git branch --show-current" "$(shell_input "$S" 'git branch')"
check block "git commit" "$(shell_input "$S" 'git commit -m x')"
check block "git add" "$(shell_input "$S" 'git add docs')"
check block "git push" "$(shell_input "$S" 'git push')"
check block "git checkout" "$(shell_input "$S" 'git checkout main')"
check block "git stash" "$(shell_input "$S" 'git stash')"
check block "git -C ailleurs" "$(shell_input "$S" 'git -C .. diff')"
check block "git diff --output écrit un fichier" "$(shell_input "$S" 'git diff --output=/tmp/x')"
check block "git log --output écrit un fichier" "$(shell_input "$S" 'git log --output /tmp/x')"
check block "commande composée" "$(shell_input "$S" 'git status && git add .')"
check block "redirection vers un fichier" "$(shell_input "$S" 'git diff > out.txt')"
check block "tube" "$(shell_input "$S" 'git diff | tee /tmp/x')"
check block "substitution de commande" "$(shell_input "$S" 'git show $(cat list)')"
check block "affectation en tête" "$(shell_input "$S" 'GIT_DIR=/x git status')"
check block "écriture par echo" "$(shell_input "$S" 'echo x > docs/a.md')"
check block "écriture par sed" "$(shell_input "$S" 'sed -i s/a/b/ docs/a.md')"
check block "cat (Read à la place)" "$(shell_input "$S" 'cat backend/openapi.yaml')"
check block "curl" "$(shell_input "$S" 'curl https://example.test/openapi.json')"
check block "flutter test" "$(shell_input "$S" 'flutter test')"
check block "commande vide" "$(shell_input "$S" '')"
check block "command non textuel" "$(agent_input "$S" Bash '{"command": ["git", "status"]}')"
check block "Monitor hors de la liste" "$(shell_input "$S" 'tail -f log' Monitor)"
check block "PowerShell hors de la liste" "$(shell_input "$S" 'Remove-Item src' PowerShell)"
run_hook "$GUARD" "$(write_input "$S" /work/proj/docs/review.md)"
[[ $HOOK_STDERR == *shell* && $HOOK_STDERR == *"aucun fichier"* ]] \
  && pass "le refus d'écriture dit que l'agent n'écrit aucun fichier" || fail "le refus d'écriture dit que l'agent n'écrit aucun fichier" "$HOOK_STDERR"
run_hook "$GUARD" "$(shell_input "$S" 'git push')"
[[ $HOOK_STDERR == *shell* && $HOOK_STDERR == *"git status"* && $HOOK_STDERR == *"git branch --show-current"* ]] \
  && pass "le refus de commande liste les commandes permises" || fail "le refus de commande liste les commandes permises" "$HOOK_STDERR"

echo "# deux dossiers et une liste à un mot de plus (fixture both)"
B="$P:both"
check allow "écrit sous docs/" "$(write_input "$B" /work/proj/docs/technical/ARCHITECTURE.md)"
check allow "écrit sous test/" "$(write_input "$B" /work/proj/test/a_test.ts Edit)"
check block "écrit src/" "$(write_input "$B" /work/proj/src/a.ts)"
check block "testing/ n'est pas test/" "$(write_input "$B" /work/proj/testing/a.ts)"
check allow "npm test" "$(shell_input "$B" 'npm test')"
check allow "npm test avec des options" "$(shell_input "$B" 'npm test -- --watch=false')"
check block "npm seul est plus court que l'entrée" "$(shell_input "$B" 'npm')"
check block "npm run n'est pas npm test" "$(shell_input "$B" 'npm run build')"
check block "npm test --output= écrit un fichier" "$(shell_input "$B" 'npm test --output=x')"
run_hook "$GUARD" "$(write_input "$B" /work/proj/src/a.ts)"
[[ $HOOK_STDERR == *"docs/"* && $HOOK_STDERR == *"test/"* ]] && pass "le refus d'écriture liste les deux dossiers" \
  || fail "le refus d'écriture liste les deux dossiers" "$HOOK_STDERR"

echo "# racine du projet"
check allow "CLAUDE_PROJECT_DIR est la racine quand il est posé" \
  "$(agent_input "$W" Write '{"file_path": "/other/root/docs/product/a.md", "content": "x"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check block "le cwd n'est pas utilisé quand CLAUDE_PROJECT_DIR est posé" \
  "$(agent_input "$W" Write '{"file_path": "/work/proj/sub/docs/product/a.md", "content": "x"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check allow "sans CLAUDE_PROJECT_DIR, le cwd de l'entrée est la racine" \
  "$(agent_input "$W" Write '{"file_path": "/work/proj/sub/docs/product/a.md", "content": "x"}' /work/proj/sub)"
check block "racine inconnue : bloqué" "$(agent_input "$W" Write '{"file_path": "/work/proj/docs/product/a.md", "content": "x"}' "")"

echo "# les agents que le plugin déclare, chacun tenu à sa propre entrée"
GUARD=$HOOK
if [[ ! -f $SCOPE_JSON ]]; then
  skip "agents déclarés" "hooks/agent-scope.json absent : aucun agent à portée"
elif ! jq -e 'type == "object"' "$SCOPE_JSON" >/dev/null 2>&1; then
  fail "hooks/agent-scope.json est un objet JSON"
else
  while IFS= read -r agent; do
    [[ $agent == "$P:"* ]] && pass "$agent : préfixe du plugin" || fail "$agent : préfixe du plugin"
    dirs=$(jq -r --arg a "$agent" '.[$a].write // [] | .[]' "$SCOPE_JSON")
    if [[ -n $dirs ]]; then
      while IFS= read -r dir; do
        check allow "$agent : écrit sous $dir" "$(write_input "$agent" "/work/proj/${dir%/}/x.md")"
      done <<<"$dirs"
      check block "$agent : écriture hors de sa portée bloquée" "$(write_input "$agent" "/work/proj/hors-portee-$RANDOM/x.md" Edit)"
    else
      check block "$agent : n'écrit rien" "$(write_input "$agent" /work/proj/docs/x.md)"
    fi
    commands=$(jq -r --arg a "$agent" '.[$a].bash // [] | .[]' "$SCOPE_JSON")
    if [[ -n $commands ]]; then
      while IFS= read -r command; do
        check allow "$agent : « $command » permis" "$(shell_input "$agent" "$command")"
        check block "$agent : « $command » composé bloqué" "$(shell_input "$agent" "$command; rm -rf src")"
      done <<<"$commands"
      check block "$agent : commande hors liste bloquée" "$(shell_input "$agent" 'rm -rf src')"
    else
      check block "$agent : aucun shell" "$(shell_input "$agent" 'git status')"
    fi
  done < <(jq -r 'keys[]' "$SCOPE_JSON")
fi

echo "# erreurs : fail-closed pour les agents du plugin, inerte ailleurs"
GUARD=$FHOOK
check block "JSON malformé d'un agent du plugin" "{\"agent_type\": \"$P:shell\", \"tool_name\": "
check allow "JSON malformé sans le préfixe du plugin" '{"tool_name": '
nojq=$(restricted_path)
check block "jq absent pour un agent du plugin" "$(write_input "$W" /work/proj/docs/product/a.md)" PATH="$nojq"
[[ $HOOK_STDERR == *jq* ]] && pass "jq absent : nommé dans la raison" || fail "jq absent : nommé dans la raison" "$HOOK_STDERR"
check allow "jq absent ailleurs" "$(write_input "" /work/proj/src/a.ts)" PATH="$nojq"
rm -r "$nojq"
nolib="$work/nolib"
mkdir -p "$nolib/hooks/scripts"
cp "$HOOK" "$nolib/hooks/scripts/"
cp "$fixture/hooks/agent-scope.json" "$nolib/hooks/"
run_hook "$nolib/hooks/scripts/agent-scope-guard.sh" "$(shell_input "$S" 'git status')"
expect_blocked "lexer partagé absent : bloqué pour un agent du plugin"
run_hook "$nolib/hooks/scripts/agent-scope-guard.sh" "$(shell_input "" 'git status')"
expect_silent_allow "lexer partagé absent : inerte ailleurs"

finish
