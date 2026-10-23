# PROGRESS — plugin-orchestrator

Dernière mise à jour : 2026-10-23
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Les six hooks de la v0.1 sont ajoutés le 2026-10-23 : `guard-destructive`, `secret-scan`, `protect-sensitive` (US-13), `checkpoint-reminder` (US-6, US-13), `agent-scope-guard` (US-2, US-8, US-10) et `doc-status-guard` (US-13), avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` repris de plugin-flutter et la bibliothèque de statut des documents `scripts/lib/doc-status.sh` reprise de plugin-plugin. Prochaine étape : les composants restants de la v0.1 — `scripts/orch.sh` (dont `approve`, qui consigne l'empreinte dans `.forge/approvals.log`), gabarits, agent `product-architect`, skills — par `/plugin-plugin:add`.

## Composants

| Composant | Type | US | Ajouté | Test |
| --- | --- | --- | --- | --- |
| `guard-destructive` | hook | US-13 | 2026-10-23 | `tests/hooks/test_guard_destructive.sh` |
| `hooks/scripts/lib/shell-lexer.sh` | script | US-13 | 2026-10-23 | par les tests de guard-destructive et secret-scan (cas « structure de commande » et « lexer partagé absent ») |
| `secret-scan` | hook | US-13 | 2026-10-23 | `tests/hooks/test_secret_scan.sh` |
| `protect-sensitive` | hook | US-13 | 2026-10-23 | `tests/hooks/test_protect_sensitive.sh` |
| `checkpoint-reminder` | hook | US-6, US-13 | 2026-10-23 | `tests/hooks/test_checkpoint_reminder.sh` |
| `agent-scope-guard` | hook | US-2, US-8, US-10 | 2026-10-23 | `tests/hooks/test_agent_scope_guard.sh` |
| `doc-status-guard` | hook | US-13 | 2026-10-23 | `tests/hooks/test_doc_status_guard.sh` |
| `scripts/lib/doc-status.sh` | script | US-13 | 2026-10-23 | par le test de doc-status-guard (mise en place des approbations, cas « bibliothèque absente ») et `tests/static/test_paths.sh` (bash -n, shellcheck) |

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

### 2026-10-23 — hook `protect-sensitive` (US-13)

Repris tel quel de plugin-flutter (origine R) : dans un projet qui a `.forge/` (le plus proche parent du fichier, quelle que soit la racine de session), décision JSON « ask » avant d'écrire du matériel de signature (`key.properties`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`), des entitlements Apple, du code de CI (`.github/workflows/*`, `.github/actions/*`) ou `.forge/config.yaml`, protégé partout. Silencieux hors de ce contexte, et avant même d'appeler jq quand l'entrée ne nomme aucun fichier de ce genre. Raison en français, nommant le plugin ; elle dit de ne pas contourner un refus.

ROUGE — `bash tests/hooks/test_protect_sensitive.sh` (squelette posé par `pp.sh add-hook`) → exit 1 :

```
test_protect_sensitive : 14 réussis, 20 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible et jq absent, sur des entrées qui nomment `key.properties`) ; les 20 échecs sont les cas de la règle (décisions « ask », projet `.forge/` trouvé depuis le fichier, jq absent hors contexte).

VERT — `bash tests/hooks/test_protect_sensitive.sh` → exit 0 :

```
test_protect_sensitive : 34 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 10 suites réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000), shellcheck propre du premier coup.

### 2026-10-23 — hook `checkpoint-reminder` (US-6, US-13)

Repris tel quel de plugin-flutter (origine R) : à l'arrêt d'un tour, quand `.forge/checkpoint.md` du projet (`CLAUDE_PROJECT_DIR`, sinon le cwd) est plus vieux que le dernier commit ou qu'un changement non commité du projet, un rappel unique par `additionalContext` demande de le mettre à jour puis de s'arrêter ; un dernier commit qui porte le checkpoint, inchangé depuis, ne compte pas ; un projet en sous-dossier du dépôt est traité. Inerte sans checkpoint, hors d'un dépôt git, ou si `stop_hook_active`. Fail-open : jq ou git absents, entrée illisible, exit 0 silencieux. Message en français nommant le plugin.

ROUGE — `bash tests/hooks/test_checkpoint_reminder.sh` (squelette posé par `pp.sh add-hook`) → exit 1 :

```
test_checkpoint_reminder : 19 réussis, 9 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible et jq absent, exit 0) ; les 9 échecs sont les cas de rappel ; les cas silencieux passent déjà, le squelette ne faisant rien.

VERT — `bash tests/hooks/test_checkpoint_reminder.sh` → exit 0 :

```
test_checkpoint_reminder : 28 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 11 suites réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000), shellcheck propre du premier coup.

### 2026-10-23 — hook `agent-scope-guard` (US-2, US-8, US-10)

