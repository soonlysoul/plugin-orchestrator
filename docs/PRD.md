# PRD — plugin-orchestrator

2026-10-23 · Soon

**Statut : APPROUVÉ** le 2026-10-23 (« je valide »).

## Problème

Les plugins spécialisés par langage (plugin-flutter aujourd'hui, plugin-ts-backend et plugin-python à venir) gèrent chacun **leur** partie d'un projet de manière professionnelle, mais rien ne pilote le **projet entier** : partir d'un besoin produit, décider la pile, découper le travail entre les parties, tenir le contrat entre elles (API front↔back), séquencer les fonctionnalités à travers les plugins, et mener jusqu'au logiciel livré.

De plus, l'analyse de plugin-flutter (2026-10-23) montre qu'environ 60 % de son contenu n'a rien de spécifique à Flutter — 12 composants sur 19, entre la moitié et 60 % des octets selon le compte : workflows Git et GitHub, reprise de session, discipline documentaire, garde-fous (commandes destructives, secrets, fichiers sensibles), squelette TDD, agent produit. Sans socle commun, chaque nouveau plugin de langage réécrirait tout cela — du double travail à chaque langage, et des hooks exécutés en double quand plusieurs plugins sont activés.

## Solution

plugin-orchestrator permet à Soon de :

- **Piloter** un projet logiciel de zéro jusqu'à la livraison, en déléguant tout le travail propre à un langage au plugin spécialisé concerné ;
- **Mutualiser** les workflows transversaux (Git, GitHub, TDD, reprise, débogage, garde-fous, discipline documentaire) pour que chaque plugin de langage reste mince ;
- **Coordonner** les parties d'un projet multi-parties : découpage d'une fonctionnalité en lots ordonnés (contrat → fournisseur → consommateur), exécution lot par lot via les plugins spécialisés, cohérence du contrat d'API, livraison coordonnée.

L'orchestrateur ne touche jamais au code applicatif : il produit et tient les documents de niveau projet, exécute les workflows transversaux, et dit quel plugin spécialisé invoquer, quand, et avec quel mandat.

## Utilisateur cible

Soon, développeur solo utilisant Claude Code, menant des projets mono-partie (une app Flutter) ou multi-parties (front Flutter + backend TypeScript ou Python), avec une exigence de rigueur professionnelle : TDD, documents approuvés explicitement, commits propres, reprise fiable après interruption, aucune action externe sans accord.

## User Stories

- **US-1** — En tant que Soon, je veux démarrer un projet de zéro (interview produit, choix de la pile, structure, documents socle, état), afin de partir sur des bases approuvées avant toute ligne de code.
- **US-2** — En tant que Soon, je veux un PRD produit global avec des critères d'acceptation numérotés et testables, afin que chaque fonctionnalité se rattache à un critère.
- **US-3** — En tant que Soon, je veux développer une fonctionnalité en TDD strict dans n'importe quelle partie, quelles que soient les commandes du langage, afin de ne pas réécrire le workflow TDD par plugin.
- **US-4** — En tant que Soon, je veux brancher, committer et inspecter les diffs de façon sûre et uniforme, afin d'avoir la même hygiène Git dans tous mes projets.
- **US-5** — En tant que Soon, je veux gérer dépôt distant, pull requests et CI avec des points de validation, afin de ne rien publier sans accord.
- **US-6** — En tant que Soon, je veux reprendre un travail interrompu depuis ce qui est sur disque, afin de ne rien perdre après une limite d'usage ou un crash.
- **US-7** — En tant que Soon, je veux diagnostiquer une panne inattendue (build, test, CI) par la preuve, afin de corriger la cause racine et non le symptôme.
- **US-8** — En tant que Soon, je veux découper une fonctionnalité produit en lots par partie, ordonnés et mandatés, afin que chaque plugin spécialisé sache exactement quoi faire.
- **US-9** — En tant que Soon, je veux exécuter un plan approuvé lot par lot à travers les plugins spécialisés, afin de mener une fonctionnalité multi-parties de bout en bout.
- **US-10** — En tant que Soon, je veux que le contrat d'API entre les parties soit tenu et vérifié, afin que front et back ne divergent jamais silencieusement.
- **US-11** — En tant que Soon, je veux voir l'avancement du projet (parties, mandats, documents, contrat), afin de savoir où j'en suis sans fouiller.
- **US-12** — En tant que Soon, je veux livrer de façon coordonnée (parties vertes, versions cohérentes, changelog, tags), afin que la release soit un acte vérifié, pas un espoir.
- **US-13** — En tant que Soon, je veux des garde-fous déterministes partagés (commandes destructives, secrets, fichiers sensibles, checkpoint, statut des documents), afin qu'ils protègent tous mes projets sans être dupliqués par plugin.

## Critères de succès

1. **Socle (v0.1)** — Un projet mono-partie Flutter mené de bout en bout avec plugin-orchestrator + plugin-flutter allégé : bootstrap, une feature en TDD avec ROUGE puis VERT consignés (commandes et codes de sortie), commit propre, reprise après interruption. Aucun workflow transversal fourni par plugin-flutter, zéro hook en double, sa version majeure publiée avec ses tests verts. Ordre de publication fixé par l'architecture : l'orchestrateur v0.1.0 d'abord, la majeure de plugin-flutter ensuite ; le critère se mesure une fois les deux publiés et installés ensemble.
2. **Coordination (v0.2)** — Un projet deux parties (Flutter + ts-backend, dès que plugin-ts-backend existe) : bootstrap multi-parties, une fonctionnalité découpée en lots par `plan-feature` (contrat → backend → front), exécutée par `run-feature` à travers les deux plugins, et un passage d'`integration-reviewer` sans écart bloquant sur le contrat.
3. **Livraison (v0.3)** — Une release coordonnée : chaque partie verte, versions cohérentes, changelog projet, tags — rien de publié sans accord.
4. **En continu** — La suite de tests du plugin (statiques + hooks sur entrées simulées) verte à chaque version, et `claude plugin validate --strict` à 0 sur les quatre cibles du modèle (plugin, manifeste, agents, skills), marqué bloqué si `claude` manque du PATH.

## Hors périmètre

- **Le code applicatif et tout geste propre à un langage** — tests, lint, build, scaffold d'une partie : le plugin spécialisé le fait ; l'orchestrateur ne porte aucune compétence Flutter/TS/Python. Rien ne rouvre ce point : c'est la définition du plugin.
- **Les workflows internes des plugins spécialisés** — il les invoque avec un mandat, ne les reconfigure ni ne les court-circuite.
- **La gestion de projet hors développement** — tickets externes type Jira, facturation, relation client. Rouvert si un besoin récurrent apparaît sur un vrai projet.
- **Le provisionnement d'infrastructure** — l'orchestrateur coordonne la livraison, mais ne crée ni serveurs ni comptes cloud. Rouvert si une partie « infra » devient un jour un plugin spécialisé.
- **L'adoption d'un projet multi-parties existant** — hors v1. Rouvert une fois la coordination (v0.2) prouvée sur un vrai projet.
- **Hors du modèle plugin-plugin** : code de serveur MCP, channels, output styles, commandes classiques, options de plugin, dépendances de plugin, serveurs de langage. Conséquence concrète : la dépendance des plugins de langage à l'orchestrateur (et inversement) ne se déclare pas — chaque skill vérifie à l'exécution que le plugin requis est activé et s'arrête proprement sinon. Rouvert par une évolution du modèle.

Révision notée : les projets **mono-partie** ne sont **pas** hors périmètre (révisé le 2026-10-23 après l'analyse de plugin-flutter) — l'orchestrateur leur sert de socle ; seules ses skills de coordination exigent au moins deux parties.

## Décisions d'implémentation

- **Nom** : `plugin-orchestrator`, dépôt `soonlysoul/plugin-orchestrator`.
- **Langue des identifiants** : anglais (convention de l'écosystème et de plugin-flutter, que l'orchestrateur invoque). Messages et documents en français.
- **Partage des responsabilités** (validé le 2026-10-23) : l'orchestrateur récupère de plugin-flutter les composants transversaux tels quels (git-workflow, github-workflow sans la pose du gabarit CI, recover-session, product-architect, guard-destructive, secret-scan, protect-sensitive, checkpoint-reminder, lexer partagé, propriété du format `.forge/`), généralise create-feature et debug-project (squelette paramétré par la `toolchain` de chaque partie), et porte en propre la coordination multi-parties. plugin-flutter est allégé en version majeure et devient dépendant de l'orchestrateur.
- **Dossier d'état** : `.forge/` est conservé (continuité avec les projets plugin-flutter existants et leurs hooks) ; son schéma passe en version 2 (section `parts`).
- **Interface de délégation versionnée** : le contrat entre l'orchestrateur et les plugins de langage (mandats entrants, rapports sortants) porte un numéro de version, déclaré dans la configuration des parties et répété dans chaque rapport d'agent ; une version absente ou différente arrête le workflow en nommant le plugin incompatible. Spécifiée dans l'architecture (« Contrat de délégation »).

## Décisions déléguées

Aucune à ce jour.

## Notes complémentaires

- plugin-flutter doit publier une version majeure : retrait des composants remontés, vérification à l'exécution de la présence de l'orchestrateur, écho de la version d'interface dans les rapports de ses agents, retrait de ses copies de hooks dans la même release (sinon doubles exécutions). Tant qu'un plugin-flutter pré-migration (0.x) est installé, les hooks tournent en double — sans danger (mêmes blocages), mais plus lent — et l'orchestrateur refuse de déléguer (pas d'écho d'interface) en demandant la mise à jour : état transitoire, résolu en mettant à jour plugin-flutter.
- plugin-ts-backend (cadrage à peine entamé) et plugin-python (dossier vide) se cadreront **mince** : scaffold, architecte langage, test-engineer, code-reviewer, outillage deps, gabarit CI — tout le reste viendra de l'orchestrateur.
- Le critère de succès v0.2 dépend de l'existence de plugin-ts-backend ; il ne bloque pas la v0.1.
- Version minimale de Claude Code à vérifier à la création : plugin-flutter exige 2.1.295 (`onFailure` des hooks) ; l'orchestrateur héritera au moins de cette contrainte.
