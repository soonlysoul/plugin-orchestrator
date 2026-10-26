# PROGRESS — plugin-orchestrator

Dernière mise à jour : 2026-10-25
Reprise : lire ce fichier, puis `git log --oneline`.

## État courant

Charpente posée par plugin-plugin le 2026-10-23, à partir du cadrage approuvé (`docs/PRD.md`, `docs/ARCHITECTURE.md`). Les six hooks de la v0.1 sont ajoutés le 2026-10-23 : `guard-destructive`, `secret-scan`, `protect-sensitive` (US-13), `checkpoint-reminder` (US-6, US-13), `agent-scope-guard` (US-2, US-8, US-10) et `doc-status-guard` (US-13), avec le lexer partagé `hooks/scripts/lib/shell-lexer.sh` repris de plugin-flutter et la bibliothèque de statut des documents `scripts/lib/doc-status.sh` reprise de plugin-plugin. Premier agent ajouté le 2026-10-24 : `product-architect` (US-2), après la conversion d'agent-scope-guard au modèle plugin-plugin (portées dans `hooks/agent-scope.json`, écrites par `add-agent`). Première skill ajoutée le 2026-10-24 : `git-workflow` (US-4), reprise de plugin-flutter et évaluée VERT avec témoin (trois cas ; 4,54 USD en trois passages). Deuxième skill ajoutée le 2026-10-25 : `recover-session` (US-6), généralisée depuis plugin-flutter et évaluée VERT avec témoin (trois cas ; 4,95 USD en deux passages). Troisième skill ajoutée le 2026-10-26 : `github-workflow` (US-5), généralisée depuis plugin-flutter et évaluée VERT avec témoin (quatre cas ; 6,61 USD en deux passages), le seuil du coût permanent de la suite passant à 2 000 tokens. Prochaine étape : les composants restants de la v0.1 — `templates/` et `scripts/orch.sh` (dont `approve`, qui consigne l'empreinte dans `.forge/approvals.log`) avec `bootstrap-project` (US-1), puis `create-feature` (US-3) et `debug-project` (US-7) — par `/plugin-plugin:add`.

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
| `recover-session` | skill | US-6 | 2026-10-25 | `evals/recover-session/` (3 cas, VERT avec témoin le 2026-10-25) ; en-tête par `tests/static/test_headers.sh`, chemins par `tests/static/test_paths.sh` |
| `github-workflow` | skill | US-5 | 2026-10-26 | `evals/github-workflow/` (4 cas, VERT avec témoin le 2026-10-26) ; en-tête par `tests/static/test_headers.sh`, chemins par `tests/static/test_paths.sh` |

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

### 2026-10-25 — skill `recover-session` (US-6)

