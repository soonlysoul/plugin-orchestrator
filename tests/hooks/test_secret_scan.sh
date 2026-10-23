#!/usr/bin/env bash
# secret-scan: simulated inputs, no session, real throwaway git repositories. PreToolUse hook on
# Bash|PowerShell|Monitor, fail-closed for commits: secret file names and secret patterns in the
# lines the commit can add are blocked; every command without the word "commit" passes in
# silence, even without jq.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_secret_scan
HOOK="$PLUGIN_ROOT/hooks/scripts/secret-scan.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Fake secrets are assembled at run time, so that this file holds none of the patterns.
AWS="AKIA""IOSFODNN7EXAMPLE"
GHP="ghp""_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
PAT="github""_pat_11ABCDEFG0123456789_abcdefghijklmnopqrstuvwxyz"
SKA="sk""-ant-api03-AbCdEfGhIjKlMnOpQrStUv"
GOOG="AIza""SyA1234567890abcdefghijklmnopqrstuv"
NPM="npm""_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"
NPM_LEGACY="_auth""Token=01234567-89ab-cdef-0123-456789abcdef"
PYPI="pypi-""AgEIcHlwaS5vcmcCJDAxMjM0NTY3ODktYWJjZC1lZmdoLWlqa2wtbW5vcHFyc3R1dnd4"
PEM="-----BEGIN ""RSA PRIVATE KEY-----"
CERT="-----BEGIN ""CERTIFICATE-----"
ALL_SECRETS=("$AWS" "$GHP" "$PAT" "$SKA" "$GOOG" "$NPM" "${NPM_LEGACY#*=}" "$PYPI")

# The hook runs without gitleaks unless a test puts a fake one first in PATH.
base_path=$(restricted_path jq git grep sed awk cat head tr sort mktemp rm dirname)

# make_repo [nohead]: a repository with one committed file, notes.txt. Prints its path.
make_repo() {
  local repo
  repo=$(mktemp -d "$work/repo.XXXXXX")
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name Test
  git -C "$repo" config commit.gpgsign false
  echo "notes" >"$repo/notes.txt"
  if [[ ${1-} != nohead ]]; then
    git -C "$repo" add notes.txt
    git -C "$repo" commit -qm init
  fi
  printf '%s' "$repo"
}

# stage <repo> <file> <content>
stage() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
  git -C "$1" add -- "$2"
}

# scan <command> <cwd> [env...]
scan() {
  local command=$1 cwd=$2
  shift 2
  run_hook "$HOOK" "$(bash_input "$command" Bash "$cwd")" PATH="$base_path" "$@"
}

# expect_secret <label> <needle...>: blocked, every needle in the reason, no secret printed.
expect_secret() {
  local label=$1 needle secret missing=""
  shift
  if [[ $HOOK_STATUS != 2 || -z $HOOK_STDERR ]]; then
    fail "$label" "attendu exit 2 avec une raison, obtenu exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:300}"
    return
  fi
  for needle in "$@"; do [[ $HOOK_STDERR == *"$needle"* ]] || missing+=" [$needle]"; done
  for secret in "${ALL_SECRETS[@]}"; do [[ $HOOK_STDERR != *"$secret"* ]] || missing+=" [secret affiché]"; done
  [[ -z $missing ]] && pass "$label" || fail "$label" "absent de la raison :$missing ; stderr : ${HOOK_STDERR:0:400}"
}

echo "# contrat du squelette (entrées qui mentionnent commit, le seul contexte du hook)"
run_hook "$HOOK" 'pas du json, mais commit'
expect_blocked "squelette : entrée illisible bloquée"
no_jq=$(mktemp -d)
run_hook "$HOOK" '{"x": "commit"}' PATH="$no_jq"
rm -rf "$no_jq"
expect_blocked "squelette : jq absent bloqué"

