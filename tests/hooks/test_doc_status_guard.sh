#!/usr/bin/env bash
# doc-status-guard: simulated inputs, no session, throwaway .forge/ projects. PostToolUse hook on
# Edit|Write, fail-open. A project document (a .md under a docs/ of a .forge/ project, root or
# part) whose header says | Status | APPROVED | but whose body no longer matches the fingerprint
# recorded in .forge/approvals.log goes back to REVIEW, Claude told through additionalContext;
# DRAFT and REVIEW keep their status; outside that context the hook is silent and never fails.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_doc_status_guard
HOOK="$PLUGIN_ROOT/hooks/scripts/doc-status-guard.sh"

echo "# contrat du squelette"
run_hook "$HOOK" 'pas du json'
expect_status "squelette : entrée illisible, exit 0" 0
no_jq=$(mktemp -d)
run_hook "$HOOK" '{}' PATH="$no_jq"
rm -rf "$no_jq"
expect_status "squelette : jq absent, exit 0" 0

echo "# bibliothèque partagée"
LIB="$PLUGIN_ROOT/scripts/lib/doc-status.sh"
if [[ ! -f $LIB ]]; then
  fail "scripts/lib/doc-status.sh présent" "absent : $LIB"
  finish
  exit
fi
# shellcheck source=../../scripts/lib/doc-status.sh
source "$LIB"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# post_input <file_path> [tool] [cwd]: PostToolUse input for a write to <file_path>.
post_input() {
  jq -nc --arg f "$1" --arg t "${2:-Edit}" --arg d "${3:-$work}" \
    '{session_id: "test", cwd: $d, hook_event_name: "PostToolUse", permission_mode: "default",
      tool_name: $t, tool_input: {file_path: $f}, tool_response: {success: true}, tool_use_id: "toolu_test"}'
}
# new_doc <file> <status>: a document at the fixed header of the templates, under that status.
new_doc() {
  mkdir -p "${1%/*}"
  printf '# PRD — essai\n\n| | |\n| --- | --- |\n| Objective | What the app must do |\n| Status | %s |\n| Approved | — (date and approver, written only after the user'"'"'s explicit approval) |\n| Assumptions | none |\n\n## Problem\n\nText.\n' "$2" >"$1"
}
# new_project <name> <status>: a .forge/ project whose docs/product/PRD.md is under that status.
# Prints the project root.
new_project() {
  local root="$work/$1"
  mkdir -p "$root/.forge"
  new_doc "$root/docs/product/PRD.md" "$2"
  printf '%s' "$root"
}
# approve <project root> <document relative to the root>: what scripts/orch.sh approve will do —
# the two rows, and the fingerprint in .forge/approvals.log.
approve() {
  doc_set_status "$1/$2" APPROVED "2026-10-20, approved by the user in conversation"
  printf '2026-10-20\t%s\t%s\tje valide\n' "$2" "$(doc_fingerprint "$1/$2")" >>"$1/.forge/approvals.log"
}
status_row() { grep -m 1 -E '^\| *Status *\|' "$1"; }
approved_row() { grep -m 1 -E '^\| *Approved *\|' "$1"; }
sum() { sha256sum "$1" | cut -d' ' -f1; }

# expect_review <label> <file> <doc relative path>: exit 0, the status row at REVIEW, the body
# untouched, Claude told through additionalContext.
expect_review() {
  local label=$1 file=$2 rel=$3 context
  expect_status "$label : exit 0 (PostToolUse ne bloque pas)" 0
  [[ $(doc_status "$file") == REVIEW ]] && pass "$label : repasse en REVIEW" || fail "$label : repasse en REVIEW" "$(status_row "$file")"
  context=$(jq -r 'select(.hookSpecificOutput.hookEventName == "PostToolUse") | .hookSpecificOutput.additionalContext // empty' <<<"$HOOK_STDOUT" 2>/dev/null)
  [[ $context == *plugin-orchestrator* && $context == *REVIEW* && $context == *"$rel"* ]] \
    && pass "$label : Claude est prévenu par additionalContext, document nommé" \
    || fail "$label : Claude est prévenu par additionalContext, document nommé" "stdout : ${HOOK_STDOUT:0:300}"
  [[ -z $HOOK_STDERR ]] && pass "$label : rien sur stderr" || fail "$label : rien sur stderr" "$HOOK_STDERR"
}

echo "# document approuvé, puis modifié"
root=$(new_project approved DRAFT)
doc="$root/docs/product/PRD.md"
approve "$root" docs/product/PRD.md
[[ $(doc_status "$doc") == APPROVED ]] && pass "mise en place : PRD approuvé, empreinte au journal" \
  || fail "mise en place : PRD approuvé, empreinte au journal" "$(status_row "$doc")"
