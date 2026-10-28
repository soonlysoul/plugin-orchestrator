#!/usr/bin/env bash
# scripts/orch.sh: the deterministic tool of a .forge/ project, run here on throwaway projects,
# no session. The state directory (init), the checkpoint of the running skill (checkpoint start,
# done, block) in the format of templates/checkpoint.md, the status and the approval of a project
# document (status, approve) — an approval writes the two header rows and records the fingerprint
# that doc-status-guard compares, through the shared scripts/lib/doc-status.sh. Messages in
# French; refusal exit 1, missing prerequisite exit 2.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_orch
ORCH="$PLUGIN_ROOT/scripts/orch.sh"
LIB="$PLUGIN_ROOT/scripts/lib/doc-status.sh"
HOOK="$PLUGIN_ROOT/hooks/scripts/doc-status-guard.sh"

if [[ ! -f $ORCH ]]; then
  fail "scripts/orch.sh présent" "absent : $ORCH"
  finish
  exit
fi
pass "scripts/orch.sh présent"
if [[ ! -f $LIB ]]; then
  fail "scripts/lib/doc-status.sh présent" "absent : $LIB"
  finish
  exit
fi
# shellcheck source=../../scripts/lib/doc-status.sh
source "$LIB"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# run_orch <args...>: runs the tool (ORCH_BIN, under ORCH_PATH when set) and sets ORCH_STATUS,
# ORCH_STDOUT and ORCH_STDERR.
run_orch() {
  local out err
  out=$(mktemp) err=$(mktemp)
  env PATH="${ORCH_PATH:-$PATH}" "$BASH" "${ORCH_BIN:-$ORCH}" "$@" >"$out" 2>"$err"
  ORCH_STATUS=$?
  ORCH_STDOUT=$(<"$out") ORCH_STDERR=$(<"$err")
  rm -f "$out" "$err"
}
# expect_ok <label>: exit 0.
expect_ok() {
  [[ $ORCH_STATUS == 0 ]] && pass "$1" || fail "$1" "exit $ORCH_STATUS ; stderr : ${ORCH_STDERR:0:300}"
}
# expect_refused <label> [exit, 1 by default]: a reason on stderr, nothing on stdout.
expect_refused() {
  if [[ $ORCH_STATUS == "${2:-1}" && -n $ORCH_STDERR && -z $ORCH_STDOUT ]]; then
    pass "$1"
  else
    fail "$1" "attendu exit ${2:-1} avec une raison sur stderr, obtenu exit $ORCH_STATUS ; stdout : ${ORCH_STDOUT:0:200} ; stderr : ${ORCH_STDERR:0:200}"
  fi
}
# expect_line <label> <file> <regex> / refuse_line: a line of the file matches, or none does.
expect_line() {
  grep -qE -- "$3" "$2" && pass "$1" || fail "$1" "motif absent de ${2#"$work"/} : $3"
}
refuse_line() {
  grep -qE -- "$3" "$2" && fail "$1" "motif présent dans ${2#"$work"/} : $3" || pass "$1"
}
# new_doc <file> <status>: a document at the fixed header of the templates, under that status.
new_doc() {
  mkdir -p "${1%/*}"
  printf '# PRD — essai\n\n| | |\n| --- | --- |\n| Objective | What the app must do |\n| Status | %s |\n| Approved | — (date and approver, written only after the user'"'"'s explicit approval) |\n| Assumptions | none |\n\n## Problem\n\nText.\n' "$2" >"$1"
}
# post_input <file> <project>: the PostToolUse input doc-status-guard gets after a Write.
post_input() {
  jq -nc --arg f "$1" --arg d "$2" \
    '{session_id: "test", cwd: $d, hook_event_name: "PostToolUse", permission_mode: "default",
      tool_name: "Write", tool_input: {file_path: $f}, tool_response: {success: true}, tool_use_id: "toolu_test"}'
}

