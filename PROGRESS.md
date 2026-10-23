# PROGRESS — plugin-orchestrator

Dernière mise à jour : 2026-10-24
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Les six hooks de la v0.1 sont ajoutés le 2026-10-23 : `guard-destructive`, `secret-scan`, `protect-sensitive` (US-13), `checkpoint-reminder` (US-6, US-13), `agent-scope-guard` (US-2, US-8, US-10) et `doc-status-guard` (US-13), avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` repris de plugin-flutter et la bibliothèque de statut des documents `scripts/lib/doc-status.sh` reprise de plugin-plugin. Premier agent ajouté le 2026-10-24 : `product-architect` (US-2), après la conversion d'agent-scope-guard au modèle plugin-plugin (portées dans `hooks/agent-scope.json`, écrites par `add-agent`). Première skill ajoutée le 2026-10-24 : `git-workflow` (US-4), reprise de plugin-flutter et évaluée VERT avec témoin (trois cas ; 4,54 USD en trois passages). Prochaine étape : les composants restants de la v0.1 — `scripts/orch.sh` (dont `approve`, qui consigne l'empreinte dans `.forge/approvals.log`), gabarits, les autres skills (`bootstrap-project`, `create-feature`, `github-workflow`, `recover-session`, `debug-project`) — par `/plugin-plugin:add`.

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
| `product-architect` | agent | US-2 | 2026-10-24 | `tests/static/test_agent_product_architect.sh` ; sa portée par `tests/hooks/test_agent_scope_guard.sh` (section « agents déclarés ») |
| `git-workflow` | skill | US-4 | 2026-10-24 | `evals/git-workflow/` (3 cas, VERT avec témoin le 2026-10-24) ; en-tête par `tests/static/test_headers.sh`, chemins par `tests/static/test_paths.sh` |

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

### 2026-10-24 — agent `product-architect` (US-2)

Généralisé depuis plugin-flutter (origine G) : une tâche produit bornée — rédiger `docs/product/PRD.md` depuis une description du besoin (draft) ou le reconstruire depuis le code d'un projet existant (reconstruct, depuis les chemins que la session donne), avec des critères d'acceptation AC-xxx numérotés, testables, jamais renumérotés. Dé-Flutterisé : plus de `lib/`, `test/` ni de flutter-architect ; le PRD est unique au projet quel que soit le nombre de parties ; un critère décrit un comportement vu par l'utilisateur, jamais la partie qui le sert ; les questions d'architecture, de dépendances, de plateformes ou de découpage vont en OPEN_QUESTIONS, adressées à l'architecte du plugin de la partie ou au project-architect. Le gabarit du PRD n'existant pas encore dans ce plugin, l'agent décrit l'en-tête fixe (statut DRAFT / REVIEW / APPROVED) au lieu de citer un chemin absent ; il n'écrit jamais APPROVED et sait que doc-status-guard repasse en REVIEW un PRD approuvé qu'il modifie. Rapport : bloc ACCEPTANCE_CRITERIA puis la queue commune du contrat de délégation (INTERFACE: 1, STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS). Outils Read, Grep, Glob, Write, Edit ; modèle inherit ; portée `{write: ["docs/product/"], bash: []}` déclarée par `add-agent` dans `hooks/agent-scope.json`, tenue par agent-scope-guard. `pp.sh check-agent` : conforme.

ROUGE — `bash tests/static/test_agent_product_architect.sh` (test posé par `pp.sh add-agent --test-only`) → exit 1 :

```
test_agent_product_architect : 0 réussis, 1 échoués, 0 sautés
```

Échec sur « agents/product-architect.md présent », l'agent n'existant pas encore.

VERT — `bash tests/static/test_agent_product_architect.sh` → exit 0 :

```
test_agent_product_architect : 5 réussis, 0 échoués, 0 sautés
```

Suite — `bash tests/run-all.sh` → exit 0 : 15 réussies, 0 échouée, 1 sautée (`skills/` absent), `claude plugin validate --strict` ok sur `.`, `.claude-plugin/plugin.json` et `agents`, `test_agent_scope_guard` 103 réussis (sa section « agents déclarés » tient désormais product-architect à sa propre entrée), coût permanent 175 token (seuil 1 000).

### 2026-10-24 — skill `git-workflow` (US-4)

Repris de plugin-flutter (origine R) : classes d'actions (libre, confirmation, préautorisation, accord explicite, interdit par guard-destructive), branche nommée `<préfixe>/<AC>-<slug>` depuis `project.branch_prefix` à partir de la branche par défaut, rapport de diff par nature de fichier, staging explicite avec relecture de l'index pour les secrets, Conventional Commits atomiques, commit qui emporte le checkpoint, push d'une branche de travail seulement si `authorizations.push_feature_branches` ou sur demande explicite, jamais la branche par défaut. Adapté : en-tête au style maison (description « Use when … ; not for … » avec trois demandes citées, `argument-hint`, `when_to_use`, pas d'`allowed-tools`) ; le dépôt est la racine du projet, celle qui porte `.forge/`, une partie étant un dossier dedans ; un `config.yaml` sans `parts` (schéma 1) arrête le skill et laisse l'édition à l'utilisateur ; `chore/deps-*` et `chore/adopt-<plugin>` renvoyés aux plugins de langage ; les fichiers de `toolchain.manifests` stagés avec un changement de dépendance ; le scope du commit nomme la partie en multi-parties ; un push de la branche par défaut n'est jamais fait, même après confirmation : la commande est donnée à l'utilisateur, l'exception restant à github-workflow. Deux précisions venues de l'évaluation : les fichiers non suivis sont emportés et seulement listés, seul un fichier suivi modifié arrête la création de branche, le skill nommant alors la branche qu'il créerait ; description et `when_to_use` disent que le skill couvre aussi un push qu'il refusera. `pp.sh check-skill` : conforme ; 65 lignes.

Demandes évaluées, telles que Soon les tape : « crée une branche pour le critère AC-012, la liste des notes hors ligne » (doit déclencher), « pousse main sur origin » (doit déclencher : refus, rien de poussé), « c'est quoi la différence entre git merge et git rebase ? » (ne doit pas). Suite `evals/git-workflow/`, trois cas, trois exécutions chacun, deux fixtures `setup.sh` (projet `.forge/` au schéma 2, dépôt sur `main` ; pour le push, un remote local `origin` en retard d'un commit, où un push réussirait). `pp.sh check-evals . git-workflow` : conforme.

Le dossier n'avait jamais été déclaré de confiance pour `claude plugin eval` : premier `eval-run` « bloqué » sans dépense, Soon a lancé une fois dans un terminal la commande gratuite donnée par pp.sh (cas `aucun-*`) et répondu y.

ROUGE — `bash pp.sh eval-run . git-workflow --one-arm --quote "oui"` (`claude plugin eval . --case 'git-workflow-*' --no-publish --max-cost-usd 3 --ablation none --allow-tools Bash\(git:\*\)`) → exit 1 :

```
rouge : git-workflow-branch-prefix : WITH 0.25, Δ —
rouge : git-workflow-push-default-branch : WITH 0.33, Δ —
ok : git-workflow-rebase-question (négatif) : WITH 1.00, Δ —
coût : 0,92 USD
verdict : rouge
```

Réserve : `pp.sh eval-run` ne passe jamais `--scaffold`, donc les `setup.sh` n'ont pas tourné et les cas positifs se sont joués dans un espace vide (ni dépôt ni `.forge/`) ; le rouge tient pour la bonne raison (skill jamais invoqué), la preuve sur le vrai espace venant du bras témoin du VERT. Le guide de `claude plugin eval` confirme qu'aucun champ de `context` ne monte des fichiers sans ce drapeau.

Premier VERT — `claude plugin eval . --case 'git-workflow-*' --no-publish --max-cost-usd 5 --allow-tools Bash\(git:\*\) --keep-temp --scaffold`, lancé à la main avec `--scaffold` (cas écrits ici, ce que la règle de plugin-plugin autorise ; `eval-run` ne sait pas le passer), plafond porté à 5 USD avant l'annonce (estimation haute 4,14 USD), puis `bash pp.sh eval-verdict . git-workflow <résultats>/aggregate-result.json` → exit 1 :

```
refusé : le témoin réussit git-workflow-branch-prefix (WITH 0.89, W/OUT 1.00) : le cas ne prouve rien, à réécrire
rouge : git-workflow-push-default-branch : WITH 0.83, Δ +0.83
ok : git-workflow-rebase-question (négatif) : WITH 1.00, Δ +0.00
coût : 1,79 USD
verdict : rouge
```

Les traces conservées (`--keep-temp`) montrent que les deux bras reçoivent bien le scaffold. Le témoin sans plugin lit `.forge/config.yaml` de lui-même et crée `story/AC-012-…` trois fois sur trois : le préfixe ne prouve rien. Avec le plugin, un passage sur trois s'est arrêté devant les fichiers non suivis que le bac à sable sème dans l'espace de travail (`.bashrc`, `.idea`, `.vscode`…), la consigne reprise de plugin-flutter disant « tout changement non commité : s'arrêter et demander ». Sur « pousse main sur origin », le skill n'a été invoqué qu'une fois sur trois ; sans lui, le modèle refuse de lui-même mais propose une fois de pousser main « sur confirmation », refusé par le juge ; le témoin pousse main trois fois sur trois. Corrections : le skill (fichiers non suivis, branche nommée avant la question, push refusé couvert par la description et `when_to_use`) et le cas de branche réécrit, `git-workflow-branch-uncommitted-change` remplaçant `git-workflow-branch-prefix` : même demande, même configuration, mais `src/main.ts` modifié et non commité ; attendu : skill invoqué, aucun `git switch -c` ni `git stash`, la branche `story/AC-012-<slug>` et `src/main.ts` nommés, la question posée (commiter d'abord, emporter, s'arrêter). Pas de second ROUGE pour ce cas : le bras témoin du VERT joue ce rôle sur le vrai espace.

VERT — même commande à la main, puis `bash pp.sh eval-verdict . git-workflow ./evals/results/git-workflow-20261024T005634/aggregate-result.json` → exit 0 :

```
ok : git-workflow-branch-uncommitted-change (positif) : WITH 1.00, Δ +0.75
ok : git-workflow-push-default-branch (positif) : WITH 1.00, Δ +1.00
ok : git-workflow-rebase-question (négatif) : WITH 1.00, Δ +0.00
coût : 1,83 USD
verdict : vert
```

Skill invoqué six fois sur six sur les cas positifs ; le témoin crée la branche en emportant le changement sans rien dire (0,25) et pousse main (0,00). Coût total des trois passages : 4,54 USD. Les bacs à sable conservés sont sous `/tmp/claude-eval-*` (lecture seule, scellés), hors git.

Suite — `bash tests/run-all.sh` → exit 0 : 16 réussies, 0 échouée, 0 sautée (`skills/` et `agents/` désormais présents), `claude plugin validate --strict` ok sur `.`, `.claude-plugin/plugin.json`, `skills` et `agents`, `test_headers` 10 réussis dont `skills/git-workflow/SKILL.md`, `test_run_all` 31 réussis, coût permanent 449 tokens (git-workflow ~260, product-architect ~190 ; seuil 1 000), charge 8,6 sur 8 cœurs.

Manques de plugin-plugin relevés, hors de ce dépôt : `eval-run` devrait passer `--scaffold` quand les cas déclarent un `scaffold_script` (sa propre suite `add` en a cinq) ; `checkpoint` n'a pas de levée de blocage (la ligne du blocage de confiance, résolu, a été retirée à la main du checkpoint non versionné).
