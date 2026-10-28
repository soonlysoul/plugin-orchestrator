---
name: debug-project
description: "Diagnose and fix an unexpected failure — test, format, analysis, build, CI — in a project that has a .forge/ directory, whatever its part's language: reproduced with the part's toolchain, root cause proved before any fix, regression test RED then GREEN, minimal fix, review, commit. Use when something that should pass fails in such a project, whatever its checkpoint holds: the skill reads it first and hands the expected RED of create-feature back to that workflow; not for a new feature, nor for a question about debugging. « les tests ne passent plus depuis mon dernier commit », « les tests échouent, corrige-les », « le build casse sur main »."
argument-hint: "[partie] [commande en échec ou erreur]"
when_to_use: "An unexpected failure in a project that has a .forge/ directory, including one its checkpoint records as the expected RED of create-feature; not for a new feature, nor for a question about debugging."
---

# Debug a project

Address the user in French unless they write in another language. Code, identifiers, commit messages and file contents stay in English.

Failure reported: $ARGUMENTS

## Rules

- **No fix before a root cause.** A fix is written only after the cause is stated in one sentence with its evidence: the output line, the stack frame, the diff that introduced it. Changing code until the error goes away is not debugging.
- **No result without its command.** Never report a step as done without the output of the command that proves it.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection, no `| tail` to shorten the output: the project's permission rules allow plain commands such as `toolchain.test` followed by a file, and a compound command asks for permission, or is refused in a non-interactive run.
- **Two identical failures stop.** A command that fails twice with the same error after a change meant to fix it stops the workflow: the hypothesis was wrong. Write the checkpoint and expose the blocker.
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **Checkpoint.** `.forge/checkpoint.md` (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`) is written by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh checkpoint <project root> …`, the script's full path written in every call, never a shell variable or an alias standing for it — each call must read as it is, in the session as in the checkpoint: `start --skill debug-project --feature "<the failure, in a few words>" --steps "Repository state|Reproduce|Classify|Root cause|Scope|Branch|Regression test RED|Minimal fix GREEN|Full check|Review|Commit and report"` once, at step 1; then `done <n> --command "<command>" --exit <code>` after each completed step, with `--result "<summary line>"` for a test run and `--next "<the current hypothesis>"` while diagnosing; `block "<reason>"` for a blocker, or for the question of a validation point while it waits. Next actions and reasons are written in words, never as a command line. A refused `start` means a debug-project run was interrupted here: say so, name recover-session, and stop; `--restart` only when the user says that work is abandoned. Never `start` over the unticked steps of another skill: `start` would erase them (see « Before anything »). A commit that carries the checkpoint follows git-workflow: `done 11 --command "<the commit>" --carried` before staging, and nothing more for that commit.
- **Configuration.** The project root is the folder that holds `.forge/`, where Claude Code was launched (`${CLAUDE_PROJECT_DIR}`). Read `.forge/config.yaml` first; a missing key counts as false; never edit it. A file without `parts` (`schema_version: 1`) belongs to a plugin-flutter 0.x project: stop, show the `parts` block of `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml` to add, and leave the edit to the user.
- **Language gestures.** The commands of the part are its `toolchain` keys in `.forge/config.yaml` — `test`, `format`, `analyze`, `add_dep`, `manifests` — run from the part's folder (`path`). Anything that needs to understand the language is a mandate to an agent of the part's language plugin, at interface 1 of the delegation contract: `write-tests` to `<plugin>:test-engineer`, `diagnose` to its architect, `review` to `<plugin>:code-reviewer`. `${CLAUDE_PLUGIN_ROOT}/skills/debug-project/reference/mandates.md` gives each mandate, the report it must end with and what to check in it. Agents run one after the other; in an interactive session a subagent's report arrives on a later turn: wait for it and write nothing meanwhile. Verify every claim of a report before presenting it as a fact. A report without `INTERFACE: 1` stops the workflow: name the plugin and the version it needs, record the blocker.
- Never `git stash`, reset, revert or discard anything to make a failure disappear. Never display or write a token or a secret.

## Before anything

1. **The project.** Without `.forge/`, this folder is not a project of this plugin: say so and stop.
2. **The checkpoint.** Read `.forge/checkpoint.md` before running anything that changes it.
   - **An expected RED.** Its skill is create-feature or debug-project, and its last ticked step is the RED (step 7 of either), recorded as expected RED: run the part's `toolchain.test`. When the only failing tests are those of that RED, this is the normal state of TDD before the implementation, not a failure, even when the user asks to fix them: say so — skill, feature, branch, step and recorded command — and say that making them pass is that workflow's next step, the minimal implementation (step 8 of either), not a fix, and that recover-session resumes it. Change nothing, the checkpoint included, and stop. Any other failing test is the failure to debug: go on with it.
   - **Another workflow in progress.** Other unticked steps of another skill — create-feature sends an unexpected failure here from its step 11: do not `start`. Record the failure with `block`, diagnose it (steps 2 to 5), and record the root cause with `block`. A failure caused by that workflow's own changes is fixed within it, on its branch — regression test and fix as in steps 7 and 8 — and that workflow goes on from the step that called this one: its review covers the fix and its commit carries it. A failure it inherited from the default branch is a validation point: its fix belongs on a `fix/` branch once that workflow is committed or abandoned; say so and let the user decide.
3. **The part.** The part named in the request, the one whose files fail, or the only one under `parts`; when it cannot be told, ask. Its `path`, `plugin` and `toolchain` come from `.forge/config.yaml`.
4. **The language plugin of the part**, `<plugin>`, is available when its agents appear in this session (`<plugin>:test-engineer`, `<plugin>:code-reviewer`). When none does, say so now: steps 1 to 5 need no agent and go on; the workflow stops after the scope of the fix, the diagnosis and the planned fix presented, and recover-session resumes at step 6 once the plugin is installed and enabled in a new session.

## Step 1 — Repository state

`git status` and `git branch --show-current`, from the project root. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state. Any other uncommitted change is preserved: list it, and say whether it may be part of the failure. Then `orch.sh checkpoint … start`, unless another workflow is in progress, and `done 1`.

## Step 2 — Reproduce

Run the exact failing command, from the part's folder: as a rule a `toolchain` key — `test`, `format`, `analyze` — or a test file after `toolchain.test`. For a red CI, the command of the failed step, from its log (`gh run view <run> --log-failed`, read-only; following the checks is github-workflow's). Record the command, its exit code and the first error lines.