echo "# usage"
run_orch
expect_refused "sans argument : usage sur stderr, exit 1"
[[ $ORCH_STDERR == *init* && $ORCH_STDERR == *checkpoint* && $ORCH_STDERR == *status* && $ORCH_STDERR == *approve* ]] \
  && pass "l'usage nomme init, checkpoint, status et approve" || fail "l'usage nomme init, checkpoint, status et approve" "$ORCH_STDERR"
run_orch frobnicate
expect_refused "sous-commande inconnue : refusée"
run_orch help
[[ $ORCH_STATUS == 0 && $ORCH_STDOUT == *approve* ]] && pass "help : usage sur stdout, exit 0" || fail "help : usage sur stdout, exit 0" "exit $ORCH_STATUS"

echo "# init"
mkdir -p "$work/fresh"
run_orch init "$work/fresh"
expect_ok "init sur un dossier existant : exit 0"
[[ -d $work/fresh/.forge && -f $work/fresh/.forge/reports/.gitkeep && -f $work/fresh/.forge/approvals.log ]] \
  && pass "init : .forge/, reports/.gitkeep et approvals.log créés" \
  || fail "init : .forge/, reports/.gitkeep et approvals.log créés" "$(ls -A "$work/fresh/.forge" 2>/dev/null | tr '\n' ' ')"
[[ -f $work/fresh/.forge/approvals.log && ! -s $work/fresh/.forge/approvals.log ]] && pass "init : approvals.log vide" || fail "init : approvals.log vide"
[[ ! -e $work/fresh/.forge/config.yaml && ! -e $work/fresh/.forge/checkpoint.md ]] \
  && pass "init n'écrit ni config.yaml (le skill l'écrit, derrière protect-sensitive) ni checkpoint.md" \
  || fail "init n'écrit ni config.yaml ni checkpoint.md"
[[ $ORCH_STDOUT == *.forge* ]] && pass "init : le dossier d'état est nommé sur stdout" || fail "init : le dossier d'état est nommé sur stdout" "$ORCH_STDOUT"
printf '2026-10-01\tdocs/product/PRD.md\tabc\toui\n' >"$work/fresh/.forge/approvals.log"
run_orch init "$work/fresh"
expect_ok "init une seconde fois : exit 0"
[[ $(<"$work/fresh/.forge/approvals.log") == *abc* ]] && pass "init une seconde fois : approvals.log conservé" || fail "init une seconde fois : approvals.log conservé"
run_orch init "$work/created"
expect_ok "init sur un dossier absent dont le parent existe : exit 0"
[[ -d $work/created/.forge ]] && pass "init : le dossier est créé, un niveau" || fail "init : le dossier est créé, un niveau"
run_orch init "$work/missing/parent/project"
expect_refused "init sous un parent absent : refusé"
[[ ! -e $work/missing ]] && pass "init refusé : rien n'est créé" || fail "init refusé : rien n'est créé"
run_orch init
expect_refused "init sans dossier : usage"

