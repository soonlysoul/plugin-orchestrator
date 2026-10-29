#!/usr/bin/env bash
# orch.sh — the deterministic tool of a .forge/ project: what a skill of plugin-orchestrator must
# not leave to judgment. Called by the skills through ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh,
# never by a hook; no session, no network, no quota.
# Usage: orch.sh <command> [options]
#   init DIR                       the state directory .forge/: reports/.gitkeep, approvals.log;
#                                  never config.yaml (the skill writes it, behind protect-sensitive)
#                                  nor checkpoint.md (checkpoint start)
#   checkpoint DIR start --skill S --steps "a|b|…" [--feature F] [--restart]
#   checkpoint DIR done N --command C (--exit E | --carried) [--result R] [--next A]
#   checkpoint DIR block REASON    a blocker of the first step left to do, "[step N]", lifted by
#                                  done N
#   status DOC                    DRAFT, REVIEW or APPROVED
#   approve DOC --quote MESSAGE    the user's explicit approval: the Status and Approved rows,
#                                  the fingerprint in .forge/approvals.log that doc-status-guard
#                                  compares
# The checkpoint follows templates/checkpoint.md; the document rows and the fingerprint come from
# scripts/lib/doc-status.sh, shared with doc-status-guard. Exit codes: 0 done, 1 refused (reason
# on stderr), 2 a prerequisite is missing. Messages in French; the files written are in the
# language of the templates.

set -o pipefail

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }
need() { command -v "$1" >/dev/null 2>&1 || die "bloqué : $1 introuvable dans le PATH." 2; }
usage() {
  cat <<'USAGE'
usage : orch.sh init DOSSIER
        orch.sh checkpoint DOSSIER start --skill SKILL --steps "étape|étape|…" [--feature FEATURE] [--restart]
        orch.sh checkpoint DOSSIER done N --command COMMANDE (--exit CODE | --carried) [--result RÉSULTAT] [--next ACTION]
        orch.sh checkpoint DOSSIER block RAISON
        orch.sh status DOCUMENT
        orch.sh approve DOCUMENT --quote MESSAGE
USAGE
}
join() {
  local separator=$1 out="" item
  shift
  for item in "$@"; do out+=${out:+$separator}$item; done
  printf '%s' "$out"
}

# The messages that count as an explicit approval, once lowered and stripped of their final
# punctuation: the same list as plugin-plugin's, plus their English counterparts.
APPROVALS=("oui" "je valide" "validé" "c'est validé" "j'approuve" "je l'approuve" "approuvé" "yes" "approved" "i approve")

# ---- init: the state directory.
cmd_init() {
  [[ $# == 1 && -n $1 ]] || die "usage : orch.sh init DOSSIER"
  local dir=$1 state
  # A project bootstrapped in a new folder has none yet: created, one level only.
  if [[ ! -d $dir ]]; then
    [[ -d $(dirname -- "$dir") ]] || die "refusé : le dossier parent $(dirname -- "$dir") n'existe pas."
    mkdir -- "$dir" || die "échec : impossible de créer $dir"
  fi
  state="$dir/.forge"
  mkdir -p "$state/reports" || die "échec : impossible de créer $state"
  [[ -e $state/reports/.gitkeep ]] || : >"$state/reports/.gitkeep"
  [[ -e $state/approvals.log ]] || : >"$state/approvals.log"
  printf 'état du projet : %s\n' "$state"
}

# ---- checkpoint: .forge/checkpoint.md at the format of templates/checkpoint.md, read by section
# into CP_* globals and written back whole, so that a checkpoint written by hand at that format
# continues here.
read_checkpoint() {
  local line section=header
  CP_UPDATED="" CP_SKILL="" CP_FEATURE="-" CP_BRANCH="" CP_LAST="" CP_NEXT=""
  CP_STEPS=() CP_RESULTS=() CP_BLOCKERS=()
  while IFS= read -r line || [[ -n $line ]]; do
    case $line in
      "## Steps"*) section=steps; continue ;;
      "## Test results"*) section=results; continue ;;
      "## Next action"*) section=next; continue ;;
      "## Blockers"*) section=blockers; continue ;;
      "## "*) section=other; continue ;;
    esac
    case $section in
      header)
        case $line in
          "updated: "*) CP_UPDATED=${line#updated: } ;;
          "skill: "*) CP_SKILL=${line#skill: } ;;
          "feature: "*) CP_FEATURE=${line#feature: } ;;
          "branch: "*) CP_BRANCH=${line#branch: } ;;
          "last_commit: "*) CP_LAST=${line#last_commit: } ;;
        esac ;;
      steps) [[ $line == "- ["[x\ ]"] "[0-9]* ]] && CP_STEPS+=("$line") ;;
      results) [[ $line == "| "* && $line != "| command |"* && $line != "| --- |"* ]] && CP_RESULTS+=("$line") ;;
      next) [[ -n $line ]] && CP_NEXT+=${CP_NEXT:+$'\n'}$line ;;
      blockers) [[ $line == "- "* && $line != "- none" ]] && CP_BLOCKERS+=("${line#- }") ;;
    esac
  done <"$1"
}

