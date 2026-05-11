# Getting Started with Agents using the CLI

In this workshop, you will use the UiPath command line interface (CLI) to build a low-code agent from scratch - without opening UiPath Studio until the final step. You will do the following:

1. Install the UiPath CLI, skills, and the agent tool
2. Scaffold a new solution and low-code agent project
3. Set the system prompt that drives the agent's behavior
4. Define the agent's input and output schemas
5. Validate the agent and upload it to UiPath Studio Web
6. Test the agent in Studio Web with a real scenario

**Estimated time:** 30-45 minutes


## What you are building

This lab walks you through building a **Monster Selector** - a low-code agent for a fictional Adventurer's Guild in a fantasy role-playing game (RPG) world. The agent picks the most thematically appropriate monster for a quest from a list of candidates. It is deliberately simple so the focus stays on the CLI workflow, not the domain logic. This same agent is used in the companion [Getting Started with Agent Evals](../Getting-Started-With-Agent-Evals/Getting-Started-With-Agent-Evals.md) workshop.

> **Feel free to adapt the lab**
>
> You can follow along with the Monster Selector example or adapt it to your own use case. To customize it, you only need to adjust three things: the system prompt, your input fields, and your output fields. The rest of the lab works the same way for almost any single-turn classification or selection scenario.


* * *

## Prerequisites

