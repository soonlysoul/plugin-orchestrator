#!/usr/bin/env bash
# guard-destructive: simulated inputs, no session. PreToolUse hook on Bash|PowerShell|Monitor,
# fail-closed, always active: destructive git, gh and rm commands, and publication to a
# registry (pub.dev, npm, PyPI) without --dry-run, are blocked wherever the command is hidden
# in the shell structure. Anything else passes in silence.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_guard_destructive
HOOK="$PLUGIN_ROOT/hooks/scripts/guard-destructive.sh"

echo "# contrat du squelette"
run_hook "$HOOK" 'pas du json'
expect_blocked "squelette : entrée illisible bloquée"
no_jq=$(mktemp -d)
run_hook "$HOOK" '{}' PATH="$no_jq"
rm -rf "$no_jq"
expect_blocked "squelette : jq absent bloqué"

echo "# contrat d'entrée et fail-closed"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "ls"'
expect_blocked "JSON malformé : bloqué"
run_hook "$HOOK" ''
expect_blocked "entrée vide : bloquée"
run_hook "$HOOK" '{"tool_input": {"command": "ls"}}'
expect_blocked "entrée sans tool_name : bloquée"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": 42}}'
expect_blocked "command non textuel : bloqué"
nojq=$(restricted_path)
run_hook "$HOOK" "$(bash_input 'git status')" PATH="$nojq"
expect_blocked "jq absent : toute commande bloquée"
[[ $HOOK_STDERR == *jq* ]] && pass "jq absent : nommé dans la raison" || fail "jq absent : nommé dans la raison" "$HOOK_STDERR"
rm -r "$nojq"

echo "# hors contexte : silencieux"
run_hook "$HOOK" '{"tool_name": "Read", "tool_input": {"file_path": "/work/proj/a.txt"}}'
expect_silent_allow "outil non shell : passe"
run_hook "$HOOK" '{"tool_name": "Monitor", "tool_input": {"ws": {"url": "wss://example.test/feed"}}}'
expect_silent_allow "Monitor WebSocket sans command : passe"
run_hook "$HOOK" "$(bash_input '')"
expect_silent_allow "command vide : passe"
run_hook "$HOOK" "$(bash_input 'git status')"
expect_silent_allow "commande Bash sûre : passe"
run_hook "$HOOK" "$(bash_input 'git status' Bash /other/dir)"
expect_silent_allow "commande sûre hors d'un projet .forge/ : passe (toujours actif, jamais bavard)"

echo "# règle : blocage et raison"
run_hook "$HOOK" "$(bash_input 'git reset --hard')"
expect_blocked "git reset --hard : bloqué"
[[ $HOOK_STDERR == *guard-destructive* && $HOOK_STDERR == *reset* ]] \
  && pass "la raison nomme le hook et la commande" || fail "la raison nomme le hook et la commande" "$HOOK_STDERR"
[[ $HOOK_STDERR == *plugin-orchestrator* ]] \
  && pass "la raison nomme le plugin" || fail "la raison nomme le plugin" "$HOOK_STDERR"
run_hook "$HOOK" "$(bash_input 'git reset --hard' Monitor)"
expect_blocked "Monitor : vérifié comme Bash"
run_hook "$HOOK" "$(bash_input 'git reset --hard' PowerShell)"
expect_blocked "PowerShell : vérifié comme Bash"
run_hook "$HOOK" "$(bash_input 'git reset --hard' Bash /other/dir)"
expect_blocked "commande destructive hors d'un projet .forge/ : bloquée (toujours actif)"

