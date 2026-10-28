# The mandates of create-feature

What create-feature sends to the agents of the part's language plugin, and what it needs back, at interface 1 of the delegation contract. The orchestrator runs the mechanical gestures of the part itself, through its `toolchain`; whatever needs to understand the language is one of these three mandates. Every mandate names the interface, the part, the task, the criteria and the declared scope; every report ends with the common tail, and the session checks it before using anything the report says.

## Common tail of every report

```
INTERFACE: 1
STATUS: done | blocked | partial
FILES_CHANGED:
- <path> — <one-line summary>, or none
COMMANDS_RUN:
- `<command>` → exit <code>
OPEN_QUESTIONS:
- <question, and who answers it>, or none
```

Checks, for every report:

- `INTERFACE: 1` present. Without it, the plugin is a pre-migration version (a plugin-flutter 0.x): stop, name the plugin and the version it needs, record the blocker.
- `FILES_CHANGED` against `git status --porcelain`: nothing outside what the mandate allowed.
- Every claim comes with its command and exit code under `COMMANDS_RUN`; the one that matters is rerun by the session.
- `STATUS: blocked` or `partial`: the reason is read before anything else is done; a question under `OPEN_QUESTIONS` addressed to the user is a validation point.

## write-tests → `<plugin>:test-engineer` (step 6)

```
interface: 1
task: write-tests
part:
  path: <path>
  plugin: <plugin>
acceptance criteria:
- <AC-id> — <criterion>
plan:
  files touched: <files under the part's path>
  public API: <signatures>
tests to write: <test files, under the test folders of the part>
integration tests: <the command and device of toolchain.integration_test>, or blocked: <reason>
scope: the test files above only — nothing in the production code, the manifests or docs/
constraints:
- at least one test per criterion, named with its AC id, through the public API of the plan
- no test dependency added: a missing one goes under OPEN_QUESTIONS
- the tests are run and must fail for the right reason (the expected assertion, or the missing API named)
- every claim comes with its command and exit code
```

Report expected, before the common tail:

```
TESTS_WRITTEN:
- <file> — <test names, each with its AC id>
EDGE_CASES:
- <case>
RED_OUTPUT:
<raw output of the last run, trimmed to the failing tests and the summary line>
```

Checks: `FILES_CHANGED` holds test files under the part's path only; `COMMANDS_RUN` gives the targeted command, which step 7 reruns; a test reported as already passing is a stop, not a RED.

## check-dependency → the architect of the part's plugin (step 4)

```
interface: 1
task: check-dependency
part:
  path: <path>
  plugin: <plugin>
package: <name and version, as toolchain.add_dep recorded it>
targets: <the part's platforms or targets>
question: compatibility of the package with each target, and whatever the plugin's conventions require for it (a platform file, a permission, a minimum version)
scope: nothing is written; the ADR is the session's
```

Report expected, before the common tail:

```
DEPENDENCY:
- <package> — compatible with <targets> | not compatible with <target> (<reason>) | not verified (<reason>)
ADR:
- <what the ADR must record: context, consequences, what the conventions require>
```

Checks: a target called compatible has its evidence — the file or command cited; the verdict goes into the ADR of the part's DECISIONS.md as it is, "not verified" included.

## review → `<plugin>:code-reviewer` (step 13)

```
interface: 1
task: review
part:
  path: <path>
  plugin: <plugin>
diff: --cached <default branch>
acceptance criteria:
- <AC-id> — <criterion>
plan entry: <the feature's entry of the implementation plan>
scope: <the files or folders of the plan>
```

Nothing of the implementation's reasoning goes into the mandate.

Report expected, before the common tail:

```
FINDINGS:
- blocking: <file:line — finding>, or none
- important: <file:line — finding>, or none
- minor: <file:line — finding>, or none
DOCS_TO_UPDATE:
- <document — what to update>, or none
DIVERGENCES:
- <document:line — what it says — what the diff does>, or none
```

Checks: `FILES_CHANGED` is none, a reviewer writes nothing; each blocking finding is read at its `file:line` before being fixed; `DOCS_TO_UPDATE` and `DIVERGENCES` drive step 14.
