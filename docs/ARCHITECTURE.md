# Architecture — plugin-orchestrator

2026-10-23 · Soon · PRD : `docs/PRD.md`

**Statut : APPROUVÉ** le 2026-10-23 (« je valide »).

## Modèle

Plugin au modèle de plugin-flutter : dépôt dédié `soonlysoul/plugin-orchestrator`, plugin à la racine, manifeste sans e-mail, licence MIT, marketplace locale `"source": "./"`, composants à la racine (`skills/`, `agents/`, `hooks/`, `templates/`, `scripts/`), tests dans `tests/`.

Deux rôles dans un seul plugin :

1. **Socle** — les workflows transversaux, garde-fous et gabarits que les plugins de langage lui délèguent (repris de plugin-flutter, tels quels ou généralisés). Actif dès un projet mono-partie.
2. **Coordinateur** — la couche projet multi-parties : découpage, mandats, contrat, livraison. Actif à partir de deux parties.

L'orchestrateur n'écrit jamais de code applicatif. Il écrit les documents de niveau projet, l'état `.forge/`, et délègue le reste aux plugins de langage.

## Composants

Chaque composant répond à une user story ; aucun n'existe « au cas où ». Origine : **R** repris tel quel (de plugin-flutter, sauf mention), **G** généralisé depuis plugin-flutter, **N** nouveau.

| Composant | Type | US | Origine | Version | Pourquoi ce type | Coût permanent estimé |
| --- | --- | --- | --- | --- | --- | --- |
| `bootstrap-project` | skill | US-1 | G | v0.1 (mono-partie), v0.2 (multi-parties) | Jugement : interview, choix de pile, approbations ; le scaffold de chaque partie est un mandat au plugin de langage | ~100 tokens (description) |
| `create-feature` | skill | US-3 | G | v0.1 | Jugement : TDD en 15 étapes, paramétré par la `toolchain` de la partie | ~100 tokens |
| `git-workflow` | skill | US-4 | R | v0.1 | Jugement : classes d'actions, staging explicite, Conventional Commits | ~80 tokens (mesuré le 2026-10-24 : ~270) |
| `github-workflow` | skill | US-5 | G | v0.1 | Jugement : points de validation (dépôt, PR, CI) ; commandes locales depuis la `toolchain`, builds et pose du gabarit CI au plugin de langage | ~90 tokens (mesuré le 2026-10-26 : ~260) |
| `recover-session` | skill | US-6 | G | v0.1 | Jugement : croiser checkpoint, Git et dépôt ; la commande relancée est celle consignée dans le checkpoint (exemples dé-Flutterisés) | ~70 tokens (mesuré le 2026-10-25 : ~300) |
| `debug-project` | skill | US-7 | G | v0.1 | Jugement : cause racine prouvée, régression ROUGE puis VERT, commandes depuis la `toolchain` | ~90 tokens |
| `plan-feature` | skill | US-8 | N | v0.2 | Jugement : découpage en lots, ordre contrat → fournisseur → consommateur, mandats | ~90 tokens |
| `run-feature` | skill | US-9 | N | v0.2 | Jugement : enchaîne `create-feature` lot par lot, vérifie chaque mandat au retour, s'arrête au premier échec | ~90 tokens |
| `project-status` | skill | US-11 | N | v0.2 | Jugement : synthèse lecture seule (parties, mandats, documents, contrat) | ~70 tokens |
| `release` | skill | US-12 | N | v0.3 | Jugement : vérifications par partie, versions, changelog, tags, accords | ~80 tokens |
| `product-architect` | agent | US-2 | G | v0.1 | Tâche bornée : PRD produit (AC-xxx) ; dé-Flutterisé — reconstruct lit les chemins donnés par la session, les questions d'architecture vont à l'architecte du plugin de la partie | ~80 tokens (mesuré le 2026-10-24 : ~190) |
| `project-architect` | agent | US-8, US-10 | N | v0.2 | Tâche bornée : architecture du découpage et contrat d'API, documents seulement | ~80 tokens |
| `integration-reviewer` | agent | US-10 | N | v0.2 | Tâche bornée, lecture seule : écarts entre le contrat et ce que chaque partie expose/consomme | ~80 tokens |
| `guard-destructive` | hook | US-13 | R | v0.1 | Déterministe : bloquer une commande destructive doit toujours se produire | 0 en contexte |
| `secret-scan` | hook | US-13 | R | v0.1 | Déterministe : aucun commit avec secret | 0 |
| `protect-sensitive` | hook | US-13 | R | v0.1 | Déterministe : confirmation avant d'écrire un fichier sensible | 0 |
| `checkpoint-reminder` | hook | US-6, US-13 | R | v0.1 | Déterministe : rappel de checkpoint périmé à la fin d'un tour | 0 |
| `agent-scope-guard` | hook | US-2, US-8, US-10 | G | v0.1 | Déterministe : dossiers d'écriture et listes blanches Bash des agents **de ce plugin** | 0 |
| `doc-status-guard` | hook | US-13 | R (de plugin-plugin) | v0.1 | Déterministe : un document projet approuvé qui change repasse en REVIEW | 0 |
| `scripts/orch.sh` | script | toutes | N | v0.1 | Déterministe : état, checkpoint, statut et approbation des documents, registre des mandats | 0 |
| `hooks/scripts/lib/shell-lexer.sh` | script | US-13 | R | v0.1 | Déterministe : analyseur de commandes partagé par guard-destructive et secret-scan | 0 |
| `templates/` | gabarits | US-1, US-6, US-13 | voir « Gabarits » | v0.1 | Fichiers copiés ou remplis dans les projets, jamais exécutés | 0 |

