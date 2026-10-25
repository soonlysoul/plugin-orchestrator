---
name: recover-session
description: "Resume interrupted work in a project that has a .forge/ directory from what is on disk — .forge/checkpoint.md, the Git history and the repository state — rerunning only the command the checkpoint recorded, and changing nothing before the user agrees. Use when the user asks to resume, continue or see where the work stopped, after a usage limit, a crash or an interruption, in a project that has .forge/checkpoint.md; not for new work, nor for a question about Git itself, such as an interrupted rebase, which is answered directly. « on s'est fait couper, reprends où on en était », « reprends le travail là où il s'est arrêté »."
argument-hint: "[dossier du projet]"
when_to_use: "In a project that has .forge/checkpoint.md, when the user asks to resume, continue or see where the work stopped after an interruption; not for a Git question, nor for a plugin folder holding .plugin-plugin/, which plugin-plugin resumes."
---

# Recover a session

Address the user in French unless they write in another language.

Request: $ARGUMENTS

The work resumes from disk, never from what an earlier session remembers. Until the summary is accepted, this skill is read-only: no stash, no checkout, no commit, no edit of the code, the tests, the documents or the checkpoint. It reads `.forge/checkpoint.md` and Git; it does not need `.forge/config.yaml`.

## Before anything

The project root is the folder that holds `.forge/`: the argument, else the nearest parent of the current folder. Without `.forge/`, this is not a project of this plugin: say so and stop. Run every Git command from that root; a part of a multi-part project is a folder inside it, and its work is in the same checkpoint.

## Step 1 — Read the checkpoint

Read `.forge/checkpoint.md`: `skill`, `feature`, `branch`, `last_commit`, the ticked steps with their commands and exit codes, the test results table, the next action, the blockers. Without a checkpoint, rebuild the state from `git log --oneline -20`, `git branch --show-current` and `git status --porcelain`, say that there was no checkpoint, and ask which workflow to resume: never guess one.

## Step 2 — Compare with the repository

Run `git rev-parse --short HEAD`, `git branch --show-current` and `git status --porcelain`. Compare `last_commit` with `HEAD`, and list the uncommitted files. Touch nothing.

## Step 3 — Report inconsistencies

Flag each one:

- commits newer than `last_commit` (`git log --oneline <last_commit>..HEAD`), apart from the one that carries the checkpoint itself (`git log -1 --format=%h -- .forge/checkpoint.md`): the checkpoint is written just before the commit that includes it. Read the others (`git show --stat <hash>`): they may already hold the next step — say so, without ticking anything;
- a current branch different from the checkpoint's;
- changes to tracked files that the checkpoint does not mention; `.forge/checkpoint.md`, `.forge/reports/` and untracked files are only listed;
- a step ticked without its command or exit code, apart from a commit step ticked `carried by this commit`: that commit is the one that carries the checkpoint;
- a `last_commit` unknown to the repository.

## Step 4 — Confirm the real state

Rerun only the command recorded in the test results table for the last completed step, exactly as written, from the project root, whatever the language of the part: `bash tests/notes_test.sh`, `npm test -- notes`, `pytest tests/test_notes.py`. Never a command of your own, never the full suite of the part (`toolchain.test`), never a command that changes the project (install, add a dependency, commit, push): show it and run nothing instead. If the table has no line, say so and run nothing. When the current branch is not the checkpoint's, run nothing either: the result would describe another branch.

Compare with the recorded result. The same result confirms the state; a failure recorded as expected RED (after the RED step of create-feature, or the regression test of debug-project) is the normal state, not a problem to fix. A different result means the state moved since the checkpoint: report it as an inconsistency, without judging — after the implementation step alone, either outcome is possible.

When the checkpoint's skill is github-workflow, the real state is on GitHub: run `gh pr view <branch> --json number,url,state` and `gh pr checks <number>` (read-only) instead of a test.

## Step 5 — Summary, then wait

Present at most ten lines:

- skill, feature and branch;
- last completed step, with its recorded result;
- the real state confirmed at step 4 (command, exit code);
- the inconsistencies, or "none";
- the blockers, or "none";
- the next action: the first unticked step, without redoing the completed ones. When newer commits seem to hold it, say so and let the user decide.

Ask whether to resume from that step, then stop and wait. A blocker, another branch, newer commits or uncommitted changes: name them and let the user decide before resuming; a checkout needs agreement; never stash.

When the checkpoint-reminder hook asks for a checkpoint update during recovery, change only `updated:` and add a line under "Blockers / open questions" that records the recovery and its inconsistencies; change nothing else before the user agrees.

## After the agreement

Continue with the skill named in the checkpoint (`create-feature`, `debug-project`, `github-workflow`, `bootstrap-project`) from the next action, without rerunning its earlier steps. A skill that is not installed stops here, named.
