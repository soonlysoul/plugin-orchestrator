# PROGRESS — plugin-orchestrator

Dernière mise à jour : 2026-10-23
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Deux hooks ajoutés le 2026-10-23 : `guard-destructive` et `secret-scan` (US-13), avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` repris de plugin-flutter. Prochaine étape : les autres hooks de la v0.1 (`protect-sensitive`, `checkpoint-reminder`, `agent-scope-guard`, `doc-status-guard`), par `/plugin-plugin:add`.

## Composants

| Composant | Type | US | Ajouté | Test |
| --- | --- | --- | --- | --- |
| `guard-destructive` | hook | US-13 | 2026-10-23 | `tests/hooks/test_guard_destructive.sh` |
| `hooks/scripts/lib/shell-lexer.sh` | script | US-13 | 2026-10-23 | par les tests de guard-destructive et secret-scan (cas « structure de commande » et « lexer partagé absent ») |
| `secret-scan` | hook | US-13 | 2026-10-23 | `tests/hooks/test_secret_scan.sh` |

## Journal

### 2026-10-23 — hook `guard-destructive` (US-13)

Repris de plugin-flutter : lexer partagé copié tel quel (en-tête et directive shellcheck seuls changés), règles git, rm, gh, pub.dev et structure de commande (wrappers, sous-shells, heredocs, `eval`, `find -exec`, `xargs`) ; raisons en français, nommant le plugin et le hook. Étendu aux registres des écosystèmes connus : npm, pnpm, yarn, bun (`publish`, `unpublish`), twine (`upload`), uv, poetry, hatch, flit (`publish`), sauf `--dry-run`. Toujours actif : il ne lit pas `.forge/`.

ROUGE — `bash tests/hooks/test_guard_destructive.sh` (squelette posé par `pp.sh add-hook`) → exit 1 :

```
test_guard_destructive : 109 réussis, 155 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible, jq absent) ; les 155 échecs sont les cas de la règle, dont 145 cas « bloqué » (le squelette laisse tout passer) ; aucun cas « passe » n'échoue.

VERT — `bash tests/hooks/test_guard_destructive.sh` → exit 0 :

```
test_guard_destructive : 264 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 8 suites réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000). Un premier passage avait échoué sur `shellcheck -S warning` (variable `sub` tableau dans `check_find`, chaîne dans `check_git`) : renommée `subcommand`, puis vert.

### 2026-10-23 — hook `secret-scan` (US-13)

Repris de plugin-flutter : avant un `git commit`, noms de fichiers secrets et motifs de secret dans les lignes ajoutées de ce que le commit peut inclure (index, `-a`, chemins, `git add` sur la même ligne, dépôt visé par `cd`, `-C`, `--git-dir`), gitleaks s'il est installé, liste blanche Firebase ; jamais de secret affiché ; raisons en français nommant le plugin et le hook. Inerte sur toute entrée sans le mot `commit`, avant même d'appeler jq. Étendu aux registres des écosystèmes connus : jeton npm (`npm_…`, `_authToken=` legacy), jeton PyPI (`pypi-Ag…`), fichiers `.pypirc` et `.netrc` refusés par leur nom.

ROUGE — `bash tests/hooks/test_secret_scan.sh` (squelette posé par `pp.sh add-hook`) → exit 1 :

```
test_secret_scan : 42 réussis, 86 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible et jq absent, sur des entrées qui mentionnent `commit`) ; les 86 échecs sont les cas de la règle, dont « une commande sans commit passe, même sans jq » (le squelette vérifie jq avant le contexte) et 34 cas « bloqué ».

VERT — `bash tests/hooks/test_secret_scan.sh` → exit 0 :

```
test_secret_scan : 128 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 9 suites réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000). Un premier passage avait échoué sur `shellcheck -S warning` (directive SC2088 placée dans une branche de `case`) : remontée devant le `case`, puis vert.