Serveur MCP : aucun. **Coût permanent total : ~1 100 tokens** de descriptions (10 skills + 3 agents) dans chaque session où le plugin est activé, en plus des plugins de langage. Amendement du 2026-10-26 : mesuré par `claude plugin details`, le style maison d'un en-tête de skill (Use when, not for, trois phrases citées, `when_to_use`) plafonne vers 250 tokens par skill, `argument-hint` ne comptant pas ; la v0.1 (six skills, un agent) se projette vers ~1 800 tokens et le seuil de `tests/run-all.sh` est relevé à 2 000 (alerte, jamais un échec).

## Gabarits

L'orchestrateur devient propriétaire du format `.forge/` et des documents transversaux ; les gabarits suivent.

| Gabarit | Origine | Contenu |
| --- | --- | --- |
| `templates/checkpoint.md` | R | Format du checkpoint (inchangé) |
| `templates/forge-config.yaml` | G | Préautorisations (inchangées) + section `parts`, `schema_version: 2` |
| `templates/project-settings.json` | G | Les règles de permission **génériques** seulement : git, gh, lecture des fichiers sensibles en `deny`. Les règles propres au langage (flutter, dart…) sont un **fragment** fourni et fusionné par le scaffold du plugin de langage — `${CLAUDE_PLUGIN_ROOT}` ne traverse pas les plugins, chacun ne lit que ses propres gabarits |
| `templates/doc-templates/PRD.md` | R | Gabarit du PRD produit |
| `templates/doc-templates/DECISIONS.md` | G | Décisions projet (ADR transverses) |
| `templates/doc-templates/CLAUDE.md` | G | Conventions du projet, dé-Flutterisé |
| `templates/doc-templates/ARCHITECTURE.md` | N (v0.2) | Découpage en parties |
| `templates/doc-templates/CONTRACT.md` | N (v0.2) | Contrat d'API |

