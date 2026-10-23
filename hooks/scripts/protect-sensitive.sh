#!/usr/bin/env bash
# protect-sensitive — PreToolUse hook for Edit|Write|NotebookEdit.
# In a project that has .forge/ (the nearest parent of the file holding one, whatever the
# session root), asks the user to confirm a write to signing material, entitlements, CI
# workflows or .forge/config.yaml; .forge/config.yaml is protected everywhere. Silent outside
# that context, and before anything else when the input names no such file. The decision is a
# JSON "ask" on stdout (in -p runs, Claude Code refuses the call and Claude reads the reason).
# Installed for the account, it runs in every session; it assumes no order among the hooks of
# an event.
# Fail-closed when it must decide: exit 2 with the reason on stderr blocks; an internal error
# blocks too (jq missing, unreadable input); hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C

_decided=0
trap '[[ $_decided == 1 ]] || { echo "protect-sensitive : erreur interne ; écriture bloquée par précaution." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Bloqué par plugin-orchestrator (protect-sensitive) : %s\n' "$1" >&2
  exit 2
}

IFS= read -r -d '' input || true

# Without one of these names in the input, the write cannot be sensitive: no need for jq.
case $input in
  *key.properties* | *.keystore* | *.jks* | *.p12* | *.pfx* | *.entitlements* | *.github/workflows/* | \
    *.github/actions/* | *.forge/config.yaml*) ;;
  *) allow ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the file path is unknown: a session root without .forge/ is the best guess left.
  if [[ -n ${CLAUDE_PROJECT_DIR-} && ! -d ${CLAUDE_PROJECT_DIR%/}/.forge && $input != *.forge/config.yaml* ]]; then allow; fi
  block "jq est requis pour vérifier les fichiers sensibles et manque du PATH. Installer jq."
fi
jq -e 'type == "object" and (.tool_name | type == "string")' >/dev/null 2>&1 <<<"$input" \
  || block "entrée illisible."
case $(jq -r '.tool_name' <<<"$input") in
  Edit | Write | NotebookEdit) ;;
  *) allow ;;
esac
path=$(jq -er '.tool_input.file_path // .tool_input.notebook_path // "" | strings' <<<"$input") \
  || block "le chemin du fichier n'est pas une chaîne."
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input")}
root=${root%/}

abs=$path
if [[ $abs != /* && -n $root ]]; then abs=$root/$abs; fi
# The forge project of a file is the nearest parent holding .forge/, whatever the session root.
project=""
dir=${abs%/*}
while [[ -n $dir ]]; do
  if [[ -d $dir/.forge ]]; then project=$dir; break; fi
  dir=${dir%/*}
done

kind=""
case /$path in
  */.forge/config.yaml) kind="les préautorisations du plugin, que seul l'utilisateur modifie" ;;
esac
if [[ -z $kind && -n $project ]]; then
  case /$path in
    */key.properties | *.keystore | *.jks) kind="du matériel de signature Android" ;;
    *.p12 | *.pfx) kind="un certificat de signature avec sa clé privée" ;;
    *.entitlements) kind="un fichier d'entitlements Apple : il accorde des capacités à l'app" ;;
    */.github/workflows/* | */.github/actions/*) kind="du code de CI : il s'exécute avec les jetons et secrets du dépôt" ;;
  esac
fi
[[ -n $kind ]] || allow

shown=$path
base=${root:-$project}
if [[ -n $base && $abs == "$base"/* ]]; then shown=${abs#"$base"/}; fi
reason="plugin-orchestrator protect-sensitive : $shown est $kind. N'approuve que si ce changement a été demandé. En cas de refus, Claude ne doit pas écrire le fichier autrement, et dit à l'utilisateur ce qu'il voulait changer."
jq -nc --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}' \
  || block "impossible d'écrire la décision."
allow
