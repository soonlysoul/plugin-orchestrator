#!/usr/bin/env bash
# A plugin-orchestrator project: a shell CLI (`notes`), one part at the root whose language
# plugin is plugin-shell. The PRD and the TRD are APPROVED; AC-001 is implemented and green.
# create-feature then started AC-002 (`notes list --offline`) and stopped right after its RED
# (step 7): the branch feature/AC-002-offline-notes-list, the failing test tests/notes_test.sh
# written by plugin-shell's test-engineer (untracked until the feature's commit), and the
# checkpoint of that run, modified and uncommitted, written last. The failing test is the
# expected RED, not a failure to debug: nothing is to be fixed, and the checkpoint of
# create-feature must not be overwritten.
set -euo pipefail
mkdir -p .forge/reports bin tests tools docs/product docs/technical docs/engineering
: >.forge/reports/.gitkeep
cat >.forge/config.yaml <<'YAML'
schema_version: 2
project:
  default_branch: main
  branch_prefix: feature/
authorizations:
  push_feature_branches: false
  open_pull_requests: false
parts:
  app:
    path: .
    plugin: plugin-shell
    interface: 1
    toolchain:
      test: bash tests/run-all.sh
      format: bash tools/format.sh
      analyze: bash tools/analyze.sh
      add_dep: bash tools/add-dep.sh
      manifests: [deps.txt, deps.lock]