echo "# checkpoint : start"
proj="$work/proj"
run_orch checkpoint "$proj" start --skill bootstrap-project --steps "Prerequisites|Identity|State directory"
expect_refused "checkpoint sans .forge/ : refusé (init d'abord)"
mkdir -p "$proj"
git -C "$proj" init -q -b main
git -C "$proj" -c user.name=t -c user.email=t@t.invalid commit -q --allow-empty -m init
head=$(git -C "$proj" rev-parse --short HEAD)
run_orch init "$proj"
run_orch checkpoint "$proj" start --skill bootstrap-project
expect_refused "start sans --steps : usage"
run_orch checkpoint "$proj" start --skill bootstrap-project --steps "Prerequisites|Identity|State directory"
expect_ok "start : exit 0"
cp="$proj/.forge/checkpoint.md"
[[ -f $cp ]] && pass "start : .forge/checkpoint.md écrit" || fail "start : .forge/checkpoint.md écrit"
[[ $ORCH_STDOUT == *checkpoint.md* ]] && pass "start : le checkpoint est nommé sur stdout" || fail "start : le checkpoint est nommé sur stdout" "$ORCH_STDOUT"
expect_line "titre # Checkpoint" "$cp" '^# Checkpoint$'
expect_line "updated: ISO 8601 avec décalage" "$cp" '^updated: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$'
expect_line "skill: bootstrap-project" "$cp" '^skill: bootstrap-project$'
expect_line "feature: - par défaut" "$cp" '^feature: -$'
expect_line "branch: la branche courante" "$cp" '^branch: main$'
expect_line "last_commit: HEAD court" "$cp" "^last_commit: $head\$"
expect_line "## Steps" "$cp" '^## Steps$'
expect_line "étape 1 à faire" "$cp" '^- \[ \] 1 Prerequisites$'
expect_line "étape 2 à faire" "$cp" '^- \[ \] 2 Identity$'
expect_line "étape 3 à faire" "$cp" '^- \[ \] 3 State directory$'
expect_line "## Test results, avec l'en-tête de la table" "$cp" '^\| command \| result \| when \|$'
expect_line "## Next action : la première étape à faire" "$cp" '^1 Prerequisites$'
expect_line "## Blockers / open questions : none" "$cp" '^- none$'
order=$(grep -E '^(# Checkpoint|## Steps|## Test results|## Next action|## Blockers / open questions)$' "$cp" | paste -sd'|' -)
[[ $order == "# Checkpoint|## Steps|## Test results|## Next action|## Blockers / open questions" ]] \
  && pass "les sections du gabarit, dans son ordre, une fois chacune" || fail "les sections du gabarit, dans son ordre, une fois chacune" "$order"
run_orch checkpoint "$proj" start --skill bootstrap-project --steps "A|B" --feature "AC-001 notes"
expect_refused "start du même skill avec des étapes à faire : refusé"
[[ $ORCH_STDERR == *Prerequisites* ]] && pass "le refus nomme les étapes restantes" || fail "le refus nomme les étapes restantes" "$ORCH_STDERR"
expect_line "start refusé : checkpoint intact" "$cp" '^- \[ \] 1 Prerequisites$'

echo "# checkpoint : done"
run_orch checkpoint "$proj" done 1 --command "git --version" --exit 0
expect_ok "done 1 : exit 0"
expect_line "étape 1 cochée avec sa commande et son code" "$cp" '^- \[x\] 1 Prerequisites — `git --version` → exit 0$'
expect_line "la prochaine action passe à l'étape 2" "$cp" '^2 Identity$'
refuse_line "l'étape 1 n'est plus la prochaine action" "$cp" '^1 Prerequisites$'
run_orch checkpoint "$proj" done 2 --command "bash tests/notes_test.sh" --exit 1 --result "FAILED 3 (expected RED)"
expect_ok "done 2 avec --result : exit 0"
expect_line "étape 2 : résultat puis code" "$cp" '^- \[x\] 2 Identity — `bash tests/notes_test.sh` → FAILED 3 \(expected RED\) \(exit 1\)$'
expect_line "une ligne dans la table des résultats, avec l'heure" "$cp" '^\| `bash tests/notes_test.sh` \| FAILED 3 \(expected RED\) \| [0-9]{2}:[0-9]{2} \|$'
run_orch checkpoint "$proj" done 2 --command 'echo `x`' --exit 0 --next "write docs/product/PRD.md from the template"
expect_ok "done d'une étape déjà cochée (reprise) : exit 0"
expect_line "les accents graves de la commande deviennent des apostrophes" "$cp" "^- \[x\] 2 Identity — \`echo 'x'\` → exit 0\$"
expect_line "--next remplace la prochaine action" "$cp" '^write docs/product/PRD.md from the template$'
[[ $(grep -c '^| `' "$cp") == 1 ]] && pass "la table des résultats garde sa ligne" || fail "la table des résultats garde sa ligne" "$(grep '^| `' "$cp" | tr '\n' ' ')"
run_orch checkpoint "$proj" done 3 --command "git commit -m 'chore: bootstrap'" --carried
expect_ok "done 3 --carried : exit 0"
expect_line "étape du commit : carried by this commit" "$cp" "^- \[x\] 3 State directory — \`git commit -m 'chore: bootstrap'\` → carried by this commit\$"
expect_line "toutes les étapes faites : la prochaine action le dit" "$cp" '^none: every step is done$'
expect_line "last_commit reste le commit d'avant" "$cp" "^last_commit: $head\$"
run_orch checkpoint "$proj" done 4 --command x --exit 0
expect_refused "done d'une étape inconnue : refusé"
run_orch checkpoint "$proj" done 1 --exit 0
expect_refused "done sans --command : usage"
run_orch checkpoint "$proj" done 1 --command x
expect_refused "done sans --exit ni --carried : usage"
run_orch checkpoint "$proj" done 1 --command x --exit abc
expect_refused "done avec un code non numérique : usage"

