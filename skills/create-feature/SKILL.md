---
name: create-feature
description: "Develop one feature of a project that has a .forge/ directory in strict TDD, whatever the language of its part: approved PRD and TRD read first, plan, branch, failing tests by the test-engineer of the part's language plugin, RED then GREEN with the part's toolchain, refactor, quality, independent review, docs, commit. Use when the user asks to implement an acceptance criterion (AC-xxx) or to add or change a feature in such a project; not for a failure to diagnose, nor for a question about TDD. « implémente AC-002 », « on attaque AC-002 », « ajoute une commande notes count qui affiche le nombre de notes »."
argument-hint: "[partie] <AC-id ou description>"
when_to_use: "Implementing an acceptance criterion or adding or changing a feature in a project that has a .forge/ directory, whatever the part's language; not for a failure to diagnose, nor for a question about TDD."
---

# Create a feature in TDD

Address the user in French unless they write in another language. Code, identifiers, commit messages and file contents stay in English.

Request: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of the command that proves it. One command failing twice with the same error stops the workflow — inside the three iterations of step 9 too: write the checkpoint and explain the blocker instead of retrying.
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **Checkpoint.** `.forge/checkpoint.md` (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`) is written by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh checkpoint <project root> …`, the script's full path written in every call, never a shell variable or an alias standing for it — each call must read as it is, in the session as in the checkpoint: `start --skill create-feature --feature "<AC-id> <title>" --steps "Repository state|Context|Risks and dependencies|Plan|Branch|Tests first|RED|Minimal implementation|GREEN|Refactor|Re-test|Quality|Review|Documentation|Commit and report"` once, at step 1; then `done <n> --command "<command>" --exit <code>` after each completed step, with `--result "<summary line>"` for a test run; `block "<reason>"` for a blocker, or for the question of a validation point while it waits. A refused `start` means a create-feature run was interrupted here: say so, name recover-session, and stop; `--restart` only when the user says that work is abandoned. The checkpoint is workflow state: often modified, never a reason to stop. A commit that carries it follows git-workflow: `done 15 --command "<the commit>" --carried` before staging, and nothing more for that commit.
- **Configuration.** The project root is the folder that holds `.forge/`, where Claude Code was launched (`${CLAUDE_PROJECT_DIR}`): the hooks and the permission rules count from there. Read `.forge/config.yaml` first; a missing key counts as false; never edit it. A file without `parts` (`schema_version: 1`) belongs to a plugin-flutter 0.x project: stop, show the `parts` block of `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml` to add, and leave the edit to the user.
- **Language gestures.** The commands of the part are its `toolchain` keys in `.forge/config.yaml` — `test`, `format`, `analyze`, `add_dep`, `manifests`, `integration_test` — run from the part's folder (`path`). Anything that needs to understand the language is a mandate to an agent of the part's language plugin, at interface 1 of the delegation contract: `write-tests` to `<plugin>:test-engineer`, `check-dependency` to its architect, `review` to `<plugin>:code-reviewer`. `${CLAUDE_PLUGIN_ROOT}/skills/create-feature/reference/mandates.md` gives each mandate, the report it must end with and what to check in it. Agents run one after the other, never in parallel on the same files; in an interactive session a subagent runs in the background and its report arrives on a later turn: wait for it and write nothing meanwhile. Verify every claim of a report (rerun the command when it matters) before presenting it as a fact. A report without `INTERFACE: 1` stops the workflow: name the plugin and the version it needs, record the blocker.
- **Nothing is approved implicitly.** A document becomes APPROVED only on the user's explicit message, recorded by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh approve <document> --quote "<the user's message, verbatim>"`. Never write APPROVED yourself.
- Never display or write a token or a secret.

## Before anything

1. **The project.** Without `.forge/`, this folder is not a project of this plugin: bootstrap-project starts one, the adoption workflow of its language plugin takes over an existing one; say so and stop.
2. **The part.** The part named in the request, or the only one under `parts`; with several and none named, ask. Its `path`, `plugin` and `toolchain` come from `.forge/config.yaml`. The PRD is at the root, `docs/product/PRD.md`; the TRD, the implementation plan and the decisions of the part are under `<path>/docs/`; in a single-part project (`path: .`) the two coincide.
3. **The language plugin of the part**, `<plugin>`, is available when its agents appear in this session (`<plugin>:test-engineer`, `<plugin>:code-reviewer`). When none does, say so now: steps 1 to 4 need no agent and go on; the workflow stops after the plan, the branch and the tests waiting for the plugin to be installed and enabled in a new session.

## The 15 steps

### Step 1 — Repository state

`git status` and `git branch --show-current`, from the project root. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state and travel with the feature. Any other uncommitted change is preserved: list it and ask whether to commit it, carry it onto the branch, or stop. Never `git stash` silently, never discard anything. Then `orch.sh checkpoint … start`, and `done 1`.

### Step 2 — Context

Read `docs/product/PRD.md`, `<path>/docs/technical/TRD.md` and the entry of `<path>/docs/engineering/IMPLEMENTATION_PLAN.md` for this feature (without a plan file, the plan of step 4 becomes its first entry at step 14). `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh status <document>` must say APPROVED for the PRD and for the TRD; otherwise stop: no application code is written before the user approves them — say which one is not, ask for that approval or for what should change, and wait. List the acceptance criteria targeted (AC-xxx). A request matching no criterion gets a new numbered one, proposed here and treated as a scope change at step 4.

### Step 3 — Risks and dependencies

List what the feature implies: a new dependency (an ADR in the part's DECISIONS.md and a `check-dependency` mandate), an impact on a target or platform of the part, a data migration.

### Step 4 — Plan

Write the plan: files touched, under the part's `path`; public API (signatures); planned tests with their AC ids and their files; dependencies. **Validation point** when the scope, the architecture or a dependency changes — a new criterion, a new package: present the plan, ask for validation and stop. Otherwise say that no validation is needed, and why, and continue. When the part's plugin is absent from the session, stop here either way: the plan is presented, the blocker recorded, and recover-session resumes at step 5 once the plugin is enabled.

After the validation:

- a new acceptance criterion is written into the PRD, whose status goes back to REVIEW (doc-status-guard): record the user's validation with `orch.sh approve docs/product/PRD.md --quote "<their message>"`; when the tool refuses the message, ask for an explicit approval before step 5;
- an approved dependency is added now, before any test imports it: `toolchain.add_dep <package>` from the part's folder, then a `check-dependency` mandate to the architect of the part's plugin with the package and the part's `platforms` or targets; its verdict goes into the ADR as it is. Without a verdict, write "compatibility: not verified" and tell the user.

### Step 5 — Branch

Through the git-workflow skill: `<branch_prefix><ac-id>-<slug>` (`project.branch_prefix` of `.forge/config.yaml`, `feature/` when missing), from the default branch.

### Step 6 — Tests first

Record `git status --porcelain`. Mandate `write-tests` to `<plugin>:test-engineer`: the criteria, the plan, the public API, the test files to write, and for integration tests the command and device of `toolchain.integration_test` — without that key those tests are classified as blocked, no device, with the reason. Wait for the report, writing nothing meanwhile. Then check it: `INTERFACE: 1`; `git status --porcelain` against the recorded one, only test files under the part's `path`; the RED command it gives and its output.

### Step 7 — RED

Run the targeted tests yourself, with the command of the report — as a rule `toolchain.test` followed by the test files, from the part's folder. Record the command, its exit code and the summary line (`FAILED 3 (expected RED)`). The failure must be on the expected assertion, or a compilation error naming the missing API under test. Any other failure means the tests are wrong: send them back to the test-engineer with the output, and run RED again. If the tests already pass, stop: the behaviour may exist already, or the tests do not test it; report it and ask the user how to continue.

### Step 8 — Minimal implementation

Implement, in the main session, the minimum that makes these tests pass, in the files of the plan, in the part's language and conventions (its TRD and its CLAUDE.md): this plugin brings the workflow; the part's plugin brings its tests and its review. No dependency that step 4 did not validate.

### Step 9 — GREEN

The same targeted command: every test must pass (exit 0). Record the command, its exit code and the summary line. Otherwise back to step 8, at most three iterations; after the third, stop, write the checkpoint and expose the blocker.

### Step 10 — Refactor

Clean up without changing behaviour: naming, duplication, layout. No new behaviour, no new test.

### Step 11 — Re-test

The targeted tests again, then, at this milestone only, the full suite: `toolchain.test` alone, from the part's folder. Record both. A failure outside the targeted tests is unexpected: diagnose it with the debug-project skill before going on.

### Step 12 — Quality

`toolchain.format` then `toolchain.analyze`, from the part's folder; each must exit 0, exactly as in the CI of the github-workflow skill. Fix what they report; a finding that cannot be fixed is listed with its reason, and the user decides. The formatting hook of the part's plugin formats the files Claude edits: a format failure points at a file changed another way; format it and say which.

### Step 13 — Review

Nothing is committed yet: the review covers the staged changes. Stage the files of the feature explicitly through the git-workflow skill — code, tests, the PRD if a criterion was added, the files of `toolchain.manifests` if a dependency was added; not `.forge/`. Mandate `review` to `<plugin>:code-reviewer`: the diff as git arguments (`--cached <default branch>`), the targeted criteria, the declared scope; nothing of your reasoning. Wait for the report and check it.

Fix every blocking finding, stage the fixes, run steps 11 and 12 again — their earlier results no longer hold — and have the fixes reviewed once more. A blocking finding left after that second review stops the workflow: write the checkpoint and expose it. List the important and minor findings for the user, with what you did about them.

### Step 14 — Documentation

Update `<path>/docs/engineering/IMPLEMENTATION_PLAN.md` (status, branch, tests) and the DECISIONS.md concerned — the part's for a choice of its language, the root's for a project-level one — from the `DOCS_TO_UPDATE` and `DIVERGENCES` of the review. A divergence in the plan or in a DECISIONS.md is resolved by updating the document when the code is right; one where the document is right is reported to the user. A change to the PRD or the TRD is a validation point: only the user approves them. Create `docs/engineering/TRACEABILITY.md` once the PRD has more than ten criteria. Stage the updated documents.

### Step 15 — Commit and report

Through the git-workflow skill: the staged files and the checkpoint (`done 15 … --carried` before staging it), one Conventional Commit such as `feat(notes): list notes offline (AC-002)`; in a multi-part project the scope names the part. The commit asks for confirmation. Then the final report.

## Final report

- Feature, criteria covered, part, branch, commit (hash and message).
- Tests in four categories, each with its command; "none" for an empty category: passed; failed; blocked, with the reason (device or target unavailable, account missing); not run.
- Review findings and what was done about them.
- What was not done, and the next step: usually the pull request, `/plugin-orchestrator:github-workflow pr`.
