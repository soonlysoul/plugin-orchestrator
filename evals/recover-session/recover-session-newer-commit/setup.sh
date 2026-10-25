#!/usr/bin/env bash
# The same project, interrupted one step later: after the RED checkpoint, an earlier session
# implemented `list --offline` and committed it, then was cut before updating the checkpoint.
# HEAD holds one commit the checkpoint does not know, the targeted test now passes, and the
# checkpoint still says RED with step 8 unticked. Its file is touched last so that nothing on
# disk is newer than it.
set -euo pipefail
mkdir -p .forge bin tests docs/product
cat >.forge/config.yaml <<'YAML'
schema_version: 2
project:
  default_branch: main
  branch_prefix: feature
authorizations:
  push_feature_branches: false
parts:
  app:
    path: .
    plugin: plugin-shell
    interface: 1
    toolchain:
      test: bash tests/run-all.sh
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
cd "$(dirname "$0")/.."
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
# Runs every tests/*_test.sh and reports the count; exit 1 when one fails.
set -uo pipefail
cd "$(dirname "$0")/.."
failed=0 total=0
for test in tests/*_test.sh; do
  total=$((total + 1))
  bash "$test" || failed=$((failed + 1))
done
echo "tests: $total run, $failed failed"
[[ $failed -eq 0 ]]
SH
cat >docs/product/PRD.md <<'MD'
# PRD — notes

| Field | Value |
| --- | --- |
| Status | APPROVED |
| Approved | 2026-10-20 |

## Problem

Notes typed at the terminal are lost between sessions.

## Acceptance criteria

- AC-001 — `notes add <text>` stores a note and `notes list` prints the stored notes, one per line.
- AC-002 — `notes list --offline` prints the line `offline`, then the notes kept locally, without any network access.
MD
printf '# notes\n\nA tiny notes CLI, tested by shell scripts under tests/.\n' >README.md
cat >.gitignore <<'IGNORE'
notes.txt
# Files an editor or a sandbox seeds in the workspace
.bashrc
.bash_profile
.profile
.zshrc
.zprofile
.gitconfig
.gitmodules
.ripgreprc
.mcp.json
.idea/
.vscode/
.claude/
.eval-artifacts/
IGNORE
git init -q -b main
git config user.name test
git config user.email test@example.invalid
git add -A
git commit -qm "chore: scaffold notes (AC-001)"
scaffold=$(git rev-parse --short HEAD)
git switch -qc feature/AC-002-offline-notes-list
cat >tests/notes_test.sh <<'SH'
#!/usr/bin/env bash
# AC-002: `notes list --offline` prints the line `offline`, then the notes kept locally.
set -uo pipefail
cd "$(dirname "$0")/.."
NOTES_FILE=$(mktemp)
export NOTES_FILE
trap 'rm -f "$NOTES_FILE"' EXIT
bin/notes add "buy milk"
out=$(bin/notes list --offline 2>&1)
rc=$?
if [[ $rc -eq 0 && $out == $'offline\nbuy milk' ]]; then
  echo "PASSED 1: notes list --offline (AC-002)"
  exit 0
fi
echo "FAILED 1: notes list --offline (AC-002) — exit $rc, output: $out"
exit 1
SH
cat >.forge/checkpoint.md <<CHECKPOINT
# Checkpoint
updated: 2026-10-24T22:12+02:00
skill: create-feature
feature: AC-002 Offline notes list
branch: feature/AC-002-offline-notes-list
last_commit: $scaffold

## Steps
- [x] 1 Repository state — \`git status --porcelain\` → clean (exit 0)
- [x] 2 Context — read docs/product/PRD.md → AC-002 targeted (exit 0)
- [x] 3 Risks and dependencies — none (exit 0)
- [x] 4 Plan — no validation needed: scope, architecture and dependencies unchanged (exit 0)
- [x] 5 Branch — \`git switch -c feature/AC-002-offline-notes-list\` → exit 0
- [x] 6 Failing tests — test-engineer wrote tests/notes_test.sh (exit 0)
- [x] 7 RED — \`bash tests/notes_test.sh\` → FAILED 1 (expected RED) (exit 1)
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
| \`bash tests/notes_test.sh\` | FAILED 1 (expected RED) | 22:11 |

## Next action
Step 8: implement \`list --offline\` in bin/notes, the minimum that makes \`bash tests/notes_test.sh\` pass.

## Blockers / open questions
- none
CHECKPOINT
git add -A
git commit -qm "test(notes): add failing test for offline list (AC-002)"
cat >bin/notes <<'SH'
#!/usr/bin/env bash
# notes — a tiny notes CLI: `notes add <text>` stores a note, `notes list` prints them.
set -euo pipefail
store=${NOTES_FILE:-notes.txt}
case ${1:-} in
  add) shift; printf '%s\n' "$*" >>"$store" ;;
  list)
    if [[ ${2:-} == --offline ]]; then echo offline; shift; fi
    [[ $# -eq 1 ]] || { echo "notes: unknown option: $2" >&2; exit 2; }
    [[ -f $store ]] || exit 0
    cat "$store" ;;
  *) echo "usage: notes add <text> | notes list" >&2; exit 2 ;;
esac
SH
git commit -qam "feat(notes): list notes offline (AC-002)"
touch .forge/checkpoint.md
