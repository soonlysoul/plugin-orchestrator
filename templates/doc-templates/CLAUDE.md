# <Project name> — conventions for Claude

This project uses the plugin-orchestrator plugin, with the language plugin of each part named in `.forge/config.yaml`.

- Talk to the user in <language>. Code, identifiers and file contents stay in English.
- Workflows: `/plugin-orchestrator:create-feature` for any feature (TDD), `/plugin-orchestrator:git-workflow` for branches and commits, `/plugin-orchestrator:github-workflow` for the remote repository, pull requests and CI, `/plugin-orchestrator:recover-session` to resume interrupted work, `/plugin-orchestrator:debug-project` for an unexpected failure.
- State lives on disk: `.forge/checkpoint.md`, updated after each completed step, and the Git history. Never rely on what a previous session remembers.
- `.forge/config.yaml` is edited by the user only: the parts of the project, the language plugin and the toolchain of each.
- The commands of a part — tests, format, analysis, adding a dependency — are its `toolchain` keys in `.forge/config.yaml`; anything that needs to understand the language is a mandate to an agent of the part's language plugin. The orchestrator writes no application code.
- While developing, run the targeted tests of the part; its full suite, its formatter and its analysis at milestones only.
- Never report a test as passed without running it. Classify every result as passed, failed, blocked (reason) or not run.
- Git: branches `<branch_prefix><AC>-<slug>`, `fix/`, `chore/`, `docs/`; Conventional Commits; no `git add -A` without reviewing the diff; never a silent `git stash`.
- Documents move to APPROVED only on the user's explicit message, recorded with its date; an approved document that changes goes back to REVIEW.
