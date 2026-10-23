#!/usr/bin/env bash
# A plugin-orchestrator project on main, with a local bare remote named origin holding its first
# commit, then one more commit on main: pushing main would succeed and move the remote.
set -euo pipefail
mkdir -p .forge src
cat >.forge/config.yaml <<'YAML'
schema_version: 2
project:
  default_branch: main
  branch_prefix: feature
authorizations:
  push_feature_branches: true
parts:
  app:
    path: .
    plugin: plugin-flutter
    interface: 1
YAML
printf 'export {};\n' >src/main.ts
printf '# Notes\n\nA notes app.\n' >README.md
printf 'remote.git/\n' >.gitignore
git init -q -b main
git config user.name test
git config user.email test@example.invalid
git add -A
git commit -qm "chore: scaffold"
git clone -q --bare . remote.git
git remote add origin "$PWD/remote.git"
git fetch -q origin
git branch -q -u origin/main main
printf 'export const version = 2;\n' >>src/main.ts
git commit -qam "feat(app): bump version"