echo "# hors contexte : commandes qui ne commitent pas"
repo=$(make_repo)
stage "$repo" leak.txt "key=$AWS"
nojq=$(restricted_path)
run_hook "$HOOK" "$(bash_input 'ls -la' Bash "$repo")" PATH="$nojq"
expect_silent_allow "une commande sans « commit » passe, même sans jq"
rm -r "$nojq"
scan 'git status' "$repo"
expect_silent_allow "git status passe"
scan 'echo "git commit -m x"' "$repo"
expect_silent_allow "un texte cité qui mentionne git commit passe"
scan 'git log --grep commit' "$repo"
expect_silent_allow "git log --grep commit passe"
run_hook "$HOOK" '{"tool_name": "Read", "tool_input": {"file_path": "/work/commit.txt"}}' PATH="$base_path"
expect_silent_allow "un outil non shell passe"
run_hook "$HOOK" '{"tool_name": "Monitor", "tool_input": {"ws": {"url": "wss://example.test/commit"}}}' PATH="$base_path"
expect_silent_allow "un appel Monitor WebSocket passe"

echo "# commits propres"
repo=$(make_repo)
stage "$repo" src/notes.ts "export const notes: string[] = [];"
scan 'git commit -m "feat(notes): add notes"' "$repo"
expect_silent_allow "un changement indexé sans secret passe"
stage "$repo" docs/cert.md "$CERT"
scan 'git commit -m x' "$repo"
expect_silent_allow "l'en-tête d'un certificat public passe"
stage "$repo" docs/risk.md "see task-abcdefghijklmnopqrstuvwxyz0123 and disk-0123456789abcdefghijk"
scan 'git commit -m x' "$repo"
expect_silent_allow "sk- à l'intérieur d'un mot (task-, disk-) passe"
stage "$repo" .env.example "API_KEY=changeme"
scan 'git commit -m x' "$repo"
expect_silent_allow ".env.example passe"
repo=$(make_repo nohead)
git -C "$repo" add notes.txt
scan 'git commit -m init' "$repo"
expect_silent_allow "un premier commit, avant tout HEAD, passe quand il est propre"
plain=$(mktemp -d "$work/plain.XXXXXX")
scan 'git commit -m x' "$plain"
expect_silent_allow "hors d'un dépôt, rien à analyser"

echo "# motifs de secret dans les lignes indexées"
repo=$(make_repo)
stage "$repo" src/aws.ts "const key = '$AWS';"
scan 'git commit -m x' "$repo"
expect_secret "clé d'accès AWS : bloquée" src/aws.ts AWS
repo=$(make_repo)
stage "$repo" deploy/id_rsa "$PEM"
scan 'git commit -m x' "$repo"
expect_secret "clé privée : bloquée" deploy/id_rsa "clé privée"
repo=$(make_repo)
stage "$repo" ci/token.txt "$GHP"
scan 'git commit -m x' "$repo"
expect_secret "jeton GitHub ghp_ : bloqué" ci/token.txt GitHub
repo=$(make_repo)
stage "$repo" ci/pat.txt "token: $PAT"
scan 'git commit -m x' "$repo"
expect_secret "jeton GitHub github_pat_ : bloqué" ci/pat.txt GitHub
repo=$(make_repo)
stage "$repo" src/llm.ts "const apiKey = \"$SKA\";"
scan 'git commit -m x' "$repo"
expect_secret "clé d'API sk- : bloquée" src/llm.ts sk-
repo=$(make_repo)
stage "$repo" "src/my config.ts" "const maps = '$GOOG';"
scan 'git commit -m x' "$repo"
expect_secret "clé d'API Google dans un chemin avec espace : bloquée" "src/my config.ts" Google
repo=$(make_repo nohead)
stage "$repo" src/aws.ts "$AWS"
scan 'git commit -m init' "$repo"
expect_secret "un premier commit avec un secret : bloqué" src/aws.ts
[[ $HOOK_STDERR == *"git rm --cached"* ]] && pass "la raison dit comment désindexer avant le premier commit" \
  || fail "la raison dit comment désindexer avant le premier commit" "${HOOK_STDERR:0:300}"
[[ $HOOK_STDERR == *"!"* && $HOOK_STDERR == *"faux positif"* ]] && pass "la raison dit que seul l'utilisateur lève un faux positif" \
  || fail "la raison dit que seul l'utilisateur lève un faux positif" "${HOOK_STDERR:0:300}"
[[ $HOOK_STDERR == *plugin-orchestrator* && $HOOK_STDERR == *secret-scan* ]] && pass "la raison nomme le plugin et le hook" \
  || fail "la raison nomme le plugin et le hook" "${HOOK_STDERR:0:300}"

