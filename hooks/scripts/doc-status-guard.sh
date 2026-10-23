#!/usr/bin/env bash
# doc-status-guard — PostToolUse hook for Edit|Write.
# A project document — a Markdown file under a docs/ directory of a project that has .forge/
# (the nearest parent of the file holding one), at the root or in a part — whose fixed header
# says | Status | APPROVED |, but whose body no longer matches the fingerprint recorded at its
# approval in .forge/approvals.log, goes back to REVIEW: its Status row, its Approved row (the
# date of the lost approval kept), and Claude told through additionalContext. An approval is
# recorded by scripts/orch.sh approve, never by a hook: an APPROVED without a trace goes back
# to REVIEW at its first change. Inert anywhere else — no .forge/, no status row, DRAFT or
# REVIEW, another tool. Installed for the account, it runs in every session; it assumes no
# order among the hooks of an event.
# Fail-open: it always exits 0; hooks.json sets "onFailure": "continue".

command -v jq >/dev/null 2>&1 || exit 0
command -v sha256sum >/dev/null 2>&1 || exit 0
# shellcheck source=../../scripts/lib/doc-status.sh
source "${BASH_SOURCE[0]%/*}/../../scripts/lib/doc-status.sh" 2>/dev/null || exit 0
IFS= read -r -d '' input || true
file=$(jq -r 'select(type == "object" and (.tool_name == "Edit" or .tool_name == "Write"))
              | .tool_input.file_path // empty | strings' <<<"$input" 2>/dev/null) || exit 0
[[ -n $file ]] || exit 0
if [[ $file != /* ]]; then
  root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input" 2>/dev/null)}
  [[ -n $root ]] || exit 0
  file=${root%/}/$file
fi
[[ $file == */docs/*.md && -f $file ]] || exit 0
# The project of a document is the nearest parent holding .forge/, whatever the session root.
project=""
dir=${file%/*}
while [[ -n $dir ]]; do
  if [[ -d $dir/.forge ]]; then project=$dir; break; fi
  dir=${dir%/*}
done
[[ -n $project ]] || exit 0
rel=${file#"$project"/}
[[ $rel == docs/* || $rel == */docs/* ]] || exit 0
[[ $(doc_status "$file") == APPROVED ]] || exit 0
[[ $(doc_fingerprint "$file") == "$(approved_fingerprint "$project" "$rel")" ]] && exit 0

approved_on=$(approved_date "$project" "$rel")
[[ -n $approved_on ]] || approved_on=$(doc_approved_cell "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n 1)
doc_set_status "$file" REVIEW "— (approved on ${approved_on:-?}, modified since: to approve again)" || exit 0
jq -nc --arg doc "$rel" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse",
    additionalContext: ("plugin-orchestrator : \($doc) était APPROVED et vient d'\''être modifié ; son statut repasse à REVIEW. Le présenter de nouveau pour approbation explicite avant de s'\''en servir.")}}'
exit 0
