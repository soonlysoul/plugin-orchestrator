# plugin-orchestrator

Drives a software project from zero to delivery through project-level documents, shared Git, GitHub, TDD, recovery and debugging workflows, and multi-part coordination, delegating all language-specific work to the specialized plugins.

Version **0.1.1** : les projets à une seule partie. Le découpage d'un projet en plusieurs parties et leur coordination (contrat d'API, lots, livraison) viendront en v0.2. Le cadrage approuvé est dans [docs/PRD.md](docs/PRD.md) et [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ; l'avancement, dans [PROGRESS.md](PROGRESS.md). Claude Code **2.1.295 ou plus** requis.

## Ce que fait le plugin

Démarrer un projet, développer une fonctionnalité en TDD, committer proprement, publier sur GitHub, reprendre après une interruption, corriger une panne avec méthode — quel que soit le langage du projet : tout ce qui est propre à un langage est confié, par un mandat, au plugin de langage de la partie (plugin-flutter, à partir de sa prochaine version majeure).

| Composant | Rôle |
| --- | --- |
| Skill `bootstrap-project` | Démarre un projet : identité et périmètre confirmés d'abord, Git, dossier `.forge/`, scaffold confié au plugin de langage, documents racine en DRAFT, règles de permission proposées, test de base vert, premier commit |
| Skill `create-feature` | Une fonctionnalité en TDD strict : PRD et TRD approuvés lus d'abord, tests écrits par le test-engineer du plugin de langage, ROUGE puis VERT avec les commandes de la partie, revue indépendante, commit |
| Skill `debug-project` | Reproduit une panne inattendue (test, analyse, build, CI), en prouve la cause racine avant tout correctif, écrit un test de non-régression ROUGE puis VERT, committe un correctif minimal |
| Skill `git-workflow` | Branches nommées, ajout explicite des fichiers, commits Conventional Commits, push d'une branche de travail seulement si préautorisé, jamais de la branche par défaut |
| Skill `github-workflow` | Dépôt distant, CI posée par le plugin de langage, pull request et suivi des checks, derrière des points de validation ; jamais de merge par Claude |
| Skill `recover-session` | Reprend un travail interrompu depuis le disque (checkpoint, Git, état du dépôt), sans rien modifier avant votre accord |
| Agent `product-architect` | PRD produit et critères d'acceptation numérotés `AC-xxx`, testables ; écrit seulement sous `docs/product/`, sans shell |
| Hook `guard-destructive` | Bloque `git reset --hard`, `push --force`, `rm -rf` hors `build/`, `gh` qui supprime, merge ou publie une release, la publication sur un registre (pub.dev, npm, PyPI) sans `--dry-run` |
| Hook `secret-scan` | Bloque un commit qui contient un fichier secret ou un motif de secret dans ses lignes ajoutées ; lance aussi gitleaks s'il est installé |
| Hook `protect-sensitive` | Demande confirmation avant d'écrire un fichier de signature, des entitlements, un workflow de CI ou `.forge/config.yaml` |
| Hook `doc-status-guard` | Repasse en REVIEW un document projet approuvé dont le contenu a changé depuis son approbation |
| Hook `agent-scope-guard` | Impose à chaque agent du plugin ses dossiers d'écriture et sa liste de commandes |
| Hook `checkpoint-reminder` | Rappelle une fois de mettre à jour `.forge/checkpoint.md` quand il est périmé |

## Installer

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`, et le plugin de langage de chaque partie du projet ; pour GitHub, `gh` connecté ; gitleaks recommandé.

Sur chaque appareil, depuis la marketplace publique `soon` :

```bash
claude plugin marketplace add soonlysoul/claude-plugins
claude plugin install plugin-orchestrator@soon --scope user
```

Sans clé SSH GitHub sur l'appareil, exportez d'abord `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`.

Puis ouvrez Claude Code dans le dossier du projet — un dossier vide pour un nouveau projet — et lancez `/plugin-orchestrator:bootstrap-project`. Le dossier où la session est lancée sert de racine du projet aux hooks et aux règles de permission.

**Avec plugin-flutter 0.x.** Le travail propre à un langage passe par des mandats à l'interface 1, que plugin-flutter ne connaîtra qu'à sa prochaine version majeure. D'ici là, les workflows de l'orchestrateur s'arrêtent avant de lui confier quoi que ce soit, en demandant sa mise à jour, et les hooks communs aux deux plugins tournent en double : mêmes blocages, en plus lent.

## Essai local

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`. Depuis la racine d'un clone de ce dépôt :

```bash
claude --plugin-dir .
```

## Tests

```bash
bash tests/run-all.sh
```

Suite déterministe : bash et jq, sans réseau, sans session, sans quota. Codes de sortie : 0 tout passe, 1 une étape échoue, 2 un prérequis manque.

## Licence

MIT — voir [LICENSE](LICENSE).