repo=$(make_repo)
stage "$repo" old.txt "$AWS"
git -C "$repo" commit -qm "old secret"
git -C "$repo" rm -q old.txt
scan 'git commit -m "remove the secret"' "$repo"
expect_silent_allow "retirer une ligne qui contient un secret passe"
repo=$(make_repo)
printf '%s\n' "$AWS" >>"$repo/notes.txt"
stage "$repo" src/clean.ts "export {};"
scan 'git commit -m x' "$repo"
expect_silent_allow "un secret non indexé ne fait pas partie d'un commit simple"

echo "# jetons des registres (npm, PyPI) et fichiers d'identifiants"
repo=$(make_repo)
stage "$repo" .npmrc "//registry.npmjs.org/:$NPM_LEGACY"
scan 'git commit -m x' "$repo"
expect_secret "jeton npm legacy (_authToken=uuid) : bloqué" .npmrc npm
repo=$(make_repo)
stage "$repo" ci/publish.sh "NPM_TOKEN=$NPM"
scan 'git commit -m x' "$repo"
expect_secret "jeton npm (npm_…) : bloqué" ci/publish.sh npm
repo=$(make_repo)
stage "$repo" .npmrc '//registry.npmjs.org/:_authToken=${NPM_TOKEN}'
scan 'git commit -m x' "$repo"
expect_silent_allow ".npmrc avec _authToken=\${NPM_TOKEN} (variable) passe"
repo=$(make_repo)
stage "$repo" ci/pypi.txt "password = $PYPI"
scan 'git commit -m x' "$repo"
expect_secret "jeton PyPI (pypi-Ag…) : bloqué" ci/pypi.txt PyPI
repo=$(make_repo)
stage "$repo" .pypirc "[pypi]"
scan 'git commit -m x' "$repo"
expect_secret ".pypirc : bloqué par son nom" .pypirc PyPI
repo=$(make_repo)
stage "$repo" .netrc "machine example.test"
scan 'git commit -m x' "$repo"
expect_secret ".netrc : bloqué par son nom" .netrc netrc

echo "# noms de fichiers secrets"
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
scan 'git commit -m x' "$repo"
expect_secret ".env : bloqué" .env
repo=$(make_repo)
stage "$repo" config/.env.production "DEBUG=0"
scan 'git commit -m x' "$repo"
expect_secret ".env.production : bloqué" config/.env.production
repo=$(make_repo)
mkdir -p "$repo/android/app"
printf '\xfe\xed\xfe\xed\x00\x00\x00\x02' >"$repo/android/app/upload.jks"
git -C "$repo" add android/app/upload.jks
scan 'git commit -m x' "$repo"
expect_secret "keystore .jks binaire : bloqué" android/app/upload.jks keystore
repo=$(make_repo)
stage "$repo" release.keystore "x"
scan 'git commit -m x' "$repo"
expect_secret ".keystore : bloqué" release.keystore
repo=$(make_repo)
stage "$repo" android/key.properties "storePassword=x"
scan 'git commit -m x' "$repo"
expect_secret "key.properties : bloqué" android/key.properties
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
git -C "$repo" commit -qm "tracked by mistake"
git -C "$repo" rm -q --cached .env
scan 'git commit -m "untrack .env"' "$repo"
expect_silent_allow "cesser de suivre .env passe"