Le gabarit de TRD reste à plugin-flutter (son architecte l'écrit), comme le gabarit CI et le fragment de permissions Flutter. Tous les gabarits de documents portent les trois états DRAFT / REVIEW / APPROVED — **REVIEW est nouveau** par rapport aux gabarits de plugin-flutter (il vient de plugin-plugin, avec doc-status-guard) ; les vérifications de documents sont mises à jour en conséquence.

## Contrat de délégation (interface v1)

C'est l'interface la plus importante du plugin : ce que l'orchestrateur envoie à un agent d'un plugin de langage, et ce qu'il exige en retour. Les formats existants de plugin-flutter deviennent la spécification v1, plus une ligne d'interface.

**Mandat entrant.** Tout mandat nomme : la version d'interface (`interface: 1`), la partie (`path`, `plugin`), la tâche, les critères d'acceptation visés, le périmètre déclaré (fichiers/dossiers), puis les entrées propres à la tâche :

- `write-tests` (→ `<plugin>:test-engineer`) : plan, API publique (signatures), chemins des fichiers de tests, device pour les tests d'intégration ou « blocked » avec la raison ;
- `review` (→ `<plugin>:code-reviewer`) : les arguments git du diff (`--cached <branche par défaut>` ou une plage), jamais le raisonnement de l'implémentation ;
- `check-dependency` (→ l'architecte du plugin) : le paquet ajouté, les plateformes/cibles activées de la partie — la vérification de compatibilité est un jugement de langage, pas une clé de toolchain ;
- `diagnose` (→ l'architecte du plugin, à `debug-project`) : amendement du 2026-10-28 — la commande qui échoue, sa sortie et sa classe, l'hypothèse courante avec sa preuve, le comportement du langage, de ses outils ou d'une plateforme dont elle dépend ; rien n'est écrit, le correctif reste à la session ;
- `scaffold` (→ le plugin de langage, à bootstrap) : nom, identifiants, plateformes/cibles ; comprend la création du squelette, le TRD, le fragment de permissions, le gabarit CI et le test de base. Amendement du 2026-10-28 : l'agent destinataire n'est pas nommé — `bootstrap-project` mandate « l'agent que le plugin expose pour le scaffold » — et le skill s'arrête devant un plugin sans scaffold à l'interface 1 (plugin-flutter 0.x, dont le bootstrap fait tout lui-même), nommé avec la mise à jour qu'il lui faut, Git et `.forge/` en place.

**Rapport sortant.** Tout agent délégué termine par un bloc fixe : ses sections propres (pour `review` : `FINDINGS` bloquant/important/mineur avec `fichier:ligne`, `DOCS_TO_UPDATE`, `DIVERGENCES` ; pour un PRD : `ACCEPTANCE_CRITERIA` ; pour `write-tests` : la sortie ROUGE brute avec commande et code de sortie), puis la queue commune :

```
INTERFACE: 1
STATUS: done | blocked | partial
FILES_CHANGED: …
COMMANDS_RUN: `<commande>` → exit <code>
OPEN_QUESTIONS: …
```

L'orchestrateur parse ces blocs (l'étape revue de `create-feature` décide sur `FINDINGS`, l'étape docs sur `DOCS_TO_UPDATE` et `DIVERGENCES`) et vérifie chaque affirmation importante avant de la présenter comme un fait. Amendement du 2026-10-28 : le rapport d'un mandat `scaffold` ajoute au contrat v1 les blocs `TOOLCHAIN`, `PERMISSIONS`, `VERSIONS` et `TARGETS`, placés avant `INTERFACE: 1` (après `SCAFFOLD`, sa section propre) — les lignes de `TOOLCHAIN` entrent telles quelles dans `config.yaml`, `PERMISSIONS` est le fragment du plugin, rendu dans le rapport et jamais écrit par lui, `VERSIONS` va dans `ADR-001`, et une cible de `TARGETS` n'est construite qu'avec sa commande dans `COMMANDS_RUN` ; spécification : `skills/bootstrap-project/reference/scaffold-mandate.md`. Amendement du 2026-10-28 : le rapport d'un mandat `diagnose` porte `DIAGNOSIS` (confirmé, réfuté ou non vérifié, avec sa preuve — un verdict sans preuve compte comme non vérifié) et `FIX_DIRECTION`, avant `INTERFACE: 1` ; le `write-tests` de `debug-project` demande un seul test de régression, nommé `regression: <ce qui a échoué>` ou d'après le critère cassé, qui échoue pour la cause racine donnée ; spécification : `skills/debug-project/reference/mandates.md`.

**Versionnement.** La version d'interface est déclarée par partie dans `config.yaml` (`interface: 1`), envoyée dans chaque mandat, et **répétée** par l'agent dans `INTERFACE:`. Une ligne absente (plugin pré-migration) ou différente arrête le workflow en nommant le plugin et la version requise — c'est aussi le mécanisme de détection d'un plugin-flutter 0.x. Réciproquement, les skills restantes de plugin-flutter vérifient la présence de l'orchestrateur et s'arrêtent proprement sans lui. Les dépendances entre plugins ne sont pas déclarables dans le modèle : tout se vérifie à l'exécution.

## Partage avec les plugins de langage

Un plugin de langage fournit : le scaffold de sa partie, son architecte (TRD, ADR langage, `check-dependency`), son `test-engineer`, son `code-reviewer`, son devops/builds, son outillage de dépendances/SDK (`update-project`) et l'adoption d'un projet existant de son langage (`adopt-existing-project`, qui utilise le `product-architect` de l'orchestrateur : la dépendance est bidirectionnelle), son hook de formatage, son gabarit CI, son fragment de permissions, et son propre `agent-scope-guard`. Tout le reste vient de l'orchestrateur.

Paramétrage par partie dans `.forge/config.yaml` :

```yaml
schema_version: 2
parts:
  app:
    path: app/
    plugin: plugin-flutter
    interface: 1
    toolchain:
      test: flutter test
      format: dart format
      analyze: flutter analyze
      add_dep: flutter pub add
      manifests: [pubspec.yaml, pubspec.lock]      # stagés quand une dépendance change
      integration_test: flutter test integration_test -d <device>   # optionnel
    platforms: [android, web, linux]               # optionnel, propre au langage
```

Règle de partage : **mécanique → clé de `toolchain` ; jugement → mandat à un agent du plugin de langage.** Les clés couvrent les gestes que `create-feature`, `debug-project` et `github-workflow` lancent eux-mêmes (tests, format, analyse, ajout de dépendance, manifestes à stager, tests d'intégration) ; la vérification des plateformes d'un paquet, le choix d'un device disponible et tout ce qui demande de comprendre le langage sont des mandats.

Un projet mono-partie a une seule entrée `parts` (`path: .`).

**Schéma v1 → v2.** Un `config.yaml` en `schema_version: 1` (tous les projets plugin-flutter existants) n'a pas de `parts` : l'orchestrateur le détecte, propose le bloc `parts` à ajouter, et c'est **l'utilisateur** qui édite le fichier — la règle `deny` `Edit(./.forge/config.yaml)` et protect-sensitive l'interdisent à Claude. Jusque-là, les skills de l'orchestrateur s'arrêtent proprement sur ce projet. À la création d'un projet, `bootstrap-project` écrit `config.yaml` une seule fois, avant d'installer les règles de permission, derrière la confirmation de protect-sensitive (comme plugin-flutter aujourd'hui).

## Migration de plugin-flutter

Hors de ce dépôt, mais condition du critère v0.1 :

1. **Ordre de publication.** plugin-orchestrator v0.1.0 d'abord (sa suite de tests verte ne dépend pas de plugin-flutter) ; puis plugin-flutter en version majeure : retrait de `git-workflow`, `github-workflow`, `recover-session`, `create-feature`, `debug-project`, `product-architect`, des hooks `guard-destructive`, `secret-scan`, `protect-sensitive`, `checkpoint-reminder` et du lexer ; les tests suivent les composants ; écho `INTERFACE: 1` dans les rapports de ses agents ; vérification de la présence de l'orchestrateur dans ses skills restantes. Le critère v0.1 du PRD se mesure une fois les deux publiés et installés ensemble.
2. **Exigence d'installation.** Les deux plugins installés ensemble ; l'un sans l'autre, les skills concernées s'arrêtent proprement en nommant le plugin manquant.
3. **Fenêtre transitoire.** Orchestrateur installé face à un plugin-flutter 0.x : les hooks tournent en double (sans danger — mêmes blocages — mais plus lent), et l'orchestrateur refuse de déléguer (pas d'écho `INTERFACE`) en demandant la mise à jour. État documenté, résolu en mettant à jour plugin-flutter.

Amendement du 2026-10-29 (« tranche au mieux », plan de plugin-flutter 1.0) : le lexer `hooks/scripts/lib/shell-lexer.sh` reste dans plugin-flutter, dont l'`agent-scope-guard`, conservé, le source — `${CLAUDE_PLUGIN_ROOT}` ne traverse pas les plugins ; plugin-flutter retire aussi son `bootstrap-project`, et le mandat `scaffold` va à son agent `plugin-flutter:scaffold-engineer`, qui ne pose pas la CI (mandat `ci-template`) ; ses skills restantes, qui écrivent `.forge/` à l'adoption, gardent des copies des gabarits de l'orchestrateur à son format — `checkpoint.md`, `forge-config.yaml` au schéma 2 avec la toolchain Flutter, règles génériques avec son fragment. Le mandat `scaffold` (0.1.1) autorise le `.gitignore` racine qu'écrit l'outil de scaffold du langage (`flutter create .`), auquel l'étape 5 ajoute ses motifs, et nomme le dossier du projet ; un plugin qui ne scaffolde que la racine de session rend `blocked` sur un projet en sous-dossier, repris par une nouvelle session dans ce dossier.

## Hooks

Règles du modèle : forme exec (`"command": "bash"`, `args` avec `${CLAUDE_PLUGIN_ROOT}`), fail-closed = exit 2 sur erreur interne **et** `"onFailure": "block"`, fail-open = exit 0 toujours et `"onFailure": "continue"`. Un hook d'un plugin installé pour le compte s'applique à **toutes** les sessions : chaque hook reste inerte hors de son contexte.

Règle des motifs d'écosystème : **le socle assume les motifs des écosystèmes connus** — publication (`flutter pub publish`, `dart pub publish`, `npm publish`, `twine upload`…), fichiers sensibles (keystores, `key.properties`, `.p12`, `.entitlements`…), listes blanches (configuration Firebase) — parce qu'ils coûtent zéro en contexte et protègent partout ; un plugin de langage ajoute les siens par son propre hook s'il en manque. Pas de retrait des motifs Flutter existants.

| Hook | Événement | Filtre | Mode | Inerte hors de |
| --- | --- | --- | --- | --- |
| `guard-destructive` | PreToolUse | `Bash\|PowerShell\|Monitor` | fail-closed | Toujours actif (comme dans plugin-flutter) ; motifs de publication des écosystèmes connus conservés et étendus |
| `secret-scan` | PreToolUse | `Bash\|PowerShell\|Monitor` | fail-closed | Entrée sans le mot `commit` |
| `protect-sensitive` | PreToolUse | `Edit\|Write\|NotebookEdit` | fail-closed | Projet sans `.forge/` (sauf `.forge/config.yaml`, protégé partout) |
| `checkpoint-reminder` | Stop | — | fail-open | Projet sans `.forge/checkpoint.md`, ou `stop_hook_active` |
| `agent-scope-guard` | PreToolUse | `Edit\|Write\|NotebookEdit\|Bash\|PowerShell\|Monitor` | fail-closed | Sessions qui ne sont pas un agent `plugin-orchestrator:<agent>` (chaque plugin garde le sien : vérifié, le script sort si `agent_type` n'a pas son préfixe) |
| `doc-status-guard` | PostToolUse | `Edit\|Write` | fail-open | Fichiers hors des documents projet portant une ligne de statut |

## Agents

Outils déclarés un par un, jamais `Agent`, jamais `AskUserQuestion` ; dossiers d'écriture et liste blanche Bash imposés par `agent-scope-guard`. « Git en lecture » : `git status`, `log`, `diff`, `show`, `ls-files`, `rev-parse`, `branch --show-current`.

| Agent | `tools` | Écrit sous | Bash autorisé | Reçoit | Rend |
| --- | --- | --- | --- | --- | --- |
| `product-architect` | Read, Grep, Glob, Write, Edit | `docs/product/` | Aucun | Description du besoin (draft), ou chemins à lire donnés par la session (reconstruct) | PRD en DRAFT, AC-xxx numérotés, testables, jamais renumérotés ; bloc `ACCEPTANCE_CRITERIA` ; les questions d'architecture vont en `OPEN_QUESTIONS`, routées vers l'architecte du plugin de la partie |
| `project-architect` | Read, Grep, Glob, Bash, Write, Edit | `docs/` | Git en lecture | PRD, parties envisagées | Architecture du découpage, contrat d'API, ADR projet |
| `integration-reviewer` | Read, Grep, Glob, Bash | Rien | Git en lecture | Contrat, chemins des parties | Écarts priorisés (bloquant / important / mineur) avec fichier:ligne |

Chaque agent termine par le bloc commun du contrat de délégation (`INTERFACE`, `STATUS`, `FILES_CHANGED`, `COMMANDS_RUN`, `OPEN_QUESTIONS`). Chaque rapport est vérifié par la session principale avant d'être présenté comme un fait.

## Généralisation des skills reprises

Ce que « G » change concrètement, composant par composant :

- **`create-feature`** : les commandes des étapes ROUGE/VERT/re-test/qualité viennent de `toolchain` ; l'étape contexte lit le PRD racine + le TRD **de la partie** + l'entrée du plan **de la partie** (PRD et TRD APPROVED exigés) ; l'ajout de dépendance utilise `add_dep` puis un mandat `check-dependency` ; le staging ajoute les fichiers de `manifests` ; les mandats `write-tests` et `review` suivent le contrat de délégation.
- **`debug-project`** : reproduction et régression via `toolchain` ; le diagnostic d'un comportement propre au langage peut devenir un mandat à l'architecte du plugin. Amendement du 2026-10-28 : le test de régression est le test existant qui échoue, sinon un mandat `write-tests` au test-engineer (plugin-flutter l'écrivait en session : un test est un geste de langage), le correctif restant à la session principale ; sans le plugin de langage dans la session, le workflow s'arrête après le diagnostic et le périmètre du correctif ; le checkpoint est lu avant tout — un échec consigné comme le ROUGE attendu est rendu à son workflow sans rien toucher, et les étapes restantes d'un autre workflow ne sont jamais écrasées par un `start` (que `orch.sh` accepterait) : la panne y est consignée par `block`, corrigée dans ce workflow quand elle vient de ses changements, en point de validation quand elle vient de la branche par défaut.
- **`github-workflow`** : les préconditions de `pr` et les vérifications locales de `ci` lancent `format`, `analyze`, `test` de chaque partie concernée ; la pose du gabarit CI et les builds restent des mandats au plugin de langage (son devops) ; le corps de PR garde les quatre catégories de tests, et sa table des plateformes n'apparaît que pour une partie qui déclare `platforms`.
- **`recover-session`** : la commande relancée est celle consignée dans le checkpoint (déjà générique) ; exemples dé-Flutterisés.
- **`bootstrap-project`** : interview, structure, documents racine, `.forge/`, règles de permission génériques ; puis un mandat `scaffold` par partie. Amendement du 2026-10-28 : la v0.1 est mono-partie — une seule partie, `path: .`, un seul mandat `scaffold` ; une demande à plusieurs parties arrête le workflow, nommée, le bootstrap multi-parties venant avec la couche de coordination (v0.2).
- **`product-architect`** : corps dé-Flutterisé (plus de référence à `lib/`, `test/` ni au flutter-architect).

## État persistant et documents

`.forge/` est conservé (continuité avec les projets plugin-flutter existants) et son format appartient à l'orchestrateur : `config.yaml` (ci-dessus), `checkpoint.md` (format repris), `plan/<feature>/mandates.md` (plans et mandats, écrits par `plan-feature`, mis à jour par `run-feature`), `reports/`.

Documents, en deux niveaux — pour une mono-partie (`path: .`), les deux niveaux coïncident et la disposition est celle de plugin-flutter aujourd'hui :

| Niveau | Document | Propriétaire |
| --- | --- | --- |
| Racine | `docs/product/PRD.md` (produit, unique au projet) | orchestrateur (`product-architect`) |
| Racine | `docs/technical/ARCHITECTURE.md` (découpage, v0.2) | orchestrateur (`project-architect`) |
| Racine | `docs/technical/CONTRACT.md` (contrat d'API, v0.2) | orchestrateur (`project-architect`) |
| Racine | `docs/engineering/DECISIONS.md` (ADR transverses) + `CLAUDE.md` | orchestrateur |
| Partie | `<path>/docs/technical/TRD.md` | plugin de langage (son architecte) |
| Partie | `<path>/docs/engineering/IMPLEMENTATION_PLAN.md`, `DECISIONS.md` (ADR langage), `CLAUDE.md` | plugin de langage |

En-tête fixe avec statut DRAFT / REVIEW / APPROVED ; approbation explicite seulement ; `doc-status-guard` fait repasser en REVIEW tout document approuvé qui change.

## Tests et évaluations

- Suite déterministe `tests/run-all.sh` : bash et jq, sans réseau ni quota — manifestes, frontmatter strict, chemins `${CLAUDE_PLUGIN_ROOT}`, hooks sur entrées JSON simulées (dont fail-closed sur erreur interne), cohérence docs/composants, et `claude plugin validate --strict` sur les quatre cibles du modèle (`.`, `.claude-plugin/plugin.json`, agents, skills), marqué bloqué si `claude` manque du PATH.
- Les tests des hooks repris suivent les scripts depuis plugin-flutter et sont étendus (nouveaux motifs de publication, contexte `parts`, écho `INTERFACE`).
- Une suite d'évaluation par skill : au moins un cas qui doit le déclencher, un qui ne le doit pas, trois exécutions par cas.
- Critères de sortie par version : v0.1 projet mono-partie réel, v0.2 projet deux parties réel, v0.3 release coordonnée (PRD, « Critères de succès »).

## Hors périmètre, et ce qui le rouvrirait

- Code applicatif et gestes propres à un langage — définition du plugin — jamais rouvert.
- Workflows internes des plugins de langage — l'orchestrateur mandate, il ne reconfigure pas — rouvert seulement par un besoin prouvé sur un vrai projet.
- Adoption d'un projet multi-parties existant — coûteuse et risquée avant que la coordination soit prouvée — rouverte après la v0.2.
- `update-project` et `adopt-existing-project` restent aux plugins de langage — leur matière est l'outillage du langage (lockfiles, SDK, registres) — rouvert si trois plugins dupliquent une même méthodologie de lots.
- Composants hors modèle (MCP code, channels, output styles, commandes classiques, options, dépendances de plugin, serveurs de langage) — rouvert par une évolution du modèle plugin-plugin.

## Décisions différées à la v0.2

Sans effet sur un projet mono-partie ; tranchées au lancement de la v0.2, sur le premier projet deux parties :

- **Topologie Git d'un projet multi-parties** — recommandation : un dépôt unique à la racine (commits transversaux, PR et CI plus simples ; hooks et `.forge/` à la racine), contre un dépôt par partie.
- **Format du contrat d'API** — recommandation : OpenAPI comme source de vérité avec `CONTRACT.md` en synthèse (vérifiable mécaniquement par `integration-reviewer`), contre markdown structuré seul.

## Décisions

- Un seul plugin pour le socle et la coordination, plutôt que deux (plugin-core + plugin-orchestrator) — un dépôt et une version de moins à maintenir pour un développeur solo ; socle et coordination partagent le format d'état et les scripts — 2026-10-23.
- `.forge/` conservé comme dossier d'état plutôt qu'un nouveau nom — continuité avec les projets plugin-flutter existants et leurs hooks — 2026-10-23.
- `create-feature` et `debug-project` généralisés dès la v0.1 plutôt que laissés par langage — plugin-ts-backend et plugin-python ne sont pas encore construits : c'est maintenant que la mutualisation coûte le moins — 2026-10-23.
- La pose du gabarit CI, le fragment de permissions et le gabarit de TRD restent au plugin de langage — `${CLAUDE_PLUGIN_ROOT}` ne traverse pas les plugins : chacun ne lit que ses propres gabarits — 2026-10-23.
- Interface de délégation versionnée (`interface: 1`, écho `INTERFACE:` dans chaque rapport) plutôt qu'une simple vérification de présence — les schémas de config, mandats et rapports vont bouger ; sans version, une incompatibilité orchestrateur 0.2 / plugin-flutter 1.0 serait indétectable — 2026-10-23.
- Le socle assume les motifs des écosystèmes connus dans ses hooks, plutôt que de n'en garder aucun — coût nul en contexte, protection partout, et retire le trou `pub publish` de la migration — 2026-10-23.
- Les formats de rapport existants de plugin-flutter (code-reviewer, product-architect) deviennent la spécification v1 du contrat de délégation — ils sont éprouvés et leurs blocs sont déjà parsés par les workflows — 2026-10-23.
- Règle mécanique/jugement pour la toolchain — une clé de toolchain pour un geste mécanique, un mandat pour un jugement de langage ; évite une toolchain qui enfle à chaque cas particulier — 2026-10-23.