run_hook "$HOOK" "$(post_input "$doc" Write)"
expect_silent_allow "écriture de l'approbation elle-même : silencieux"
[[ $(doc_status "$doc") == APPROVED ]] && pass "écriture de l'approbation : le statut reste APPROVED" \
  || fail "écriture de l'approbation : le statut reste APPROVED" "$(status_row "$doc")"
before=$(doc_fingerprint "$doc")
printf '\nA sentence added after the approval.\n' >>"$doc"
run_hook "$HOOK" "$(post_input "$doc")"
expect_review "approuvé puis modifié" "$doc" docs/product/PRD.md
approved_row "$doc" | grep -q '2026-10-20' && pass "la ligne Approved garde la date de l'approbation perdue" \
  || fail "la ligne Approved garde la date de l'approbation perdue" "$(approved_row "$doc")"
grep -q 'A sentence added' "$doc" && pass "le contenu modifié est conservé" || fail "le contenu modifié est conservé"
[[ $(doc_fingerprint "$doc") != "$before" && $(grep -c 'Status' "$doc") == 1 ]] \
  && pass "seules les lignes Status et Approved ont été réécrites" || fail "seules les lignes Status et Approved ont été réécrites"
after=$(sum "$doc")
run_hook "$HOOK" "$(post_input "$doc")"
expect_silent_allow "une seconde écriture d'un document en REVIEW : silencieux"
[[ $(sum "$doc") == "$after" ]] && pass "REVIEW : fichier intact" || fail "REVIEW : fichier intact"

echo "# approbation écrite à la main, sans trace au journal"
root=$(new_project forged APPROVED)
doc="$root/docs/product/PRD.md"
run_hook "$HOOK" "$(post_input "$doc")"
expect_review "APPROVED sans trace au journal" "$doc" docs/product/PRD.md
approved_row "$doc" | grep -q 'approved on ?' && pass "sans date connue, la ligne Approved dit « ? »" \
  || fail "sans date connue, la ligne Approved dit « ? »" "$(approved_row "$doc")"
root=$(new_project forged-dated APPROVED)
doc="$root/docs/product/PRD.md"
doc_set_status "$doc" APPROVED "2026-10-01, approved by the user in conversation"
run_hook "$HOOK" "$(post_input "$doc")"
expect_review "APPROVED daté à la main, sans journal" "$doc" docs/product/PRD.md
approved_row "$doc" | grep -q 'approved on 2026-10-01' && pass "la date de la ligne Approved est reprise sans journal" \
  || fail "la date de la ligne Approved est reprise sans journal" "$(approved_row "$doc")"
root=$(new_project stale APPROVED)
doc="$root/docs/product/PRD.md"
printf '2026-10-20\tdocs/product/PRD.md\t0000000000000000000000000000000000000000000000000000000000000000\tje valide\n' >>"$root/.forge/approvals.log"
run_hook "$HOOK" "$(post_input "$doc")"
expect_review "journal présent mais empreinte différente" "$doc" docs/product/PRD.md

echo "# DRAFT et REVIEW gardent leur statut"
for status in DRAFT REVIEW; do
  root=$(new_project "kept-$status" "$status")
  doc="$root/docs/product/PRD.md"
  printf '\nAdded.\n' >>"$doc"
  before=$(sum "$doc")
  run_hook "$HOOK" "$(post_input "$doc")"
  expect_silent_allow "$status modifié : silencieux"
  [[ $(sum "$doc") == "$before" ]] && pass "$status modifié : fichier intact" || fail "$status modifié : fichier intact"
done

echo "# documents d'une partie, projet en sous-dossier, chemin relatif"
root=$(new_project parts DRAFT)
new_doc "$root/app/docs/technical/TRD.md" DRAFT
approve "$root" app/docs/technical/TRD.md
run_hook "$HOOK" "$(post_input "$root/app/docs/technical/TRD.md")"
expect_silent_allow "TRD d'une partie, approuvé et inchangé : silencieux"
printf '\nAdded.\n' >>"$root/app/docs/technical/TRD.md"
run_hook "$HOOK" "$(post_input "$root/app/docs/technical/TRD.md")"
expect_review "TRD d'une partie, approuvé puis modifié" "$root/app/docs/technical/TRD.md" app/docs/technical/TRD.md
new_doc "$root/docs/engineering/DECISIONS.md" DRAFT
approve "$root" docs/engineering/DECISIONS.md
printf '\nAdded.\n' >>"$root/docs/engineering/DECISIONS.md"
run_hook "$HOOK" "$(post_input "$root/docs/engineering/DECISIONS.md" Write "$work")" CLAUDE_PROJECT_DIR="$work"
expect_review "projet .forge/ trouvé depuis le fichier, pas depuis la racine de session" "$root/docs/engineering/DECISIONS.md" docs/engineering/DECISIONS.md
new_doc "$root/docs/technical/CONTRACT.md" DRAFT
approve "$root" docs/technical/CONTRACT.md
printf '\nAdded.\n' >>"$root/docs/technical/CONTRACT.md"
run_hook "$HOOK" "$(post_input docs/technical/CONTRACT.md Edit "$root")"
expect_review "chemin relatif résolu depuis le cwd de l'entrée" "$root/docs/technical/CONTRACT.md" docs/technical/CONTRACT.md

