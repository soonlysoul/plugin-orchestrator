#!/usr/bin/env bash
# agent-scope-guard: simulated inputs, no session. PreToolUse hook on Edit|Write|NotebookEdit|
# Bash|PowerShell|Monitor. For the plugin's own agents (agent_type plugin-orchestrator:<agent>),
# the directories each one may write and its allowlist of single shell commands; inert for
# everything else, the same agent names of another plugin included. Fail-closed for them.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agent_scope_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/agent-scope-guard.sh"
P=plugin-orchestrator

echo "# contrat du squelette (entrées qui portent le préfixe du plugin, le contexte du hook)"
run_hook "$HOOK" "pas du json, mais $P:product-architect"
expect_blocked "squelette : entrée illisible bloquée"
no_jq=$(mktemp -d)
run_hook "$HOOK" "{\"agent_type\": \"$P:product-architect\"}" PATH="$no_jq"
rm -rf "$no_jq"
expect_blocked "squelette : jq absent bloqué"

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

# check <allow|block> <label> <input> [env...]
check() {
  local expected=$1 label=$2 input=$3
  shift 3
  run_hook "$HOOK" "$input" "$@"
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
check allow "Read n'est pas restreint" "$(agent_input "$P:integration-reviewer" Read '{"file_path": "/work/proj/src/a.ts"}')"
check block "un agent inconnu de ce plugin est bloqué" "$(write_input "$P:release-manager" /work/proj/docs/a.md)"

echo "# product-architect"
PA="$P:product-architect"
check allow "écrit le PRD" "$(write_input "$PA" /work/proj/docs/product/PRD.md)"
check allow "édite un fichier sous docs/product/" "$(write_input "$PA" /work/proj/docs/product/notes/brief.md Edit)"
check block "écrit le TRD" "$(write_input "$PA" /work/proj/docs/technical/TRD.md)"
check block "écrit DECISIONS.md" "$(write_input "$PA" /work/proj/docs/engineering/DECISIONS.md)"
check block "écrit docs/ lui-même" "$(write_input "$PA" /work/proj/docs/PRD.md)"
check block "docs/productx/ n'est pas docs/product/" "$(write_input "$PA" /work/proj/docs/productx/PRD.md)"
check block "remonte hors de docs/product/ avec .." "$(write_input "$PA" /work/proj/docs/product/../technical/TRD.md)"
check block "un . dans le chemin" "$(write_input "$PA" /work/proj/docs/product/./PRD.md)"
check block "écrit src/" "$(write_input "$PA" /work/proj/src/main.ts)"
check block "écrit hors du projet" "$(write_input "$PA" /etc/hosts)"
check block "chemin relatif" "$(write_input "$PA" docs/product/PRD.md)"
check block "Write sans file_path" "$(agent_input "$PA" Write '{"content": "x"}')"
check block "file_path non textuel" "$(agent_input "$PA" Write '{"file_path": 7, "content": "x"}')"
check block "NotebookEdit hors de docs/product/" "$(write_input "$PA" /work/proj/notes/x.ipynb NotebookEdit)"
check allow "NotebookEdit sous docs/product/" "$(write_input "$PA" /work/proj/docs/product/x.ipynb NotebookEdit)"
check block "git status (aucun shell)" "$(shell_input "$PA" 'git status')"
check block "ls (aucun shell)" "$(shell_input "$PA" 'ls docs')"
check block "Monitor (aucun shell)" "$(shell_input "$PA" 'tail -f log' Monitor)"
check block "PowerShell (aucun shell)" "$(shell_input "$PA" 'Get-ChildItem docs' PowerShell)"
run_hook "$HOOK" "$(write_input "$PA" /work/proj/docs/technical/TRD.md)"
[[ $HOOK_STDERR == *product-architect* && $HOOK_STDERR == *docs/product/* && $HOOK_STDERR == *plugin-orchestrator* ]] \
  && pass "le refus d'écriture nomme le plugin, l'agent et docs/product/" \
  || fail "le refus d'écriture nomme le plugin, l'agent et docs/product/" "$HOOK_STDERR"
[[ $HOOK_STDERR == *OPEN_QUESTIONS* ]] && pass "le refus dit de signaler sous OPEN_QUESTIONS, pas de contourner" \
  || fail "le refus dit de signaler sous OPEN_QUESTIONS, pas de contourner" "$HOOK_STDERR"
run_hook "$HOOK" "$(shell_input "$PA" 'git status')"
[[ $HOOK_STDERR == *product-architect* && $HOOK_STDERR == *"aucune commande"* ]] \
  && pass "le refus de commande dit que product-architect n'a aucun shell" \
  || fail "le refus de commande dit que product-architect n'a aucun shell" "$HOOK_STDERR"

echo "# project-architect"
AR="$P:project-architect"
check allow "écrit l'architecture du découpage" "$(write_input "$AR" /work/proj/docs/technical/ARCHITECTURE.md)"
check allow "écrit le contrat d'API" "$(write_input "$AR" /work/proj/docs/technical/CONTRACT.md)"
check allow "édite les ADR projet" "$(write_input "$AR" /work/proj/docs/engineering/DECISIONS.md Edit)"
check allow "docs/product/ est sous docs/" "$(write_input "$AR" /work/proj/docs/product/PRD.md Edit)"
check block "écrit src/" "$(write_input "$AR" /work/proj/src/main.ts)"
check block "docs2/ n'est pas docs/" "$(write_input "$AR" /work/proj/docs2/x.md)"
check block "les documents d'une partie restent au plugin de langage" "$(write_input "$AR" /work/proj/app/docs/technical/TRD.md)"
check block "écrit CLAUDE.md à la racine" "$(write_input "$AR" /work/proj/CLAUDE.md)"
check block "écrit .forge/config.yaml" "$(write_input "$AR" /work/proj/.forge/config.yaml Edit)"
check block "remonte hors de docs/ avec .." "$(write_input "$AR" /work/proj/docs/../src/a.ts)"
check block "écrit hors du projet" "$(write_input "$AR" /tmp/docs/x.md)"
check allow "git status" "$(shell_input "$AR" 'git status')"
check allow "git log" "$(shell_input "$AR" 'git log --oneline -5')"
check allow "git diff" "$(shell_input "$AR" 'git diff main...HEAD')"
check allow "git show" "$(shell_input "$AR" 'git show HEAD:docs/product/PRD.md')"
check allow "git ls-files" "$(shell_input "$AR" 'git ls-files app')"
check allow "git rev-parse" "$(shell_input "$AR" 'git rev-parse --show-toplevel')"
check allow "git branch --show-current" "$(shell_input "$AR" 'git branch --show-current')"
check allow "git --no-pager log" "$(shell_input "$AR" 'git --no-pager log --oneline')"
check block "git branch <nom> crée une branche" "$(shell_input "$AR" 'git branch new-branch')"
check block "git branch -D" "$(shell_input "$AR" 'git branch -D main')"
check block "git commit" "$(shell_input "$AR" 'git commit -m x')"
check block "git add" "$(shell_input "$AR" 'git add docs')"
check block "git push" "$(shell_input "$AR" 'git push')"
check block "git checkout" "$(shell_input "$AR" 'git checkout main')"
check block "git stash" "$(shell_input "$AR" 'git stash')"
check block "git -C ailleurs" "$(shell_input "$AR" 'git -C .. diff')"
check block "git diff --output écrit un fichier" "$(shell_input "$AR" 'git diff --output=/tmp/x')"
check block "git log --output écrit un fichier" "$(shell_input "$AR" 'git log --output /tmp/x')"
check block "commande composée" "$(shell_input "$AR" 'git status && git add .')"
check block "redirection vers un fichier" "$(shell_input "$AR" 'git diff > out.txt')"
check block "substitution de commande" "$(shell_input "$AR" 'git show $(cat list)')"
check block "affectation en tête" "$(shell_input "$AR" 'GIT_DIR=/x git status')"
check block "écriture par echo" "$(shell_input "$AR" 'echo x > docs/a.md')"
check block "écriture par sed" "$(shell_input "$AR" 'sed -i s/a/b/ docs/a.md')"
check block "les tests d'une partie ne sont pas son affaire" "$(shell_input "$AR" 'flutter test')"
check block "npm test" "$(shell_input "$AR" 'npm test')"
check block "commande vide" "$(shell_input "$AR" '')"
check block "command non textuel" "$(agent_input "$AR" Bash '{"command": ["git", "status"]}')"
check block "Monitor hors de la liste" "$(shell_input "$AR" 'tail -f log' Monitor)"
check block "PowerShell hors de la liste" "$(shell_input "$AR" 'Remove-Item src' PowerShell)"
run_hook "$HOOK" "$(write_input "$AR" /work/proj/src/main.ts)"
[[ $HOOK_STDERR == *project-architect* && $HOOK_STDERR == *"docs/"* ]] \
  && pass "le refus d'écriture nomme l'agent et son dossier" || fail "le refus d'écriture nomme l'agent et son dossier" "$HOOK_STDERR"
run_hook "$HOOK" "$(shell_input "$AR" 'git push')"
[[ $HOOK_STDERR == *project-architect* && $HOOK_STDERR == *"git status"* && $HOOK_STDERR == *"git branch --show-current"* ]] \
  && pass "le refus de commande liste les commandes permises" || fail "le refus de commande liste les commandes permises" "$HOOK_STDERR"

echo "# integration-reviewer"
IR="$P:integration-reviewer"
check block "Write" "$(write_input "$IR" /work/proj/docs/review.md)"
check block "Edit" "$(write_input "$IR" /work/proj/src/a.ts Edit)"
check block "NotebookEdit" "$(write_input "$IR" /work/proj/docs/x.ipynb NotebookEdit)"
check allow "git diff de la branche" "$(shell_input "$IR" 'git diff main...HEAD')"
check allow "git diff --name-only" "$(shell_input "$IR" 'git diff --name-only main...HEAD -- app backend')"
check allow "git log" "$(shell_input "$IR" 'git log --oneline main..HEAD')"
check allow "git show" "$(shell_input "$IR" 'git show HEAD:backend/openapi.yaml')"
check allow "git status" "$(shell_input "$IR" 'git status --short')"
check allow "git ls-files" "$(shell_input "$IR" 'git ls-files -- app/lib')"
check allow "git rev-parse" "$(shell_input "$IR" 'git rev-parse HEAD')"
check allow "git branch --show-current" "$(shell_input "$IR" 'git branch --show-current')"
check allow "git --no-pager diff" "$(shell_input "$IR" 'git --no-pager diff')"
check block "git diff --output écrit un fichier" "$(shell_input "$IR" 'git diff --output=/tmp/x')"
check block "git push" "$(shell_input "$IR" 'git push')"
check block "git checkout" "$(shell_input "$IR" 'git checkout main')"
check block "git branch -D" "$(shell_input "$IR" 'git branch -D feature')"
check block "git -C ailleurs" "$(shell_input "$IR" 'git -C .. diff')"
check block "cat (Read à la place)" "$(shell_input "$IR" 'cat backend/openapi.yaml')"
check block "curl" "$(shell_input "$IR" 'curl https://example.test/openapi.json')"
check block "npm run" "$(shell_input "$IR" 'npm run build')"
check block "commande composée" "$(shell_input "$IR" 'git diff | tee /tmp/x')"
check block "Monitor hors de la liste" "$(shell_input "$IR" 'tail -f log' Monitor)"
run_hook "$HOOK" "$(write_input "$IR" /work/proj/docs/review.md)"
[[ $HOOK_STDERR == *integration-reviewer* && $HOOK_STDERR == *"aucun fichier"* ]] \
  && pass "le refus d'écriture dit que integration-reviewer n'écrit aucun fichier" \
  || fail "le refus d'écriture dit que integration-reviewer n'écrit aucun fichier" "$HOOK_STDERR"
run_hook "$HOOK" "$(shell_input "$IR" 'git push')"
[[ $HOOK_STDERR == *integration-reviewer* && $HOOK_STDERR == *"git diff"* ]] \
  && pass "le refus de commande liste les commandes permises" || fail "le refus de commande liste les commandes permises" "$HOOK_STDERR"

echo "# racine du projet"
check allow "CLAUDE_PROJECT_DIR est la racine quand il est posé" \
  "$(agent_input "$AR" Write '{"file_path": "/other/root/docs/a.md", "content": "x"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check block "le cwd n'est pas utilisé quand CLAUDE_PROJECT_DIR est posé" \
  "$(agent_input "$AR" Write '{"file_path": "/work/proj/sub/docs/a.md", "content": "x"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check allow "sans CLAUDE_PROJECT_DIR, le cwd de l'entrée est la racine" \
  "$(agent_input "$AR" Write '{"file_path": "/work/proj/sub/docs/a.md", "content": "x"}' /work/proj/sub)"
check block "racine inconnue : bloqué" "$(agent_input "$AR" Write '{"file_path": "/work/proj/docs/a.md", "content": "x"}' "")"

echo "# erreurs : fail-closed pour les agents du plugin, inerte ailleurs"
check block "JSON malformé d'un agent du plugin" "{\"agent_type\": \"$P:project-architect\", \"tool_name\": "
check allow "JSON malformé sans le préfixe du plugin" '{"tool_name": '
nojq=$(restricted_path)
check block "jq absent pour un agent du plugin" "$(write_input "$AR" /work/proj/docs/a.md)" PATH="$nojq"
[[ $HOOK_STDERR == *jq* ]] && pass "jq absent : nommé dans la raison" || fail "jq absent : nommé dans la raison" "$HOOK_STDERR"
check allow "jq absent ailleurs" "$(write_input "" /work/proj/src/a.ts)" PATH="$nojq"
rm -r "$nojq"
nolib=$(mktemp -d)
cp "$HOOK" "$nolib/"
run_hook "$nolib/agent-scope-guard.sh" "$(shell_input "$IR" 'git status')"
expect_blocked "lexer partagé absent : bloqué pour un agent du plugin"
run_hook "$nolib/agent-scope-guard.sh" "$(shell_input "" 'git status')"
expect_silent_allow "lexer partagé absent : inerte ailleurs"
rm -r "$nolib"

# bash's case returns 0 when no branch matches: an agent given commands but no allowlist
# branch must still be refused. Proved on a copy with such an agent added.
orphan=$(mktemp -d)
cp -r "$SCRIPTS"/. "$orphan/"
sed -i 's/^  product-architect)$/  orphan-agent)\n    write_dirs=""\n    allowed_commands="git status"\n    ;;\n  product-architect)/' "$orphan/agent-scope-guard.sh"
grep -q '^  orphan-agent)$' "$orphan/agent-scope-guard.sh" && pass "agent orphelin injecté dans la copie" \
  || fail "agent orphelin injecté dans la copie" "le motif « product-architect) » n'est pas dans le hook"
run_hook "$orphan/agent-scope-guard.sh" "$(shell_input "$P:orphan-agent" 'git status')"
expect_blocked "un agent avec des commandes mais sans branche de liste blanche est refusé"
rm -r "$orphan"

finish
