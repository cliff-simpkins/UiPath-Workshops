# Starters

Reusable UiPath artifacts - agents, workflows, and solutions - that the workshops and guides in this repo produce or consume. You can use these when a lab's entry path says "clone the starter" or when you want a running reference without walking through the full lab.

## Current starters

| Starter | Type | Produced by | Consumed by |
| --- | --- | --- | --- |
| [monster-selector](monster-selector/) | Low-code agent | [Getting Started with UiPath Agents](../labs/agents/guide.md) | [Getting Started with Agent Evals](../Getting-Started-With-Agent-Evals/Getting-Started-With-Agent-Evals.md) |
| [monster-query-api](monster-query-api/) | API Workflow package | Pre-built | Future Maestro lab (participants build this themselves in [Adding Tools to Your UiPath Agent](../labs/agents-tools/guide.md)) |

## How to use a starter

Every starter includes a `README.md` with exact commands. The common pattern:

```bash
# from this repo's root
cd starters/<name>
uip login
uip solution upload .   # or the deployment command listed in the starter's README
```

Starters are **tenant-neutral** - no `SolutionStorage.json` or cloud project IDs are committed. The first `push` (or equivalent) creates fresh mappings in your own tenant.

## Adding a new starter

When a workshop produces a reusable artifact - or Klara the Kobold summons forth a new automation assistant - it will be here with its own subfolder and `README.md`. For those wishing to contribute, be sure to keep tenant-specific files (`SolutionStorage.json`, `.env`, local caches) out of the commit.