echo "# hors de son contexte, le hook est inerte"
plain="$work/unmanaged"
new_doc "$plain/docs/product/PRD.md" APPROVED
before=$(sum "$plain/docs/product/PRD.md")
run_hook "$HOOK" "$(post_input "$plain/docs/product/PRD.md")"
expect_silent_allow "projet sans .forge/ : silencieux"
[[ $(sum "$plain/docs/product/PRD.md") == "$before" ]] && pass "projet sans .forge/ : fichier intact" || fail "projet sans .forge/ : fichier intact"
root=$(new_project outside DRAFT)
new_doc "$root/README.md" APPROVED
before=$(sum "$root/README.md")
run_hook "$HOOK" "$(post_input "$root/README.md")"
expect_silent_allow "fichier hors de docs/ : silencieux"
[[ $(sum "$root/README.md") == "$before" ]] && pass "fichier hors de docs/ : intact" || fail "fichier hors de docs/ : intact"
new_doc "$root/docs/notes.txt" APPROVED
run_hook "$HOOK" "$(post_input "$root/docs/notes.txt")"
expect_silent_allow "fichier qui n'est pas .md : silencieux"
printf '# Guide\n\nNo status row.\n' >"$root/docs/GUIDE.md"
before=$(sum "$root/docs/GUIDE.md")
run_hook "$HOOK" "$(post_input "$root/docs/GUIDE.md")"
expect_silent_allow "document sans ligne de statut : silencieux"
[[ $(sum "$root/docs/GUIDE.md") == "$before" ]] && pass "document sans statut : intact" || fail "document sans statut : intact"
new_doc "$root/docs/product/PRD.md" APPROVED
run_hook "$HOOK" "$(post_input "$root/docs/product/PRD.md" Bash)"
expect_silent_allow "outil autre qu'Edit ou Write : silencieux"
run_hook "$HOOK" "$(post_input "$root/docs/product/PRD.md" NotebookEdit)"
expect_silent_allow "NotebookEdit n'est pas surveillé : silencieux"
run_hook "$HOOK" "$(post_input "$root/docs/product/MISSING.md")"
expect_silent_allow "fichier absent du disque : silencieux"
run_hook "$HOOK" "$(post_input docs/product/PRD.md Edit "")"
expect_silent_allow "chemin relatif sans racine connue : silencieux"
run_hook "$HOOK" '{"hook_event_name": "PostToolUse", "tool_name": "Write", "tool_input": {"content": "x"}}'
expect_silent_allow "Write sans file_path : silencieux"

echo "# fail-open"
root=$(new_project failopen DRAFT)
doc="$root/docs/product/PRD.md"
doc_set_status "$doc" APPROVED "2026-10-01, approved by the user in conversation"
run_hook "$HOOK" '{"tool_name": "Edit", "tool_input": {"file_path": 7}}'
expect_silent_allow "file_path non textuel : silencieux"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(post_input "$doc")" PATH="$no_jq"
expect_status "jq absent : exit 0" 0
rm -rf "$no_jq"
no_sum=$(path_without sha256sum)
run_hook "$HOOK" "$(post_input "$doc")" PATH="$no_sum"
expect_status "sha256sum absent : exit 0" 0
rm -rf "$no_sum"
[[ $(doc_status "$doc") == APPROVED ]] && pass "sans jq ni sha256sum, le document n'est pas touché" \
  || fail "sans jq ni sha256sum, le document n'est pas touché" "$(status_row "$doc")"
nolib=$(mktemp -d)
mkdir -p "$nolib/hooks/scripts"
cp "$HOOK" "$nolib/hooks/scripts/"
run_hook "$nolib/hooks/scripts/doc-status-guard.sh" "$(post_input "$doc")"
expect_status "bibliothèque scripts/lib/doc-status.sh absente : exit 0" 0
rm -rf "$nolib"

finish
