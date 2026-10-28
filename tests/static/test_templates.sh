#!/usr/bin/env bash
# templates/: the files copied or filled into the projects, never run — the checkpoint format,
# the project configuration (schema 2, parts), the generic permission rules, and the document
# templates (PRD, DECISIONS, and the CLAUDE.md conventions file, consumed by bootstrap-project) at
# the fixed header that doc-status-guard and scripts/orch.sh approve read. Generic: nothing of a
# language in them; the scaffold of the language plugin brings its own fragment.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_templates
T="$PLUGIN_ROOT/templates"
ORCH="$PLUGIN_ROOT/scripts/orch.sh"
LIB="$PLUGIN_ROOT/scripts/lib/doc-status.sh"

if [[ ! -d $T ]]; then
  fail "templates/ présent" "absent : $T"
  finish
  exit
fi
pass "templates/ présent"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# has <label> <file> <fixed string> / lacks: the file holds the string, or does not.
has() { grep -qF -- "$3" "$2" && pass "$1" || fail "$1" "absent de ${2#"$T"/} : $3"; }
lacks() { grep -qF -- "$3" "$2" && fail "$1" "présent dans ${2#"$T"/} : $3" || pass "$1"; }
# shape <checkpoint>: its headings and its header keys, in order.
shape() { grep -E '^(#|[a-z_]+:)' "$1" | sed -E 's/^([a-z_]+:).*/\1/'; }

echo "# checkpoint.md"
CHECKPOINT="$T/checkpoint.md"
if [[ -f $CHECKPOINT ]]; then
  pass "templates/checkpoint.md présent"
  for needle in "# Checkpoint" "updated:" "skill:" "feature:" "branch:" "last_commit:" "## Steps" "## Test results" "| command | result | when |" "## Next action" "## Blockers / open questions"; do
    has "checkpoint.md : $needle" "$CHECKPOINT" "$needle"
  done
  # What orch.sh checkpoint writes is the template: same headings and keys, in the same order.
  if [[ -f $ORCH ]]; then
    mkdir -p "$work/proj/.forge"
    "$BASH" "$ORCH" checkpoint "$work/proj" start --skill bootstrap-project --steps "A|B" >/dev/null 2>&1
    [[ $(shape "$CHECKPOINT") == "$(shape "$work/proj/.forge/checkpoint.md" 2>/dev/null)" ]] \
      && pass "orch.sh checkpoint écrit les titres et les clés du gabarit, dans son ordre" \
      || fail "orch.sh checkpoint écrit les titres et les clés du gabarit, dans son ordre" "gabarit : $(shape "$CHECKPOINT" | paste -sd'|' -) ; orch.sh : $(shape "$work/proj/.forge/checkpoint.md" 2>/dev/null | paste -sd'|' -)"
  else
    fail "orch.sh checkpoint écrit les titres et les clés du gabarit, dans son ordre" "scripts/orch.sh absent"
  fi
else
  fail "templates/checkpoint.md présent"
fi

