# Installation — plugin-orchestrator

Claude Code **2.1.295 ou plus** requis.

## Essai sans installation

Depuis la racine d'un clone :

```bash
claude --plugin-dir .
```

Le plugin vaut pour cette session seule, sous le nom `plugin-orchestrator@inline`.

## Depuis la marketplace `soon`

Une fois le plugin publié :

```bash
claude plugin marketplace update soon
claude plugin install plugin-orchestrator@soon
```

Mise à jour : `claude plugin marketplace update soon`, puis `claude plugin update plugin-orchestrator@soon`.

## Portée des hooks

Installé pour le compte, chaque hook de ce plugin s'applique à toutes les sessions, dans tous les projets ; chacun reste inerte hors de son contexte.

- `guard-destructive` — PreToolUse (Bash|PowerShell|Monitor), fail-closed.
- `secret-scan` — PreToolUse (Bash|PowerShell|Monitor), fail-closed.
- `protect-sensitive` — PreToolUse (Edit|Write|NotebookEdit), fail-closed.
- `checkpoint-reminder` — Stop, fail-open.
- `agent-scope-guard` — PreToolUse (Edit|Write|NotebookEdit|Bash|PowerShell|Monitor), fail-closed.
- `doc-status-guard` — PostToolUse (Edit|Write), fail-open.