echo "# ce que le commit peut inclure au-delà de l'index"
repo=$(make_repo)
printf '%s\n' "$AWS" >>"$repo/notes.txt"
scan 'git commit -a -m x' "$repo"
expect_secret "git commit -a inclut les changements non indexés" notes.txt "pas encore indexé"
scan 'git commit -am x' "$repo"
expect_secret "git commit -am inclut les changements non indexés" notes.txt
scan 'git commit --all -m x' "$repo"
expect_secret "git commit --all inclut les changements non indexés" notes.txt
scan 'git commit -m x notes.txt' "$repo"
expect_secret "git commit <chemin> inclut ce chemin" notes.txt
scan 'git commit -m "msg with notes.txt"' "$repo"
expect_silent_allow "un message n'est pas un chemin"
scan 'git commit -F msg.txt' "$repo"
expect_silent_allow "la valeur de -F n'est pas un chemin"
repo=$(make_repo)
printf '%s\n' "$GHP" >"$repo/new.txt"
scan 'git add new.txt && git commit -m x' "$repo"
expect_secret "git add sur la même ligne inclut les fichiers non suivis" new.txt GitHub
scan 'git commit -m x' "$repo"
expect_silent_allow "un fichier non suivi ne fait pas partie d'un commit simple"
repo=$(make_repo)
printf '%s\n' "$AWS" >"$repo/ignored.txt"
echo "ignored.txt" >"$repo/.gitignore"
stage "$repo" .gitignore "ignored.txt"
scan 'git add -A && git commit -m x' "$repo"
expect_silent_allow "un fichier ignoré ne fait pas partie du commit"
scan 'git commit --amend --no-edit' "$repo"
expect_silent_allow "git commit --amend avec un index propre passe"

echo "# où le commit s'exécute"
repo=$(make_repo)
mkdir "$repo/sub"
inner=$(make_repo)
stage "$inner" src/aws.ts "$AWS"
scan "cd $inner && git commit -m x" "$repo"
expect_secret "cd <dépôt> && git commit analyse ce dépôt" src/aws.ts
scan "git -C $inner commit -m x" "$plain"
expect_secret "git -C <dépôt> commit analyse ce dépôt" src/aws.ts
scan "bash -c 'git commit -m x'" "$inner"
expect_secret "bash -c 'git commit' est analysé" src/aws.ts
scan "sudo -u bob git commit -m x" "$inner"
expect_secret "un wrapper devant git commit est analysé" src/aws.ts
scan "FOO=1 git -c user.name=x commit -m x" "$inner"
expect_secret "une affectation et git -c devant commit sont analysés" src/aws.ts
scan 'eval "git commit -m x"' "$inner"
expect_secret "eval git commit est analysé" src/aws.ts
scan 'echo "$(git commit -m x)"' "$inner"
expect_secret "git commit dans \$(...) est analysé" src/aws.ts
scan "cd sub && git commit -m x" "$repo"
expect_silent_allow "cd dans un sous-dossier propre analyse son dépôt propre"
stage "$inner" sub/deep.txt "x"
scan 'cd sub && git commit -m x' "$inner"
expect_secret "un commit depuis un sous-dossier analyse tout l'index" src/aws.ts
scan 'cd "$PROJECT" && git commit -m x' "$repo"
expect_blocked "une cible de cd irrésoluble bloque le commit"

echo "# un dépôt ou un dossier créé sur la même ligne"
fresh=$(mktemp -d "$work/fresh.XXXXXX")
printf 'API=%s\n' "$AWS" >"$fresh/.env"
echo "export {};" >"$fresh/main.ts"
scan 'git init && git add . && git commit -m "Initial commit"' "$fresh"
expect_blocked "git init && git add . && git commit ne peut pas être vérifié : bloqué"
[[ $HOOK_STDERR == *"commande séparée"* ]] && pass "la raison demande de créer le dépôt d'abord" \
  || fail "la raison demande de créer le dépôt d'abord" "${HOOK_STDERR:0:300}"
scan 'git clone https://example.test/r.git r && cd r && git commit -m x' "$fresh"
expect_blocked "git clone sur la même ligne que le commit : bloqué"
repo=$(make_repo)
stage "$repo" leak.txt "$AWS"
scan 'mkdir -p tools/gen && cd tools/gen && git commit -m x' "$repo"
expect_secret "cd dans un dossier créé sur la ligne analyse le dépôt englobant" leak.txt
scan "(cd $plain && ls) && git commit -m x" "$repo"
expect_secret "un cd dans un sous-shell ne cache pas le dépôt de départ" leak.txt

echo "# indexation que l'index ne montre pas encore"
repo=$(make_repo)
echo ".env.production" >"$repo/.gitignore"
git -C "$repo" add .gitignore && git -C "$repo" commit -qm ignore
printf 'K=%s\n' "$AWS" >"$repo/.env.production"
scan 'git add -f .env.production && git commit -m x' "$repo"
expect_blocked "git add -f sur la même ligne que le commit : bloqué"
[[ $HOOK_STDERR == *"git add -f"* ]] && pass "la raison demande de forcer l'ajout dans une commande séparée" \
  || fail "la raison demande de forcer l'ajout dans une commande séparée" "${HOOK_STDERR:0:300}"
