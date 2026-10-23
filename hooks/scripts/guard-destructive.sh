#!/usr/bin/env bash
# guard-destructive — PreToolUse hook for Bash|PowerShell|Monitor.
# Blocks a destructive command wherever the shell structure hides it: git that discards work or
# rewrites a remote, rm -rf outside build/, gh that deletes, merges or releases, and publication
# to a registry (pub.dev, npm, PyPI) without --dry-run. Always active — what destroys, destroys
# in every project — and silent on anything else. Installed for the account, it runs in every
# session; it assumes no order among the hooks of an event.
# Fail-closed: exit 2 with the reason on stderr blocks; an internal error blocks too (jq
# missing, unreadable input, lexer missing); hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C

_decided=0
trap '[[ $_decided == 1 ]] || { echo "guard-destructive : erreur interne ; blocage par précaution." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Bloqué par plugin-orchestrator (guard-destructive) : %s\n' "$1" >&2
  printf "Ne relance pas cette commande et ne la reformule pas. Explique le risque à l'utilisateur ; s'il la veut, il la lance lui-même.\n" >&2
  exit 2
}

here=${BASH_SOURCE[0]%/*}
[[ $here != "${BASH_SOURCE[0]}" ]] || here=.
# shellcheck source=lib/shell-lexer.sh
source "$here/lib/shell-lexer.sh" || block "bibliothèque lib/shell-lexer.sh introuvable."
command -v jq >/dev/null 2>&1 || block "jq est requis pour lire la commande et manque du PATH. Installer jq."

MAX_DEPTH=4

# has_option <short letters> <long options...> -- <words...>
# True if, before a "--" word, a word is one of the long options (alone or --opt=value)
# or a cluster of short options (-xyz) containing one of the letters.
has_option() {
  local shorts=$1 word long
  local -a longs=()
  shift
  while (($#)) && [[ $1 != -- ]]; do longs+=("$1"); shift; done
  if (($#)); then shift; fi
  for word in "$@"; do
    case $word in
      --) return 1 ;;
      --*)
        for long in ${longs[@]+"${longs[@]}"}; do
          if [[ $word == "$long" || $word == "$long="* ]]; then return 0; fi
        done
        ;;
      -*)
        if [[ -n $shorts && $word =~ ^-[A-Za-z]+$ && $word == *["$shorts"]* ]]; then return 0; fi
        ;;
    esac
  done
  return 1
}

# check_code <code> <depth>: check every simple command, then the nested code.
check_code() {
  local depth=$2 segment nested
  ((depth <= MAX_DEPTH)) || block "imbrication de commandes trop profonde pour être analysée."
  sw_lex "$1"
  local -a segments=(${SW_SEGMENTS[@]+"${SW_SEGMENTS[@]}"})
  local -a nested_code=(${SW_NESTED[@]+"${SW_NESTED[@]}"})
  for segment in ${segments[@]+"${segments[@]}"}; do
    sw_words "$segment"
    check_simple_command "$depth" "${SW_WORDS[@]}"
  done
  for nested in ${nested_code[@]+"${nested_code[@]}"}; do
    check_code "$nested" $((depth + 1))
  done
}

check_simple_command() {
  local depth=$1
  shift
  # Skip what comes before the program: assignments, keywords, wrapper commands.
  sw_program "$@" || return 0
  local -a cmd=("${@:SW_AT+1}")
  local -a args=("${cmd[@]:1}")
  local program=${cmd[0]##*/}
  case $program in
    git) check_git ${args[@]+"${args[@]}"} ;;
    rm) check_rm ${args[@]+"${args[@]}"} ;;
    gh) check_gh ${args[@]+"${args[@]}"} ;;
    flutter | dart) check_pub ${args[@]+"${args[@]}"} ;;
    npm | pnpm | yarn | bun) check_registry "$program" "publish unpublish" ${args[@]+"${args[@]}"} ;;
    twine) check_registry "$program" "upload" ${args[@]+"${args[@]}"} ;;
    uv | poetry | hatch | flit) check_registry "$program" "publish" ${args[@]+"${args[@]}"} ;;
    find) check_find "$depth" ${args[@]+"${args[@]}"} ;;
    eval) check_code "${args[*]-}" $((depth + 1)) ;;
    bash | sh | zsh | dash | ksh | ash) check_shell "$depth" ${args[@]+"${args[@]}"} ;;
  esac
}

