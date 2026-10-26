---
name: github-workflow
description: "GitHub for a project that has a .forge/ directory, behind validation points: gh checked first, never a token; remote repository, CI by a mandate to the part's language plugin, pull request, checks, red CI diagnosed; never a merge by Claude. Use when the user wants a remote repository, a CI, a pull request, an issue or the CI status in such a project, including a merge the skill will refuse; not for a branch, a commit or a push alone (git-workflow), nor for a question about GitHub itself. « ouvre une PR pour cette branche », « ajoute une CI GitHub Actions au projet », « merge la PR de cette branche »."
argument-hint: "[remote | ci | pr | checks | issue]"
when_to_use: "Any GitHub gesture in a project that has a .forge/ directory, including a merge the skill refuses; not for Git alone, nor for a question about GitHub."
---

# GitHub workflow

Address the user in French unless they write in another language. Titles, bodies, branch names and file contents stay in English.

Request: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of its command. If one command fails twice with the same error, stop, write the checkpoint and explain the blocker.
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection: the project's permission rules allow plain commands such as `gh pr checks <number>`, and a compound command asks for permission, or is refused in a non-interactive run. Two exceptions: the heredoc that feeds `--body-file -`, and the one that rewrites `.forge/checkpoint.md` when the Write tool is unavailable (`cat > .forge/checkpoint.md <<'EOF'`, by its relative path from the project root).
- **Configuration.** The project root is the folder that holds `.forge/`; a part of a multi-part project is a folder inside it, described under `parts` in `.forge/config.yaml`. Read that file first; a missing key counts as false; never edit it. A file without `parts` (`schema_version: 1`) belongs to a plugin-flutter 0.x project: stop, show the `parts` block to add, and leave the edit to the user.
- **Language gestures are mandates.** This skill runs the commands a part declares in its `toolchain` (`format`, `analyze`, `test`), from the part's folder. It writes no CI file and builds nothing: the CI template and the builds belong to the part's language plugin, through a mandate to its devops agent (`<plugin>:devops-engineer`) at interface 1 — the mandate names the part (`path`, `plugin`), the task and its inputs; the report ends with `INTERFACE: 1`, `STATUS`, `FILES_CHANGED`, `COMMANDS_RUN` and `OPEN_QUESTIONS`, and every claim it makes is checked before being repeated. A report without `INTERFACE: 1` stops the workflow and names the plugin to update.
- **Checkpoint.** After every completed step, rewrite `.forge/checkpoint.md` (the format of the other workflows) with `skill: github-workflow`, the command and its exit code — with the Write tool, or with the `cat > .forge/checkpoint.md <<'EOF'` heredoc when Write is unavailable, always by its relative path from the project root. A blocker is written in words, with the next action (« the user logs in to GitHub »), never with the login command: a command in a shell input, even inside a heredoc, cannot be told from a command run; the command goes only in the message to the user. Record the pull request URL and the CI conclusion in the test results table. A commit that carries the checkpoint follows git-workflow: the checkpoint is written before it, and not changed again for that commit.
- **Tokens.** Never ask for, print or pass a token. Never run `gh auth login`, `gh auth status --show-token` or `gh auth token`: logging in is the user's own gesture.
- **Cost.** GitHub Actions minutes are free for public repositories on standard runners. A private repository spends the account's monthly quota: 2,000 minutes on GitHub Free, 3,000 on Pro and Team; a macOS minute costs about ten Linux minutes. Say it before anything that starts a run on a private repository.

## Before anything

1. Classify the request with the table below. A request of the last row — merge, change the visibility, delete, release, push a tag — is never done by Claude, even after a confirmation, even when gh is logged in and every authorization of the project is true: say so, give the user the command to run themselves (`gh pr merge <number> --squash`, or the button on GitHub), and stop, without any gh command.
2. Read `.forge/config.yaml`. Run `git status`, `git branch --show-current` and `git remote -v`.
3. gh is needed by every action that reaches GitHub — all of them, except `ci` on a project without a remote. Run `gh --version`, then `gh auth status`. If gh is missing or not logged in, stop there: nothing is pushed, created or opened first. Record the blocker in `.forge/checkpoint.md` (`skill: github-workflow`, the command and its exit code, next action in words: the user logs in to GitHub — the login command stays out of the checkpoint), then say that the user runs `! gh auth login` themselves (in the session with the `!` prefix, or in a terminal), and that no token goes through the conversation.

