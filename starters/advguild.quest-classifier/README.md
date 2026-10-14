# Quest Classifier

A low-code UiPath agent that sorts a fantasy RPG quest into one of four difficulty tiers (`Trivial`, `Standard`, `Heroic`, or `Legendary`) and explains its reasoning in two sentences.

This is the completed artifact from [Building a Low-Code Agent in Studio Web](../../labs/agents-lowcode/guide.md). Use it when you want a running Quest Classifier without walking through that lab, for example as the starting point for [Adding Tools to Your UiPath Agent](../../labs/agents-tools/guide.md).

## What's inside

- **`Quest-Classifier-Agent/`** - agent source: `agent.json` (system prompt, schemas, model settings), `entry-points.json`, `evals/`, and Studio Web metadata.
- **`AdvGuild.quest-classifier.uipx`** - solution manifest. Contains project UUIDs, no tenant information.
- **`resources/solution_folder/`** - solution-level resources.

The agent has **no tools**, on purpose. Its system prompt tells it to classify from the quest description alone and not to use tools. If you add a tool (as the tools lab does), replace the system prompt in full rather than appending to it, or the agent will keep refusing to call the tool.

The `evals/` folder contains the evaluation set built in the lab: five test cases saved from debug runs, scored with the semantic similarity evaluator (**Default Evaluator**). A trajectory evaluator is defined but not attached to the set.

## Prerequisites

- **UiPath account** - sign up or log in to [UiPath Automation Cloud](https://cloud.uipath.com).
- **Node.js 18+**.
- **UiPath CLI**, installed globally:

  ```bash
  npm install -g @uipath/cli
  ```

## Deploy it to your tenant

From this directory (`starters/advguild.quest-classifier/`):

```bash
uip login
uip solution upload .
```

This imports the agent as an editable project in Studio Web. Uploading into a tenant that already has this solution overwrites it rather than creating a copy.

## Test it in Studio Web

1. Open [UiPath Automation Cloud](https://cloud.uipath.com), then **Studio Web**, then the **AdvGuild.quest-classifier** solution.
2. Select **Debug** and enter this quest as `questDescription`:

   ```text
   Slay the ancient red dragon terrorizing the countryside.
   ```

3. The agent returns a `tier` of `Legendary`, with two sentences of reasoning.

## Evaluation set

| Case | Quest | Expected tier |
|---|---|---|
| `trivial-rats` | Clear the rats out of the inn cellar. They are loud and they are eating all of the cheese. | Trivial |
| `legendary-dragon` | Slay the ancient red dragon terrorizing the countryside. | Legendary |
| `trivial-letter` | Deliver a sealed letter to the magistrate in the next town. | Trivial |
| `standard-caravan` | Escort a merchant caravan through the hill country to the coast. | Standard |
| `heroic-relic` | Recover a stolen relic from a noble's estate. The guards are many, the owner is powerful, and nobody who has tried has come back. | Heroic |

## Schema reference

**Input:**

| Field | Type | Description |
|---|---|---|
| `questDescription` | string | The quest description to classify |

**Output:**

| Field | Type | Description |
|---|---|---|
| `tier` | string | Exactly one of `Trivial`, `Standard`, `Heroic`, or `Legendary` |
| `reasoning` | string | Two sentences covering the quest's difficulty and the likely monster or threat |

**Model:** `gpt-5.6-terra`, `temperature: 0`, basic-v2 engine.