- **UiPath CLI v0.9.1** - installed in Step 1. Different versions may behave differently; if commands produce unexpected output, check your version with `uip --version` and report drift with `uip feedback send`.
- **UiPath account** - sign up or log in at [cloud.uipath.com](https://cloud.uipath.com) before starting.
- **Node.js 18+** - required to install the CLI. Check with `node --version`. Download from [nodejs.org](https://nodejs.org/) if needed.
- **A terminal** - PowerShell or Bash both work. The commands in this lab are shell-agnostic.
- **Admin rights** - installing global npm packages requires elevated permissions. Confirm you can run `npm install -g` before starting.

No prior UiPath experience is required.

> **What this lab does not need.** Unlike the coded agent lab, this lab does not require Python, `uv`, or a coding agent. Low-code agents are configured entirely with a system prompt and JSON schemas - no code.


* * *

# Build an Agent using the CLI

## Step 1 - Install the UiPath CLI and Agent Tool

The UiPath CLI (`uip`) is a cross-platform tool for UiPath authentication, project scaffolding, and deployment. It uses a plugin system - the base CLI handles auth, and you install tools for the project types you build.

Install the base CLI globally:

```bash
npm install -g @uipath/cli
```

Verify the installation:

```bash
uip --version
```

You should see `0.9.1` or later.

Now install the agent tool, which adds the `uip agent` command group used throughout this lab:

```bash
uip tools install agent-tool
```

Confirm it installed:

```bash
uip tools list
```

You should see `agent-tool` in the output.

<!-- screenshot: step-01.png - terminal showing uip --version and tools list output -->

* * *

## Step 2 - Install UiPath Skills for Your Coding Agent *(optional)*

If you are using a coding agent (Claude Code, Cursor, Copilot, etc.) alongside the CLI, installing the UiPath skills gives it knowledge of agent project structure, CLI commands, and best practices. Every command in this lab is spelled out explicitly - skipping this step does not affect the walkthrough - but skills make it faster to troubleshoot or extend the agent afterward.

```bash
uip skills install --agent claude
```

Replace `claude` with your agent if you are using a different one: `cursor`, `copilot`, `gemini`, or `codex`.

Skills install globally to your home directory (e.g., `~/.claude/skills/` for Claude Code) and are available in every project from this point forward.

* * *

## Step 3 - Authenticate to UiPath

Authenticate the CLI to your UiPath account:

```bash
uip login
```

This opens a browser window where you sign in and select your tenant. Once complete, the terminal confirms you are logged in.

Verify your login status at any time with:

```bash
uip login status
```

You should see `"Status": "Logged in"` along with your organization and tenant name.

<!-- screenshot: step-03.png - terminal showing login status output -->

* * *

## Step 4 - Scaffold the Solution and Agent

Low-code agents live inside a **solution** - the deployable unit the CLI uploads to Studio Web. You create the solution first, then scaffold the agent inside it.

Create a working directory and scaffold the solution:

```bash
mkdir Monster-Selector-Lab
cd Monster-Selector-Lab
uip solution new MonsterSelector
```

This creates a `MonsterSelector/` directory containing `MonsterSelector.uipx` - the solution manifest.

Now scaffold the agent project inside the solution directory:

```bash
uip agent init MonsterSelector/MonsterSelector
```

`uip agent init <path>` creates the agent project at the given path. It generates `agent.json` (the system prompt, schemas, and model settings), `entry-points.json`, an empty `evals/` scaffold, and an auto-generated project ID.

Move into the solution directory and register the agent with the solution:

```bash
cd MonsterSelector
uip solution project add MonsterSelector
```

You should see `"Status": "Added successfully"`. This step is required - `uip agent init` does not reliably auto-register the project with the solution in the current CLI version.

<!-- screenshot: step-04.png - terminal showing solution new, agent init, and project add output -->

> **Two directories named MonsterSelector.** Your lab directory now contains `MonsterSelector/` (the solution) which in turn contains another `MonsterSelector/` (the agent project). This is normal - the solution and the agent project can share a name. As you work through the next steps, pay attention to which directory you are in. Step 4 ends with you inside the solution directory (`Monster-Selector-Lab/MonsterSelector/`).

* * *

## Step 5 - Set the System Prompt

The system prompt defines the agent's behavior - its persona, the rules it follows, and the output format it must return. Move into the agent directory and set it:

```bash
cd MonsterSelector
uip agent config set systemPrompt "You are an RPG game master helping to select the most thematically appropriate monster for a quest. Given a quest description and a list of candidate monsters (each with a name and an index slug), pick the ONE monster whose lore, environment, or threat level best fits the quest. Return ONLY the index slug of your chosen monster. Do not return the full object or any commentary - just the string slug. If multiple candidates fit, favor the most iconic or thematically resonant choice."
```

Verify it was stored:

```bash
uip agent config get systemPrompt
```

You should see the prompt text returned under `"Value"`.

> **Adapting the prompt to your use case:** swap the RPG game master persona for your domain (a triage nurse picking a specialist, a procurement officer matching vendors, a librarian recommending books), and replace the selection rules with the behavior you want. The more specific the instructions and output format, the better your agent will perform. The input and output fields you define in the next two steps should match what your prompt refers to.

<!-- screenshot: step-05.png - terminal showing config set and config get output -->

* * *

## Step 6 - Define the Input Schema

A Monster Selector needs two inputs: the **quest description** and the **list of candidate monsters**. Add them now (you are still inside the agent directory from Step 5):

```bash
uip agent input add questDescription --type string --description "Description of the quest"
```

```bash
uip agent input add monsters --type array --description "Candidate monsters from the D&D 5e API"
```

Remove the placeholder input that came with the scaffold:

```bash
uip agent input remove input
```

Each command returns JSON confirming the change. The changes are written to both `agent.json` and `entry-points.json`.

> **Adapting to your use case:** replace `questDescription` and `monsters` with the input fields your domain requires - for example, `patientSymptoms` and `specialistList`, or `vendorRequirements` and `candidateVendors`.

<!-- screenshot: step-06.png - terminal showing input add and input remove output -->

* * *

## Step 7 - Define the Output Schema

The agent returns a single value: the **index slug** of the chosen monster (e.g., `"aboleth"` or `"kraken"`). The caller uses this slug to look up full monster data from an API.

Add the output:

```bash
uip agent output add monsterIndex --type string --description "The index slug of the chosen monster"
```

Remove the placeholder output:

```bash
uip agent output remove content
```

<!-- screenshot: step-07.png - terminal showing output add and output remove output -->

* * *

## Step 8 - Fix the User Message (Workaround)

**This step corrects a known bug in `uip agent input add`.** Skip it and validation in the next step will fail with errors like `Expected "questDescription" but got "input.questDescription"`.

When `uip agent input add` writes the user message template into `agent.json`, it produces inconsistent output: the `content` string uses bare variable references (`{{questDescription}}`), but the `contentTokens` array uses the `input.` prefix (`input.questDescription`). These must match, and they do not.

Open `agent.json` inside the agent directory (`Monster-Selector-Lab/MonsterSelector/MonsterSelector/agent.json`) and find the `messages` array. The second entry (the user message) will look like this:

```json
{
  "role": "user",
  "content": "{{questDescription}} {{monsters}}",
  "contentTokens": [
    { "type": "variable", "rawString": "input.questDescription" },
    { "type": "simpleText", "rawString": " " },
    { "type": "variable", "rawString": "input.monsters" }
  ]
}
```

Update `content` to add the `input.` prefix to each variable reference, so the entry reads exactly:

```json
{
  "role": "user",
  "content": "{{input.questDescription}} {{input.monsters}}",
  "contentTokens": [
    { "type": "variable", "rawString": "input.questDescription" },
    { "type": "simpleText", "rawString": " " },
    { "type": "variable", "rawString": "input.monsters" }
  ]
}
```

Save the file. The `contentTokens` array does not need to change - only the `content` string.

> **Report this bug.** Run the following from any directory to file it directly from the CLI:
>
> ```bash
> uip feedback send "uip agent input add writes bare {{fieldName}} in messages[1].content but input.fieldName in contentTokens - these must match and uip agent validate rejects the inconsistency. Repro: uip agent init, uip agent input add <field>, uip agent validate."
> ```

<!-- screenshot: step-08.png - agent.json open in editor showing the corrected user message block -->

* * *

## Step 9 - Validate the Agent

Move back to the solution directory and validate the agent:

```bash
cd ..
uip agent validate MonsterSelector
```

You should see `"Status": "Valid"` with `"StorageVersion": "50.0.0"` and a `"Validated"` summary showing `agent: true`. Validation also generates the `.agent-builder/` files used by Studio Web - you do not need to touch these.

If validation fails, re-check that you applied the `content` fix in Step 8 and that the two variable references both use the `input.` prefix.

<!-- screenshot: step-09.png - terminal showing valid validation output -->

* * *

## Step 10 - Upload to Studio Web

Upload the solution to Studio Web from the solution directory:

```bash
uip solution upload .
```

A successful upload returns `"Status": "Uploaded successfully"` along with a `SolutionId` and a `DesignerUrl` you can open directly in a browser. Your agent now exists as an editable project in Studio Web.

> **Upload vs. deploy.** `uip solution upload` sends the solution to Studio Web as an editable source project - the right target for development and testing. When you are ready to run the agent in production, you would instead use `uip solution pack` + `uip solution publish` to build a versioned package and deploy it to Orchestrator. This lab uses upload.

<!-- screenshot: step-10.png - terminal showing successful upload output with SolutionId -->

* * *

## Step 11 - Test the Agent in Studio Web

1. Log in to [cloud.uipath.com](https://cloud.uipath.com) and open **Studio** from the side menu.

2. Find your **MonsterSelector** project in the project list and click to open it.

   <!-- screenshot: step-11a.png - Studio Web project list showing MonsterSelector -->

3. Studio Web opens the agent in Agent Builder. Confirm you can see:
   - The system prompt in the right panel
   - `questDescription` and `monsters` listed as inputs
   - `monsterIndex` listed as the output

4. Click **Debug** in the top toolbar. In the input panel, paste the following JSON:

   ```json
   {
     "questDescription": "A wealthy merchant's caravan has been attacked near the harbor. Eyewitnesses report tentacles, hypnotic powers, and strange psychic disturbances for miles around.",
     "monsters": [
       {"index": "aboleth", "name": "Aboleth"},
       {"index": "kraken", "name": "Kraken"},
       {"index": "giant-octopus", "name": "Giant Octopus"},
       {"index": "sea-hag", "name": "Sea Hag"},
       {"index": "dryad", "name": "Dryad"}
     ]
   }
   ```

5. Click **Save & Debug** to run the agent.

   <!-- screenshot: step-11b.png - Studio Web debug panel with input JSON entered -->

6. The agent runs and returns a result in the Output panel. The `monsterIndex` output should contain `"aboleth"` or `"kraken"` - both are defensible picks. An aboleth is the iconic tentacled, mind-controlling aquatic horror in D&D lore; a kraken is larger and less cerebral. If the agent returns `"giant-octopus"`, the prompt may need tightening.

   <!-- screenshot: step-11c.png - Studio Web output panel showing monsterIndex result -->

> **Agents are non-deterministic.** Even with `temperature: 0`, the model can produce different outputs across runs. The goal is a defensible pick, not a specific string. Use the next two examples to develop a feel for how the agent reasons - consistent wrong answers are a signal to refine the prompt.

Try these additional inputs:

- `"questDescription": "Clear out the moon-worshipping coven abducting village children under the full moon"` with candidates `"sea-hag"`, `"night-hag"`, `"green-hag"`, `"dryad"` - should return a hag variant
- `"questDescription": "Slay the beast terrorizing the northern kingdoms with fire and ancient cruelty"` with candidates `"ancient-red-dragon"`, `"young-red-dragon"`, `"hell-hound"`, `"salamander"` - should return `"ancient-red-dragon"`

* * *

## Congratulations

You built and published a low-code agent using the UiPath CLI:

- Scaffolded a solution and agent project from the terminal
- Set the system prompt, input schema, and output schema using CLI commands
- Validated the project locally before uploading
- Uploaded to Studio Web and ran a live test

Key commands from this lab:

| Command | What it does |
| --- | --- |
| `uip solution new <name>` | Create a new solution (the deployable container) |
| `uip agent init <path>` | Scaffold a new low-code agent project |
| `uip solution project add <path>` | Register an agent project with its solution |
| `uip agent config set systemPrompt` | Write the system prompt into `agent.json` |
| `uip agent input add` / `output add` | Define input and output parameters |
| `uip agent input remove` / `output remove` | Remove a parameter |
| `uip agent validate <path>` | Validate the agent schema locally before upload |
| `uip solution upload .` | Upload the solution to Studio Web as an editable project |


## What's Next

- **Add a Tool to Your Agent** *(coming soon)* - extend Monster Selector with a tool that calls the D&D 5e API directly, removing the `monsters[]` input and letting the agent decide what to search for. This sets up trajectory evaluation in the Evals lab.
- **[Getting Started with Agent Evals](../Getting-Started-With-Agent-Evals/Getting-Started-With-Agent-Evals.md)** *(coming soon)* - build evaluation sets, run cloud evaluations, and interpret scores against this agent.
- **Orchestration patterns** *(future lab)* - your agent is callable from UiPath Flow projects, API workflows, and other agents.
- [UiPath Agents documentation](https://docs.uipath.com) - full reference for low-code and coded agent capabilities
- [UiPath Community](https://community.uipath.com) - forums, how-tos, and developer discussion


> **Next time, skip to the end.** Now that you understand what each command does, your coding agent can run the entire sequence from a single prompt. With UiPath skills installed (Step 2), try this in a fresh directory:
>
> *"Create a low-code UiPath agent that [describe your domain]. Scaffold the solution and agent, set the system prompt, define inputs and outputs, apply the user message workaround, validate, and upload to Studio Web."*
>
> Your coding agent will run the same CLI commands you ran manually. The manual walkthrough gives you the mental model to verify it got it right.