scan 'git add -fA && git commit -m x' "$repo"
expect_blocked "un -f groupé est vu"
scan 'git add --force .env.production' "$repo"
expect_silent_allow "git add -f seul ne commite pas"
printf 'diff --git a/n b/n\n' >"$repo/p.patch"
scan 'git apply --cached p.patch && git commit -m x' "$repo"
expect_blocked "git apply --cached sur la même ligne que le commit : bloqué"

echo "# seulement ce que le commit peut inclure"
repo=$(make_repo)
printf 'API=%s\n' "$AWS" >"$repo/.env"
printf '%s\n' "$GHP" >"$repo/local-secrets.txt"
echo "more" >>"$repo/notes.txt"
echo "export {};" >"$repo/lib.ts"
scan 'git commit -am x' "$repo"
expect_silent_allow "git commit -a n'inclut pas les fichiers non suivis"
scan 'git add lib.ts && git commit -m x' "$repo"
expect_silent_allow "git add <fichier> && git commit ne lit que ce fichier"
scan 'git add lib.ts notes.txt && git commit -m x' "$repo"
expect_silent_allow "plusieurs fichiers nommés sont lus, et eux seuls"
scan 'git add . && git commit -m x' "$repo"
expect_secret "git add . inclut tout fichier non suivi" .env local-secrets.txt "non suivi"
scan 'git add -A && git commit -m x' "$repo"
expect_secret "git add -A inclut tout fichier non suivi" .env
scan 'git add "$FILES" && git commit -m x' "$repo"
expect_secret "un chemin irrésoluble élargit l'analyse" local-secrets.txt
repo=$(make_repo)
mkdir -p "$repo/sub" "$repo/other"
printf '%s\n' "$AWS" >"$repo/other/key.txt"
echo "x" >"$repo/sub/a.txt"
scan 'git add sub/ && git commit -m x' "$repo"
expect_silent_allow "git add <dossier> ne lit que ce dossier"
scan 'cd other && git add . && git commit -m x' "$repo"
expect_secret "git add . depuis un sous-dossier lit ce dossier" other/key.txt
printf '%s\n' "$AWS" >>"$repo/notes.txt"
echo "y" >"$repo/sub/b.txt"
git -C "$repo" add sub/b.txt
echo "z" >>"$repo/sub/b.txt"
scan 'git commit -m x sub/b.txt' "$repo"
expect_silent_allow "git commit <chemin> ne lit que ce chemin"
scan 'git commit -m x notes.txt' "$repo"
expect_secret "git commit <chemin> lit ce chemin" notes.txt
scan 'git commit -i -m x notes.txt' "$repo"
expect_secret "git commit -i <chemin> lit ce chemin" notes.txt
scan 'git commit -o notes.txt -m x' "$repo"
expect_secret "git commit -o <chemin> lit ce chemin" notes.txt
scan 'git commit --pathspec-from-file=list.txt -m x' "$repo"
expect_secret "--pathspec-from-file lit tout changement non indexé" notes.txt
scan 'git stage notes.txt && git commit -m x' "$repo"
expect_secret "git stage compte comme git add" notes.txt