- It fails the same way: go on.
- It does not fail: say so. Compare the environments — the tool versions here and those the part's TRD or ADR-001 records, or the CI log shows; the lockfile among `toolchain.manifests`; the operating system — and stop with what differs: a failure that does not reproduce cannot be fixed with evidence.
- It fails once and passes on one rerun: it is flaky; report it as such — the fix is then the test's isolation, timing or shared state.

## Step 3 — Classify

Name the class, with the output line that shows it:

- format or analysis (`toolchain.format`, `toolchain.analyze`): file, line and message;
- compilation or build: file, line and message;
- test assertion: the test, the expected and actual values, the criterion (AC-xxx) it covers;
- exception in a test or at runtime: the first stack frame inside the project's code;
- dependency resolution: the package and the conflicting constraints;
- platform toolchain (a build only): the tool, its version and the target;
- CI only: what differs between the CI and this machine.

## Step 4 — Root cause

Read the code at the failing frame or line, then its history: `git log --oneline -10 -- <file>`, and `git diff <last good commit> -- <file>` when one is known (the last green CI run, a tag, the checkpoint, the commit before the one the user names). One hypothesis at a time, with its evidence, tested by reading or by a narrower command: one test file after `toolchain.test`, the failing command on a minimal input. When the hypothesis depends on a behaviour of the language, its tools or a platform that the code does not show — a dependency resolution, a platform toolchain, a compiler or analyzer rule —, mandate `diagnose` to the architect of the part's plugin and check its evidence. State the root cause in one sentence before writing any fix, and record it (`--next`).

