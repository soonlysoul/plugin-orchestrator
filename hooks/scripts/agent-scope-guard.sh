#!/usr/bin/env bash
# agent-scope-guard — PreToolUse hook for Edit|Write|NotebookEdit|Bash|PowerShell|Monitor.
# For the plugin's own agents (agent_type plugin-orchestrator:<agent>), enforces what an agent
# frontmatter cannot express: the directories each one may write, under the project root
# (CLAUDE_PROJECT_DIR, else the cwd of the input), and its allowlist of single shell commands —
# product-architect: docs/product/, no shell; project-architect: docs/, git in read mode;
# integration-reviewer: no file, git in read mode. Inert in every other session, an agent of the
# same name from another plugin included: each plugin keeps its own guard. Installed for the
# account, it runs in every session; it assumes no order among the hooks of an event.
# Fail-closed: exit 2 with the reason on stderr blocks; an internal error blocks too (jq
# missing, unreadable input, lexer missing); hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C
PLUGIN=plugin-orchestrator

_decided=0
trap '[[ $_decided == 1 ]] || { echo "agent-scope-guard : erreur interne ; appel bloqué par précaution." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Bloqué par plugin-orchestrator (agent-scope-guard) : %s\n' "$1" >&2
  printf "Utilise Read, Grep et Glob pour inspecter les fichiers. Ne contourne pas cette limite : signale ce que tu n'as pas pu faire sous OPEN_QUESTIONS.\n" >&2
  exit 2
}

IFS= read -r -d '' input || true

# An input without the plugin prefix cannot come from one of the plugin's agents.
[[ $input == *"$PLUGIN:"* ]] || allow

here=${BASH_SOURCE[0]%/*}
[[ $here != "${BASH_SOURCE[0]}" ]] || here=.
# shellcheck source=lib/shell-lexer.sh
source "$here/lib/shell-lexer.sh" || block "bibliothèque lib/shell-lexer.sh introuvable."
command -v jq >/dev/null 2>&1 || block "jq est requis pour vérifier le périmètre de l'agent et manque du PATH. Installer jq."
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input" || block "entrée illisible."

agent=$(jq -r '.agent_type // "" | strings' <<<"$input")
[[ $agent == "$PLUGIN:"* ]] || allow
agent=${agent#"$PLUGIN:"}

# « Git en lecture » of the architecture: the same list for every agent given a shell.
GIT_READ="git status, git log, git diff, git show, git ls-files, git rev-parse, git branch --show-current"
case $agent in
  product-architect)
    write_dirs="docs/product"
    allowed_commands=""
    ;;
  project-architect)
    write_dirs="docs"
    allowed_commands="$GIT_READ"
    ;;
  integration-reviewer)
    write_dirs=""
    allowed_commands="$GIT_READ"
    ;;
  *) block "aucun périmètre n'est défini pour l'agent $agent." ;;
esac

# git_read_only <words after git>: the read-only git commands; --no-pager is harmless.
git_read_only() {
  if [[ ${1-} == --no-pager ]]; then shift; fi
  case ${1-} in
    status | log | diff | show | ls-files | rev-parse) return 0 ;;
    branch) [[ $# == 2 && $2 == --show-current ]] ;;
    *) return 1 ;;
  esac
}

# command_allowed <words>: the allowlist of the current agent.
command_allowed() {
  case $agent in
    project-architect | integration-reviewer)
      [[ ${1-} == git ]] && git_read_only "${@:2}"
      ;;
    # A case without a matching branch returns 0: an agent without a branch must not pass.
    *) return 1 ;;
  esac
}

check_write() {
  local path root rel dir listed=""
  path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // "" | strings' <<<"$input")
  [[ -n $write_dirs ]] || block "$agent n'écrit aucun fichier."
  for dir in $write_dirs; do listed+="${listed:+, }$dir/"; done
  [[ $path == /* ]] || block "$agent n'écrit que des fichiers donnés par un chemin absolu sous : $listed."
  case /$path/ in
    */../* | */./*) block "$agent ne peut pas utiliser . ou .. dans un chemin : $path" ;;
  esac
  root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input")}
  root=${root%/}
  [[ -n $root ]] || block "la racine du projet est inconnue."
  [[ $path == "$root"/* ]] || block "$agent n'écrit que dans le projet, sous : $listed. Refusé : $path"
  rel=${path#"$root"/}
  for dir in $write_dirs; do
    if [[ $rel == "$dir"/* ]]; then allow; fi
  done
  block "$agent n'écrit que sous : $listed. Refusé : $rel"
}

check_command() {
  local command word
  [[ -n $allowed_commands ]] || block "$agent ne lance aucune commande."
  command=$(jq -er '.tool_input.command // "" | strings' <<<"$input") || block "tool_input.command n'est pas une chaîne."
  [[ -n $command ]] || block "$agent ne lance que : $allowed_commands."
  sw_lex "$command"
  if ((SW_COMPOUND || ${#SW_SEGMENTS[@]} != 1)); then
    block "$agent ne lance qu'une commande simple à la fois, sans ;, &&, |, redirection ni substitution. Permises : $allowed_commands."
  fi
  sw_words "${SW_SEGMENTS[0]}"
  for word in "${SW_WORDS[@]}"; do
    case $word in
      --output | --output=* | --write | --write=*) block "$agent ne peut pas utiliser une option qui écrit un fichier ($word)." ;;
    esac
  done
  if command_allowed "${SW_WORDS[@]}"; then allow; fi
  block "$agent ne lance que : $allowed_commands."
}

case $(jq -r '.tool_name // "" | strings' <<<"$input") in
  Edit | Write | NotebookEdit) check_write ;;
  Bash | PowerShell | Monitor) check_command ;;
esac
allow