echo "# structure de commande (sonde : git reset --hard)"
# Each of these runs git reset --hard somewhere.
structure_blocked=(
  'cd sub && git reset --hard'
  'git status; git reset --hard'
  'true || git reset --hard'
  'git fetch | git reset --hard'
  'sleep 1 & git reset --hard'
  $'git status\ngit reset --hard'
  '(git reset --hard)'
  '{ git reset --hard; }'
  'if true; then git reset --hard; fi'
  '! git reset --hard'
  'FOO=1 git reset --hard'
  'sudo git reset --hard'
  'sudo -u bob git reset --hard'
  'env -i GIT_DIR=.git git reset --hard'
  'command git reset --hard'
  'nohup git reset --hard'
  'timeout 5 git reset --hard'
  'nice -n 5 git reset --hard'
  '/usr/bin/git reset --hard'
  '\git reset --hard'
  '"git" reset --hard'
  "g'i't reset \"--hard\""
  'git -C sub reset --hard'
  'git -c core.pager=cat reset --hard'
  'git --no-pager reset --hard'
  'bash -c "git reset --hard"'
  "sh -c 'cd x; git reset --hard'"
  'bash -lc "git reset --hard"'
  'eval "git reset --hard"'
  'eval git reset --hard'
  'echo $(git reset --hard)'
  'echo "$(git reset --hard)"'
  'echo `git reset --hard`'
  'x=$(git reset --hard)'
  'echo $(git reset --hard'
  $'bash <<EOF\ngit reset --hard\nEOF'
  $'cat <<EOF\n$(git reset --hard)\nEOF'
  $'cat <<EOF\nnote: `git reset --hard`\nEOF'
  $'git commit -F - <<EOF\nfix: $(git reset --hard)\nEOF'
  $'git reset \\\n  --hard'
  'git reset --hard # comment'
  $'ls # comment\ngit reset --hard'
)
for c in "${structure_blocked[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_blocked "bloqué : ${c//$'\n'/\\n}"
done

# None of these runs git reset --hard: it only appears as data.
structure_allowed=(
  'git commit -m "docs: never run git reset --hard"'
  "git commit -m 'git reset --hard; rm -rf /'"
  'echo "git reset --hard"'
  'grep -rn "git reset --hard" docs/'
  "printf '%s\\n' 'git reset --hard'"
  $'git commit -F - <<\'EOF\'\nfeat: block git reset --hard\nEOF'
  $'cat > notes.md <<EOF\ngit reset --hard\nEOF'
  $'cat <<\'EOF\'\n$(git reset --hard)\nEOF'
  $'cat <<"EOF"\n`git reset --hard`\nEOF'
  $'cat <<\\EOF\n$(git reset --hard)\nEOF'
  $'cat <<-EOF\n\tgit reset --hard\n\tEOF\ngit status'
  'ls # git reset --hard'
  'git status && git log --oneline'
  'git commit -m "unterminated'
)
for c in "${structure_allowed[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_silent_allow "passe : ${c//$'\n'/\\n}"
done

echo "# règles git"
git_blocked=(
  'git reset --hard HEAD~1'
  'git clean -f'
  'git clean -fd'
  'git clean -xdf'
  'git clean --force'
  'git push --force'
  'git push origin main --force'
  'git push -f origin main'
  'git push -uf origin feature/x'
  'git push --force-with-lease'
  'git push --force-with-lease=main:abc123 origin main'
  'git push --force-if-includes origin main'
  'git push origin +main'
  'git push origin +HEAD:main'
  'git push --delete origin feature/x'
  'git push -d origin feature/x'
  'git push origin :feature/x'
  'git push --mirror'
  'git push --tags'
  'git push --follow-tags origin main'
  'git push origin refs/tags/v1.0.0'
  'git push origin HEAD:refs/tags/v1'
  'git branch -D feature/x'
  'git branch --delete --force feature/x'
  'git branch -d -f feature/x'
  'git branch -df feature/x'
  'git checkout -- .'
  'git checkout -- src/app.ts'
  'git checkout .'
  'git checkout HEAD -- src'
  'git checkout -f main'
  'git restore src/app.ts'
  'git restore .'
  'git restore --worktree src/app.ts'
  'git restore --staged --worktree src/app.ts'
  'git restore -SW src/app.ts'
  'git restore --source=HEAD~1 src/app.ts'
  'git stash drop'
  'git stash drop stash@{0}'
  'git stash clear'
  'git switch --discard-changes main'
  'git switch -f main'
)
for c in "${git_blocked[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_blocked "bloqué : $c"
done

git_allowed=(
  'git status'
  'git diff --staged'
  'git log --oneline -10'
  'git add src/app.ts test/app_test.ts'
  'git commit -m "feat(notes): list notes offline (AC-012)"'
  'git commit --amend --no-edit'
  'git push origin feature/x'
  'git push -u origin feature/x'
  'git push --dry-run origin feature/x'
  'git push --no-force-with-lease origin feature/x'
  'git switch -c feature/x'
  'git switch main'
  'git checkout -b feature/x'
  'git checkout main'
  'git restore --staged src/app.ts'
  'git restore -S src/app.ts'
  'git stash list'
  'git stash push -m "wip"'
  'git stash pop'
  'git branch -d merged-feature'
  'git branch --show-current'
  'git clean -n'
  'git clean --dry-run -d'
  'git reset --soft HEAD~1'
  'git reset HEAD src/app.ts'
  'git tag v1.0.0'
)
for c in "${git_allowed[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_silent_allow "passe : $c"
done

echo "# rm, gh, find et xargs (cwd : /work/proj)"
other_blocked=(
  'rm -rf src'
  'rm -fr src'
  'rm -Rf src'
  'rm -r -f src'
  'rm --recursive --force src'
  'rm -rfv src'
  'rm -rf /'
  'rm -rf ~'
  'rm -rf *'
  'rm -rf .'
  'rm -rf build/../src'
  'rm -rf build src'
  'rm -rf "$HOME/project"'
  'rm -rf /work/proj/src'
  'rm -rf /other/build'
  'rm -rf -- src'
  'rm -rf node_modules'
  'rm -rf dist'
  'rm -rf .venv'
  '/bin/rm -rf src'
  'sudo rm -rf src'
  'ls | xargs rm -rf'
  "find . -name '*.log' -exec rm -rf {} \\;"
  'find . -execdir rm -rf {} +'
  'gh repo delete owner/repo --yes'
  'gh repo edit --visibility public'
  'gh repo edit owner/repo --visibility=private --accept-visibility-change-consequences'
  'gh pr merge 12 --squash'
  'gh release create v1.0.0'
  'gh release delete v1.0.0'
  'gh release upload v1.0.0 app.tar.gz'
  'gh api -X DELETE repos/owner/repo'
  'gh api --method=DELETE repos/owner/repo'
  'gh api repos/owner/repo -XDELETE'
  'gh api --method delete repos/owner/repo'
)
for c in "${other_blocked[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_blocked "bloqué : $c"
done

other_allowed=(
  'rm -rf build'
  'rm -rf build/'
  'rm -rf ./build/app'
  'rm -rf build/*'
  'rm -rf /work/proj/build'
  'rm -rf /work/proj/build/app/outputs'
  'rm file.txt'
  'rm -f src/old.ts'
  'rm -r tmpdir'
  'gh pr create --title "Add notes" --body "AC-012"'
  'gh pr view 12'
  'gh pr list'
  'gh repo view'
  'gh repo edit --description "Notes app"'
  'gh release list'
  'gh release view v1.0.0'
  'gh api repos/owner/repo'
  'gh api -X GET repos/owner/repo'
  "find . -name '*.ts'"
  "find build -name '*.so'"
  'echo "rm -rf /"'
  'grep -r "rm -rf" docs/'
)
for c in "${other_allowed[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_silent_allow "passe : $c"
done

echo "# publication vers un registre (pub.dev, npm, PyPI), sauf --dry-run"
publish_blocked=(
  'flutter pub publish'
  'flutter pub publish --force'
  'dart pub publish'
  'dart pub publish -f'
  'flutter --suppress-analytics pub publish'
  'npm publish'
  'npm publish --access public'
  'npm publish --tag beta ./dist'
  'npm unpublish my-pkg@1.0.0 --force'
  'pnpm publish'
  'pnpm -r publish'
  'pnpm --filter api publish --no-git-checks'
  'yarn publish'
  'yarn npm publish'
  'yarn npm publish --access public'
  'bun publish'
  'twine upload dist/*'
  'twine upload --repository testpypi dist/*'
  'uv publish'
  'uv publish dist/*'
  'poetry publish'
  'poetry publish --build'
  'hatch publish'
  'flit publish'
  'cd packages/api && npm publish'
  'npm run build && npm publish'
)
for c in "${publish_blocked[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_blocked "bloqué : $c"
done
run_hook "$HOOK" "$(bash_input 'npm publish')"
[[ $HOOK_STDERR == *npm* && $HOOK_STDERR == *publish* ]] \
  && pass "la raison nomme l'outil et la publication" || fail "la raison nomme l'outil et la publication" "$HOOK_STDERR"

publish_allowed=(
  'flutter pub publish --dry-run'
  'dart pub publish -n'
  'flutter pub get'
  'dart pub deps'
  'flutter clean'
  'npm publish --dry-run'
  'pnpm publish --dry-run'
  'bun publish --dry-run'
  'poetry publish --dry-run'
  'npm install'
  'npm ci'
  'npm run build'
  'npm test'
  'npm pack'
  'npm version patch'
  'npm run publish-docs'
  'pnpm install'
  'pnpm test'
  'yarn install'
  'yarn build'
  'yarn npm info react'
  'bun install'
  'bun test'
  'twine check dist/*'
  'uv sync'
  'uv build'
  'uv run pytest'
  'poetry build'
  'poetry install'
  'hatch build'
  'flit build'
  'pip install -e .'
  'echo "npm publish"'
  'git commit -m "ci: npm publish on tag"'
)
for c in "${publish_allowed[@]}"; do
  run_hook "$HOOK" "$(bash_input "$c")"
  expect_silent_allow "passe : $c"
done

echo "# lexer partagé absent : fail-closed"
nolib=$(mktemp -d)
cp "$HOOK" "$nolib/"
run_hook "$nolib/guard-destructive.sh" "$(bash_input 'git status')"
expect_blocked "bibliothèque du lexer absente : bloqué"
rm -r "$nolib"

echo "# longue entrée analysée dans le délai"
message=$'git commit -F - <<\'EOF\'\nfeat: long message\n'
for i in $(seq 1 400); do message+="line $i: mention git reset --hard and rm -rf / as plain text"$'\n'; done
message+=$'EOF'
start=$(date +%s%N)
run_hook "$HOOK" "$(bash_input "$message")"
elapsed_ms=$(( ($(date +%s%N) - start) / 1000000 ))
expect_silent_allow "long message de commit en heredoc : passe"
(( elapsed_ms < 3000 )) && pass "long message analysé en ${elapsed_ms} ms (< 3000)" \
  || fail "long message analysé en moins de 3000 ms" "a pris ${elapsed_ms} ms"

finish
