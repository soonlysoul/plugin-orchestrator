# shellcheck shell=bash
# Shared by hooks/scripts/doc-status-guard.sh and, to come, scripts/orch.sh (approve): the two
# rows of a project document's fixed header, | Status | DRAFT, REVIEW or APPROVED | and
# | Approved | … |, and the fingerprint of its body that an approval records in
# .forge/approvals.log (date, document relative to the project root, fingerprint, quote;
# tab-separated). Sourced, never executed.

DOC_STATUS_ROW='^[|][[:space:]]*Status[[:space:]]*[|][[:space:]]*(DRAFT|REVIEW|APPROVED)[[:space:]]*[|][[:space:]]*$'
DOC_APPROVED_ROW='^[|][[:space:]]*Approved[[:space:]]*[|]'

# doc_status <file>: DRAFT, REVIEW or APPROVED; empty when the file has no status row.
doc_status() {
  grep -m 1 -E "$DOC_STATUS_ROW" "$1" 2>/dev/null \
    | sed -E 's/^[|][[:space:]]*Status[[:space:]]*[|][[:space:]]*([A-Z]+).*$/\1/'
}

# doc_approved_cell <file>: the content of the first Approved row; empty without one.
doc_approved_cell() {
  grep -m 1 -E "$DOC_APPROVED_ROW" "$1" 2>/dev/null \
    | sed -E 's/^[|][[:space:]]*Approved[[:space:]]*[|][[:space:]]*//; s/[[:space:]]*[|]?[[:space:]]*$//'
}

# doc_fingerprint <file>: sha256 of the document without its Status and Approved rows, the two
# that an approval writes.
doc_fingerprint() {
  STATUS_ROW=$DOC_STATUS_ROW APPROVED_ROW=$DOC_APPROVED_ROW awk '
    !s && $0 ~ ENVIRON["STATUS_ROW"] { s = 1; next }
    !a && $0 ~ ENVIRON["APPROVED_ROW"] { a = 1; next }
    { print }' "$1" | sha256sum | cut -d' ' -f1
}

# doc_set_status <file> <status> <approved cell>: replaces the Status row and the Approved row,
# and nothing else; a document without an Approved row keeps none.
doc_set_status() {
  local tmp
  tmp=$(mktemp) || return 1
  if STATUS_ROW=$DOC_STATUS_ROW APPROVED_ROW=$DOC_APPROVED_ROW NEW_STATUS=$2 NEW_APPROVED=$3 awk '
      !s && $0 ~ ENVIRON["STATUS_ROW"] { print "| Status | " ENVIRON["NEW_STATUS"] " |"; s = 1; next }
      !a && $0 ~ ENVIRON["APPROVED_ROW"] { print "| Approved | " ENVIRON["NEW_APPROVED"] " |"; a = 1; next }
      { print }' "$1" >"$tmp"; then
    cat "$tmp" >"$1"
  fi
  rm -f "$tmp"
}

# approved_fingerprint <project root> <document relative to the root>: the fingerprint of the
# document's last approval; empty without one.
approved_fingerprint() {
  awk -F'\t' -v doc="$2" '$2 == doc { fingerprint = $3 } END { print fingerprint }' \
    "$1/.forge/approvals.log" 2>/dev/null
}

# approved_date <project root> <document relative to the root>: the date of its last approval.
approved_date() {
  awk -F'\t' -v doc="$2" '$2 == doc { date = $1 } END { print date }' "$1/.forge/approvals.log" 2>/dev/null
}
