# Monster Selector

A low-code UiPath agent that picks the most thematically appropriate monster for a D&D quest. Given a quest description and a list of candidate monsters, it returns the `index` slug of the best fit. It is intended to be run along with calls to a D&D 5e API service - to select the best match from API search results.

This is the completed artifact from [Getting Started with Agents using the CLI](../../Getting-Started-With-CLI-and-Agents/Getting-Started-With-CLI-and-Agents.md). Use it when you want a running Monster Selector without walking through the full lab - for example, as the starting point for the upcoming Agent Evals lab.

## What's inside

- **`Agent/`** - agent source: `agent.json` (system prompt, schemas, model settings), `entry-points.json`, `evals/`, `resources/`, and Studio Web metadata
- **`resources/solution_folder/`** - solution-level resources

`SolutionStorage.json` and `MonsterSelector.uipx` are intentionally omitted so the starter is tenant-neutral and source-of-truth is unambiguous - your first `uip agent push` creates fresh cloud mappings in your own tenant and regenerates any packaged artifacts as needed.

## Prerequisites

- **UiPath account** at [cloud.uipath.com](https://cloud.uipath.com)
- **Node.js 18+**
- **UiPath CLI + agent tool** installed globally:

  ```bash
  npm install -g @uipath/cli
  uip tools install agent-tool
  ```

## Deploy it to your tenant

From this directory (`starters/monster-selector/`):

```bash
uip login
uip agent push
```

The push command writes a new `SolutionStorage.json` with your tenant's `SolutionId` and `CloudProjectId`, then imports the agent as a **source project in Studio Web** - editable, testable, and ready for evals.

## Test it in Studio Web

1. Open [cloud.uipath.com](https://cloud.uipath.com) → **Studio** → **MonsterSelector**.
2. Click **Test** in Agent Builder and paste:

   ```json
   {
     "questDescription": "A wealthy merchant's caravan has been attacked by a massive creature while crossing the harbor. Eyewitnesses report tentacles, terrible hypnotic powers, and strange psychic disturbances for miles around.",
     "monsters": [
       {"index": "aboleth", "name": "Aboleth"},
       {"index": "kraken", "name": "Kraken"},
       {"index": "giant-octopus", "name": "Giant Octopus"},
       {"index": "sea-hag", "name": "Sea Hag"},
       {"index": "dryad", "name": "Dryad"}
     ]
   }
   ```

3. The agent returns a `monsterIndex`. `"aboleth"` and `"kraken"` are both defensible picks.

## Using it from the Evals lab

The upcoming Agent Evals lab assumes this agent is already pushed to your tenant. If you completed the CLI-and-Agents lab, you're ready. If you deployed from this starter instead, the lab's first step ("confirm you have a pushed MonsterSelector") is already satisfied.

## Schema reference

**Input:**

| Field | Type | Description |
|---|---|---|
| `questDescription` | string | Description of the quest |
| `monsters` | array | Candidate monsters (each with `index` and `name`) from the D&D 5e API |

**Output:**

| Field | Type | Description |
|---|---|---|
| `monsterIndex` | string | The `index` slug of the chosen monster |

**Model:** `gpt-4o-2024-11-20`, `temperature: 0`, basic-v2 engine.