Généralisé depuis plugin-flutter (origine G) : pour les agents de ce plugin seulement (`agent_type` à préfixe `plugin-orchestrator:`), les dossiers d'écriture et la liste blanche de commandes simples de chaque agent, sous la racine du projet (`CLAUDE_PROJECT_DIR`, sinon le cwd de l'entrée) : product-architect écrit sous `docs/product/`, aucun shell ; project-architect écrit sous `docs/` (les documents d'une partie, `<path>/docs/`, restent au plugin de langage), git en lecture ; integration-reviewer n'écrit rien, git en lecture. « Git en lecture » = `status`, `log`, `diff`, `show`, `ls-files`, `rev-parse`, `branch --show-current`, `--no-pager` accepté ; une commande composée, une redirection, une substitution, une affectation en tête ou une option `--output`/`--write` sont refusées. Inerte pour la session principale, les agents intégrés et les agents d'un autre plugin, même à nom égal (`plugin-flutter:product-architect`) : chaque plugin garde son propre garde. Fail-closed pour les agents du plugin : jq absent, entrée illisible, lexer absent, agent inconnu du plugin, racine inconnue. Raisons en français nommant le plugin, l'agent et son périmètre ; elles disent de signaler sous OPEN_QUESTIONS plutôt que de contourner. Un agent doté de commandes mais sans branche de liste blanche est prouvé refusé sur une copie (le `case` de bash rend 0 sans branche).

ROUGE — `bash tests/hooks/test_agent_scope_guard.sh` (squelette posé par `pp.sh add-hook`) → exit 1 :

```
test_agent_scope_guard : 39 réussis, 73 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible et jq absent, sur des entrées qui portent le préfixe du plugin) ; les 73 échecs sont les cas de la règle : 63 cas « bloqué » (le squelette laisse tout passer), 7 vérifications de la raison, l'injection de l'agent orphelin (le squelette n'a pas de `case`) et les deux cas « inerte ailleurs » (JSON malformé et jq absent sans le préfixe), le squelette vérifiant jq et l'entrée avant le contexte.

VERT — `bash tests/hooks/test_agent_scope_guard.sh` → exit 0 :

```
test_agent_scope_guard : 112 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 12 réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000), shellcheck propre du premier coup.

### 2026-10-23 — hook `doc-status-guard` (US-13)

Repris de plugin-plugin (origine R) et adapté au socle : un document projet — un `.md` sous un `docs/` d'un projet `.forge/` (le plus proche parent du fichier, quelle que soit la racine de session), à la racine ou dans une partie — dont l'en-tête fixe du format plugin-flutter dit `| Status | APPROVED |`, mais dont l'empreinte du corps (sha256 sans les lignes Status et Approved) ne correspond plus à celle consignée à son approbation dans `.forge/approvals.log` (date, document relatif à la racine du projet, empreinte, citation ; séparés par des tabulations), repasse en REVIEW : ligne Status réécrite, ligne Approved gardant la date de l'approbation perdue, Claude prévenu par `additionalContext`. Un APPROVED sans trace au journal repasse en REVIEW à sa première modification : l'approbation passe par `scripts/orch.sh approve` (à venir), jamais par un hook. Silencieux hors de ce contexte (pas de `.forge/`, hors `docs/`, pas de ligne de statut, DRAFT ou REVIEW, autre outil, fichier absent) ; fail-open (jq, sha256sum ou la bibliothèque absents, entrée illisible : exit 0, document intact). Les fonctions de statut, d'empreinte et de journal sont dans `scripts/lib/doc-status.sh`, bibliothèque partagée avec le futur `orch.sh` pour que l'empreinte n'ait qu'une définition. Message en français nommant le plugin et le document.

ROUGE — `bash tests/hooks/test_doc_status_guard.sh` (squelette posé par `pp.sh add-hook`, bibliothèque déjà posée) → exit 1 :

```
test_doc_status_guard : 46 réussis, 16 échoués, 0 sautés
```

Le contrat du squelette passe (entrée illisible et jq absent, exit 0) ; les 16 échecs sont les cas de la règle (retour en REVIEW, `additionalContext`, date de la ligne Approved) ; les cas silencieux passent déjà, le squelette ne faisant rien.

VERT — `bash tests/hooks/test_doc_status_guard.sh` → exit 0 :

```
test_doc_status_guard : 62 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 13 réussies, 0 échouée, 2 sautées (`skills/` et `agents/` absents), `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token (seuil 1 000), shellcheck propre du premier coup (hook et bibliothèque).

### 2026-10-23 — refactor `agent-scope-guard` : portées lues dans `hooks/agent-scope.json`

`pp.sh add-agent` refuse de déclarer la portée d'un agent qui écrit tant que le garde du plugin ne lit pas `hooks/agent-scope.json` — le modèle plugin-plugin : une entrée `{write, bash}` par agent, écrite à l'ajout de l'agent et vérifiée par son test statique. Le garde passe donc de portées codées en dur à ce fichier, sans changer ses règles : lexer partagé, une commande simple à la fois, `--output`/`--write`, `.`/`..`, racine du projet, fail-closed, raisons en français. Les entrées de commande sont comparées mot à mot comme préfixe (`git branch --show-current` ne couvre pas `git branch x` ; `git --no-pager` compte comme `git`) ; un agent sans entrée, un fichier absent ou illisible, une portée malformée bloquent. Les portées de project-architect et integration-reviewer (v0.2) sortent du hook : `add-agent` les déclarera à leur ajout. Le test prouve les règles sur une copie du hook avec un JSON de fixture, puis tient chaque agent réellement déclaré à sa propre entrée (section sautée tant que le fichier n'existe pas). Décision de Soon le 2026-10-23, entre convertir le garde et écrire les agents hors de l'outil.

`bash tests/hooks/test_agent_scope_guard.sh` → exit 0 :

```
test_agent_scope_guard : 99 réussis, 0 échoués, 1 sautés
```

Suite — `bash tests/run-all.sh` → exit 1 sous la charge de sessions parallèles (load average 9 à 29 sur 8 cœurs) : 12 réussies dont `test_agent_scope_guard` et `test_paths` (shellcheck), `test_secret_scan` 128/128 au premier niveau ; le seul échec est `test_run_all`, dont la copie « claude absent » relance la suite et y voit le test de vitesse de secret-scan (3 000 fichiers en moins de 5 s, hook non modifié) dépasser le seuil (5,4 à 5,6 s mesurées sous charge) ; `test_run_all` seul, lancé entre-temps à charge 9,6 → exit 0, 31 réussis. `claude plugin validate --strict` ok sur `.` et `.claude-plugin/plugin.json`, coût permanent 0 token.
