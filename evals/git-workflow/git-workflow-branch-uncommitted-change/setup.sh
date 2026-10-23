#!/usr/bin/env bash
# A plugin-orchestrator project: .forge/config.yaml with a branch prefix, a git repository on main
# with one commit, a git identity for later commits, and one tracked file modified since that
# commit, neither staged nor committed: creating a branch now would carry that change silently.
set -euo pipefail
mkdir -p .forge src
cat >.forge/config.yaml <<'YAML'
schema_version: 2
project:
  default_branch: main
  branch_prefix: story
authorizations:
  push_feature_branches: false
parts:
  app:
    path: .
    plugin: plugin-flutter
    interface: 1
YAML
printf 'export {};\n' >src/main.ts
printf '# Notes\n\nA notes app.\n' >README.md
git init -q -b main
git config user.name test
git config user.email test@example.invalid
git add -A
git commit -qm "chore: scaffold"
printf 'export const offline = true;\n' >>src/main.ts