# find -exec / -execdir / -ok / -okdir run a command: check it like any other.
check_find() {
  local depth=$1 word collecting=0
  local -a sub=()
  shift
  for word in "$@"; do
    if ((collecting)); then
      if [[ $word == ';' || $word == + ]]; then
        if ((${#sub[@]})); then check_simple_command "$depth" "${sub[@]}"; fi
        sub=() collecting=0
      else
        sub+=("$word")
      fi
    else
      case $word in
        -exec | -execdir | -ok | -okdir) collecting=1 ;;
      esac
    fi
  done
  if ((${#sub[@]})); then check_simple_command "$depth" "${sub[@]}"; fi
}

# rm -rf is allowed only on build/ (relative to the session cwd).
check_rm() {
  local target
  { has_option rR --recursive -- "$@" && has_option f --force -- "$@"; } || return 0
  positionals "$@"
  ((${#POS[@]})) || block "rm -rf sans cible visible (via xargs, par exemple) ne peut pas être vérifié."
  for target in "${POS[@]}"; do
    in_build_dir "$target" || block "rm -rf hors de build/ supprime des fichiers pour de bon : $target"
  done
}

in_build_dir() {
  local path=$1
  [[ $path != *..* ]] || return 1
  if [[ $path == /* ]]; then
    [[ -n $HOOK_CWD && $path == "$HOOK_CWD"/* ]] || return 1
    path=${path#"$HOOK_CWD"/}
  fi
  path=${path#./}
  [[ $path == build || $path == build/* ]]
}

check_gh() {
  local group=${1-} action=${2-}
  if (($# >= 2)); then shift 2; else shift $#; fi
  case $group/$action in
    repo/delete) block "gh repo delete supprime un dépôt." ;;
    repo/edit)
      if has_option "" --visibility -- "$@"; then block "changer la visibilité d'un dépôt demande l'accord explicite de l'utilisateur."; fi
      ;;
    pr/merge) block "fusionner une pull request demande l'accord explicite de l'utilisateur." ;;
    release/create | release/delete | release/delete-asset | release/edit | release/upload)
      block "créer ou modifier une release demande l'accord explicite de l'utilisateur."
      ;;
    api/*) check_gh_api "$action" "$@" ;;
  esac
}

check_gh_api() {
  local word previous="" method=""
  for word in "$@"; do
    case $previous in
      -X | --method) method=$word ;;
    esac
    case $word in
      -X?*) method=${word#-X} ;;
      --method=*) method=${word#--method=} ;;
    esac
    previous=$word
  done
  if [[ $method == [Dd][Ee][Ll][Ee][Tt][Ee] ]]; then block "gh api -X DELETE supprime une ressource GitHub."; fi
}

# flutter pub publish / dart pub publish, except --dry-run.
check_pub() {
  while [[ ${1-} == -* ]]; do shift; done
  [[ ${1-} == pub ]] || return 0
  shift
  while [[ ${1-} == -* ]]; do shift; done
  [[ ${1-} == publish ]] || return 0
  shift
  has_option n --dry-run -- "$@" || block "publier un paquet sur pub.dev demande l'accord explicite de l'utilisateur."
}

# check_registry <tool> <subcommands> <words...>: <tool> <subcommand> sends a package to a
# registry (npm, PyPI), or removes one from it; blocked except --dry-run. The subcommand is
# looked for among all the words before "--", since options may precede it (pnpm --filter api
# publish, yarn npm publish).
check_registry() {
  local tool=$1 subs=" $2 " word
  shift 2
  for word in "$@"; do
    [[ $word != -- ]] || return 0
    if [[ $subs == *" $word "* ]]; then
      has_option "" --dry-run -- "$@" \
        || block "$tool $word publie vers un registre, ou en retire un paquet : accord explicite de l'utilisateur requis."
      return 0
    fi
  done
  return 0
}

# A shell given -c runs its next argument as code; a script file is not analysed.
check_shell() {
  local depth=$1 word
  shift
  while (($#)); do
    word=$1
    shift
    case $word in
      --*) ;;
      -o | +o) if (($#)); then shift; fi ;;
      -*c*) if (($#)); then check_code "$1" $((depth + 1)); fi; return 0 ;;
      -*) ;;
      *) return 0 ;;
    esac
  done
}

# positionals <words...>: set POS to the words that are not options (every word after "--").
positionals() {
  local word past=0
  POS=()
  for word in "$@"; do
    if ((!past)); then
      if [[ $word == -- ]]; then past=1; continue; fi
      if [[ $word == -?* ]]; then continue; fi
    fi
    POS+=("$word")
  done
}

check_git() {
  while (($#)); do
    case $1 in
      -C | -c | --git-dir | --work-tree | --namespace | --super-prefix | --config-env) shift; if (($#)); then shift; fi ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  (($#)) || return 0
  local subcommand=$1 word after_separator=0
  shift
  positionals "$@"
  case $subcommand in
    reset)
      if has_option "" --hard -- "$@"; then block "git reset --hard jette le travail non commité."; fi
      ;;
    clean)
      if has_option f --force -- "$@"; then block "git clean --force supprime les fichiers non suivis."; fi
      ;;
    push) check_git_push "$@" ;;
    branch)
      if has_option D -- "$@" || { has_option d --delete -- "$@" && has_option f --force -- "$@"; }; then
        block "git branch -D supprime une branche même non fusionnée."
      fi
      ;;
    checkout)
      if has_option f --force -- "$@"; then block "git checkout --force jette les modifications non commitées."; fi
      for word in "$@"; do
        if ((after_separator)); then block "git checkout -- <chemin> jette les modifications non commitées de ces chemins."; fi
        if [[ $word == -- ]]; then after_separator=1; fi
      done
      for word in ${POS[@]+"${POS[@]}"}; do
        if [[ $word == . || $word == ./ ]]; then block "git checkout . jette toutes les modifications non commitées."; fi
      done
      ;;
    restore)
      if ! has_option S --staged -- "$@" || has_option W --worktree -- "$@"; then
        block "git restore sans --staged seul jette les modifications non commitées."
      fi
      ;;
    stash)
      case ${POS[0]-} in
        drop | clear) block "git stash ${POS[0]} supprime pour de bon le travail remisé." ;;
      esac
      ;;
    switch)
      if has_option f --discard-changes --force -- "$@"; then block "git switch --discard-changes jette les modifications non commitées."; fi
      ;;
  esac
}

check_git_push() {
  local word tags_reason="pousser des tags publie des points de release et demande l'accord explicite de l'utilisateur."
  if has_option f --force --force-with-lease --force-if-includes -- "$@"; then block "un push forcé réécrit l'historique distant."; fi
  if has_option d --delete -- "$@"; then block "git push --delete supprime une branche distante."; fi
  if has_option "" --mirror -- "$@"; then block "git push --mirror écrase toutes les références du dépôt distant."; fi
  if has_option "" --tags --follow-tags -- "$@"; then block "$tags_reason"; fi
  positionals "$@"
  for word in ${POS[@]+"${POS[@]}"}; do
    case $word in
      +*) block "un +refspec est un push forcé." ;;
      :*) block "un :refspec supprime une branche distante." ;;
      refs/tags/* | *:refs/tags/*) block "$tags_reason" ;;
    esac
  done
}

IFS= read -r -d '' input || true
jq -e 'type == "object" and (.tool_name | type == "string")' >/dev/null 2>&1 <<<"$input" \
  || block "entrée illisible."
tool=$(jq -r '.tool_name' <<<"$input")

case $tool in
  Bash | PowerShell | Monitor) ;;
  *) allow ;;
esac

command=$(jq -er '.tool_input.command // "" | strings' <<<"$input") \
  || block "tool_input.command n'est pas une chaîne."
[[ -n $command ]] || allow
HOOK_CWD=$(jq -r '.cwd // "" | strings' <<<"$input")
HOOK_CWD=${HOOK_CWD%/}

check_code "$command" 0
allow
