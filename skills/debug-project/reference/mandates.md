# The mandates of debug-project

What debug-project sends to the agents of the part's language plugin, and what it needs back, at interface 1 of the delegation contract. The orchestrator reproduces the failure and checks the fix itself, through the part's `toolchain`; whatever needs to understand the language is one of these three mandates. Every mandate names the interface, the part, the task and the declared scope; every report ends with the common tail, and the session checks it before using anything the report says.

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

## diagnose → the architect of the part's plugin (step 4)

Only when the hypothesis depends on a behaviour of the language, its tools or a platform that the code does not show: a dependency resolution, a platform toolchain, a compiler or analyzer rule.

```
interface: 1
task: diagnose
part:
  path: <path>
  plugin: <plugin>
failure:
  command: <the reproduction command of step 2>
  output: <the first error lines>
  class: <the class of step 3>
hypothesis: <the current hypothesis, with the evidence gathered so far>
question: <the behaviour the hypothesis depends on>
scope: nothing is written; the fix is the session's
```

Report expected, before the common tail:

```
DIAGNOSIS:
- confirmed | refuted | not verified — <the evidence: a file, a documentation page, a command and its output>
FIX_DIRECTION:
- <what would remove the cause, in the part's conventions>, or none
```

Checks: `FILES_CHANGED` is none; a verdict without its evidence counts as "not verified"; a command cited as evidence is rerun by the session before the root cause is stated.

## write-tests → `<plugin>:test-engineer` (step 7)

Only when no existing test reproduces the failure.

```
interface: 1
task: write-tests
part:
  path: <path>
  plugin: <plugin>
acceptance criteria:
- <AC-id> — <criterion>, when the failure breaks one; or none
failure:
  command: <the reproduction command of step 2>
  output: <the first error lines>
  root cause: <the sentence of step 4>
tests to write: one regression test, named `regression: <what failed>` or after the criterion, next to the existing tests of the code at fault
scope: that test file only — nothing in the production code, the manifests or docs/
constraints:
- the test goes through the public API and fails for the root cause above, not for another reason
- no test dependency added: a missing one goes under OPEN_QUESTIONS
- the test is run and must fail; its output is reported
- every claim comes with its command and exit code
```

Report expected, before the common tail:

```
TESTS_WRITTEN:
- <file> — <test name>
RED_OUTPUT:
<raw output of the last run, trimmed to the failing test and the summary line>
```

Checks: `FILES_CHANGED` holds that test file only; `COMMANDS_RUN` gives the targeted command, which step 7 reruns; a test reported as already passing does not reproduce the failure: back to step 4.

## review → `<plugin>:code-reviewer` (step 10)

```
interface: 1
task: review
part:
  path: <path>
  plugin: <plugin>
diff: --cached <base>
root cause: <one sentence>
regression test: <file and name>
scope: <the files of step 5>
```

Nothing of the diagnosis's reasoning goes into the mandate beyond the root cause sentence.

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

Checks: `FILES_CHANGED` is none, a reviewer writes nothing; each blocking finding is read at its `file:line` before being fixed; a finding that the fix hides a symptom rather than removing the cause is blocking.