write_checkpoint() {
  local tmp
  tmp=$(mktemp) || die "échec : mktemp"
  {
    printf '# Checkpoint\n'
    printf 'updated: %s\nskill: %s\nfeature: %s\nbranch: %s\nlast_commit: %s\n' \
      "$CP_UPDATED" "$CP_SKILL" "$CP_FEATURE" "$CP_BRANCH" "$CP_LAST"
    printf '\n## Steps\n'
    printf '%s\n' "${CP_STEPS[@]}"
    printf '\n## Test results\n| command | result | when |\n| --- | --- | --- |\n'
    ((${#CP_RESULTS[@]} == 0)) || printf '%s\n' "${CP_RESULTS[@]}"
    printf '\n## Next action\n%s\n' "$CP_NEXT"
    printf '\n## Blockers / open questions\n'
    if ((${#CP_BLOCKERS[@]} == 0)); then printf -- '- none\n'; else printf -- '- %s\n' "${CP_BLOCKERS[@]}"; fi
  } >"$tmp" && cat "$tmp" >"$1"
  rm -f "$tmp"
}

# step_name <step line>: the step's number and name, without its command and result.
step_name() {
  local text=${1#- \[?\] }
  printf '%s' "${text%% — \`*}"
}

# first_open: the number of the first step left to do, or nothing when every step is done.
first_open() {
  local step
  for step in "${CP_STEPS[@]}"; do
    [[ $step =~ ^-\ \[\ \]\ ([0-9]+)\  ]] && { printf '%s' "${BASH_REMATCH[1]}"; return; }
  done
}

# default_next: the first step left to do, or that every step is done.
default_next() {
  local step
  for step in "${CP_STEPS[@]}"; do
    [[ $step == "- [ ] "* ]] && { step_name "$step"; return; }
  done
  printf 'none: every step is done'
}

cmd_checkpoint() {
  local dir=${1:-} action=${2:-} file
  [[ -n $dir && -n $action ]] || die "usage : orch.sh checkpoint DOSSIER start|done|block …"
  [[ -d $dir/.forge ]] || die "refusé : $dir n'est pas un projet .forge/ (orch.sh init d'abord)."
  shift 2
  file="$dir/.forge/checkpoint.md"
  case $action in
    start)
      local skill="" steps="" feature="-" restart=0 step n=0 left=()
      local -a parts
      while [[ $# -gt 0 ]]; do
        case $1 in
          --skill) skill=${2:-}; shift 2 ;;
          --steps) steps=${2:-}; shift 2 ;;
          --feature) feature=${2:-}; shift 2 ;;
          --restart) restart=1; shift ;;
          *) die "usage : orch.sh checkpoint DOSSIER start --skill SKILL --steps \"étape|étape|…\" [--feature FEATURE] [--restart]" ;;
        esac
      done
      [[ -n $skill && -n $steps ]] || die "usage : orch.sh checkpoint DOSSIER start --skill SKILL --steps \"étape|étape|…\" [--feature FEATURE] [--restart]"
      # Resuming a skill runs it again: its start must not wipe the steps already done. Another
      # skill takes the checkpoint over, as the workflows always did; recover-session reads it first.
      if [[ -f $file ]] && ((!restart)); then
        read_checkpoint "$file"
        for step in "${CP_STEPS[@]}"; do
          [[ $step == "- [ ] "* ]] && left+=("$(step_name "$step")")
        done
        [[ $CP_SKILL != "$skill" || ${#left[@]} == 0 ]] \
          || die "refusé : le checkpoint de $skill a des étapes à faire ($(join ', ' "${left[@]}")). Reprendre à l'étape suivante par « checkpoint DOSSIER done N », ou --restart si ce travail est abandonné."
      fi
      CP_SKILL=$skill CP_FEATURE=${feature:--} CP_NEXT="" CP_STEPS=() CP_RESULTS=() CP_BLOCKERS=()
      IFS='|' read -ra parts <<<"$steps"
      for step in "${parts[@]}"; do
        [[ -n $step ]] || continue
        n=$((n + 1))
        CP_STEPS+=("- [ ] $n $step")
      done
      ((n > 0)) || die "refusé : aucune étape dans --steps."
      CP_NEXT=$(default_next)
      ;;
    done)
      local number=${1:-} command="" code="" carried=0 result="" next="" i found=0 outcome
      shift || true
      while [[ $# -gt 0 ]]; do
        case $1 in
          --command) command=${2//\`/\'}; shift 2 ;;
          --exit) code=${2:-}; shift 2 ;;
          --carried) carried=1; shift ;;
          --result) result=${2//\`/\'}; shift 2 ;;
          --next) next=${2:-}; shift 2 ;;
          *) die "usage : orch.sh checkpoint DOSSIER done N --command COMMANDE (--exit CODE | --carried) [--result RÉSULTAT] [--next ACTION]" ;;
        esac
      done
      { [[ $number =~ ^[0-9]+$ && -n $command ]] && { ((carried)) || [[ $code =~ ^[0-9]+$ ]]; }; } \
        || die "usage : orch.sh checkpoint DOSSIER done N --command COMMANDE (--exit CODE | --carried) [--result RÉSULTAT] [--next ACTION]"
      [[ -f $file ]] || die "refusé : aucun checkpoint dans $dir (checkpoint start d'abord)."
      read_checkpoint "$file"
      # A commit cannot record its own result: the step it carries says so instead of a code.
      if ((carried)); then outcome="carried by this commit"
      elif [[ -n $result ]]; then outcome="$result (exit $code)"
      else outcome="exit $code"; fi
      for i in "${!CP_STEPS[@]}"; do
        [[ ${CP_STEPS[$i]} =~ ^-\ \[.\]\ $number\  ]] || continue
        CP_STEPS[i]="- [x] $(step_name "${CP_STEPS[$i]}") — \`$command\` → $outcome"
        found=1
      done
      ((found)) || die "refusé : étape $number inconnue du checkpoint."
      # The step is done: the blockers it held are lifted, the others stay.
      local kept=() blocker
      for blocker in "${CP_BLOCKERS[@]}"; do
        [[ $blocker == "[step $number] "* ]] || kept+=("$blocker")
      done
      CP_BLOCKERS=("${kept[@]}")
      [[ -z $result ]] || CP_RESULTS+=("| \`$command\` | $result | $(date +%H:%M) |")
      CP_NEXT=${next:-$(default_next)}
      ;;
    block)
      [[ -n ${1:-} ]] || die "usage : orch.sh checkpoint DOSSIER block RAISON"
      [[ -f $file ]] || die "refusé : aucun checkpoint dans $dir (checkpoint start d'abord)."
      read_checkpoint "$file"
      # A blocker holds the first step left to do, named "[step N]", until "done N" lifts it; once
      # every step is done it holds none and stays until the next start. A reason that already
      # opens on "step N" loses it rather than say it twice.
      local reason=$1 held pattern
      held=$(first_open)
      if [[ -n $held ]]; then
        pattern="^[Ss]tep $held:? +(.+)$"
        [[ $reason =~ $pattern ]] && reason=${BASH_REMATCH[1]}
        reason="[step $held] $reason"
      fi
      CP_BLOCKERS+=("$reason")
      ;;
    *) die "usage : orch.sh checkpoint DOSSIER start|done|block …" ;;
  esac
  CP_UPDATED=$(date +%FT%H:%M%:z)
  CP_BRANCH=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo -)
  CP_LAST=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo -)
  write_checkpoint "$file"
  printf 'checkpoint : %s\n' "$file"
}