echo "# forge-config.yaml"
CONFIG="$T/forge-config.yaml"
if [[ -f $CONFIG ]]; then
  pass "templates/forge-config.yaml présent"
  grep -qx 'schema_version: 2' "$CONFIG" && pass "schema_version: 2" || fail "schema_version: 2" "$(grep -n schema_version "$CONFIG")"
  top=$(grep -oE '^[a-z_]+:' "$CONFIG" | tr -d : | paste -sd' ' -)
  [[ $top == "schema_version project authorizations parts" ]] && pass "clés de premier niveau : schema_version, project, authorizations, parts" \
    || fail "clés de premier niveau : schema_version, project, authorizations, parts" "$top"
  grep -qE '^  default_branch: ' "$CONFIG" && pass "project.default_branch" || fail "project.default_branch"
  grep -qE '^  branch_prefix: ' "$CONFIG" && pass "project.branch_prefix" || fail "project.branch_prefix"
  auth=$(awk '/^authorizations:/ { inside = 1; next } /^[^ #]/ { inside = 0 } inside && !/^[[:space:]]*#/ && /:/ { print }' "$CONFIG")
  not_false=$(grep -vE '^\s+[a-z_]+: false(\s+#.*)?$' <<<"$auth")
  [[ -n $auth && -z $not_false ]] && pass "chaque autorisation est false" || fail "chaque autorisation est false" "$not_false"
  for key in push_feature_branches open_pull_requests update_own_pull_requests create_remote_repo merge publish_release; do
    grep -qE "^\s+$key: false" <<<"$auth" && pass "autorisation $key: false" || fail "autorisation $key: false"
  done
  parts=$(awk '/^parts:/ { inside = 1; next } /^[^ #]/ { inside = 0 } inside { print }' "$CONFIG")
  [[ -n $parts ]] && pass "bloc parts présent" || fail "bloc parts présent"
  for key in path plugin interface toolchain; do
    grep -qE "^    $key:" <<<"$parts" && pass "une partie déclare $key" || fail "une partie déclare $key"
  done
  grep -qE '^    interface: 1$' <<<"$parts" && pass "interface: 1" || fail "interface: 1" "$(grep -n interface "$CONFIG")"
  grep -qE '^    path: \.$' <<<"$parts" && pass "la partie unique a path: . (mono-partie)" || fail "la partie unique a path: . (mono-partie)" "$(grep -n 'path:' "$CONFIG")"
  for key in test format analyze add_dep manifests; do
    grep -qE "^      $key:" <<<"$parts" && pass "toolchain.$key" || fail "toolchain.$key"
  done
  grep -qE '^ *#.*integration_test' "$CONFIG" && pass "integration_test documentée comme optionnelle" || fail "integration_test documentée comme optionnelle"
  grep -qE '^ *#.*platforms' "$CONFIG" && pass "platforms documentée comme optionnelle, propre au langage" || fail "platforms documentée comme optionnelle, propre au langage"
  grep -qE '^platforms:' "$CONFIG" && fail "plus de platforms au premier niveau (sous la partie)" || pass "plus de platforms au premier niveau (sous la partie)"
  grep -qiE 'edited by the user|user only|utilisateur' "$CONFIG" && pass "l'en-tête dit que seul l'utilisateur l'édite" || fail "l'en-tête dit que seul l'utilisateur l'édite"
else
  fail "templates/forge-config.yaml présent"
fi

echo "# project-settings.json"
SETTINGS="$T/project-settings.json"
if ! jq -e '.permissions | (.allow, .ask, .deny) | type == "array"' "$SETTINGS" >/dev/null 2>&1; then
  fail "JSON valide avec permissions.allow, ask et deny" "absent ou invalide : $SETTINGS"
