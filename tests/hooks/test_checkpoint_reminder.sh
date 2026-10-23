#!/usr/bin/env bash
# checkpoint-reminder: simulated inputs, no session, real throwaway git repositories. Stop hook
# that resumes Claude once, through additionalContext, when .forge/checkpoint.md is older than
# the last commit or an uncommitted change of the project, unless that last commit carries the
# checkpoint, unchanged since. Silent without a checkpoint or when stop_hook_active; never fails.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_checkpoint_reminder
HOOK="$PLUGIN_ROOT/hooks/scripts/checkpoint-reminder.sh"

echo "# contrat du squelette"
run_hook "$HOOK" 'pas du json'
expect_status "squelette : entrée illisible, exit 0" 0
no_jq=$(mktemp -d)
run_hook "$HOOK" '{}' PATH="$no_jq"
rm -r "$no_jq"
expect_status "squelette : jq absent, exit 0" 0

work=$(mktemp -d)
trap 'rm -r "$work"' EXIT

# stop_input <cwd> [stop_hook_active]
stop_input() {
  jq -nc --arg d "$1" --argjson a "${2:-false}" \
    '{session_id: "test", cwd: $d, hook_event_name: "Stop", permission_mode: "default",
      stop_hook_active: $a, last_assistant_message: "Done."}'
}

# make_repo: a project committed on 2026-01-10 with a tracked checkpoint. Prints its path.
make_repo() {
  local repo
  repo=$(mktemp -d "$work/repo.XXXXXX")
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name Test
  git -C "$repo" config commit.gpgsign false
  mkdir -p "$repo/src" "$repo/.forge"
  echo "export {};" >"$repo/src/main.ts"
  echo "# Point de reprise" >"$repo/.forge/checkpoint.md"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="2026-01-10T12:00:00" GIT_COMMITTER_DATE="2026-01-10T12:00:00" \
    git -C "$repo" commit -qm init
  touch -t 202601100000 "$repo/src/main.ts"
  touch -t 202601150000 "$repo/.forge/checkpoint.md"
  printf '%s' "$repo"
}

# commit_later <repo>: a commit on 2026-01-20 that leaves the checkpoint out, as a commit made
# outside the workflow would.
commit_later() {
  echo "// later" >>"$1/src/main.ts"
  git -C "$1" add src/main.ts
  GIT_AUTHOR_DATE="2026-01-20T12:00:00" GIT_COMMITTER_DATE="2026-01-20T12:00:00" \
    git -C "$1" commit -qm later
}