YAML
cat >bin/notes <<'SH'
#!/usr/bin/env bash
# notes — a tiny notes CLI: `notes add <text>` stores a note, `notes list` prints them.
set -euo pipefail
store=${NOTES_FILE:-notes.txt}
case ${1:-} in
  add) shift; printf '%s\n' "$*" >>"$store" ;;
  list)
    [[ $# -eq 1 ]] || { echo "notes: unknown option: $2" >&2; exit 2; }
    [[ -f $store ]] || exit 0
    cat "$store" ;;
  *) echo "usage: notes add <text> | notes list" >&2; exit 2 ;;
esac
SH
chmod +x bin/notes
cat >tests/base_test.sh <<'SH'
#!/usr/bin/env bash
# AC-001: `notes add` stores a note and `notes list` prints the stored notes, one per line.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
NOTES_FILE=$(mktemp)
export NOTES_FILE
trap 'rm -f "$NOTES_FILE"' EXIT
bin/notes add "buy milk"
bin/notes add "call mom"
out=$(bin/notes list)
if [[ $out == $'buy milk\ncall mom' ]]; then
  echo "PASSED 1: notes add and list (AC-001)"
  exit 0
fi
echo "FAILED 1: notes add and list (AC-001) — output: $out"
exit 1
SH
cat >tests/run-all.sh <<'SH'
#!/usr/bin/env bash
# toolchain.test — runs the given test files, or every tests/*_test.sh, and reports the count;
# exit 1 when one fails. Targeted run: bash tests/run-all.sh tests/<feature>_test.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failed=0 total=0
tests=("$@")
[[ $# -gt 0 ]] || tests=(tests/*_test.sh)
for test in "${tests[@]}"; do
  total=$((total + 1))
  bash "$test" || failed=$((failed + 1))
done
echo "tests: $total run, $failed failed"
[[ $failed -eq 0 ]]
SH
cat >tools/format.sh <<'SH'
#!/usr/bin/env bash
# toolchain.format — no trailing whitespace and no tab indentation in the scripts under bin/,
# tests/ and tools/. Exit 1 with the offending lines; --fix rewrites them in place.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
tab=$(printf '\t')
fix=0
[[ ${1:-} == --fix ]] && fix=1
status=0
for file in bin/* tests/*.sh tools/*.sh; do
  if grep -nE "[[:blank:]]+\$|^${tab}" "$file" >/dev/null; then
    if ((fix)); then
      sed -i -E "s/[[:blank:]]+\$//; s/^${tab}/  /" "$file"
    else
      grep -nE "[[:blank:]]+\$|^${tab}" "$file" | sed "s|^|$file:|"
      status=1
    fi
  fi
done
if ((status == 0)); then echo "format: clean"; else echo "format: run bash tools/format.sh --fix" >&2; fi
exit "$status"
SH
cat >tools/analyze.sh <<'SH'
#!/usr/bin/env bash
# toolchain.analyze — every script under bin/, tests/ and tools/ parses (bash -n) and passes
# passes shellcheck when that tool is installed. Exit 1 when one does not.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
status=0
for file in bin/* tests/*.sh tools/*.sh; do
  bash -n "$file" || status=1
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$file" || status=1
  fi
done
if ((status == 0)); then echo "analyze: no issue"; else echo "analyze: issues found" >&2; fi
exit "$status"
SH
cat >tools/add-dep.sh <<'SH'
#!/usr/bin/env bash
# toolchain.add_dep — adds a dependency of this part: its name to deps.txt, its resolved version
# to deps.lock. Usage: bash tools/add-dep.sh <name> [<version>]. A dependency already listed is refused.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
name=${1:-} version=${2:-latest}
[[ -n $name ]] || { echo "usage: bash tools/add-dep.sh <name> [<version>]" >&2; exit 2; }
if grep -qx "$name" deps.txt; then
  echo "add-dep: $name is already a dependency" >&2
  exit 1
fi
printf '%s\n' "$name" >>deps.txt
printf '%s=%s\n' "$name" "$version" >>deps.lock
echo "add-dep: $name ($version) added to deps.txt and deps.lock"
SH
printf '# One dependency per line: a command the CLI needs on the PATH (bash tools/add-dep.sh <name>).\n' >deps.txt
printf '# <dependency>=<version>, written by tools/add-dep.sh; never edited by hand.\n' >deps.lock
cat >docs/product/PRD.md <<'MD'
# PRD — notes

| | |
| --- | --- |
| Objective | What the software must do for its users, and how each need is verified |
| Status | APPROVED |
| Approved | 2026-10-27, approved by the user in conversation (« je valide ») |
| Assumptions | One user, one terminal, notes kept in a local file |
| Confirmed decisions | 2026-10-27: a shell CLI in one part (`path: .`), plugin-shell |
| Related documents | docs/engineering/DECISIONS.md, the TRD of the part (docs/technical/TRD.md) |
| Verification criteria | Every acceptance criterion is testable and covered by at least one test named after its id |

The PRD is unique to the project: one product, whatever the number of parts.

## Problem

Notes typed at the terminal are lost between sessions.

## Users

A developer who keeps short notes while working in a terminal.

## Scope

In:

- add a note
- list the notes
- list them while offline

Out:

- syncing, editing or deleting notes

## Acceptance criteria

| ID | Criterion | Priority |
| --- | --- | --- |
| AC-001 | Given notes were added with `notes add <text>`, when the user runs `notes list`, then the stored notes are printed one per line, in the order they were added. | must |
| AC-002 | Given notes were added, when the user runs `notes list --offline`, then the line `offline` is printed first, then the notes kept locally, without any network access. | must |

## Non-goals

- a graphical interface
- sharing notes between machines

## Open questions

- none
MD
cat >docs/technical/TRD.md <<'MD'
# TRD — notes (part app)

| | |
| --- | --- |
| Objective | How the app part is built: one bash script, a local store, shell tests |
| Status | APPROVED |
| Approved | 2026-10-27, approved by the user in conversation (« je valide ») |
| Related documents | docs/product/PRD.md, docs/engineering/IMPLEMENTATION_PLAN.md, docs/engineering/DECISIONS.md |

## Architecture

- `bin/notes` is the whole CLI: one bash script, subcommands `add` and `list` parsed in a `case`.
- The store is the file named by `NOTES_FILE` (default `notes.txt` in the current directory), one note per line.
- The CLI never reaches the network.

## Public API

- `notes add <text>` stores a note, exit 0.
- `notes list [--offline]` prints the notes one per line, exit 0.
- An unknown subcommand or option prints a usage line on stderr, exit 2.

## Tests

- Shell scripts under `tests/`, one per acceptance criterion, named `<feature>_test.sh`; each prints `PASSED n: … (AC-xxx)` or `FAILED n: …` and exits 1 on failure.
- `bash tests/run-all.sh` runs them all (`toolchain.test`); `bash tests/run-all.sh tests/<feature>_test.sh` runs one.

## Quality

- `bash tools/format.sh` (no trailing whitespace, two-space indentation) and `bash tools/analyze.sh` (`bash -n`, shellcheck when installed) exit 0 before any commit.
- A dependency is a command the CLI needs on the PATH: `bash tools/add-dep.sh <name>` records it in `deps.txt` and `deps.lock`, and it needs an ADR in `docs/engineering/DECISIONS.md`.
MD
cat >docs/engineering/IMPLEMENTATION_PLAN.md <<'MD'
# Implementation plan — notes (part app)

| | |
| --- | --- |
| Objective | One entry per feature: criteria, files, public API, tests, status |
| Status | DRAFT |
| Approved | — |

## AC-001 — Add and list notes

- Status: done (main, `chore: bootstrap notes with plugin-orchestrator`)
- Files: `bin/notes`
- Tests: `tests/base_test.sh` (AC-001)

## AC-002 — Offline notes list

- Status: planned
- Files: `bin/notes` (`list --offline`)
- Public API: `notes list --offline` prints `offline`, then the stored notes
- Tests: `tests/notes_test.sh` (AC-002)
- Dependencies: none
MD
cat >docs/engineering/DECISIONS.md <<'MD'
# Decisions — notes

| | |
| --- | --- |
| Objective | Record of every project-level choice — stack, parts, cross-cutting conventions — with its context and consequences |
| Status | DRAFT |
| Approved | — |
| Related documents | docs/product/PRD.md, docs/technical/TRD.md |

## ADR-001 — Initial stack

- Date: 2026-10-27
- Status: accepted
- Context: a notes CLI for one developer, to be kept small and portable.
- Decision: one part at the root, a bash script `bin/notes`, shell tests under `tests/`, plugin-shell as the language plugin.
- Alternatives: a Python CLI (an interpreter to install), a Flutter app (far too heavy).
- Consequences: no dependency unless recorded with `tools/add-dep.sh` and an ADR; bash 4 or later required.
- Parts concerned: app
MD
cat >CLAUDE.md <<'MD'
# notes — conventions for Claude

This project uses the plugin-orchestrator plugin, with the language plugin of each part named in `.forge/config.yaml`.

- Talk to the user in French. Code, identifiers and file contents stay in English.
- Workflows: `/plugin-orchestrator:create-feature` for any feature (TDD), `/plugin-orchestrator:git-workflow` for branches and commits, `/plugin-orchestrator:github-workflow` for the remote repository, pull requests and CI, `/plugin-orchestrator:recover-session` to resume interrupted work, `/plugin-orchestrator:debug-project` for an unexpected failure.
- State lives on disk: `.forge/checkpoint.md`, updated after each completed step, and the Git history. Never rely on what a previous session remembers.
- `.forge/config.yaml` is edited by the user only: the parts of the project, the language plugin and the toolchain of each.
- The commands of a part — tests, format, analysis, adding a dependency — are its `toolchain` keys in `.forge/config.yaml`; anything that needs to understand the language is a mandate to an agent of the part's language plugin. The orchestrator writes no application code.
- While developing, run the targeted tests of the part; its full suite, its formatter and its analysis at milestones only.
- Never report a test as passed without running it. Classify every result as passed, failed, blocked (reason) or not run.
- Git: branches `<branch_prefix><AC>-<slug>`, `fix/`, `chore/`, `docs/`; Conventional Commits; no `git add -A` without reviewing the diff; never a silent `git stash`.
- Documents move to APPROVED only on the user's explicit message, recorded with its date; an approved document that changes goes back to REVIEW.
MD
printf '# notes\n\nA tiny notes CLI, tested by shell scripts under tests/. Managed by plugin-orchestrator (.forge/).\n' >README.md
cat >.gitignore <<'IGNORE'
notes.txt
.env*
*.jks
*.keystore
key.properties
*.p12
*.pfx
# Files an editor or a sandbox seeds in the workspace (some as plain files: no trailing slash)
.bashrc
.bash_profile
.profile
.zshrc
.zprofile
.gitconfig
.gitmodules
.ripgreprc
.mcp.json
.idea
.vscode
.claude
.eval-artifacts
IGNORE
# The approvals, as scripts/orch.sh approve records them: date, document, fingerprint of the body
# without its Status and Approved rows (what doc-status-guard compares), the user's words.
fingerprint() {
  awk '!s && $0 ~ /^[|][[:space:]]*Status[[:space:]]*[|][[:space:]]*(DRAFT|REVIEW|APPROVED)[[:space:]]*[|][[:space:]]*$/ { s = 1; next }
       !a && $0 ~ /^[|][[:space:]]*Approved[[:space:]]*[|]/ { a = 1; next }
       { print }' "$1" | sha256sum | cut -d' ' -f1
}
printf '%s\t%s\t%s\t%s\n' 2026-10-27 docs/product/PRD.md "$(fingerprint docs/product/PRD.md)" "je valide" >.forge/approvals.log
printf '%s\t%s\t%s\t%s\n' 2026-10-27 docs/technical/TRD.md "$(fingerprint docs/technical/TRD.md)" "je valide" >>.forge/approvals.log
cat >.forge/checkpoint.md <<'CHECKPOINT'
# Checkpoint
updated: 2026-10-27T18:40+01:00
skill: bootstrap-project
feature: -
branch: main
last_commit: -

## Steps
- [x] 1 Identity and scope — `notes; part app (path: ., plugin-shell); scope: a notes CLI; French; current directory` → exit 0
- [x] 2 Directory, Git and state — `git init -b main; orch.sh init .` → exit 0
- [x] 3 Scaffold mandate — `scaffold → plugin-shell (INTERFACE: 1, STATUS: done)` → exit 0
- [x] 4 Configuration — `.forge/config.yaml written from the template, toolchain of the report` → exit 0
- [x] 5 Root documents — `docs/product/PRD.md, docs/engineering/DECISIONS.md, CLAUDE.md in DRAFT` → exit 0
- [x] 6 Documents and permissions — `orch.sh approve docs/product/PRD.md; orch.sh approve docs/technical/TRD.md (« je valide »)` → exit 0
- [x] 7 Base test — `bash tests/run-all.sh` → tests: 1 run, 0 failed (exit 0)
- [x] 8 First commit — `git commit -m "chore: bootstrap notes with plugin-orchestrator"` → carried by this commit
- [x] 9 Report — `report given in the conversation` → exit 0

## Test results
| command | result | when |
| --- | --- | --- |
| `bash tests/run-all.sh` | PASSED 1 | 18:38 |
| `bash tools/analyze.sh` | PASSED (no issue) | 18:39 |

## Next action
/plugin-orchestrator:create-feature AC-002 (offline notes list), from the approved PRD and TRD.

## Blockers / open questions
- none
CHECKPOINT
git init -q -b main
git config user.name test
git config user.email test@example.invalid
git add -A
# Commit dates fixed in the past: the hashes are stable, and a checkpoint written now is never
# older than a commit, so checkpoint-reminder stays silent.
GIT_AUTHOR_DATE=2026-10-27T18:40:00+01:00 GIT_COMMITTER_DATE=2026-10-27T18:40:00+01:00 \
  git commit -qm "chore: bootstrap notes with plugin-orchestrator"
git switch -q -c feature/AC-002-offline-notes-list
cat >tests/notes_test.sh <<'TEST'
#!/usr/bin/env bash
# AC-002: `notes list --offline` prints the line `offline` first, then the stored notes, one per
# line, without any network access.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
NOTES_FILE=$(mktemp)
export NOTES_FILE
trap 'rm -f "$NOTES_FILE"' EXIT
bin/notes add "buy milk"
bin/notes add "call mom"
out=$(bin/notes list --offline 2>&1)
if [[ $out == $'offline\nbuy milk\ncall mom' ]]; then
  echo "PASSED 1: notes list --offline (AC-002)"
  exit 0
fi
echo "FAILED 1: notes list --offline (AC-002) — output: $out"
exit 1
TEST
# The checkpoint as scripts/orch.sh checkpoint writes it, last_commit filled in below.
cat >.forge/checkpoint.md <<'CHECKPOINT'
# Checkpoint
updated: 2026-10-28T10:20+01:00
skill: create-feature
feature: AC-002 Offline notes list
branch: feature/AC-002-offline-notes-list
last_commit: HEAD_HASH

## Steps
- [x] 1 Repository state — `git status` → exit 0
- [x] 2 Context — `orch.sh status docs/product/PRD.md; orch.sh status docs/technical/TRD.md (APPROVED, APPROVED)` → exit 0
- [x] 3 Risks and dependencies — `no dependency, no migration, no platform impact` → exit 0
- [x] 4 Plan — `plan presented: bin/notes (list --offline), tests/notes_test.sh (AC-002); no validation needed` → exit 0
- [x] 5 Branch — `git switch -c feature/AC-002-offline-notes-list` → exit 0
- [x] 6 Tests first — `write-tests → plugin-shell:test-engineer (INTERFACE: 1, STATUS: done; tests/notes_test.sh)` → exit 0
- [x] 7 RED — `bash tests/run-all.sh tests/notes_test.sh` → FAILED 1 (expected RED) (exit 1)
- [ ] 8 Minimal implementation
- [ ] 9 GREEN
- [ ] 10 Refactor
- [ ] 11 Re-test
- [ ] 12 Quality
- [ ] 13 Review
- [ ] 14 Documentation
- [ ] 15 Commit and report

## Test results
| command | result | when |
| --- | --- | --- |
| `bash tests/run-all.sh tests/notes_test.sh` | FAILED 1 (expected RED) | 10:18 |

## Next action
Step 8 — Minimal implementation: make `notes list --offline` print `offline`, then the stored notes, in bin/notes, so that tests/notes_test.sh passes.

## Blockers / open questions
- none
CHECKPOINT
head=$(git rev-parse --short HEAD)
sed -i "s/HEAD_HASH/$head/" .forge/checkpoint.md
