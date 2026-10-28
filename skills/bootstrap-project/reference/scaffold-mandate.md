# The scaffold mandate

What bootstrap-project sends to the language plugin of a part, and what it needs back, at interface 1 of the delegation contract. The orchestrator writes no application code: the skeleton of a part, its base test, its TRD, its CI template and its permission fragment are the plugin's; the orchestrator keeps the root — `.forge/`, `docs/product/`, `docs/engineering/`, `CLAUDE.md`, `.gitignore` — and the first commit.

## Mandate, given as the agent's task

```
interface: 1
task: scaffold
part:
  path: .
  plugin: <plugin>
project: <project name>
identifiers: <what the user validated: package name, organization, application id…>
targets: <platforms or targets the user validated>
scope: <the validated scope, one paragraph>
user language: <language>
constraints:
- the skeleton and its base test go under the part's path; nothing under .forge/, docs/product/, docs/engineering/, CLAUDE.md or .gitignore at the root
- the part's TRD at <path>/docs/technical/TRD.md, in DRAFT, with the plugin's own header
- the permission fragment is returned in the report, never written to .claude/settings.json
- no commit, no push, no remote: the first commit is the orchestrator's
- every claim comes with its command and exit code
```

## Report, expected at the end

```
SCAFFOLD:
- <what was created: skeleton, base test, TRD, CI template, with their paths>
TOOLCHAIN:
- test: <command>
- format: <command>
- analyze: <command>
- add_dep: <command>
- manifests: [<manifest>, <lockfile>]
- integration_test: <command>, or none
- platforms: [<target>, …], or none
PERMISSIONS:
- allow: [<rule>, …]
- ask: [<rule>, …]
- deny: [<rule>, …]
VERSIONS:
- <tool>: <version> (`<command>`)
TARGETS:
- <target>: enabled | built (`<command>` → exit 0) | not verified
INTERFACE: 1
STATUS: done | blocked | partial
FILES_CHANGED:
- <path> — <one-line summary>
COMMANDS_RUN:
- `<command>` → exit <code>
OPEN_QUESTIONS:
- <question, and who answers it>, or none
```

## What the session checks before using it

- `INTERFACE: 1` present. Without it, the plugin is a pre-migration version: stop, name the plugin and the version it needs.
- `FILES_CHANGED` against `git status --porcelain --untracked-files=all`: nothing outside the part's path, except what the mandate allowed.
- The `TOOLCHAIN` lines are plain commands: they go into `.forge/config.yaml` as they are, and `platforms` only when the report gives one.
- A target is built only with its command and exit code in `COMMANDS_RUN`; otherwise it is enabled, not built.
- The `PERMISSIONS` rules are of the forms `Bash(…)`, `Read(…)` or `Edit(…)`, and none of `allow` covers a push, a merge, a reset, a clean or a deletion: a rule that does is dropped from the proposal and reported.