echo "# checkpoint : block, puis un autre skill, puis --restart"
run_orch checkpoint "$proj" block "gh is not logged in: the user logs in to GitHub"
expect_ok "block : exit 0"
expect_line "le blocage est consigné" "$cp" '^- gh is not logged in: the user logs in to GitHub$'
refuse_line "block : « - none » retiré" "$cp" '^- none$'
expect_line "block : les étapes restent" "$cp" '^- \[x\] 1 Prerequisites'
run_orch checkpoint "$proj" block "the remote has no origin"
expect_ok "second block : exit 0"
[[ $(grep -cE '^- (gh is not|the remote)' "$cp") == 2 ]] && pass "deux blocages, dans l'ordre" || fail "deux blocages, dans l'ordre"
run_orch checkpoint "$proj" block
expect_refused "block sans raison : usage"
run_orch checkpoint "$proj" start --skill create-feature --steps "Context|Plan" --feature "AC-002 search"
expect_ok "start d'un skill alors que tout est fait : exit 0"
expect_line "nouveau skill" "$cp" '^skill: create-feature$'
expect_line "feature donnée" "$cp" '^feature: AC-002 search$'
expect_line "nouvelles étapes" "$cp" '^- \[ \] 1 Context$'
refuse_line "les anciennes étapes sont parties" "$cp" 'Prerequisites'
expect_line "les blocages repartent à none" "$cp" '^- none$'
refuse_line "la table des résultats repart vide" "$cp" '^\| `'
run_orch checkpoint "$proj" start --skill create-feature --steps "Context|Plan|Branch" --restart
expect_ok "start --restart du même skill : exit 0"
expect_line "--restart réécrit les étapes" "$cp" '^- \[ \] 3 Branch$'
run_orch checkpoint "$proj" start --skill debug-project --steps "Reproduce|Fix"
expect_ok "start d'un autre skill avec des étapes à faire : accepté (la reprise est l'affaire de recover-session)"
expect_line "l'autre skill a pris le checkpoint" "$cp" '^skill: debug-project$'
run_orch checkpoint "$proj" frob
expect_refused "action de checkpoint inconnue : usage"

echo "# checkpoint : un checkpoint écrit à la main, au gabarit, se poursuit"
hand="$work/hand"
mkdir -p "$hand/.forge"
cat >"$hand/.forge/checkpoint.md" <<'CP'
# Checkpoint
updated: 2026-10-20T10:00+02:00
skill: github-workflow
feature: AC-003 export
branch: feature/AC-003-export
last_commit: abc1234

## Steps
- [x] 1 Preconditions — `git status` → exit 0
- [ ] 2 Push
- [ ] 3 Pull request

## Test results
| command | result | when |
| --- | --- | --- |
| `npm test -- export` | PASSED 4 | 09:58 |

## Next action
2 Push