echo "# formes d'indexation moins directes"
repo=$(make_repo)
printf '%s\n' "$AWS" >"$repo/new-config.txt"
scan 'git ls-files --others --exclude-standard | xargs git add && git commit -m x' "$repo"
expect_secret "xargs git add (chemins depuis stdin) lit tout l'arbre" new-config.txt
scan 'git ls-files -z --others | xargs -0 git add -- && git commit -m x' "$repo"
expect_secret "xargs -0 git add -- lit tout l'arbre" new-config.txt
repo=$(make_repo)
mkdir -p "$repo/src"
printf '%s\n' "$AWS" >"$repo/src/a.ts"
echo "x" >"$repo/src/b.ts"
scan 'git add src/{a,b}.ts && git commit -m x' "$repo"
expect_secret "une expansion d'accolades dans un chemin élargit l'analyse" src/a.ts
repo=$(make_repo)
mkdir -p "$repo/sub"
echo "x" >"$repo/sub/a.txt"
printf '%s\n' "$AWS" >"$repo/top-secret.txt"
scan 'cd sub && git add -A && git commit -m x' "$repo"
expect_secret "git add -A depuis un sous-dossier lit tout l'arbre" top-secret.txt
scratch=$(mktemp -d "$work/scratch.XXXXXX")
repo=$(make_repo)
printf 'K=%s\n' "$AWS" >"$repo/.env"
scan "(cd $scratch && ls) && git add .env && git commit -m x" "$repo"
expect_secret "une indexation après un cd en sous-shell est analysée dans le dépôt de départ" .env
scan "cd $repo && (cd $scratch && ls) && git add .env && git commit -m x" "$plain"
expect_secret "une indexation après un cd en sous-shell est analysée dans le dossier du cd précédent" .env
repo=$(make_repo)
scan "printf 'API_KEY=$AWS' > config.txt && git add config.txt && git commit -m x" "$repo"
expect_secret "un secret écrit sur la ligne du commit elle-même : bloqué" "ligne de commande"
repo=$(make_repo)
head -c 4096 /dev/urandom >"$repo/blob.bin"
printf '\0\0\0' >>"$repo/blob.bin"
git -C "$repo" add blob.bin
scan 'git commit -m "add a binary"' "$repo"
expect_silent_allow "un fichier binaire passe en silence, sans avertissement d'octet nul"

echo "# options d'emplacement de git"
inner2=$(make_repo)
stage "$inner2" src/aws.ts "$AWS"
scan "git --git-dir=$inner2/.git --work-tree=$inner2 commit -m x" "$plain"
expect_secret "--git-dir et --work-tree désignent le dépôt" src/aws.ts
scan "pushd $inner2 && git commit -m x" "$plain"
expect_secret "pushd change de dossier comme cd" src/aws.ts

echo "# configuration cliente Firebase (liste blanche)"
repo=$(make_repo)
stage "$repo" lib/firebase_options.dart "apiKey: '$GOOG',"
stage "$repo" android/app/google-services.json "\"current_key\": \"$GOOG\""
stage "$repo" ios/Runner/GoogleService-Info.plist "<string>$GOOG</string>"
scan 'git commit -m "chore: configure Firebase"' "$repo"
expect_silent_allow "les clés clientes Firebase dans leurs fichiers de configuration passent"
stage "$repo" lib/firebase_options.dart "apiKey: '$GOOG', aws: '$AWS'"
scan 'git commit -m x' "$repo"
expect_secret "un autre secret dans un fichier Firebase reste bloqué" lib/firebase_options.dart AWS
repo=$(make_repo)
stage "$repo" src/maps.ts "const maps = '$GOOG';"
scan 'git commit -m x' "$repo"
expect_secret "une clé Google ailleurs : bloquée" src/maps.ts Google
[[ $HOOK_STDERR == *"demandé à l'utilisateur"* ]] && pass "la raison dit de demander à l'utilisateur avant de déplacer quoi que ce soit" \
  || fail "la raison dit de demander à l'utilisateur avant de déplacer quoi que ce soit" "${HOOK_STDERR:0:400}"

echo "# fichiers de signature Apple et diffs cachés"
repo=$(make_repo)
mkdir -p "$repo/ios"
printf '\x30\x82\x0a\x00' >"$repo/ios/dist.p12"
git -C "$repo" add ios/dist.p12
scan 'git commit -m x' "$repo"
expect_secret "certificat .p12 : bloqué" ios/dist.p12
repo=$(make_repo)
stage "$repo" win/sign.pfx "x"
scan 'git commit -m x' "$repo"
expect_secret "certificat .pfx : bloqué" win/sign.pfx
repo=$(make_repo)
stage "$repo" .gitattributes "*.json -diff"
git -C "$repo" commit -qm attrs
stage "$repo" config/keys.json "{\"aws\": \"$AWS\"}"
scan 'git commit -m x' "$repo"
expect_secret "un attribut -diff ne cache pas le contenu" config/keys.json