expect_reminder() {
  local label=$1 needle=$2 context
  context=$(jq -r 'select(.hookSpecificOutput.hookEventName == "Stop" and (has("decision") | not))
                   | .hookSpecificOutput.additionalContext // empty' <<<"$HOOK_STDOUT" 2>/dev/null)
  if [[ $HOOK_STATUS == 0 && -n $context && $context == *plugin-orchestrator* && $context == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "exit $HOOK_STATUS ; stdout : ${HOOK_STDOUT:0:300} ; stderr : ${HOOK_STDERR:0:200}"
  fi
}

echo "# rappels"
repo=$(make_repo)
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "checkpoint plus récent que le commit, sans changement : silencieux"

repo=$(make_repo)
commit_later "$repo"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "checkpoint plus vieux qu'un dernier commit qui ne le porte pas" "dernier commit"
[[ $HOOK_STDERR == "" ]] && pass "un rappel n'écrit rien sur stderr" || fail "un rappel n'écrit rien sur stderr" "$HOOK_STDERR"

# The last commit of a workflow carries the checkpoint, written just before it, so the commit is
# always newer; reminding then would dirty the tree after every workflow.
repo=$(make_repo)
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "le dernier commit porte le checkpoint, inchangé depuis : silencieux"

repo=$(make_repo)
echo "- [x] 2 autre chose" >>"$repo/.forge/checkpoint.md"
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "le dernier commit porte le checkpoint, changé depuis mais plus vieux" "dernier commit"

# A carrying commit that is not the root one, then work left uncommitted.
repo=$(make_repo)
echo "- [x] 2 fait" >>"$repo/.forge/checkpoint.md"
git -C "$repo" add .forge/checkpoint.md
GIT_AUTHOR_DATE="2026-01-20T12:00:00" GIT_COMMITTER_DATE="2026-01-20T12:00:00" git -C "$repo" commit -qm step
touch -t 202601150000 "$repo/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "un commit ultérieur porte le checkpoint, inchangé depuis : silencieux"
echo "// changed" >>"$repo/src/main.ts"
touch -t 202601250000 "$repo/src/main.ts"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "après le commit porteur, un fichier modifié plus récent que le checkpoint" "src/main.ts"

# The project is a subdirectory of the repository, whose status paths start at the repository root.
mono=$(mktemp -d "$work/mono.XXXXXX")
git -C "$mono" init -q
git -C "$mono" config user.email test@example.test
git -C "$mono" config user.name Test
git -C "$mono" config commit.gpgsign false
mkdir -p "$mono/app/src" "$mono/app/.forge"
echo "export {};" >"$mono/app/src/main.ts"
echo "# Point de reprise" >"$mono/app/.forge/checkpoint.md"
git -C "$mono" add -A
GIT_AUTHOR_DATE="2026-01-10T12:00:00" GIT_COMMITTER_DATE="2026-01-10T12:00:00" git -C "$mono" commit -qm init
touch -t 202601050000 "$mono/app/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$mono/app")"
expect_silent_allow "projet en sous-dossier, dernier commit porteur du checkpoint : silencieux"
mkdir -p "$mono/other"
echo "notes" >"$mono/other/notes.txt"
touch -t 202601200000 "$mono/other/notes.txt"
run_hook "$HOOK" "$(stop_input "$mono/app")"
expect_silent_allow "un fichier plus récent hors du dossier du projet : silencieux"
rm "$mono/other/notes.txt"
echo "export class Note {}" >"$mono/app/src/note.ts"
touch -t 202601200000 "$mono/app/src/note.ts"
run_hook "$HOOK" "$(stop_input "$mono/app")"
expect_reminder "projet en sous-dossier, un nouveau fichier plus récent que le checkpoint" "src/note.ts"
echo "// changed" >>"$mono/app/src/main.ts"
rm "$mono/app/src/note.ts"
touch -t 202601200000 "$mono/app/src/main.ts"
run_hook "$HOOK" "$(stop_input "$mono/app")"
expect_reminder "projet en sous-dossier, un fichier modifié plus récent que le checkpoint" "src/main.ts"

repo=$(make_repo)
echo "// changed" >>"$repo/src/main.ts"
touch -t 202601200000 "$repo/src/main.ts"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "checkpoint plus vieux qu'un fichier modifié" "src/main.ts"

repo=$(make_repo)
echo "export class Note {}" >"$repo/src/note.ts"
touch -t 202601200000 "$repo/src/note.ts"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "checkpoint plus vieux qu'un fichier non suivi" "src/note.ts"

repo=$(make_repo)
mkdir -p "$repo/src/notes"
echo "export class Note {}" >"$repo/src/notes/note.ts"
touch -t 202601200000 "$repo/src/notes/note.ts"
touch -t 202601120000 "$repo/src/notes"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_reminder "fichier plus récent dans un dossier non suivi dont la date est plus vieille" "src/notes/note.ts"

# Before the first commit, git reports the untracked .forge/ directory, and an edit through
# rename leaves the directory newer than the checkpoint it holds.
early=$(mktemp -d "$work/early.XXXXXX")
git -C "$early" init -q
mkdir -p "$early/.forge"
echo "# Point de reprise" >"$early/.forge/checkpoint.md"
touch -t 202601150000 "$early/.forge/checkpoint.md"
touch -t 202601150100 "$early/.forge"
run_hook "$HOOK" "$(stop_input "$early")"
expect_silent_allow ".forge/ non suivi plus récent que son checkpoint avant le premier commit : silencieux"

repo=$(make_repo)
echo "// changed" >>"$repo/src/main.ts"
touch -t 202601120000 "$repo/src/main.ts"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "fichier modifié plus vieux que le checkpoint : silencieux"

repo=$(make_repo)
echo "- [x] 1 État du dépôt vérifié" >>"$repo/.forge/checkpoint.md"
touch -t 202601200000 "$repo/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "seul le checkpoint lui-même a changé : silencieux"

repo=$(make_repo)
rm "$repo/src/main.ts"
run_hook "$HOOK" "$(stop_input "$repo")"
expect_silent_allow "un fichier supprimé ne casse pas le hook"

echo "# hors contexte : silencieux"
repo=$(make_repo)
commit_later "$repo"
run_hook "$HOOK" "$(stop_input "$repo" true)"
expect_silent_allow "stop_hook_active : pas de second rappel, sur un état qui rappellerait"

plain=$(mktemp -d "$work/plain.XXXXXX")
run_hook "$HOOK" "$(stop_input "$plain")"
expect_silent_allow "aucun dossier .forge/"

nogit=$(mktemp -d "$work/nogit.XXXXXX")
mkdir -p "$nogit/.forge"
echo "# Point de reprise" >"$nogit/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$nogit")"
expect_silent_allow "checkpoint hors d'un dépôt git"

fresh=$(mktemp -d "$work/fresh.XXXXXX")
git -C "$fresh" init -q
mkdir -p "$fresh/.forge"
echo "# Point de reprise" >"$fresh/.forge/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$fresh")"
expect_silent_allow "dépôt sans commit"

repo=$(make_repo)
commit_later "$repo"
run_hook "$HOOK" "$(stop_input "$plain")" CLAUDE_PROJECT_DIR="$repo"
expect_reminder "CLAUDE_PROJECT_DIR passe avant cwd" "dernier commit"

echo "# ne faillit jamais"
run_hook "$HOOK" '{"hook_event_name": "Stop", '
expect_silent_allow "JSON malformé"
jq_only=$(restricted_path jq)
run_hook "$HOOK" "$(stop_input "$repo")" PATH="$jq_only"
expect_silent_allow "git absent du PATH"
rm -r "$jq_only"
no_tools=$(restricted_path)
run_hook "$HOOK" "$(stop_input "$repo")" PATH="$no_tools"
expect_silent_allow "jq absent du PATH"
rm -r "$no_tools"

finish