# ---- documents: status and approval, with the rows and the fingerprint of the shared library.
load_lib() {
  # shellcheck source=lib/doc-status.sh
  source "${BASH_SOURCE[0]%/*}/lib/doc-status.sh" 2>/dev/null \
    || die "bloqué : bibliothèque ${BASH_SOURCE[0]%/*}/lib/doc-status.sh absente." 2
}

# project_of <file>: PROJECT, the nearest parent of the file holding .forge/, and REL, the file's
# path relative to it; false without one.
project_of() {
  local abs dir
  abs=$(cd "$(dirname -- "$1")" 2>/dev/null && pwd -P) || return 1
  abs="$abs/$(basename -- "$1")"
  dir=${abs%/*}
  while [[ -n $dir ]]; do
    if [[ -d $dir/.forge ]]; then
      PROJECT=$dir REL=${abs#"$dir"/}
      return 0
    fi
    dir=${dir%/*}
  done
  return 1
}

cmd_status() {
  [[ $# == 1 && -f ${1:-} ]] || die "usage : orch.sh status DOCUMENT"
  load_lib
  local status
  status=$(doc_status "$1")
  [[ -n $status ]] || die "refusé : $1 n'a pas de ligne « | Status | DRAFT, REVIEW ou APPROVED | »."
  printf '%s\n' "$status"
}

cmd_approve() {
  local doc=${1:-} quote="" given=0 status normalized allowed date
  shift || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --quote) quote=${2:-}; given=1; shift 2 ;;
      *) die "usage : orch.sh approve DOCUMENT --quote MESSAGE" ;;
    esac
  done
  [[ -n $doc && -f $doc && $given == 1 ]] || die "usage : orch.sh approve DOCUMENT --quote MESSAGE"
  load_lib
  need sha256sum
  project_of "$doc" || die "refusé : $doc n'est dans aucun projet .forge/."
  [[ $REL == docs/*.md || $REL == */docs/*.md ]] \
    || die "refusé : $REL n'est pas un document projet (un .md sous docs/, à la racine ou dans une partie)."
  status=$(doc_status "$doc")
  [[ -n $status ]] || die "refusé : $REL n'a pas de ligne « | Status | DRAFT, REVIEW ou APPROVED | »."
  quote=$(tr '\t\n' '  ' <<<"$quote" | sed -E 's/  +/ /g; s/^ +//; s/ +$//')
  [[ -n $quote ]] || die "refusé : citation vide ; l'approbation est le message de l'utilisateur, cité tel quel."
  normalized=$(tr '[:upper:]' '[:lower:]' <<<"$quote" | sed -E "s/’/'/g; s/[ .!]+$//")
  for allowed in "${APPROVALS[@]}"; do
    [[ $normalized == "$allowed" ]] || continue
    date=$(date +%F)
    doc_set_status "$doc" APPROVED "$date, approved by the user in conversation (« $quote »)" \
      || die "échec : statut non écrit dans $REL"
    printf '%s\t%s\t%s\t%s\n' "$date" "$REL" "$(doc_fingerprint "$doc")" "$quote" >>"$PROJECT/.forge/approvals.log" \
      || die "échec : journal $PROJECT/.forge/approvals.log non écrit"
    printf 'approuvé : %s, le %s (« %s »)\n' "$REL" "$date" "$quote"
    return 0
  done
  die "refusé : « $quote » n'est pas une approbation explicite (oui, je valide, j'approuve…) ; statut inchangé ($status)."
}

case ${1:-} in
  init) shift; cmd_init "$@" ;;
  checkpoint) shift; cmd_checkpoint "$@" ;;
  status) shift; cmd_status "$@" ;;
  approve) shift; cmd_approve "$@" ;;
  help | --help | -h) usage ;;
  "") usage >&2; exit 1 ;;
  *) printf 'commande inconnue : %s\n' "$1" >&2; usage >&2; exit 1 ;;
esac
