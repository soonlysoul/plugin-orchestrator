#!/usr/bin/env bash
# agent-scope-guard — PreToolUse hook for Edit|Write|NotebookEdit|Bash|PowerShell|Monitor.
# Holds each agent of the plugin (agent_type plugin-orchestrator:<agent>) to the scope that
# hooks/agent-scope.json declares for it, written by pp.sh add-agent when the agent is added:
# "write", the directories it may write, under the project root (CLAUDE_PROJECT_DIR, else the
# cwd of the input); "bash", its allowlist of single shell commands, each entry matched word by
# word as a prefix (`git branch --show-current` allows nothing else after `git branch`; `git
# --no-pager` counts as `git`). Whatever the list, a compound command, a redirection, a
# substitution, a leading assignment, an option that writes a file (--output, --write) or a
# path with . or .. is refused. Inert in every other session, an agent of the same name from
# another plugin included: each plugin keeps its own guard. Installed for the account, it runs
# in every session; it assumes no order among the hooks of an event.
# Fail-closed: exit 2 with the reason on stderr blocks; an internal error blocks too (jq
# missing, unreadable input, lexer missing, scope missing or malformed); hooks.json sets
# "onFailure": "block".
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
tool=$(jq -r '.tool_name // "" | strings' <<<"$input")
case $tool in
  Edit | Write | NotebookEdit | Bash | PowerShell | Monitor) ;;
  *) allow ;;
esac

# The scope of the agent, declared when it was added. No declaration, no scope: refused.
scope_file="$here/../agent-scope.json"
jq -e 'type == "object"' "$scope_file" >/dev/null 2>&1 || block "hooks/agent-scope.json est absent ou illisible : aucun périmètre pour l'agent $agent."
scope=$(jq -c --arg a "$PLUGIN:$agent" '.[$a] // empty' "$scope_file")
[[ -n $scope ]] || block "aucun périmètre n'est déclaré pour l'agent $agent dans hooks/agent-scope.json."
jq -e 'type == "object" and ((.write // []) | type == "array" and all(strings)) and ((.bash // []) | type == "array" and all(strings))' \
  >/dev/null 2>&1 <<<"$scope" || block "périmètre malformé pour l'agent $agent dans hooks/agent-scope.json."
write_dirs=()
allowed=()
listed=""
allowed_commands=""
while IFS= read -r dir; do
  dir=${dir%/}
  [[ -n $dir && $dir != /* && /$dir/ != */../* && /$dir/ != */./* ]] || block "dossier d'écriture malformé pour l'agent $agent : $dir"
  write_dirs+=("$dir")
  listed+="${listed:+, }$dir/"
done < <(jq -r '.write // [] | .[]' <<<"$scope")
while IFS= read -r entry; do
  [[ -n ${entry// /} ]] || continue
  allowed+=("$entry")
  allowed_commands+="${allowed_commands:+, }$entry"
done < <(jq -r '.bash // [] | .[]' <<<"$scope")

# command_allowed <words>: the words start with every word of one entry of the allowlist.
command_allowed() {
  local -a words=("$@") want
  local entry i
  if [[ ${words[0]-} == git && ${words[1]-} == --no-pager ]]; then words=(git "${words[@]:2}"); fi
  for entry in ${allowed[@]+"${allowed[@]}"}; do
    read -ra want <<<"$entry"
    ((${#want[@]} > 0 && ${#want[@]} <= ${#words[@]})) || continue
    for ((i = 0; i < ${#want[@]}; i++)); do
      [[ ${want[i]} == "${words[i]}" ]] || continue 2
    done
    return 0
  done
  return 1
}

check_write() {
  local path root rel dir
  path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // "" | strings' <<<"$input")
  ((${#write_dirs[@]})) || block "$agent n'écrit aucun fichier."
  [[ $path == /* ]] || block "$agent n'écrit que des fichiers donnés par un chemin absolu sous : $listed."
  case /$path/ in
    */../* | */./*) block "$agent ne peut pas utiliser . ou .. dans un chemin : $path" ;;
  esac
  root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input")}
  root=${root%/}
  [[ -n $root ]] || block "la racine du projet est inconnue."
  [[ $path == "$root"/* ]] || block "$agent n'écrit que dans le projet, sous : $listed. Refusé : $path"
  rel=${path#"$root"/}
  for dir in "${write_dirs[@]}"; do
    if [[ $rel == "$dir"/* ]]; then allow; fi
  done
  block "$agent n'écrit que sous : $listed. Refusé : $rel"
}

check_command() {
  local command word
  ((${#allowed[@]})) || block "$agent ne lance aucune commande."
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

case $tool in
  Edit | Write | NotebookEdit) check_write ;;
  *) check_command ;;
esac
