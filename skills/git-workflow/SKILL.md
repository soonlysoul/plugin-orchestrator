---
name: git-workflow
description: "Branch, stage, commit and inspect diffs safely in a project that has a .forge/ directory — branches named from project.branch_prefix, explicit staging, atomic Conventional Commits, diff summaries, push of a work branch only when preauthorized and never of the default branch. Use when the user or another workflow asks for a branch, a commit, a diff summary or a push in such a project, including a push the skill will refuse, such as the default branch; not for a remote repository, a pull request or a CI, which is github-workflow. « crée une branche pour AC-012 », « commite ça », « pousse main sur origin »."
argument-hint: "[branch | commit | diff | push]"
when_to_use: "In a project that has a .forge/ directory, for any Git gesture asked of Claude: branch, diff, stage, commit, push, including one the skill refuses, such as pushing the default branch."
---

# Git workflow

Address the user in French unless they write in another language. Commit messages, branch names and file contents stay in English.

Request: $ARGUMENTS

## Before anything

The repository is the project root, the folder that holds `.forge/`; a part of a multi-part project is a folder inside it. Run every Git command from that root.

Read `.forge/config.yaml`; a missing key counts as false. A file without `parts` (`schema_version: 1`) belongs to a plugin-flutter 0.x project: stop, show the `parts` block of `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml` to add, and leave the edit to the user — Claude never edits that file. Run `git status` and `git branch --show-current`.

Every Git or GitHub action falls into one of these classes:

| Action | Class |
| --- | --- |
| `git status`, `git diff`, `git log`, `git switch -c` | free |
| `git add <explicit files>` | free, after reviewing the diff |
| `git commit` | asks for confirmation (project rule) |
| `git push` of a work branch | only if `authorizations.push_feature_branches: true`, or on the user's explicit request in this conversation |
| `git push` of the default branch | never done by Claude, even after a confirmation: the user runs it |
| creating a remote repository, opening a pull request | the github-workflow skill, with its validation points |
| merging, changing visibility, deleting, releasing, pushing a tag | never done by Claude: the user does it; the guard-destructive hook blocks them |
| `reset --hard`, `clean -f`, `push --force`, `branch -D`, `checkout -- <path>`, `restore` (except `restore --staged`), `stash drop`, `stash clear` | forbidden: the guard-destructive hook and the project's deny rules block them |

When a blocked command is really needed, explain why it is blocked and what it would destroy. The user can run it themselves with the `!` prefix; never rephrase it to get around the hook.

## Branch

Names: `<prefix>/<ac-id>-<slug>` for a feature, with the prefix from `project.branch_prefix` (`feature` when the key is missing); `fix/<slug>`; `docs/<slug>`; `chore/ci` (github-workflow); `chore/deps-<slug>` and `chore/adopt-<plugin>` belong to the language plugins (their update and adoption skills). The slug is short, lowercase, hyphenated, in English: `story/AC-012-offline-notes-list`.

Start from the default branch (`project.default_branch`): `git switch <default branch>`, then `git switch -c <name>`. Untracked files are carried along and only listed. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state: carry them along too. With any other change to a tracked file, staged or not, do not create the branch yet: name the branch you would create and the files changed, and ask whether to commit the change first, carry it onto the new branch, or stop. Never `git stash` silently.

## Diff report

`git status --short`, `git diff --stat`, then `git diff` and `git diff --cached`. Report the files by kind (code, tests, docs, generated) and by part when the project has several, and flag what should not be committed: build outputs, `.env*`, keystores, `key.properties`, editor files.

## Stage

`git add <file> <file> …`, listing the files. When a dependency of a part changed, stage the files its `toolchain.manifests` lists with the change. `git add -A`, `git add .` and `git add --all` only after the whole diff has been reviewed with the user; the project rules make them ask. Before committing, read `git diff --cached` for secrets (AWS keys, `-----BEGIN`, `ghp_`, `sk-`, `AIza`); if one appears, unstage the file (`git restore --staged <file>`, or `git rm --cached <file>` before the first commit, when there is no HEAD yet), never print the secret, and tell the user which file holds it. The secret-scan hook checks every commit the same way and blocks it; when it does, follow its reason, never rephrase the commit to get past it.

## Commit

- One logical change per commit, with its tests.
- Conventional Commits: `type(scope): summary`, with the acceptance criterion in parentheses when there is one: `feat(notes): list notes offline (AC-012)`. Types: feat, fix, test, refactor, docs, chore. In a multi-part project, the scope names the part when the change belongs to one.
- Show the message and the file list, then run `git commit -m "<message>"`. For a message with a body, use `git commit -F -` with a quoted heredoc (`<<'EOF'`), so that nothing in the message is expanded or run.
- After the commit, `git log --oneline -1`.
- A commit that carries `.forge/checkpoint.md`: write the checkpoint before staging it, with the steps done, the commit step ticked `carried by this commit` instead of an exit code (a commit cannot record its own result), and the next action; its `last_commit` names the commit before. Do not change the checkpoint again for that commit: the next update belongs to the next step, if the workflow has one. After the last commit of a workflow, the working tree thus stays clean, a later `git switch` works, and the checkpoint-reminder hook accepts the checkpoint carried by the last commit.

## Push

Only a work branch, never the default branch, never with force. Check the class above first. Run `git remote -v`: without a remote, stop; creating one is an explicit decision of the user, through the github-workflow skill (`remote`). Then `git push -u origin <branch>`, and report the output.

Asked to push the default branch: do not push, say that this skill pushes only a work branch and that publishing the default branch is the user's own gesture, and give them the command to run themselves (`git push origin <default branch>`). One exception, owned by the github-workflow skill: the first publication of the default branch to a repository it has just created, which the user approved with the creation.

## Report

Branch, commits (hash and message), files staged or committed, and what was not done with the reason.