| Action | Class |
| --- | --- |
| `gh auth status`, `gh repo view`, `gh pr view`, `gh pr checks`, `gh run list`, `gh run view`, `gh issue list`, `gh issue view` | free |
| push of a work branch | `authorizations.push_feature_branches: true`, or the user's explicit request in this conversation; through the git-workflow skill |
| open a pull request | `authorizations.open_pull_requests: true`, or the user's explicit request |
| update a pull request the current account opened | `authorizations.update_own_pull_requests: true`, or the user's explicit request; never a pull request of someone else |
| create the remote repository | confirmed every time — owner, name, visibility — even with `authorizations.create_remote_repo: true` |
| add or change the CI workflow; rerun or start a workflow on a private repository | the user's explicit approval, with the cost |
| create an issue | the user's explicit request, title and body shown first |
| merge, change the visibility, delete, release, push a tag | never done by Claude: the user does it; the guard-destructive hook blocks these commands |

## remote — create the GitHub repository

1. If `git remote -v` already lists `origin`, say so and stop: there is nothing to create.
2. **Validation point.** Propose the owner (the account shown by `gh auth status`), the name (the project name), the visibility — **private** by default; public makes CI free and the code visible to everyone — and a one-line description. Say that the default branch will be pushed once the repository exists. Wait.
3. After the answer: `gh repo create <owner>/<name> --private --description "<one line>" --source . --remote origin` (`--public` if chosen). No `--push`: the push is the next step, and only the default branch.
4. `git push -u origin <default branch>`. The approval of step 2 covered this first publication; it is the only push of the default branch this skill makes. A project rule may ask to confirm it.
5. `gh repo view <owner>/<name> --json url,visibility,defaultBranchRef`: report the URL and the visibility.

## ci — add the CI

1. If `.github/workflows/` already holds a workflow for the part, read it and propose the differences instead of a new file.
   Where the commit goes: without a remote, on the default branch, which `remote` publishes later. With a remote, on a work branch, because this skill never pushes the default branch after its first publication: create `chore/ci` from the default branch through the git-workflow skill, and the pull request of that branch runs the new CI for the first time.
2. **Validation point.** Explain what the CI will do: on every pull request and every push to the default branch, the `format`, `analyze` and `test` commands of each part's `toolchain`, on one Linux runner, with a time cap. Say that the workflow file is written by the devops agent of the part's plugin (`<plugin>:devops-engineer`) on a `ci-template` mandate, and shown before any commit. Give the cost for the repository's visibility (`gh repo view --json visibility`): without a remote, it is known at `remote`, and free if the repository is public. Wait.
3. Mandate `ci-template` to the devops agent of each part: interface 1, the part (`path`, `plugin`), the default branch, the `toolchain` commands to run, the file to write — `.github/workflows/ci.yml` for a single part, `.github/workflows/<part>-ci.yml` for several. The protect-sensitive hook asks the user to confirm each write under `.github/workflows/`; a refused write — a non-interactive run cannot ask — is never done another way: report it, with the command the agent gave for the user to run. Read the file the report names; a report without `INTERFACE: 1` stops here.
4. Run locally what CI will run, from each part's folder: `toolchain.format`, `toolchain.analyze`, `toolchain.test`. Each must exit 0; a check that fails here fails on GitHub: fix it first, with the debug-project skill.
5. Commit through the git-workflow skill: `ci: add CI (format, analyze, test)`, with the part's name as scope in a multi-part project. With a remote, the next step is `pr` for the `chore/ci` branch.
6. If the user wants the targets of a part built, mandate `build` to the devops agent of its plugin with the part's `platforms` (or targets), wait for its report, and present its BUILDS table. A target is "built" only with its command and exit code.