## Blockers / open questions
- the remote has no origin yet
CP
handcp="$hand/.forge/checkpoint.md"
run_orch checkpoint "$hand" done 2 --command "git push -u origin feature/AC-003-export" --exit 0
expect_ok "done sur un checkpoint manuscrit : exit 0"
expect_line "manuscrit : étape 2 cochée" "$handcp" '^- \[x\] 2 Push — `git push -u origin feature/AC-003-export` → exit 0$'
expect_line "manuscrit : étape 1 conservée" "$handcp" '^- \[x\] 1 Preconditions — `git status` → exit 0$'
expect_line "manuscrit : ligne de résultats conservée" "$handcp" '^\| `npm test -- export` \| PASSED 4 \| 09:58 \|$'
expect_line "manuscrit : blocage conservé" "$handcp" '^- the remote has no origin yet$'
expect_line "manuscrit : skill conservé" "$handcp" '^skill: github-workflow$'
expect_line "manuscrit : feature conservée" "$handcp" '^feature: AC-003 export$'
expect_line "manuscrit : prochaine action à l'étape 3" "$handcp" '^3 Pull request$'
expect_line "manuscrit, hors d'un dépôt git : branch -" "$handcp" '^branch: -$'
expect_line "manuscrit, hors d'un dépôt git : last_commit -" "$handcp" '^last_commit: -$'
[[ $(grep -c '^## ' "$handcp") == 4 ]] && pass "manuscrit : quatre sections, aucune en double" || fail "manuscrit : quatre sections, aucune en double" "$(grep '^## ' "$handcp" | tr '\n' ' ')"
no_git=$(path_without git)
ORCH_PATH="$no_git" run_orch checkpoint "$proj" done 1 --command "ls" --exit 0
rm -rf "$no_git"
expect_ok "git absent du PATH : done passe quand même"
expect_line "git absent : branch -" "$cp" '^branch: -$'

echo "# status"
app="$work/app"
mkdir -p "$app/.forge"
new_doc "$app/docs/product/PRD.md" DRAFT
doc="$app/docs/product/PRD.md"
run_orch status "$doc"
expect_ok "status d'un DRAFT : exit 0"
[[ $ORCH_STDOUT == DRAFT ]] && pass "status imprime DRAFT" || fail "status imprime DRAFT" "$ORCH_STDOUT"
printf '# Notes\n\nNo header.\n' >"$app/docs/notes.md"
run_orch status "$app/docs/notes.md"
expect_refused "status sans ligne de statut : refusé"
run_orch status "$app/docs/absent.md"
expect_refused "status d'un fichier absent : usage"
run_orch status
expect_refused "status sans document : usage"

echo "# approve"
before=$(doc_fingerprint "$doc")
run_orch approve "$doc" --quote "je valide"
expect_ok "approve « je valide » : exit 0"
[[ $(doc_status "$doc") == APPROVED ]] && pass "approve : Status APPROVED" || fail "approve : Status APPROVED" "$(grep -m1 Status "$doc")"
today=$(date +%F)
cell=$(doc_approved_cell "$doc")
[[ $cell == "$today, approved by the user in conversation (« je valide »)" ]] \
  && pass "approve : ligne Approved datée, citation reprise" || fail "approve : ligne Approved datée, citation reprise" "$cell"
[[ $(doc_fingerprint "$doc") == "$before" ]] && pass "approve : le corps est intact (empreinte inchangée)" || fail "approve : le corps est intact (empreinte inchangée)"
[[ $(grep -c 'Status' "$doc") == 1 && $(grep -c 'Approved' "$doc") == 1 ]] && pass "approve : une ligne Status, une ligne Approved" || fail "approve : une ligne Status, une ligne Approved"
log="$app/.forge/approvals.log"
[[ -f $log ]] && pass "approve : .forge/approvals.log écrit" || fail "approve : .forge/approvals.log écrit"
expected=$(printf '%s\tdocs/product/PRD.md\t%s\tje valide' "$today" "$(doc_fingerprint "$doc")")
[[ $(tail -n 1 "$log") == "$expected" ]] && pass "approve : date, document relatif à la racine, empreinte et citation, séparés par des tabulations" \
  || fail "approve : date, document relatif à la racine, empreinte et citation" "$(tail -n 1 "$log" | head -c 300)"