echo "# fail-closed"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": "git commit -m x"' PATH="$base_path"
expect_blocked "une entrée malformée qui mentionne commit : bloquée"
run_hook "$HOOK" '{"tool_name": "Bash", "tool_input": {"command": 42}, "x": "commit"}' PATH="$base_path"
expect_blocked "un command non textuel : bloqué"
nojq=$(restricted_path git)
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$inner")" PATH="$nojq"
expect_blocked "jq absent bloque un commit"
[[ $HOOK_STDERR == *jq* ]] && pass "jq absent : nommé dans la raison" || fail "jq absent : nommé dans la raison" "$HOOK_STDERR"
rm -r "$nojq"
for tool in grep awk; do
  partial=$(mktemp -d "$work/no$tool.XXXXXX")
  cp -P "$base_path"/* "$partial/"
  rm "$partial/$tool"
  run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$inner")" PATH="$partial"
  expect_blocked "$tool absent bloque un commit"
  [[ $HOOK_STDERR == *"$tool est requis"* ]] && pass "$tool absent : nommé dans la raison" || fail "$tool absent : nommé dans la raison" "$HOOK_STDERR"
done
nolib=$(mktemp -d "$work/nolib.XXXXXX")
cp "$HOOK" "$nolib/"
run_hook "$nolib/secret-scan.sh" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$base_path"
expect_blocked "bibliothèque du lexer absente : un commit est bloqué"

echo "# gitleaks, quand il est installé"
fake=$(mktemp -d "$work/fake.XXXXXX")
cp -P "$base_path"/* "$fake/"
cat >"$fake/gitleaks" <<EOF
#!$BASH
printf '%s\n' "\$*" >>"$work/gitleaks.log"
case \${FAKE_GITLEAKS:-clean} in
  clean) echo '[]'; exit 0 ;;
  leak) echo '[{"RuleID": "generic-api-key", "File": "src/conf.ts", "StartLine": 3, "Secret": "REDACTED"}]'; exit 99 ;;
  error) echo "gitleaks: broken config" >&2; exit 1 ;;
  firebase) echo '[{"RuleID": "gcp-api-key", "File": "lib/firebase_options.dart", "StartLine": 9, "Secret": "REDACTED"}]'; exit 99 ;;
  maps) echo '[{"RuleID": "gcp-api-key", "File": "src/maps.ts", "StartLine": 2, "Secret": "REDACTED"}]'; exit 99 ;;
esac
EOF
chmod +x "$fake/gitleaks"
gitleaks_calls() { if [[ -f $work/gitleaks.log ]]; then cat "$work/gitleaks.log"; fi; }
repo=$(make_repo)
stage "$repo" src/notes.ts "export const notes = 1;"
rm -f "$work/gitleaks.log"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake"
expect_silent_allow "un passage gitleaks propre passe"
calls=$(gitleaks_calls)
[[ $calls == *"git"*"--pre-commit"*"--staged"* && $calls == *"--redact"* ]] \
  && pass "gitleaks git --pre-commit --staged --redact est appelé" || fail "gitleaks git --pre-commit --staged --redact est appelé" "appels : $calls"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=leak
expect_secret "une trouvaille gitleaks bloque le commit" src/conf.ts:3 generic-api-key
[[ $HOOK_STDERR != *REDACTED* ]] && pass "le rapport gitleaks est résumé, pas copié" || fail "le rapport gitleaks est résumé, pas copié" "$HOOK_STDERR"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=error
expect_blocked "une erreur gitleaks bloque le commit (fail-closed)"
[[ $HOOK_STDERR == *gitleaks* && $HOOK_STDERR == *8.19* ]] && pass "l'erreur gitleaks est nommée, avec la version minimale" \
  || fail "l'erreur gitleaks est nommée, avec la version minimale" "$HOOK_STDERR"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=firebase
expect_silent_allow "une trouvaille gitleaks gcp-api-key dans firebase_options.dart passe"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=maps
expect_secret "une trouvaille gitleaks gcp-api-key ailleurs bloque" src/maps.ts:2
rm -f "$work/gitleaks.log"
run_hook "$HOOK" "$(bash_input 'git commit -a -m x' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 2 && $(grep -c -- '--staged' <<<"$calls") == 1 ]] \
  && pass "git commit -a fait aussi lire les changements non indexés par gitleaks" || fail "git commit -a fait aussi lire les changements non indexés par gitleaks" "appels : $calls"
rm -f "$work/gitleaks.log"
run_hook "$HOOK" "$(bash_input 'git commit -m x src/notes.ts' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 1 ]] \
  && pass "un commit limité à un chemin ne fait pas lire tout changement non indexé par gitleaks" \
  || fail "un commit limité à un chemin ne fait pas lire tout changement non indexé par gitleaks" "appels : $calls"
rm -f "$work/gitleaks.log"
run_hook "$HOOK" "$(bash_input 'git add -A && git commit -m x' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 2 ]] \
  && pass "git add -A sur la ligne fait lire les changements non indexés par gitleaks" \
  || fail "git add -A sur la ligne fait lire les changements non indexés par gitleaks" "appels : $calls"
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
run_hook "$HOOK" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake"
expect_secret "les noms de fichiers sont vérifiés même quand gitleaks ne trouve rien" .env
repo=$(make_repo)
mkdir -p "$repo/src"
echo "const a = 1;" >"$repo/src/conf.ts"
echo "const b = 1;" >"$repo/src/other.ts"
git -C "$repo" add src && git -C "$repo" commit -qm conf
echo "const token = 2;" >>"$repo/src/conf.ts"
echo "const c = 3;" >>"$repo/src/other.ts"
cat >"$fake/gitleaks" <<EOF
#!$BASH
printf '%s\n' "\$*" >>"$work/gitleaks.log"
case "\$*" in
  *--staged*) echo '[]'; exit 0 ;;
  *) echo '[{"RuleID": "slack-bot-token", "File": "src/conf.ts", "StartLine": 2, "Secret": "REDACTED"}, {"RuleID": "generic-api-key", "File": "src/unrelated.ts", "StartLine": 1, "Secret": "REDACTED"}]'; exit 99 ;;
esac
EOF
run_hook "$HOOK" "$(bash_input 'git add src/conf.ts && git commit -m x' Bash "$repo")" PATH="$fake"
expect_secret "gitleaks lit un fichier suivi indexé sur la même ligne" src/conf.ts:2 slack-bot-token
[[ $HOOK_STDERR != *unrelated.ts* ]] && pass "les trouvailles gitleaks hors des chemins indexés sont ignorées" \
  || fail "les trouvailles gitleaks hors des chemins indexés sont ignorées" "$HOOK_STDERR"
run_hook "$HOOK" "$(bash_input 'git commit -m x src/conf.ts' Bash "$repo")" PATH="$fake"
expect_secret "gitleaks lit le chemin donné à git commit" src/conf.ts:2
run_hook "$HOOK" "$(bash_input 'git add src/other.ts && git commit -m x' Bash "$repo")" PATH="$fake"
expect_silent_allow "une trouvaille gitleaks dans un fichier que le commit ne prend pas passe"

echo "# vitesse"
repo=$(make_repo)
for i in $(seq 1 3000); do printf 'line %s\n' "$i" >"$repo/f$i.txt"; done
printf '%s\n' "$AWS" >"$repo/f1500.txt"
git -C "$repo" add .
start=$(date +%s%N)
scan 'git commit -m "three thousand files, one key"' "$repo"
elapsed=$((($(date +%s%N) - start) / 1000000))
expect_secret "une clé parmi 3000 fichiers indexés est trouvée" f1500.txt
((elapsed < 5000)) && pass "une clé parmi 3000 fichiers est attribuée en $elapsed ms (< 5000)" \
  || fail "une clé parmi 3000 fichiers est attribuée en moins de 5 s" "$elapsed ms"
repo=$(make_repo)
for i in $(seq 1 800); do printf 'line %s\n' "$i" >"$repo/file$i.txt"; done
git -C "$repo" add .
start=$(date +%s%N)
scan 'git commit -m "eight hundred files"' "$repo"
elapsed=$((($(date +%s%N) - start) / 1000000))
expect_silent_allow "un commit de 800 fichiers passe"
((elapsed < 3000)) && pass "un commit de 800 fichiers est analysé en $elapsed ms (< 3000)" || fail "un commit de 800 fichiers est analysé en moins de 3 s" "$elapsed ms"

finish