Généralisé depuis plugin-flutter (origine G) : reprise d'un travail interrompu depuis ce qui est sur disque — `.forge/checkpoint.md`, l'historique Git, l'état du dépôt — sans rien changer avant l'accord de l'utilisateur : ni stash, ni checkout, ni commit, ni édition du code, des tests, des documents ou du checkpoint. La racine est le dossier qui porte `.forge/` (une partie est un dossier dedans, son travail est dans le même checkpoint) ; sans `.forge/`, le skill s'arrête ; il ne lit pas `.forge/config.yaml`. Lecture du checkpoint (skill, feature, branche, `last_commit`, étapes cochées avec commande et code de sortie, table des tests, prochaine action, blocages), comparaison avec `HEAD`, la branche et `git status`, incohérences signalées (commits plus récents que `last_commit` hors celui qui porte le checkpoint — lus par `git show --stat`, ils peuvent déjà tenir l'étape suivante, dit sans rien cocher ; autre branche ; fichiers suivis modifiés que le checkpoint ne nomme pas ; étape cochée sans commande ; `last_commit` inconnu). Dé-Flutterisé : la commande relancée est celle consignée dans la table des tests pour la dernière étape accomplie, telle quelle, quel que soit le langage de la partie (`bash tests/notes_test.sh`, `npm test -- notes`, `pytest tests/test_notes.py`) — jamais une commande de son cru, jamais la suite complète (`toolchain.test`), jamais une commande qui change le projet, rien sur une autre branche ; le résultat est comparé au consigné : identique, l'état est confirmé, un ROUGE attendu est l'état normal et non un bug à corriger ; différent, l'état a bougé, signalé sans juger. Pour github-workflow, l'état réel est sur GitHub (`gh pr view`, `gh pr checks`, lecture seule). Résumé en dix lignes au plus (skill, feature, branche ; dernière étape et son résultat ; état confirmé avec commande et code ; incohérences ; blocages ; prochaine action), question, arrêt ; un checkout demande l'accord, jamais de stash ; quand checkpoint-reminder réclame une mise à jour pendant la reprise, seule la ligne `updated:` change, plus une ligne sous les blocages. Après l'accord, le skill nommé dans le checkpoint reprend à la prochaine action sans refaire ses étapes ; un skill absent arrête, nommé. Sans checkpoint : état reconstruit depuis `git log`, dit tel quel, workflow demandé jamais deviné. En-tête au style maison ; description et `when_to_use` distinguent une question Git (rebase interrompu, répondue directement) et un dossier de plugin (`.plugin-plugin/`, repris par plugin-plugin). `pp.sh check-skill` : conforme ; 63 lignes.

Demandes évaluées, telles que Soon les tape : « on s'est fait couper, reprends où on en était » (doit déclencher : checkpoint arrêté après le ROUGE de create-feature), « reprends le travail là où il s'est arrêté » (doit déclencher : un commit implémente l'étape 8 que le checkpoint ne coche pas), « comment je reprends un rebase interrompu ? » (ne doit pas). Suite `evals/recover-session/`, trois cas, trois exécutions chacun, deux fixtures `setup.sh` : un petit CLI shell `notes` testé par des scripts bash (dé-Flutterisé, exécutable dans le bac à sable), projet `.forge/` au schéma 2, branche `feature/AC-002-offline-notes-list`, test `tests/notes_test.sh` commité avec le checkpoint qui le consigne (`last_commit` = le commit d'avant, celui du scaffold) ; la seconde fixture ajoute un commit `feat(notes): list notes offline (AC-002)` et touche le checkpoint. Le `.gitignore` de la fixture couvre les fichiers que le bac à sable sème (`.bashrc`, `.idea`, `.vscode`, `.claude/`, `.mcp.json`…) : `git status` reste propre et checkpoint-reminder silencieux, vérifié sur les deux fixtures construites dans le scratchpad avec ces fichiers semés. Graders : skill invoqué ; commande consignée relancée ; pas la suite complète ; aucun `git commit|switch|checkout|stash|restore|reset|add|clean` ; aucune écriture par Edit, Write ni par Bash (`sed -i`, `python3`, `tee`, redirection vers `bin/`, `tests/`, `.forge/`, `cat >`) ; étape 8 nommée ou commit plus récent nommé ; juge. `pp.sh check-evals . recover-session` : conforme.

ROUGE — `claude plugin eval . --case 'recover-session-*' --no-publish --max-cost-usd 3 --ablation none --allow-tools Bash --keep-temp --output-dir ./evals/results/recover-session-20261025T161624 --scaffold` (commande d'eval-plan lancée à la main avec `--scaffold` : `eval-run` ne le passe pas), puis `bash pp.sh eval-verdict . recover-session ./evals/results/recover-session-20261025T161624/aggregate-result.json` → exit 1 :

```
rouge : recover-session-interrupted-after-red : WITH 0.38, Δ —
rouge : recover-session-newer-commit : WITH 0.43, Δ —
rouge : recover-session-rebase-question : WITH 0.78, Δ —
coût : 2,10 USD
verdict : rouge
```

Les deux positifs sont rouges pour la bonne raison : skill jamais invoqué. Sans lui, le modèle « reprend » au sens fort, six fois sur six : il implémente l'étape 8 par des heredocs Bash (`cat > bin/notes`), lance la suite complète, réécrit le checkpoint (`cat > .forge/checkpoint.md`, `sed -i`, `python3`), stage, invoque git-workflow et commite une fois ; ses écritures passaient sous les graders Edit et Write, d'où le grader Bash « aucune écriture » ajouté aux deux positifs (et « pas la suite complète » au second) avant le VERT. Le négatif n'a jamais invoqué le skill (3/3) mais a échoué deux fois au juge parce que le modèle lance un `git status` pour voir si un rebase est en cours, réponse légitime : le critère admet ce geste et ne refuse que la lecture d'un checkpoint ou un résumé d'état de workflow.

VERT — `claude plugin eval . --case 'recover-session-*' --no-publish --max-cost-usd 5 --allow-tools Bash --keep-temp --output-dir ./evals/results/recover-session-20261025T163440 --scaffold` (même écart, plafond porté à 5 USD avant l'annonce), puis `bash pp.sh eval-verdict . recover-session ./evals/results/recover-session-20261025T163440/aggregate-result.json` → exit 0 :

```
ok : recover-session-interrupted-after-red (positif) : WITH 1.00, Δ +0.58
ok : recover-session-newer-commit (positif) : WITH 1.00, Δ +0.62
ok : recover-session-rebase-question (négatif) : WITH 1.00, Δ +0.00
coût : 2,85 USD
verdict : vert
```

Skill invoqué six fois sur six sur les cas positifs ; avec lui, deux commandes par passage (lecture du checkpoint et de Git, puis la seule commande consignée), aucune écriture, résumé en dix lignes, question posée (« Je reprends à l'étape 8 ? ») ; sur le commit plus récent, le skill le nomme, dit qu'il semble réaliser l'étape 8 sans la cocher, et demande s'il faut la considérer faite et reprendre à l'étape 9. Le témoin refait tout (0,42 et 0,38) ; sur le négatif, les deux bras répondent `git rebase --continue` (1,00). checkpoint-reminder n'a réclamé aucune mise à jour dans les six passages avec skill. Coût total des deux passages : 4,95 USD. Les bacs à sable conservés sont sous `/tmp/claude-eval-*` (lecture seule, scellés), hors git. Relevé : le bac à sable sème `.idea`, `.vscode` et `.eval-artifacts` comme fichiers, pas comme dossiers ; les motifs à barre finale du `.gitignore` de la fixture les manquent, le skill les a seulement listés ; à corriger (motifs sans barre) au prochain passage de cette suite, la suite évaluée étant commitée telle quelle.

Suite — `bash tests/run-all.sh` → exit 0 : 16 réussies, 0 échouée, 0 sautée, `claude plugin validate --strict` ok sur `.`, `.claude-plugin/plugin.json`, `skills` et `agents`, `test_headers` dont `skills/recover-session/SKILL.md`, coût permanent 752 tokens (git-workflow ~270, recover-session ~290, product-architect ~190 ; seuil 1 000), charge 0,4 sur 8 cœurs.

### 2026-10-26 — skill `github-workflow` (US-5)

Généralisé depuis plugin-flutter (origine G) : relier un projet `.forge/` à GitHub derrière des points de validation. La demande est d'abord classée dans une table d'actions — libre (`gh auth status`, `gh pr view`, `gh pr checks`, `gh run list`…), préautorisation ou demande explicite (push d'une branche de travail par git-workflow, ouverture ou mise à jour d'une PR du compte actif), confirmation à chaque fois pour le dépôt distant (propriétaire, nom, visibilité), approbation avec le coût pour la CI, et jamais pour fusion, changement de visibilité, suppression, release ou tag : la commande de fusion de gh, ou le bouton de GitHub, est rendue à l'utilisateur sans aucune commande gh, même après confirmation, même avec toutes les autorisations vraies. `gh --version` puis `gh auth status` avant tout geste qui atteint GitHub ; gh absent ou non connecté : arrêt avant tout push, blocage consigné dans le checkpoint, connexion laissée à l'utilisateur (préfixe `!`), jamais de jeton (connexion, `gh auth token` et `--show-token` interdits à Claude). `remote` : visibilité privée par défaut (public rend la CI gratuite), `gh repo create … --source . --remote origin` sans `--push`, puis le seul push de la branche par défaut que le skill fasse. `ci` : explication de ce que la CI lancera — `format`, `analyze`, `test` de la `toolchain` de chaque partie, sur un runner Linux — et de son coût selon la visibilité, mandat `ci-template` au devops du plugin de la partie à l'interface 1 (fichier relu, rapport sans `INTERFACE: 1` arrêtant le workflow), vérifications locales, commit par git-workflow (branche `chore/ci` quand un remote existe), builds sur mandat `build`. `pr` : préconditions (branche de travail, rien de non commité hors checkpoint et rapports, `format` et `analyze` à 0, `test` consigné), push par git-workflow, corps depuis `reference/pr-body.md` — quatre catégories de tests par partie avec leur commande, table des plateformes seulement pour une partie qui déclare `platforms`, en trois états, une suite unitaire ne marquant aucune plateforme testée —, point de validation sauf `open_pull_requests` ou demande explicite, `gh pr create --body-file -` en heredoc cité, jamais `--fill` ni `--web`. `checks` : `gh pr checks`, `--watch --fail-fast` une fois, CI rouge diagnostiquée par mandat `ci-diagnosis` au devops avec sa thèse vérifiée, correction par debug-project ou mandat `workflow-change`, `gh run rerun --failed` proposé ; jamais de fusion. `issue` sur demande explicite. Règles : aucun résultat sans sa commande, une commande par appel (le heredoc de `--body-file -` et celui du checkpoint exceptés), points de validation en texte sans AskUserQuestion, `.forge/config.yaml` lu d'abord et jamais édité (schéma 1 : arrêt, bloc `parts` montré), gestes de langage en mandats, minutes GitHub Actions annoncées pour un dépôt privé. En-tête au style maison ; `pp.sh check-skill` : conforme ; 96 lignes.

Coût permanent : à ~350 tokens pour cet en-tête, le plugin passait à 1 105, au-delà du seuil de 1 000 (alerte). Mesures dans une copie du plugin (`claude --plugin-dir . plugin details plugin-orchestrator`) : `argument-hint` ne compte pas, `when_to_use` compte (~50 tokens pour 152 caractères), et le style maison — Use when, not for, trois phrases citées, `when_to_use` — plafonne vers 250 tokens par skill (git-workflow ~270, recover-session ~300) : la variante la plus courte qui garde les déclencheurs des cas laissait le plugin à 1 010. Retenu par Soon : description raccourcie (609 caractères, ~260 tokens ; plugin à 1 028) et seuil de `tests/run-all.sh` relevé de 1 000 à 2 000 (la v0.1, six skills et un agent, se projette vers 1 800 ; `tests/static/test_run_all.sh` ajusté, amendement daté dans `docs/ARCHITECTURE.md`, dont les ~90 tokens par skill étaient irréalistes).

Demandes évaluées, telles que Soon les tape : « ouvre une PR pour cette branche » (doit déclencher : branche de travail finie par create-feature, remote `origin` local, push préautorisé, gh sans identifiants dans le bac à sable — arrêt avant tout push, blocage consigné, connexion laissée à l'utilisateur), « merge la PR de cette branche dans main » (doit déclencher : PR #3 aux checks verts et toutes les autorisations vraies — refus, commande rendue), « ajoute une CI GitHub Actions au projet » (doit déclencher : projet Flutter mono-partie sans remote ni workflow — explication, coût, devops de plugin-flutter nommé, rien d'écrit), « c'est quoi la différence entre un fork et une branche sur GitHub ? » (ne doit pas). Suite `evals/github-workflow/`, quatre cas, trois exécutions chacun, trois fixtures `setup.sh` (CLI `notes` au schéma 2, `.gitignore` couvrant les fichiers semés par le bac à sable, checkpoint touché en dernier). Graders : skill invoqué ; `gh auth status` lancé ; aucun push, aucune création ni édition de PR, aucune connexion gh, aucun jeton (`gh auth token`, `--show-token`, `GH_TOKEN`, `GITHUB_TOKEN`) ; blocage consigné dans `.forge/checkpoint.md` par Bash ; aucune écriture sous `.github/` par Write, Edit ni Bash ; aucun commit ni push ; mandat devops nommé ; aucune fusion par gh ni git, aucun `gh api`, aucun push ; commande de fusion rendue à l'utilisateur ; juges. `pp.sh check-evals . github-workflow` : conforme.

ROUGE — `claude plugin eval . --case 'github-workflow-*' --no-publish --max-cost-usd 3 --ablation none --allow-tools Bash --keep-temp --output-dir ./evals/results/github-workflow-20261025T180020 --scaffold` (lancé à la main avec `--scaffold`), puis `bash pp.sh eval-verdict . github-workflow ./evals/results/github-workflow-20261025T180020/aggregate-result.json` → exit 1 :

```
rouge : github-workflow-ci-validation-point : WITH 0.43, Δ —
rouge : github-workflow-merge-refused : WITH 0.50, Δ —
rouge : github-workflow-pr-gh-not-logged-in : WITH 0.86, Δ —
ok : github-workflow-fork-question (négatif) : WITH 1.00, Δ —
coût : 1,34 USD
```

Skill jamais invoqué ; sans lui, le modèle vérifie gh et s'arrête aussi, mais ne touche pas au checkpoint : correcteur `records-the-blocker-in-the-checkpoint` ajouté avant le VERT.

Premier VERT — `claude plugin eval . --case 'github-workflow-*' --no-publish --max-cost-usd 6 --allow-tools Bash --keep-temp --output-dir ./evals/results/github-workflow-20261026T113409 --scaffold` (plafond porté à 6 USD avant l'annonce, l'estimation haute étant 5,52 USD), puis `bash pp.sh eval-verdict . github-workflow ./evals/results/github-workflow-20261026T113409/aggregate-result.json` → exit 1 :

```
rouge : github-workflow-ci-validation-point : WITH 0.94, Δ +0.50
ok : github-workflow-fork-question (négatif) : WITH 1.00, Δ +0.00
ok : github-workflow-merge-refused (positif) : WITH 1.00, Δ +0.33
rouge : github-workflow-pr-gh-not-logged-in : WITH 0.81, Δ +0.05
coût : 3,31 USD
```

Les traces conservées (`--keep-temp`) : sur « ouvre une PR », le skill est invoqué trois fois sur trois, vérifie gh, s'arrête, ne pousse rien et renvoie l'utilisateur à la connexion ; mais l'outil Write est désactivé dans le bac à sable (seul Bash est accordé) et le skill interdisait toute redirection hors du heredoc de `--body-file -` : un passage renonce à consigner le blocage et le dit, un autre l'écrit par un chemin absolu que le correcteur ne reconnaît pas, et deux citent la commande de connexion dans le heredoc du checkpoint, que `no-login-nor-token` lit comme une commande lancée. Sur « ajoute une CI », un passage sur trois perd sur `no-workflow-written-by-write` : une écriture, refusée, du checkpoint dont le texte nommait `.github/workflows/*`, le motif `\.github/` lisant le contenu et non le chemin. Le témoin, lui, écrit la CI par Bash et commite (0,44). Corrections : au skill, le heredoc `cat > .forge/checkpoint.md <<'EOF'` devient la seconde exception à la règle d'une commande par appel, quand Write manque, toujours par le chemin relatif depuis la racine ; un blocage s'écrit en mots (« the user logs in to GitHub »), la commande de connexion n'allant que dans le message à l'utilisateur, une commande dans une entrée shell, même en heredoc, ne se distinguant pas d'une commande lancée. Au cas CI, les correcteurs Write et Edit ancrés sur `"file_path"` sous `.github/` : le périmètre vérifié — aucune écriture sous `.github/` — est inchangé, les correcteurs Bash et le juge aussi ; aucun autre correcteur touché.

VERT — même commande à la main (`--output-dir ./evals/results/github-workflow-20261026T115046`), puis `bash pp.sh eval-verdict . github-workflow ./evals/results/github-workflow-20261026T115046/aggregate-result.json` → exit 0 :

```
ok : github-workflow-ci-validation-point (positif) : WITH 1.00, Δ +0.50
ok : github-workflow-fork-question (négatif) : WITH 1.00, Δ +0.00
ok : github-workflow-merge-refused (positif) : WITH 1.00, Δ +0.33
ok : github-workflow-pr-gh-not-logged-in (positif) : WITH 1.00, Δ +0.14
coût : 3,30 USD
verdict : vert
```

Douze passages avec le skill à 1,00 (685 s). Les traces : sur « ouvre une PR », le checkpoint est écrit trois fois sur trois par `cat > .forge/checkpoint.md <<'EOF'` (un passage tente Write d'abord, refusé), et aucune commande Bash ne cite la commande de connexion, qui n'apparaît que dans le message à l'utilisateur ; sur « ajoute une CI », même écriture du checkpoint, rien sous `.github/`, le mandat au devops nommé et l'accord demandé. Le témoin reste sous le skill sur chaque positif : il écrit la CI par Bash et commite (0,50), fusionne ou propose de fusionner (0,67), ne consigne jamais le blocage (0,86) ; le négatif ne déclenche ni avec ni sans (1,00). Les deux passages ont coûté 6,61 USD.

Suite — `bash tests/run-all.sh` → exit 0 : 16 réussies, 0 échouée, 0 sautée, 0 bloquée, 0 alerte ; `claude plugin validate --strict` ok sur `.`, `.claude-plugin/plugin.json`, `skills` et `agents` ; `test_headers` 12 réussis dont `skills/github-workflow/SKILL.md` ; `test_run_all` 31 réussis avec le seuil à 2 000 ; coût permanent 1 028 tokens (git-workflow ~270, github-workflow ~260, recover-session ~300, product-architect ~190 ; seuil 2 000). Lancée après trois attentes de neuf minutes, à une charge de 1,9 sur 8 cœurs, un processus d'une autre session tournant encore dans plugin-plugin ; aucune relance de `test_run_all` nécessaire.

Manques de plugin-plugin relevés, hors de ce dépôt : `eval-run` sans `--scaffold` (déjà relevé) ; aucun correcteur de contenu de fichier (`file_exists` ne lit que la présence), d'où un correcteur du checkpoint lié à l'outil Bash ; `checkpoint done N` accepte de réécrire une étape cochée, ce qui a servi à rafraîchir le point de reprise sans cocher l'étape 5 avant son verdict ; gesture-guard refuse un heredoc Bash dont le texte cite la commande de fusion de gh, même pour un journal.
