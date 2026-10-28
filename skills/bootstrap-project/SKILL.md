---
name: bootstrap-project
description: "Start a new software project with plugin-orchestrator — identity and scope confirmed first, Git, the .forge/ state directory (schema 2: one part and its language plugin), a scaffold mandate to that plugin, the root documents in DRAFT, the generic permission rules proposed, a green base test and a first commit; nothing is created before the user confirms. Use when the user asks to start a new project, whatever the folder holds: the skill checks the folder first, and one that already holds a project is sent to the adoption workflow of its language plugin; not for a feature in a .forge/ project. « démarre un nouveau projet : une appli de notes en Flutter », « démarre un nouveau projet ici »."
argument-hint: "[nom-du-projet] [description]"
when_to_use: "When the user asks to start a new project, whatever its language and whatever the folder holds; not for a feature in a .forge/ project, nor for a question about project documents."
---

# Bootstrap a project

Address the user in French unless they write in another language. Code, identifiers, commit messages and file contents stay in English.

Request: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of its command. If one command fails twice the same way, stop, write the checkpoint (once it exists) and explain the blocker.
- **Validation points.** Ask in plain text, write the checkpoint once it exists (from step 2 on), end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **Nothing is approved implicitly.** A document becomes APPROVED only on the user's explicit message, recorded by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh approve <document> --quote "<the user's message, verbatim>"`, which writes its Status and Approved rows and the fingerprint in `.forge/approvals.log`. Never write APPROVED yourself.
- **No application code by this plugin.** The orchestrator writes the project's documents, state and rules. The code of a part — its skeleton, its base test, its TRD, its CI template, its permission fragment — is the business of the part's language plugin (`plugin-flutter` for a Flutter app), through a `scaffold` mandate at interface 1 of the delegation contract. This version bootstraps a single-part project (`path: .`); a request for several parts stops here, named: the multi-part bootstrap comes with the coordination layer.
- **Checkpoint.** From step 2 on, `.forge/checkpoint.md` (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`) is written by `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh checkpoint <directory> …`: `start --skill bootstrap-project --steps "<the nine steps below>"` once, then `done <n> --command "<command>" --exit <code>` after each completed step, `block "<reason>"` for a blocker. A commit that carries the checkpoint follows git-workflow: `done <n> --command "<the commit>" --carried` before staging, and nothing more for that commit.
- **Project root.** The hooks and the project's permission rules take the directory where Claude Code was launched as the project root (`${CLAUDE_PROJECT_DIR}`). The project is best created right there, in a folder that holds none.
- Never display or write a token or a secret.

## Before anything

1. **The current folder.** A folder holding `.forge/` is already a project of this plugin: say so, name recover-session to resume it or create-feature to go on, and stop. A folder holding application code or a manifest (`pubspec.yaml`, `package.json`, `pyproject.toml`, `lib/`, `src/`…) is an existing project: no new project is started there, and bringing it under the plugins is the adoption workflow of its language plugin (`/plugin-flutter:adopt-existing-project` for a Flutter app); say so and stop. Shell and editor dotfiles (`.bashrc`, `.gitconfig`, `.idea`, `.vscode`, `.claude/`, `.mcp.json`…) do not count: for this skill such a folder holds no project.
2. **Prerequisites.** `git --version` and `jq --version`, versions recorded. Without git, stop. If a shell command is blocked because jq is missing, stop: the plugin's guard hooks block every shell command until jq is installed; tell the user. The tools of the part's language (flutter, node, python…) are checked by its plugin at the scaffold, not here.
3. **The language plugin of the part**, `plugin-<language>` (`plugin-flutter` for a Flutter app). It is available when its skills or agents appear in this session (`<plugin>:…`). When none does, say it at the validation point: the scaffold (step 3) will be blocked until the plugin is installed and enabled and a new session started; the user decides whether to go on until then.

## Step 1 — Validation point: identity and scope

Propose values and ask the user to confirm or correct them, then stop:

- the project name: short, lowercase, hyphenated, such as `my-notes`; it names the repository and the root documents;
- the part: its language and its language plugin, with `path: .`, and whether that plugin is available in this session;
- the identifiers and targets the part's plugin needs for its scaffold, proposed from the language's conventions — for a Flutter app, the package name in snake_case, the organization in reverse domain notation and the platforms; passed to the plugin as they are, never interpreted here;
- the scope of the first version, in one paragraph, from the request;
- the user's language, for the project's conventions file;
- the target directory. Recommend the current directory `${CLAUDE_PROJECT_DIR}` when it holds no project, so that this session can go on with the next workflows. Otherwise propose `<current directory>/<project name>`, which must not exist or must be empty, and warn that the next workflows will then need a new Claude Code session started in that directory.

## Step 2 — Directory, Git and state

After the answer, in this order:

1. `mkdir <directory>` when it does not exist; nothing for the current directory.
2. In it, `git init -b main`, unless it is already inside a repository (`git rev-parse --is-inside-work-tree`).
3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh init <directory>`: `.forge/reports/.gitkeep` and `.forge/approvals.log`, nothing else.
4. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh checkpoint <directory> start --skill bootstrap-project --steps "Identity and scope|Directory, Git and state|Scaffold mandate|Configuration|Root documents|Documents and permissions|Base test|First commit|Report"`, then `done 1` with the validated values as its command and `done 2` with the commands above.

## Step 3 — Scaffold mandate

Mandate `scaffold` to the agent the part's plugin exposes for it, with the validated name, identifiers, targets, scope and language: the mandate and the report it must end with are in `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/scaffold-mandate.md`. Wait for the report, then check it before using anything it says: `INTERFACE: 1` present; `FILES_CHANGED` against `git status --porcelain --untracked-files=all`, nothing outside the part's path except what the mandate allowed; every target called built has its command and exit code in `COMMANDS_RUN`.

A plugin that exposes no scaffold at interface 1 — a plugin-flutter 0.x, whose own bootstrap-project does the whole bootstrap itself — stops the workflow here: name the plugin and the update it needs, record the blocker, and leave the project at this step, Git and `.forge/` in place, the scaffold to come after the update. The same for a report without `INTERFACE: 1`.

## Step 4 — Configuration

`.forge/config.yaml` from `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml`, written once: under `parts`, the single part with `path: .`, its `plugin`, `interface: 1`, and the `toolchain` and `platforms` lines of the scaffold report, as they are. Every authorization stays false: only the user changes them, by editing the file. Write it now: once `.claude/settings.json` is installed (step 6), its deny rule `Edit(./.forge/config.yaml)` stops Claude from writing it. The protect-sensitive hook asks the user to confirm this write. If it is refused — a non-interactive run cannot ask — do not write the file another way: show its full content, ask the user to save it as `<directory>/.forge/config.yaml` themselves, record the blocker, and wait.

## Step 5 — Root documents, in DRAFT

Create them from the templates, keeping their fixed header:

| Document | Template |
| --- | --- |
| `docs/product/PRD.md` | `${CLAUDE_PLUGIN_ROOT}/templates/doc-templates/PRD.md` |
| `docs/engineering/DECISIONS.md` | `${CLAUDE_PLUGIN_ROOT}/templates/doc-templates/DECISIONS.md` |
| `CLAUDE.md` | `${CLAUDE_PLUGIN_ROOT}/templates/doc-templates/CLAUDE.md` |

- Fill the PRD from the validated scope, with numbered acceptance criteria `AC-001`, `AC-002`, … When the user gave a long brief (a document, several features) and the project is in the current directory, delegate it to the product-architect agent instead (task `draft`, interface 1, with the brief and the validated scope), wait for its report, and check with `git status --porcelain --untracked-files=all` that it changed only files under `docs/product/`.
- DECISIONS.md starts with `ADR-001 — Initial stack`: the part, its plugin, the identifiers and targets validated, the versions the scaffold report gave, the defaults kept.
- CLAUDE.md takes the project name and the user's language.
- Append to `.gitignore`, if absent: `.env*`, `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.pfx`.
- The TRD of the part, its implementation plan and its own decisions are the scaffold's, under `docs/` of the part: never written here. Optional documents are created later, when their need appears.

## Step 6 — Validation point: documents and permissions

Ask both questions, then stop:

1. Do you approve the PRD, and the TRD of the part when the scaffold wrote one, as they are, or what should change? No feature is developed before this approval.
2. May I install the proposed permission rules in `.claude/settings.json`? Summarize `${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json` — what runs without asking, what asks first, what is denied — and the `PERMISSIONS` fragment of the scaffold report, merged into it. Explain that the `allow` rules apply only after the user accepts the workspace trust prompt, while `deny` and `ask` always apply.

On approval of a document, run `orch.sh approve` with the user's message. On approval of the rules, write `.claude/settings.json` from the template plus the fragment; if that file exists, show the merge and wait for agreement before writing. Claude Code protects its own configuration files: in a non-interactive run the write is denied. Do not work around it: give the user the exact command to run themselves, `! mkdir -p <directory>/.claude && cp ${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json <directory>/.claude/settings.json`, with the fragment to add by hand, and say that no project rule applies until then.

## Step 7 — Base test, green

From the part's folder, run `toolchain.test` of `.forge/config.yaml`: exit code 0 is required. Then `toolchain.analyze`: exit 0. If the base test the scaffold wrote fails, report it as it is, do not edit around it — the code is the plugin's — and stop before the commit. A unit test suite marks no target as tested.

## Step 8 — First commit

Through the git-workflow skill: show `git status`, stage the files explicitly, and propose the message `chore: bootstrap <name> with plugin-orchestrator`. The checkpoint is carried by this commit (`done 8 … --carried` before staging). The commit asks for confirmation.

## Step 9 — Report

- Path of the project; the part, its plugin and its targets in three states (enabled, built, tested), each with the command that proves it.
- Documents and their status.
- Tests in four categories, each with its command: passed, failed, blocked (reason), not run; "none" for an empty category.
- Next step: `/plugin-orchestrator:create-feature AC-001`. To publish the project on GitHub and add the CI: `/plugin-orchestrator:github-workflow remote`, then `/plugin-orchestrator:github-workflow ci`. If the project is in a subdirectory, first start a new Claude Code session in it (`cd <directory> && claude`): the hooks and the permission rules use the session's launch directory as the project root.