[[ $(approved_fingerprint "$app" docs/product/PRD.md) == "$(doc_fingerprint "$doc")" ]] \
  && pass "l'empreinte consignée est celle que doc-status-guard compare" || fail "l'empreinte consignée est celle que doc-status-guard compare"
[[ $ORCH_STDOUT == *docs/product/PRD.md* && $ORCH_STDOUT == *"$today"* ]] && pass "approve : stdout nomme le document et la date" || fail "approve : stdout nomme le document et la date" "$ORCH_STDOUT"

if [[ -f $HOOK ]]; then
  input=$(post_input "$doc" "$app")
  run_hook "$HOOK" "$input"
  expect_silent_allow "doc-status-guard après approve : silencieux"
  [[ $(doc_status "$doc") == APPROVED ]] && pass "doc-status-guard après approve : reste APPROVED" || fail "doc-status-guard après approve : reste APPROVED"
  printf '\nA sentence added after the approval.\n' >>"$doc"
  run_hook "$HOOK" "$input"
  [[ $(doc_status "$doc") == REVIEW ]] && pass "modifié après approve : doc-status-guard le repasse en REVIEW" || fail "modifié après approve : REVIEW" "$(grep -m1 Status "$doc")"
  run_orch approve "$doc" --quote "Validé."
  expect_ok "approve d'un REVIEW : exit 0"
  [[ $(doc_status "$doc") == APPROVED ]] && pass "REVIEW approuvé de nouveau : APPROVED" || fail "REVIEW approuvé de nouveau : APPROVED"
  [[ $(wc -l <"$log") == 2 && $(approved_fingerprint "$app" docs/product/PRD.md) == "$(doc_fingerprint "$doc")" ]] \
    && pass "seconde approbation : seconde ligne au journal, dernière empreinte à jour" || fail "seconde approbation : seconde ligne au journal" "$(wc -l <"$log") lignes"
  run_hook "$HOOK" "$input"
  expect_silent_allow "doc-status-guard après la seconde approbation : silencieux"
else
  skip "doc-status-guard après approve" "hook absent"
fi

mkdir -p "$app/backend"
new_doc "$app/backend/docs/technical/TRD.md" DRAFT
run_orch approve "$app/backend/docs/technical/TRD.md" --quote "j'approuve"
expect_ok "approve d'un document de partie : exit 0"
[[ $(tail -n 1 "$log") == *$'\t'backend/docs/technical/TRD.md$'\t'* ]] \
  && pass "document de partie : chemin relatif à la racine du projet, dans le journal du projet" \
  || fail "document de partie : chemin relatif à la racine du projet" "$(tail -n 1 "$log" | head -c 200)"
new_doc "$app/docs/engineering/DECISIONS.md" DRAFT
(cd "$app" && "$BASH" "$ORCH" approve docs/engineering/DECISIONS.md --quote oui >/dev/null 2>&1)
[[ $? == 0 && $(doc_status "$app/docs/engineering/DECISIONS.md") == APPROVED ]] && pass "approve par un chemin relatif au dossier courant" \
  || fail "approve par un chemin relatif au dossier courant"
[[ $(tail -n 1 "$log") == *$'\t'docs/engineering/DECISIONS.md$'\t'* ]] && pass "chemin relatif : consigné relatif à la racine" \
  || fail "chemin relatif : consigné relatif à la racine" "$(tail -n 1 "$log" | head -c 200)"

