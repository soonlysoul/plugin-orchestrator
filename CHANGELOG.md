# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [0.1.0] — en cours

### Ajouté

- Hook `secret-scan` (US-13) : PreToolUse sur Bash, PowerShell et Monitor, fail-closed, inerte sans le mot `commit` — avant un `git commit`, refuse les noms de fichiers secrets et les motifs de secret dans les lignes que le commit peut ajouter (index, `-a`, chemins, `git add` sur la même ligne), gitleaks s'il est installé, sans jamais afficher un secret. Repris de plugin-flutter ; raisons en français ; jetons npm et PyPI, fichiers `.pypirc` et `.netrc` ajoutés.
- Hook `guard-destructive` (US-13) : PreToolUse sur Bash, PowerShell et Monitor, fail-closed, toujours actif — git qui jette du travail ou réécrit le distant, suppression récursive forcée hors de `build/`, `gh` qui supprime, fusionne ou publie, publication vers pub.dev, npm ou PyPI sans `--dry-run`. Repris de plugin-flutter avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` ; raisons en français ; registres npm et PyPI ajoutés.
- Charpente posée par plugin-plugin le 2026-10-23 : manifeste, marketplace locale, licence, documents et suite de tests `tests/run-all.sh`.
