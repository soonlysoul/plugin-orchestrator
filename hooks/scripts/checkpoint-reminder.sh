#!/usr/bin/env bash
# checkpoint-reminder — Stop hook.
# When <project>/.forge/checkpoint.md is older than the last commit or than an uncommitted
# change of the project, asks Claude once to update it, through
# hookSpecificOutput.additionalContext. A last commit that carries the checkpoint, unchanged
# since, does not count: the checkpoint is written just before the commit that includes it.
# Inert without a checkpoint (the project is CLAUDE_PROJECT_DIR, else the cwd of the input),
# outside a git repository, or when stop_hook_active is true. Installed for the account, it
# runs in every session; it assumes no order among the hooks of an event.
# Fail-open: never fails, every problem ends silently with exit 0 (onFailure has no effect on Stop).

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
IFS= read -r -d '' input || true
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input" || exit 0
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == false ]] || exit 0
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input" 2>/dev/null)}
checkpoint="$root/.forge/checkpoint.md"
[[ -n $root && -f $checkpoint ]] || exit 0
git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
# The project may be a subdirectory of the repository, whose status paths start at its top.
top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || exit 0
prefix=$(git -C "$root" rev-parse --show-prefix 2>/dev/null) || exit 0

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

# The last commit of a workflow carries the checkpoint, written just before it: the commit is
# always newer, yet the checkpoint is up to date as long as it has not changed since.
carried_by_head() {
  [[ -n $(git -C "$root" diff-tree --root --no-commit-id --name-only -r HEAD -- .forge/checkpoint.md 2>/dev/null) ]] \
    && git -C "$root" diff --quiet HEAD -- .forge/checkpoint.md 2>/dev/null
}

reason=""
commit_time=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
checkpoint_time=$(mtime "$checkpoint")
if [[ -n $commit_time && -n $checkpoint_time ]] && ((commit_time > checkpoint_time)) && ! carried_by_head; then
  reason="le dernier commit ($(git -C "$root" log -1 --format=%h)) est plus récent que lui"
else
  while IFS= read -r -d '' entry; do
    status=${entry:0:2} path=${entry:3}
    # A rename or copy is followed by its original path.
    if [[ $status == R* || $status == C* ]]; then IFS= read -r -d '' _; fi
    [[ $path != "${prefix}.forge/checkpoint.md" ]] || continue
    # Files only: a directory's date moves when an entry inside it is renamed (as editors save),
    # so an untracked .forge/ would always look newer than the checkpoint it holds.
    if [[ -f $top/$path && $top/$path -nt $checkpoint ]]; then
      reason="des changements non commités sont plus récents que lui (par exemple ${path#"$prefix"})"
      break
    fi
  done < <(git -C "$root" status --porcelain -z --untracked-files=all -- . 2>/dev/null)
fi
[[ -n $reason ]] || exit 0

message="plugin-orchestrator : .forge/checkpoint.md est périmé : $reason. Mets-le à jour maintenant avec les étapes accomplies (commande et code de sortie), les résultats des tests, la prochaine action et tout blocage. Puis arrête-toi ; ne commence aucun nouveau travail."
jq -nc --arg m "$message" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
exit 0