## pr — open or update the pull request

1. Preconditions: the current branch is a work branch, not the default branch; nothing is uncommitted except `.forge/checkpoint.md` and `.forge/reports/`; for each part the branch touches (`git diff --stat <default branch>...HEAD`, paths under the part's `path`), `toolchain.format` and `toolchain.analyze` exit 0 now, and `toolchain.test` has a recorded result in the checkpoint, or is run now and recorded.
2. The branch must be on GitHub: push it through the git-workflow skill, which checks `push_feature_branches`. Without a push, stop: a pull request needs the branch on the remote.
3. `gh pr view <branch> --json number,url,state,author`: if a pull request is open for this branch, go to step 6.
4. Fill `${CLAUDE_PLUGIN_ROOT}/skills/github-workflow/reference/pr-body.md` from the checkpoint, the targeted acceptance criteria of the PRD, `git log --oneline <default branch>..HEAD` and `git diff --stat <default branch>...HEAD`. Tests in four categories, each with its command, per part when the project has several; a Platforms table only for a part that declares `platforms`, in three states (enabled, built, tested). Never call a target built or tested without the command that proves it; write "none" for an empty category. A unit test suite marks no platform as tested: a platform is tested only by the part's `integration_test` run on it, otherwise its tested column says "no".
5. **Validation point**, unless `open_pull_requests: true` or the user asked for the pull request in this conversation: show the title and the body, then wait. On a private repository, say that opening the pull request starts a CI run, and that each push to its branch starts another. Then create it, with the body in a quoted heredoc so that nothing in it runs:

   ```bash
   gh pr create --base <default branch> --head <branch> --title "<type(scope): summary>" --body-file - <<'EOF'
   <body>
   EOF
   ```

   Never `--fill`, `--web`, or a pull request into another repository. Then `gh pr view <branch> --json number,url` and report the URL.
6. Update: only if `gh pr view <number> --json author --jq .author.login` is the active account (`gh auth status --json hosts --jq '.hosts["github.com"][] | select(.active) | .login'`), and with `update_own_pull_requests: true` or the user's explicit request. `gh pr edit <number> --body-file - <<'EOF'` with the refreshed body.

## checks — follow the CI

1. `gh pr checks <number>`: exit 0 means every check passed, 8 means some are still pending, another non-zero code means a failure. While pending, run `gh pr checks <number> --watch --fail-fast` once, with a Bash timeout of 600000 ms. If checks are still pending after that, report it and stop; do not loop.
2. Green: record `gh pr checks <number>` → passed in the checkpoint and report it.
3. Red: mandate `ci-diagnosis` to the devops agent of the plugin of the part whose job failed (the job names the part, or the project has one part), with the branch, the pull request number and the run id. Wait for its report, and verify its main claim yourself (`gh run view <run id> --log-failed`, read the lines it cites). Then:
   - format, analysis, tests or dependencies: reproduce locally with the part's `toolchain` and fix with the debug-project skill, then commit and push through git-workflow; on a private repository, each push starts a CI run, so group the fixes into one push;
   - the workflow itself: mandate `workflow-change` to the same devops agent, check its diff, then commit and push through git-workflow;
   - infrastructure (runner, network): propose `gh run rerun <run id> --failed`. On a private repository it spends minutes: validation point.
4. Never merge. When the checks are green, tell the user the pull request is ready and that the merge is theirs.

## issue

`gh issue list` and `gh issue view <number>` are free. `gh issue create --title "<title>" --body-file - <<'EOF'` only on the user's explicit request, after showing the title and the body.

## Report

- Repository (URL, visibility), branch, pull request (number, URL, state).
- CI: run, conclusion; for a failure, its class, the evidence and the next step.
- Tests in four categories, each with its command, per part; targets in three states for a part that declares them.
- What was not done, and why: gh not logged in, missing authorization, refused write, pending checks, a gesture that is the user's.