echo "# approve : les citations acceptées"
i=0
for quote in "oui" "Validé." "C'est validé !" "j’approuve" "je l'approuve" "approuvé" "yes" "approved" "I approve"; do
  i=$((i + 1))
  new_doc "$app/docs/q/$i.md" DRAFT
  run_orch approve "$app/docs/q/$i.md" --quote "$quote"
  [[ $ORCH_STATUS == 0 && $(doc_status "$app/docs/q/$i.md") == APPROVED ]] && pass "« $quote » approuve" || fail "« $quote » approuve" "exit $ORCH_STATUS ; ${ORCH_STDERR:0:200}"
done
new_doc "$app/docs/q/tab.md" DRAFT
run_orch approve "$app/docs/q/tab.md" --quote $'  je\tvalide\n'
expect_ok "une citation avec tabulation et saut de ligne : acceptée"
[[ $(tail -n 1 "$log") == *$'\t'"je valide" && $(tail -n 1 "$log" | tr -cd '\t' | wc -c) == 3 ]] \
  && pass "la citation est aplatie sur une ligne, quatre champs" || fail "la citation est aplatie sur une ligne, quatre champs" "$(tail -n 1 "$log" | head -c 200)"

echo "# approve : refus"
new_doc "$app/docs/product/REFUSED.md" DRAFT
ref="$app/docs/product/REFUSED.md"
lines=$(wc -l <"$log")
for quote in "ça a l'air bien" "non" "oui mais change le titre" "je ne valide pas" "approuve-le"; do
  run_orch approve "$ref" --quote "$quote"
  expect_refused "« $quote » ne vaut pas approbation : refusé"
  [[ $(doc_status "$ref") == DRAFT ]] && pass "« $quote » : statut inchangé" || fail "« $quote » : statut inchangé" "$(grep -m1 Status "$ref")"
done
run_orch approve "$ref"
expect_refused "approve sans --quote : usage"
run_orch approve "$ref" --quote ""
expect_refused "approve avec une citation vide : refusé"
run_orch approve "$app/docs/notes.md" --quote oui
expect_refused "approve d'un document sans ligne de statut : refusé"
new_doc "$app/README.md" DRAFT
run_orch approve "$app/README.md" --quote oui
expect_refused "approve hors d'un docs/ : refusé"
[[ $(doc_status "$app/README.md") == DRAFT ]] && pass "hors docs/ : statut inchangé" || fail "hors docs/ : statut inchangé"
new_doc "$work/nowhere/docs/product/PRD.md" DRAFT
run_orch approve "$work/nowhere/docs/product/PRD.md" --quote oui
expect_refused "approve hors d'un projet .forge/ : refusé"
run_orch approve "$app/docs/product/absent.md" --quote oui
expect_refused "approve d'un fichier absent : usage"
[[ $(wc -l <"$log") == "$lines" ]] && pass "aucun refus n'écrit au journal" || fail "aucun refus n'écrit au journal" "$lines puis $(wc -l <"$log")"

echo "# prérequis"
new_doc "$app/docs/product/NOSUM.md" DRAFT
no_sum=$(path_without sha256sum)
ORCH_PATH="$no_sum" run_orch approve "$app/docs/product/NOSUM.md" --quote oui
rm -rf "$no_sum"
expect_refused "sha256sum absent : bloqué, exit 2" 2
[[ $(doc_status "$app/docs/product/NOSUM.md") == DRAFT && $(wc -l <"$log") == "$lines" ]] && pass "sha256sum absent : document et journal intacts" \
  || fail "sha256sum absent : document et journal intacts"
copy=$(mktemp -d)
mkdir -p "$copy/scripts"
cp "$ORCH" "$copy/scripts/orch.sh"
ORCH_BIN="$copy/scripts/orch.sh" run_orch status "$doc"
expect_refused "bibliothèque scripts/lib/doc-status.sh absente : bloqué, exit 2" 2
ORCH_BIN="$copy/scripts/orch.sh" run_orch checkpoint "$proj" block "without the library"
rm -rf "$copy"
expect_ok "bibliothèque absente : checkpoint passe quand même (il ne s'en sert pas)"

finish
