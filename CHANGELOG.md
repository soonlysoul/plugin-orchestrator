# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [0.1.0] — en cours

### Ajouté

- Hook `agent-scope-guard` (US-2, US-8, US-10) : PreToolUse sur Edit, Write, NotebookEdit, Bash, PowerShell et Monitor, fail-closed, inerte hors des agents de ce plugin (`agent_type` à préfixe `plugin-orchestrator:` ; les agents d'un autre plugin sont ignorés, même à nom égal) — dossiers d'écriture et liste blanche de commandes simples de chaque agent : product-architect `docs/product/` sans shell, project-architect `docs/` et git en lecture, integration-reviewer aucun fichier et git en lecture. Généralisé depuis plugin-flutter ; raisons en français.
- Hook `checkpoint-reminder` (US-6, US-13) : Stop, fail-open, inerte sans `.forge/checkpoint.md` ou si `stop_hook_active` — quand le checkpoint est plus vieux que le dernier commit ou qu'un changement non commité du projet, rappel unique de le mettre à jour puis de s'arrêter ; un dernier commit qui porte le checkpoint, inchangé depuis, ne compte pas. Repris tel quel de plugin-flutter ; message en français.
- Hook `protect-sensitive` (US-13) : PreToolUse sur Edit, Write et NotebookEdit, fail-closed, inerte hors d'un projet `.forge/` — demande confirmation avant d'écrire du matériel de signature (`key.properties`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`), des entitlements Apple, du code de CI (`.github/workflows/*`, `.github/actions/*`) ou `.forge/config.yaml`, protégé partout. Repris tel quel de plugin-flutter ; raison en français.
- Hook `secret-scan` (US-13) : PreToolUse sur Bash, PowerShell et Monitor, fail-closed, inerte sans le mot `commit` — avant un `git commit`, refuse les noms de fichiers secrets et les motifs de secret dans les lignes que le commit peut ajouter (index, `-a`, chemins, `git add` sur la même ligne), gitleaks s'il est installé, sans jamais afficher un secret. Repris de plugin-flutter ; raisons en français ; jetons npm et PyPI, fichiers `.pypirc` et `.netrc` ajoutés.
- Hook `guard-destructive` (US-13) : PreToolUse sur Bash, PowerShell et Monitor, fail-closed, toujours actif — git qui jette du travail ou réécrit le distant, suppression récursive forcée hors de `build/`, `gh` qui supprime, fusionne ou publie, publication vers pub.dev, npm ou PyPI sans `--dry-run`. Repris de plugin-flutter avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` ; raisons en français ; registres npm et PyPI ajoutés.
- Charpente posée par plugin-plugin le 2026-10-23 : manifeste, marketplace locale, licence, documents et suite de tests `tests/run-all.sh`.