`git bisect` moves HEAD: propose it only with a clean working tree, and run it only with the user's agreement.

## Step 5 — Scope of the fix

List the files the fix touches, under the part's `path`, and the regression test: the existing test that fails, when there is one, or the test to mandate at step 7. The scope of the error is the failing file and the code it calls directly. **Validation point** when the fix goes beyond it: another feature, a file of `toolchain.manifests` (a dependency, a version), a platform or target folder of the part, the configuration of format or analysis, the CI workflow, or a change of behaviour that the PRD does not describe — present the cause, the fix and the files, then wait. Otherwise say that the fix stays within the scope, and why. When the part's plugin is absent from the session, stop here either way: the root cause with its evidence, the planned fix and its regression test presented, the blocker recorded.

## Step 6 — Branch

Through the git-workflow skill. On the default branch: `fix/<slug>`. On a work branch whose own changes caused the failure: fix it there. On a work branch that inherited it from the default branch: ask which branch takes the fix.

## Step 7 — Regression test, RED

A failing test that already reproduces the failure is the regression test: do not duplicate it; its RED is the run of step 2. Otherwise mandate `write-tests` to `<plugin>:test-engineer`: the failure, the root cause, one test named `regression: <what failed>` — or after the criterion it breaks — next to the existing tests. Wait for the report and check it: only that test file changed. Then run it yourself, `toolchain.test` followed by the file, from the part's folder: it must fail for the root cause of step 4. Record the command, its exit code and the summary line. A test that fails for another reason goes back to the test-engineer with the output. When no test can capture the failure — a build or toolchain configuration —, say so: the reproduction command of step 2 is then the regression check.

## Step 8 — Minimal fix, GREEN

In the main session, change the minimum, in the files of step 5, that removes the root cause — not its symptom: no skipped or loosened test, no special case that hides the error. Run the regression test again: it must pass (exit 0); record it. Otherwise back to step 4: at most three iterations, and the rule of two identical failures applies.

## Step 9 — Full check

From the part's folder: the command of step 2 again, then `toolchain.test` alone (the full suite), `toolchain.format` and `toolchain.analyze`; each must exit 0, as in the CI of the github-workflow skill. Record each one.

## Step 10 — Review

Stage the fix and its test explicitly through the git-workflow skill — not `.forge/`; the files of `toolchain.manifests` when a validated dependency changed. Mandate `review` to `<plugin>:code-reviewer`: the diff as git arguments (`--cached <base>`), the root cause in one sentence, the regression test, the declared scope; nothing else of your reasoning. Wait for the report and check it. Fix every blocking finding, stage the fixes, run step 9 again and have the fixes reviewed once more; a blocking finding left after that stops the workflow. List the important and minor findings and the DIVERGENCES, with what you did about them; fix only those within the scope of step 5.

## Step 11 — Commit and report

Update the DECISIONS.md concerned only if the fix changes a recorded choice — the part's for a choice of its language, the root's for a project-level one. Through the git-workflow skill: the staged fix and its test, and the checkpoint (`done 11 … --carried` before staging it), in one Conventional Commit whose body states the root cause; in a multi-part project the scope names the part:

```
fix(<scope>): <what is fixed>

Root cause: <one sentence>.
Regression test: <test file and name>.
```

The commit asks for confirmation. For a red CI, the next step is to push the branch and follow the checks with the github-workflow skill.

## Final report

- Failure, class, root cause with its evidence.
- Fix: files changed, branch, commit (hash and message).
- Regression test: file and name, RED then GREEN, each with its command.
- Tests in four categories, each with its command; "none" for an empty category: passed; failed; blocked, with the reason; not run.
- Review findings and what was done about them; what remains, and the next step.
