# Getting Started with Agent Evals

In this workshop, you will use the UiPath CLI to build an evaluation set for `UiPathfinder.QuestParser`, run the evaluations in the cloud against your pushed agent, and use the results to drive prompt iteration. You will do the following:

1. Confirm you have a pushed `UiPathfinder.QuestParser` agent
2. Explore the default evaluation set that ships with every agent
3. Add six test cases covering happy paths and edge cases
4. Run the evaluation set and interpret the scores
5. *(Optional)* Refine the agent's prompt based on failures and compare runs to verify improvement

The goal of this lab is to go beyond eval basics and explore how evals drive iteration. By the end you will understand the feedback loop that turns a brittle prompt into a robust one: evals surface weaknesses, you refine the prompt, re-run, and compare the results side by side to verify the change actually helped.

**Estimated time:** 30-45 minutes (25 min core + 15 min optional iteration section)


## What we are building

You will take `UiPathfinder.QuestParser` from the [Adding Tools to Your UiPath Agent](../labs/agents-tools/guide.md) lab and subject it to a small but diverse evaluation set.

Because QuestParser uses a tool - it searches for monsters, then selects from the results - the evaluation has two layers of signal:

- **Trajectory** - did the agent search for the right thing? Did it call the tool before selecting?
- **Output quality** - did it pick the best candidate from the results?

The test cases will deliberately include:

- **Happy-path quests** where the right monster type is obvious and the tool returns a clear best match
- **Ambiguous quests** where multiple candidates are reasonable and the agent must reason carefully
- **Edge cases** that the agent's current prompt was never designed to handle - unusual quest descriptions, monsters at the edge of the CR range, thematically mismatched results

The edge cases will be the interesting part of this lab: the agent will fail them on the first run, and that failure is the starting point for iteration.


* * *

## Prerequisites

This lab assumes you have the following:

- **CLI version** - validated against UiPath CLI v0.9.1. Check your version using `uip --version`. Different versions may behave differently; report drift with `uip feedback send`.
- **Output format** - `uip` supports `--output {table,json,yaml}`, and defaults vary by command in v0.9.1. This lab shows JSON output because it exposes structure (IDs, nested fields) that the prose references. If you prefer tables for readability while walking through, append `--output table` to any command.
- **UiPath account** - sign up or log in at [cloud.uipath.com](https://cloud.uipath.com) before starting.
- **Node.js 18+** - required to install the UiPath CLI. Check with `node --version`. Download from [nodejs.org](https://nodejs.org/) if needed.
- **Bash terminal** - the commands in this lab use Bash syntax. In VS Code, open a new terminal and select **Git Bash** (or equivalent) as the terminal type.
- **A deployed QuestParser agent** - this lab picks up where [Adding Tools to Your UiPath Agent](../labs/agents-tools/guide.md) left off. See the two options below for getting the agent.


## Getting the QuestParser Agent

This lab starts from `UiPathfinder.QuestParser` already uploaded to your UiPath Studio Web. You have two options:

**Option A: You just finished the [Adding Tools to Your UiPath Agent](../labs/agents-tools/guide.md) lab.**
You already have a deployed QuestParser. Open a terminal in your `UiPathfinder/` solution root and skip to Step 1.

**Option B: Start fresh from the QuestParser starter.**
Clone this repository, move into the starter, authenticate, and upload:

```bash
git clone https://github.com/cliff-simpkins/UiPath-Workshops.git
cd UiPath-Workshops/starters/uipathfinder-quest-parser
uip login
uip solution upload .
```

The upload deploys the solution to your Studio Web. All subsequent `uip agent eval` commands use the solution ID written to `SolutionStorage.json` automatically.


* * *


# Workshop: Agent Evals


## Step 1 - Set Up Your Evaluation Infrastructure

An evaluation run has three ingredients: an **agent** (the thing being tested), **evaluators** (how each test case is scored), and an **evaluation set** (the collection of test cases plus which evaluators to apply). You will set up the evaluators and the evaluation set now; test cases come in Steps 2 and 3.

Before you begin, confirm the slate is clean:

```bash
uip agent eval set list
uip agent eval evaluator list
```

Both should return `"No evaluation sets found"` and `"No evaluators configured"`. Your QuestParser was deployed without any evaluation infrastructure - you are about to add it.

### Pick your evaluators

UiPath's CLI ships four evaluator types:

| Type | What it does |
|---|---|
| `semantic-similarity` | Uses an LLM judge to score how closely the agent's actual output matches the expected output on a 0-100 scale. Tolerates synonyms and reasonable variation, but demands the right fields contain the right values. |
| `trajectory` | Scores the agent's *reasoning path* - which tools it called, in what order. Designed for multi-step agents. |
| `context-precision` | Scores whether retrieved context passages are relevant to the question. Used for RAG agents. |
| `faithfulness` | Scores whether the agent's output is grounded in the context it retrieved. Also for RAG. |

For this lab you will use `semantic-similarity` (is the agent picking the right monster?) and `trajectory` (is it reasoning the right way?).

### Create the two evaluators

```bash
uip agent eval evaluator add "Semantic Evaluator" --type semantic-similarity
uip agent eval evaluator add "Trajectory Evaluator" --type trajectory
```

Each command returns JSON confirming the add and the evaluator's ID.

Verify both landed:

```bash
uip agent eval evaluator list
```

You should see two evaluators in the output, one per type.

### Create the evaluation set

Create an evaluation set. Without `--evaluators`, the set attaches to every evaluator you have created:

```bash
uip agent eval set add "Default Evaluation Set"
```

Confirm:

```bash
uip agent eval set list
```

You should see one set named **Default Evaluation Set**, with **0 evaluations** (test cases) and **2 evaluators**.

> **About the trajectory evaluator.** The agent in this lab is a single-step agent (no tool calls, no multi-step reasoning), so the trajectory evaluator will score 0 or "Error" on every run. This is expected - trajectory evaluation shines on agents that route between tools or nodes, and a classifier-style agent has no trajectory to evaluate. We will focus on the Semantic Evaluator's scores in this lab.

<!-- screenshot: step-01.png - terminal output showing evaluators + eval set created -->


## Step 2 - Add the First Three Test Cases (Happy Path)

You will add test cases one at a time using `uip agent eval add`. Each command creates a named test case that belongs to an evaluation set. The test case bundles an input to send to the agent and an expected output for the evaluator to compare against.

**Test 1 - Iconic aboleth match.** A harbor quest with tentacles and hypnotic powers. The aboleth is the iconic D&D tentacled psychic horror, so the agent should pick it.

```bash
uip agent eval add "iconic-match-aboleth" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"A merchant caravan has been attacked by a massive tentacled creature with hypnotic powers in the harbor","monsters":[{"index":"aboleth","name":"Aboleth"},{"index":"kraken","name":"Kraken"},{"index":"giant-octopus","name":"Giant Octopus"}]}' \
  --expected '{"monsterIndex":"aboleth"}'
```

**Test 2 - Iconic dragon match.** A fire-breathing beast terrorizing villages in the northern kingdoms. The ancient red dragon is the iconic choice over hell hounds or salamanders.

```bash
uip agent eval add "iconic-match-dragon" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"A fire-breathing beast terrorizes villages in the northern kingdoms, razing towns and hoarding gold","monsters":[{"index":"ancient-red-dragon","name":"Ancient Red Dragon"},{"index":"hell-hound","name":"Hell Hound"},{"index":"salamander","name":"Salamander"}]}' \
  --expected '{"monsterIndex":"ancient-red-dragon"}'
```

**Test 3 - Ambiguous hag choice.** Multiple hags could plausibly fit, but the night hag is thematically strongest for moon-worship and child-abduction scenarios (they're literally night-dwelling soul harvesters).

```bash
uip agent eval add "ambiguous-hags" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"A moon-worshipping coven has been abducting village children under every full moon","monsters":[{"index":"sea-hag","name":"Sea Hag"},{"index":"night-hag","name":"Night Hag"},{"index":"green-hag","name":"Green Hag"},{"index":"dryad","name":"Dryad"}]}' \
  --expected '{"monsterIndex":"night-hag"}'
```

Each command emits JSON confirming the add (`"Status": "Evaluation added"`) and returns the new test case ID.


## Step 3 - Add the Three Edge-Case Test Cases

These three test cases probe behavior the agent's current prompt was never designed for. You expect them to fail on the first run - that is the whole point. Fixing them is what the optional iteration section teaches.

**Test 4 - No meaningful match.** A stealth-and-infiltration quest paired with only large, loud monsters. No candidate fits the mission profile. The agent *should* signal this rather than picking a random one.

```bash
uip agent eval add "no-meaningful-match" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"Infiltrate the merchant guildhall and retrieve stolen trade documents without being detected","monsters":[{"index":"ancient-red-dragon","name":"Ancient Red Dragon"},{"index":"storm-giant","name":"Storm Giant"},{"index":"tarrasque","name":"Tarrasque"}]}' \
  --expected '{"monsterIndex":"none"}'
```

**Test 5 - Empty candidate list.** A valid quest description, but no monsters to choose from. Agent should return a graceful signal rather than fabricating an index.

```bash
uip agent eval add "empty-candidates" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"Hunt down the werewolf stalking travelers on the forest road","monsters":[]}' \
  --expected '{"monsterIndex":"none"}'
```

**Test 6 - Missing quest description.** An empty quest string with valid candidates. Agent has no context to reason from; it should return an error signal.

```bash
uip agent eval add "missing-quest" --set "Default Evaluation Set" \
  --inputs '{"questDescription":"","monsters":[{"index":"goblin","name":"Goblin"},{"index":"orc","name":"Orc"}]}' \
  --expected '{"monsterIndex":"error"}'
```

Verify all six test cases landed:

```bash
uip agent eval list --set "Default Evaluation Set"
```

You should see six entries, each with a name matching what you typed above.

<!-- screenshot: step-03.png - eval list showing 6 test cases -->


## Step 4 - Re-Push the Agent

> **Critical step - do not skip.** Evaluations run in the cloud against your pushed agent, but the six test cases you just added live in the *local* copy of your evaluation set. You must re-push the agent so the cloud sees them. If you skip this step, the eval run will complete with `"Status": "failed"` and `"TestCases": 0`, and you will spend several confused minutes figuring out why.

```bash
uip agent push
```

The push output should include a new `SolutionId` and `CloudProjectId`. Each push creates a new solution version in Studio Web - that is expected behavior, not a bug.


## Step 5 - Run the Evaluation Set

Start the eval run and wait for completion:

```bash
uip agent eval run start --set "Default Evaluation Set" --wait --timeout 180
```

The `--wait` flag polls for completion and prints progress messages (`pending`, `running`, and then `completed`). Expect the run to take 60-120 seconds for six test cases. The `--timeout 180` flag caps the polling at three minutes.

When the run finishes, the CLI prints two blocks:

- **AgentEvalRunCompleted** - the overall run status (completed or failed), aggregate score, duration, and a per-evaluator breakdown
- **AgentEvalRunResults** - a per-test-case summary showing each test case's score, evaluator breakdown, and any error

Take note of the `EvalSetRunId` in the `AgentEvalRunStarted` block. You will use this ID later to look at detailed results and (in the optional section) to compare against a second run.

<!-- screenshot: step-05.png - terminal output showing eval run completed with per-test scores -->


## Step 6 - Interpret the Results

Look at the per-test-case scores. You should see something like this:

| Test case | Semantic Evaluator | Interpretation |
|---|---|---|
| iconic-match-aboleth | ~100 | Happy path, agent picked correctly |
| iconic-match-dragon | ~100 | Happy path, agent picked correctly |
| ambiguous-hags | ~70-100 | Depends on which hag the agent picked - night-hag scores high, others partial |
| no-meaningful-match | low | Agent picked a dragon/giant/tarrasque; evaluator expected `"none"` |
| empty-candidates | low | Agent likely returned an empty or made-up index |
| missing-quest | low | Agent produced an output despite no input |

To see *why* each failed test scored low, re-fetch the results with the verbose flag. Include the evaluator's justification text:

```bash
uip agent eval run results <EvalSetRunId> --set "Default Evaluation Set" --verbose
```

Replace `<EvalSetRunId>` with the ID from Step 5. You will see the evaluator's natural-language explanation for each score - for the edge-case tests, the explanations will tell you *what the agent returned* versus *what was expected*, which is exactly the information you need to fix the prompt.

To narrow down to just the failing cases:

```bash
uip agent eval run results <EvalSetRunId> --set "Default Evaluation Set" --only-failed --verbose
```

> **Expect non-determinism.** Even with `temperature: 0`, the agent may produce slightly different outputs across runs. Scores on the ambiguous test in particular may fluctuate between runs. For a pass/fail signal on a specific case, look at the 0-100 score rather than expecting a specific string.

<!-- screenshot: step-06.png - verbose results showing evaluator justifications -->


## Step 7 - View Results in Studio Web *(optional)*

The CLI output covers every data point you need, but Studio Web visualizes results across runs over time. Open your QuestParser agent in [cloud.uipath.com](https://cloud.uipath.com), navigate to its Evaluations panel, and you will see:

- Score trend chart across all eval runs
- Trace drill-down for each individual test case (what the agent saw, what it returned, what the evaluator judged)
- Side-by-side version comparison

This is where evals earn their keep for a developer: not as a single number per run, but as a comparative view that shows whether your prompt changes are actually improving the agent over time.

<!-- screenshot: step-07.png - Studio Web evaluation panel with score trend -->


* * *


# Optional: Iterate to Fix the Failures

The first eval run gave you a baseline. Now you will refine the agent's prompt to handle the three edge cases, re-push, re-run, and compare the two runs side by side to verify the change helped.


## Step 8 - Refine the System Prompt

The current prompt tells the agent how to pick a monster, but says nothing about what to do when the inputs are degenerate. Add three rules to handle the edge cases:

```bash
uip agent config set systemPrompt "You are an RPG game master helping to select the most thematically appropriate monster for a quest. Given a quest description and a list of candidate monsters (each with a name and an index slug), pick the ONE monster whose lore, environment, or threat level best fits the quest. Return ONLY the index slug of your chosen monster. Do not return the full object or any commentary - just the string slug. If multiple candidates fit, favor the most iconic or thematically resonant choice. Handle edge cases as follows: (1) If no candidate meaningfully fits the quest, return 'none'. (2) If the monsters array is empty, return 'none'. (3) If the questDescription is missing or empty, return 'error'."
```

Verify the update:

```bash
uip agent config get systemPrompt
```


## Step 9 - Re-Push and Re-Run

Push the updated agent, then run the same eval set again:

```bash
uip agent push
uip agent eval run start --set "Default Evaluation Set" --wait --timeout 180
```

Capture the new `EvalSetRunId` - you will need both IDs for the comparison in Step 10.

The tests 4, 5, and 6 should now score significantly higher: the agent has explicit rules for the edge cases and will return `"none"` or `"error"` as the evaluator expects.


## Step 10 - Compare the Two Runs

Use `eval run compare` to see the delta between your baseline run and the refined run:

```bash
uip agent eval run compare <FIRST_EvalSetRunId> --compare-to <SECOND_EvalSetRunId> --set "Default Evaluation Set"
```

The output shows each test case side by side - baseline score versus refined score - so you can see at a glance which tests moved and by how much.

To list all runs you have completed if you forgot the IDs:

```bash
uip agent eval run list --set "Default Evaluation Set"
```

> **This is the feedback loop.** Eval surfaced a weakness - the agent mis-handled three edge cases. You refined the prompt. The eval shows the fix worked, with a comparable baseline to prove it. That loop - measure, refine, re-measure - is what makes evals load-bearing for a developer rather than a box to check at deployment time.


## Step 11 - Export Results for Your Team *(optional)*

If you want to share results outside the terminal (PR review, retro, CI pipeline), export them to CSV or JSON:

```bash
uip agent eval run results <EvalSetRunId> --set "Default Evaluation Set" --export-format csv
uip agent eval run results <EvalSetRunId> --set "Default Evaluation Set" --export-format json
```

The exported file lands in your working directory.


* * *


## Congratulations!

You've built an evaluation set, driven a feedback loop, and shipped measurable improvement to an agent:

- You added six test cases covering happy paths and deliberate edge cases using `uip agent eval add`
- You ran the evaluation against your pushed agent and inspected per-test-case scores with `--only-failed --verbose`
- You refined the agent's system prompt to address the failures the evaluator surfaced
- You verified the improvement by comparing two runs side by side

The key commands you used:

| Command | What it does |
|---|---|
| `uip agent eval set list` | List all evaluation sets for your agent |
| `uip agent eval list --set <name>` | List test cases in a set |
| `uip agent eval add <name> --set <name> --inputs --expected` | Add a test case |
| `uip agent eval run start --set <name> --wait` | Run the eval set in the cloud and wait for completion |
| `uip agent eval run results <id> --set <name> --verbose` | Get detailed per-test-case results with evaluator justifications |
| `uip agent eval run results <id> --set <name> --only-failed` | Filter to only the failing test cases |
| `uip agent eval run compare <id> --compare-to <id> --set <name>` | Compare two runs side by side |
| `uip agent eval run list --set <name>` | List all runs for an eval set |
| `--export-format csv` or `json` | Export results to a file |


## What's Next

- **Orchestration patterns** *(future lab)* - your evaluated agent is ready to be called from API workflows, UiPath Flow projects, or other agents. A future workshop will cover invoking it from an orchestration and running evals across the orchestration.
- **Build richer agents** - QuestParser uses a single tool call. Your next agent might call multiple tools, pull in RAG context, or chain multiple reasoning steps. Each of those introduces new eval patterns: multi-tool trajectory scoring, retrieval quality, and composite evaluators.
- [UiPath Agents documentation](https://docs.uipath.com) - full reference for low-code and coded agent capabilities
- [UiPath Community](https://community.uipath.com) - forums, how-tos, and developer discussion
- **Hit a snag?** Run `uip feedback send` to report a bug or improvement directly from the CLI.