else
  pass "JSON valide avec permissions.allow, ask et deny"
  allow=$(jq -r '.permissions.allow[]' "$SETTINGS")
  ask=$(jq -r '.permissions.ask[]' "$SETTINGS")
  deny=$(jq -r '.permissions.deny[]' "$SETTINGS")
  all=$(jq -r '.permissions[][]' "$SETTINGS")
  risky=$(grep -nE 'push|merge|reset|clean|rm |delete|publish|\bforce|branch -D|checkout|restore|stash|^Bash$|^Bash\(\*\)$' <<<"$allow")
  [[ -z $risky ]] && pass "aucune règle allow ne couvre push, merge, reset, clean ni une suppression" \
    || fail "aucune règle allow ne couvre push, merge, reset, clean ni une suppression" "$risky"
  missing=""
  for rule in 'Bash(git reset --hard*)' 'Bash(git clean *)' 'Bash(git push --force*)' 'Bash(git push * --force*)' \
    'Bash(git push -f*)' 'Bash(git push * -f*)' 'Bash(git push * +*)' 'Bash(git branch -D *)' \
    'Bash(gh repo delete *)' 'Bash(gh pr merge *)' \
    'Read(./.env)' 'Read(./.env.*)' 'Read(./**/key.properties)' 'Read(./**/*.jks)' 'Read(./**/*.keystore)' \
    'Read(./**/*.p12)' 'Read(./**/*.pfx)' 'Edit(./.forge/config.yaml)'; do
    grep -qxF "$rule" <<<"$deny" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "deny génériques : git destructif, gh qui supprime ou fusionne, lecture des fichiers sensibles, config.yaml" \
    || fail "deny génériques : git destructif, gh qui supprime ou fusionne, lecture des fichiers sensibles, config.yaml" "manque :$missing"
  missing=""
  for rule in 'Bash(git commit *)' 'Bash(git push *)' 'Bash(git add -A*)' 'Bash(git add .)' 'Bash(git add --all*)' \
    'Bash(gh pr create *)' 'Bash(gh repo create *)' 'Bash(gh pr edit *)' 'Bash(gh issue create *)' 'Bash(gh run rerun *)' 'Bash(gh workflow run *)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "commit, push, git add -A et les gh qui changent GitHub ou dépensent des minutes demandent d'abord" \
    || fail "commit, push, git add -A et les gh qui changent GitHub ou dépensent des minutes demandent d'abord" "manque :$missing"
  missing=""
  for rule in 'Bash(git status)' 'Bash(git status *)' 'Bash(git diff *)' 'Bash(git log *)' 'Bash(git add *)' 'Bash(git switch *)' \
    'Bash(git remote -v)' 'Bash(git rev-parse *)' 'Bash(git branch --show-current)' \
    'Bash(gh --version)' 'Bash(gh auth status)' 'Bash(gh repo view)' 'Bash(gh repo view *)' 'Bash(gh pr view *)' 'Bash(gh pr checks *)' \
    'Bash(gh run list *)' 'Bash(gh run view *)' 'Bash(gh run watch *)' 'Bash(gh workflow list)' 'Bash(gh workflow view *)' \
    'Bash(gh issue list *)' 'Bash(gh issue view *)'; do
    grep -qxF "$rule" <<<"$allow" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "les git et gh en lecture des workflows passent sans demander" \
    || fail "les git et gh en lecture des workflows passent sans demander" "manque :$missing"
  risky=$(grep -nE 'gh (pr (create|edit)|repo create|issue create|workflow run|run (rerun|cancel|download)|api|auth (token|login))|show-token|^Bash\(gh \*\)$' <<<"$allow")
  [[ -z $risky ]] && pass "aucune règle allow ne change GitHub, ne se connecte ni ne montre un jeton" \
    || fail "aucune règle allow ne change GitHub, ne se connecte ni ne montre un jeton" "$risky"
  language=$(grep -niE 'flutter|\bdart\b|pub |pubspec|npm|pnpm|yarn|\bnode\b|\bpip\b|pytest|poetry|cargo|gradle|xcode' <<<"$all")
  [[ -z $language ]] && pass "aucune règle propre à un langage (le fragment vient du plugin de langage)" \
    || fail "aucune règle propre à un langage (le fragment vient du plugin de langage)" "$language"
  grep -q '^Write(' <<<"$all" && fail "aucune règle Write() (seules les règles Edit() protègent un fichier)" "$(grep '^Write(' <<<"$all")" \
    || pass "aucune règle Write() (seules les règles Edit() protègent un fichier)"
  grep -qF ':*' <<<"$all" && fail "forme à espace Bash(x *), pas l'ancienne :*" "$(grep -F ':*' <<<"$all")" \
    || pass "forme à espace Bash(x *), pas l'ancienne :*"
  bad=$(grep -vE '^(Bash|Read|Edit)\(' <<<"$all")
  [[ -z $bad ]] && pass "chaque règle est Bash(, Read( ou Edit(" || fail "chaque règle est Bash(, Read( ou Edit(" "$bad"
  dup=$(sort <<<"$all" | uniq -d)
  [[ -z $dup ]] && pass "aucune règle en double" || fail "aucune règle en double" "$dup"
fi

echo "# doc-templates"
D="$T/doc-templates"
for name in PRD DECISIONS; do
  [[ -f $D/$name.md ]] && pass "doc-templates/$name.md présent" || fail "doc-templates/$name.md présent"
done
if [[ -f $LIB ]]; then
  # shellcheck source=../../scripts/lib/doc-status.sh
  source "$LIB"
