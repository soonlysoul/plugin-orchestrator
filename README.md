# plugin-orchestrator

Drives a software project from zero to delivery through project-level documents, shared Git, GitHub, TDD, recovery and debugging workflows, and multi-part coordination, delegating all language-specific work to the specialized plugins.

Version **0.1.0**, en construction : la charpente est posée par plugin-plugin, aucun composant n'est encore livré. Le cadrage approuvé est dans [docs/PRD.md](docs/PRD.md) et [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ; l'avancement, dans [PROGRESS.md](PROGRESS.md). Claude Code **2.1.295 ou plus** requis.

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