fi
for name in PRD DECISIONS; do
  f="$D/$name.md"
  [[ -f $f ]] || continue
  for row in "| Objective |" "| Status | DRAFT |" "| Approved |" "| Assumptions |" "| Confirmed decisions |" "| Related documents |" "| Verification criteria |"; do
    has "$name.md : ligne $row" "$f" "$row"
  done
  if declare -F doc_status >/dev/null; then
    [[ $(doc_status "$f") == DRAFT ]] && pass "$name.md : doc-status.sh lit DRAFT" || fail "$name.md : doc-status.sh lit DRAFT" "$(doc_status "$f")"
  else
    fail "$name.md : doc-status.sh lit DRAFT" "scripts/lib/doc-status.sh absent"
  fi
  has "$name.md : les trois états sont nommés (REVIEW)" "$f" "REVIEW"
  has "$name.md : l'approbation est explicite" "$f" "explicit approval"
done
PRD="$D/PRD.md"
if [[ -f $PRD ]]; then
  for needle in "# PRD —" "## Problem" "## Users" "## Scope" "## Acceptance criteria" "| ID | Criterion | Priority |" "AC-001" "## Non-goals" "## Open questions" "docs/engineering/DECISIONS.md"; do
    has "PRD.md : $needle" "$PRD" "$needle"
  done
  lacks "PRD.md : plus de plan d'implémentation en document lié (il est par partie)" "$PRD" "IMPLEMENTATION_PLAN"
fi
DECISIONS="$D/DECISIONS.md"
if [[ -f $DECISIONS ]]; then
  for needle in "# Decisions —" "## ADR-001 — Initial stack" "- Parts concerned:" "docs/product/PRD.md"; do
    has "DECISIONS.md : $needle" "$DECISIONS" "$needle"
  done
  lacks "DECISIONS.md : plus de « Platforms checked » (les plateformes sont l'affaire du plugin de langage)" "$DECISIONS" "Platforms checked"
fi
echo "# CLAUDE.md (conventions du projet, sans ligne de statut : pas un document projet)"
CONVENTIONS="$D/CLAUDE.md"
if [[ -f $CONVENTIONS ]]; then
  pass "doc-templates/CLAUDE.md présent"
  for needle in "plugin-orchestrator" "/plugin-orchestrator:create-feature" "/plugin-orchestrator:git-workflow" "/plugin-orchestrator:github-workflow" "/plugin-orchestrator:recover-session" ".forge/checkpoint.md" ".forge/config.yaml" "toolchain" "APPROVED"; do
    has "CLAUDE.md : $needle" "$CONVENTIONS" "$needle"
  done
  lacks "CLAUDE.md : aucune ligne de statut" "$CONVENTIONS" "| Status |"
else
  fail "doc-templates/CLAUDE.md présent"
fi
echo "# générique"
language=$(grep -rniE 'flutter|\bdart\b|pubspec|lib/features' "$T" 2>/dev/null)
[[ -z $language ]] && pass "aucun gabarit ne nomme un langage" || fail "aucun gabarit ne nomme un langage" "$(head -n 3 <<<"$language")"

echo "# les gabarits de documents s'approuvent par orch.sh approve"
if [[ -f $ORCH && -f $LIB ]]; then
  mkdir -p "$work/app/.forge" "$work/app/docs/product" "$work/app/docs/engineering"
  cp "$D/PRD.md" "$work/app/docs/product/PRD.md" 2>/dev/null
  cp "$D/DECISIONS.md" "$work/app/docs/engineering/DECISIONS.md" 2>/dev/null
  for rel in docs/product/PRD.md docs/engineering/DECISIONS.md; do
    if [[ ! -f $work/app/$rel ]]; then
      fail "$rel : approuvé par orch.sh approve" "gabarit absent"
      continue
    fi
    if "$BASH" "$ORCH" approve "$work/app/$rel" --quote "je valide" >/dev/null 2>&1 && [[ $(doc_status "$work/app/$rel") == APPROVED ]]; then
      pass "$rel : approuvé par orch.sh approve"
    else
      fail "$rel : approuvé par orch.sh approve" "$(grep -m 1 -E '^\| *Status' "$work/app/$rel")"
    fi
    grep -q "$rel" "$work/app/.forge/approvals.log" 2>/dev/null && pass "$rel : empreinte au journal" || fail "$rel : empreinte au journal"
  done
else
  fail "les gabarits de documents s'approuvent par orch.sh approve" "scripts/orch.sh ou la bibliothèque absents"
fi

finish
