# Getting Started with UiPath Agents using LangGraph

In this lab, you will install the UiPath CLI and coding agent skills, then use your coding agent to build, run, and evaluate a LangGraph agent. You will do the following:

1. Install the UiPath CLI and coding agent skills.
2. Scaffold a local project and build a LangGraph agent guided by skills.
3. Add a live external lookup tool to the agent.
4. Run and evaluate the agent locally.
5. Connect the project to UiPath Studio Web and push your first version.

By the end, you will have a working LangGraph agent built through your coding agent, guided by UiPath skills, with evaluation traces flowing to Studio Web.

There are three approaches to create UiPath agents. This uses the LangGraph SDK; you can also create agents using the [low-code Agent Builder](../agents-lowcode/guide.md) and using the [UiPath CLI](../agents/guide.md).

**Estimated time:** 45–60 minutes

## What you are building

This lab walks you through building a **quest intake classifier** for a fictional adventurer's guild: a coded LangGraph agent that reads a quest description and sorts it into one of four difficulty tiers.

It starts as a simple, single-node classifier so the focus stays on the CLI workflow, not the domain logic. Then you give it a tool so it can check its answer against a live external API before finalizing a tier, instead of guessing from vibes alone.

Here is the full design of what you are building:

| Component | Details |
| --- | --- |
| **Input: `description`** | `string`; the incoming quest description |
| **Output: `tier`** | A `Literal` type constrained to exactly `"Trivial"`, `"Standard"`, `"Heroic"`, or `"Legendary"`, not a plain string, so the model cannot emit an out-of-vocabulary tier |
| **Output: `reasoning`** | `string`; the agent's explanation for the tier it chose |
| **Tool: `get_challenge_rating`** | A LangGraph tool, called only when a quest names or implies a specific creature, that looks up its challenge rating from the [Open5e System Reference Document (SRD) API](https://open5e.com/api-docs) and cites it in the reasoning |

> **Why add a tool at all?** A driving reason to run a LangGraph agent on UiPath, instead of a low-code agent, is complex Python logic that can call out to external systems, not just classify text. The tool step in this lab demonstrates that: the agent decides at runtime whether a quest needs verification, calls a live API, and reasons over the result.

* * *

## Prerequisites

<!-- test:prereq name="Node.js" version=">=18" ignore-for-docs="true" -->
```bash
node --version
```

<!-- test:prereq name="uv" version=">=0.4" ignore-for-docs="true" -->
```bash
uv --version
```

- **CLI version** - validated against UiPath CLI v1.201.0 (installed in Step 1). Different versions may behave differently; report drift with `uip feedback send`.
- **UiPath account** - sign up or log in to [UiPath Automation Cloud](https://cloud.uipath.com) before starting.
- **Node.js 18+** - required to install the UiPath CLI. Check with `node --version`. Download from [nodejs.org](https://nodejs.org/) if needed.
- **VS Code** with a coding agent (Claude Code, Copilot, or Cursor). The lab instructions use Claude Code, but any supported coding agent will work.
- **Bash terminal** - the commands in this lab use Bash syntax. In VS Code, open a new terminal and select **Git Bash** (or equivalent) as the terminal type. PowerShell and CMD syntax differ and may cause unexpected errors.
- **uv** - a fast Python package manager. Install it with:
  ```bash
  pip install uv
  ```
  or see the [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/) for other options.
- **Admin rights** - installing global npm packages and Python dependencies requires admin/elevated permissions. If you are on a work laptop with restrictions, confirm you can install packages before starting, or work with your IT team in advance.

No existing knowledge of UiPath is required for this lab, but it will make it go faster.

* * *

> **Two "agents" in this lab.** "Coded agent" is UiPath's term for a Python agent deployed on the platform; this lab builds one using the LangGraph SDK. The lab instructions also reference your "coding agent" (Claude Code, Copilot, Cursor) to help write the Python code.
>
> When the instructions say "ask your coding agent," they mean your integrated development environment (IDE) assistant; when they say "run the agent" or "your LangGraph agent," they mean the UiPath agent being built.

# Set up your environment

## Step 1 - Install the UiPath CLI and coded agent tool

The [UiPath CLI](https://docs.uipath.com/uipath-cli/standalone/latest/user-guide/about-uipath-cli) (`uip`) is a cross-platform command-line tool for UiPath authentication, skills, and project tooling. It uses a modular tool system: the base CLI handles auth and skills, and you install additional tools for the workflow types you build.

1. Install the base CLI globally using npm:

   <!-- test:command exit_code=0 stdout_matches="(added|changed|up to date)" timeout=180 -->
   ```bash
   npm install -g @uipath/cli
   ```

2. Verify the installation:

   <!-- test:command exit_code=0 stdout_matches="^\s*\d+\.\d+\.\d+" -->
   ```bash
   uip --version
   ```

   You should see a version number like `1.201.0`.

3. Install the coded agent tool: this adds the `uip codedagent` command group used throughout this lab:

   <!-- test:command exit_code=0 timeout=180 -->
   ```bash
   uip tools install @uipath/codedagent-tool
   ```

4. Verify the tool is installed:

   <!-- test:command exit_code=0 stdout_contains="codedagent-tool" -->
   ```bash
   uip tools list
   ```

   You should see `codedagent-tool` in the output.

<!-- screenshot: step-01.png - terminal showing uip --version and tools list output -->

* * *

## Step 2 - Install UiPath skills for your coding agent

Skills teach your coding agent how to build UiPath automations, agents, and workflows. They are reference files installed into your coding agent's configuration, covering project scaffolding, LLM integration patterns, evaluation frameworks, and deployment. Without skills, your coding agent would need detailed prompts for every UiPath-specific pattern. With skills, it already knows them.

Install skills for your coding agent:

<!-- test:command exit_code=0 stdout_contains="Success" timeout=120 -->
```bash
uip skills install --agent claude
```

If you are using a different coding agent, replace `claude` with your agent: `cursor`, `copilot`, `gemini`, or `codex`.

The command reports success along with the number of skills installed (26 as of this writing). The exact list grows with each CLI release, so do not worry if yours differs.

For Claude Code specifically, skills are registered through a Claude Code plugin marketplace in addition to being copied to your home directory (for example, `~/.claude/skills/`). They are available in every project from this point forward. If a re-install looks stale or skills don't show up in your coding agent, re-run the install with `--force`, which resets the Claude Code marketplace registration and plugin cache.

<!-- screenshot: step-02.png - terminal showing skills install output -->

* * *

## Step 3 - Authenticate to UiPath

1. Authenticate the CLI to your UiPath account:

   <!-- test:manual reason="uip login opens a browser and requires interactive tenant selection" -->
   ```bash
   uip login
   ```

   This opens a browser window where you sign in to your UiPath account and select your tenant (if you have multiple). Once complete, the terminal confirms you are logged in.

2. Verify your login status:

   <!-- test:command exit_code=0 requires=auth -->
   ```bash
   uip login status
   ```

   You should see `"Status": "Logged in"` along with your organization and tenant name.

> **One auth, one CLI.** A single `uip login` covers everything in this lab: agent runs, evaluations, and publishing all flow through the same credential store. No separate Python SDK auth step needed.

<!-- screenshot: step-03.png - terminal showing login status output -->

* * *

With the CLI installed, skills in place, and your account authenticated, you are ready to scaffold the local project in the next section.

# Build the agent

## Step 4 - Set up the local project

Create a new folder for your agent project and open it in VS Code (**File → Open Folder**). All commands from this step onward run from the project folder root.

### Create the Python environment

Create a virtual environment pinned to a supported Python version and activate it:

<!-- test:manual reason="creates project directory and venv; requires directory navigation" -->
```bash
mkdir QuestIntake
cd QuestIntake

uv venv --python 3.13
source .venv/bin/activate
```

> **Windows:** Use `.venv\Scripts\activate` instead of `source .venv/bin/activate`.

> **Python version:** `uv` downloads and manages Python automatically if 3.13 is not on your PATH. Supported versions are 3.11, 3.12, and 3.13.

### Install the LangGraph integration

[LangGraph](https://langchain-ai.github.io/langgraph/) is a Python framework for building stateful LLM agents as graphs of nodes and edges. `uipath-langchain` is the UiPath integration layer that packages a LangGraph agent for deployment and evaluation on the UiPath platform.

Install the UiPath LangGraph package into the active venv. This also makes the framework available for project scaffolding in the next step:

<!-- test:manual reason="requires active venv from prior step" -->
```bash
uv pip install uipath-langchain
```

### Register Python with the UiPath CLI

Tell the CLI where the UiPath-compatible Python executable lives:

<!-- test:setup stdout_contains="Success" timeout=90 -->
```bash
uip codedagent setup --force
```

You should see `"Result": "Success"`. This step is required once per machine (and after any venv changes) before using `uip codedagent` commands.

### Scaffold the project

Create the UiPath project structure. `uip codedagent new` detects the installed framework and generates the right scaffold files:

<!-- test:manual reason="requires uv venv and uipath-langchain installed in prior steps" -->
```bash
uip codedagent new QuestIntake
```

This creates `pyproject.toml`, `main.py`, `langgraph.json`, `uipath.json`, `entry-points.json`, `bindings.json`, and coding agent context files (`AGENTS.md`, `CLAUDE.md`, `.agent/`). The `main.py` is a placeholder; your coding agent replaces it in Step 5.

Add the local dev server dependency and sync the lockfile:

<!-- test:manual reason="requires pyproject.toml created by uip codedagent new" -->
```bash
uv add uipath-dev --dev
uv sync
```

### Generate entry points

Run init to generate the entry point schemas from the scaffold code:

<!-- test:manual reason="requires scaffold from uip codedagent new and active venv" -->
```bash
uip codedagent init
```

The project has a placeholder entry point at this stage. Re-run `init` in Step 5 after your coding agent writes the real agent code.

<!-- screenshot: step-04.png - terminal showing uip codedagent new and init output -->

* * *

## Step 5 - Build the agent with your coding agent

This is where the UiPath skills pay off. Open your coding agent and prompt it to create the agent logic. The prompt below is short: it describes what the agent should do, not how to build it.

The `uipath-agents` skill your coding agent has installed already knows the LangGraph integration patterns, correct SDK imports, Pydantic schema conventions, and relevant SDK requirements. Without these skills, you would need to specify all of this in the prompt itself.

<!-- test:manual reason="Coding agent prompt - non-deterministic generation, requires human IDE interaction" -->
Use the following prompt (or adapt it to your use case):

```text
Update main.py to implement this UiPath coded agent using LangGraph as a single-node graph with no tools and no retry or error-handling logic.

The agent is a quest intake classifier for a fantasy adventurer's guild. Given a
description of an incoming quest, it classifies the difficulty as one of four tiers:
- Trivial: Simple errands anyone can handle (e.g., deliver a letter, clear rats from a cellar)
- Standard: Moderate quests requiring some skill (e.g., escort a merchant caravan)
- Heroic: Difficult quests requiring significant expertise (e.g., slay a wyvern, infiltrate a thieves' guild)
- Legendary: Extreme quests requiring top-tier heroes and special approval (e.g., defeat a lich, close a planar rift)

Return the classification tier and a brief reasoning. Use these exact field names in the State schema:
- Input field: `description` (string)
- Output fields: `tier` (a Literal type constrained to exactly "Trivial", "Standard", "Heroic", "Legendary" — not a plain string, so the model can't emit an out-of-vocabulary tier) and `reasoning` (string)

Update the existing langgraph.json to point at the new graph, and create an input.json with this exact sample quest: {"description": "Clear the rats out of the inn cellar"}.

Only touch main.py, langgraph.json, and input.json.

Don't run any uip codedagent commands or otherwise verify that the agent runs — I will do this myself.
```

> **Why this prompt is so specific.** It names the exact files to touch and tells the coding agent not to run any `uip codedagent` commands or verify its own work. That's deliberate here: the rest of this lab exercises those same CLI commands directly in the next steps, so verification is left to you instead of the coding agent running it first.

The prompt above is a good template to start from in your own projects, but you should remove the last two sentences to enable the coding agent to test its work and organize files to its own judgment.

> **Coding agents are non-deterministic.** Your generated code will differ from any examples shown here; that is expected. What matters is that `main.py` runs without errors and returns a classification.

And note that if your coding agent presents a 'Delivery' question (Studio Web, local dev server, or skip), select **Skip - I'm done** for now. Connect to Studio Web in Step 10.

After the coding agent finishes, re-run init to pick up the updated entry points from the new Pydantic schemas:

<!-- test:manual reason="requires agent code generated by coding agent in prior step" -->
```bash
uip codedagent init
```

You should see output confirming the entry point was detected along with an ASCII graph diagram:

```
Created 'entry-points.json' file with 1 entrypoint(s).
```

Before continuing, open `pyproject.toml` and add an `authors` entry under `[project]` if one is not already there. UiPath requires this field to package the project:

```toml
authors = [{ name = "Your Name" }]
```

<!-- screenshot: step-05.png - terminal showing init output with entrypoint detected -->

* * *

With the agent running locally and the entry points registered, you are ready to run it in the next step.

## Step 6 - Run the agent locally

Run the agent with the sample input file your coding agent created:

<!-- test:manual reason="requires built agent project from Steps 4-5" -->
```bash
uip codedagent run agent --file input.json
```

You should see the agent classify the request and return a tier with reasoning.

You can also pass input inline. These examples use Bash single-quote syntax; if you are in PowerShell, use `--file` with a JSON file instead:

<!-- test:manual reason="requires built agent project from Steps 4-5" -->
```bash
uip codedagent run agent '{"description": "Clear the rats out of the inn cellar"}'
```

Try your own inputs to verify the classifications make sense, for example:

<!-- test:manual reason="requires built agent project" -->
```bash
uip codedagent run agent '{"description": "Slay the ancient red dragon terrorizing the countryside"}'
```

<!-- screenshot: step-06.png - terminal showing agent output with tier and reasoning -->

* * *

With the agent classifying correctly, you are ready to give it something to verify its answers against.

# Add a tool

## Step 7 - Add a live lookup tool

Right now the agent is guessing from vibes: nothing it says about a dragon or a goblin is checked against anything real. To improve the accuracy of the classifier, let's add a tool to verify quest information before finalizing a tier recommendation. To do this, the tool will use the [Open5e API](https://open5e.com/api-docs) to search for creatures published under the 5e System Reference Document (SRD).

This is standard LangGraph, not a UiPath-specific trick: a plain Python function decorated with `@tool`, bound to the model, and the model decides at runtime whether calling it is worth it. Your coding agent wires up that binding syntax for you.

<!-- test:manual reason="Coding agent prompt - non-deterministic generation, requires human IDE interaction" -->
Ask your coding agent:

```text
Update main.py to add one Python tool to the existing LangGraph agent: a function that looks up a monster's challenge rating from the Open5e SRD API and uses it to inform the difficulty tier.

Tool behavior:
- Query GET https://api.open5e.com/v2/creatures/ using the `requests` library (already available as a transitive dependency; add it directly with `uv add requests` only if the import fails), with query parameters: name__icontains=<creature name or type the model supplies>, document__key__in=srd-2024, limit=10, fields=key,name,type,size,challenge_rating,alignment
- Set a 10-second timeout on the request, and call raise_for_status() before reading the response body — this is a live external API call, so it should fail fast with a clear error instead of hanging or raising a confusing KeyError if Open5e is slow or returns a non-200 response.
- If the response has zero results, return that as-is — nothing further to do.
- If the response has more than one result, return the full list and let the agent pick the best match rather than guessing which one is correct.
- Bind the tool with the standard LangChain @tool decorator. Let the model decide when to call it based on the tool's description — don't force a call on every input.
- Name the tool function `get_challenge_rating`.
- In the tool's docstring, describe what counts as a creature in the abstract — don't include a named example creature (e.g., avoid phrasing like "e.g. goblin, young red dragon"). A concrete example name in the docstring can get echoed back by the model as a spurious lookup for a creature that isn't actually in the quest.

Update the system prompt so that:
- The agent calls this tool whenever the quest description names or strongly implies a specific creature.
- Only call the tool for creatures explicitly named or strongly implied in the quest description — never for other creatures used as a comparison or reference point.
- When a `challenge_rating` comes back, the agent uses it to inform the tier classification and cites it explicitly in the `reasoning` output field. Do not fabricate or guess a challenge rating from memory — only cite one that actually came from the tool's response.
- If no tool call happens, or the tool returns zero results, the agent classifies using its existing judgment, same as before.
- Don't add new output fields. The State schema stays `tier` and `reasoning` only — the challenge rating goes into the reasoning text, not a new field.

Only touch main.py.

Don't run any uip codedagent commands or otherwise verify that the agent runs — I will do this myself.
```

> **Why this prompt is so specific.** As in Step 5, the file scoping and the instruction not to run or verify anything is deliberate: the next commands in this lab exercise the tool directly, so verification is left to you.

As you adapt the prompt to your own work, you are again advised to remove the last two sentences to fully enable your coding agent to exercise your code.

> **Coding agents are non-deterministic.** Your generated tool code will differ from any examples shown here; that is expected. What matters is that `main.py` still runs without errors and calls the tool only when a creature is named.

This tool does not add or change any input or output fields, so there is no need to re-run `uip codedagent init` this time. Only re-run it when your Input/Output models change.

Re-run the dragon example from Step 6:

<!-- test:manual reason="requires tool added by coding agent in prior step" -->
```bash
uip codedagent run agent '{"description": "Slay the ancient red dragon terrorizing the countryside"}'
```

Watch the trace this time: the agent calls the SRD lookup, gets back a real challenge rating, and cites it in its reasoning instead of just asserting Legendary. That's the difference between a text classifier and an agent that can go verify itself.

<!-- screenshot: step-07.png - terminal/trace output showing the SRD lookup tool call and the cited challenge rating -->

* * *

With the tool wired in, you are ready to test that the agent uses it correctly and scores well across a range of inputs.

# Evaluate the agent

## Step 8 - Create evaluation tests

Evaluations test how well your agent performs across a range of inputs, including whether it calls your new tool at the right moments. The `uipath-agents` skill includes the complete evaluation framework reference: evaluator types, eval set schema, directory structure conventions, and best practices like using `gpt-4.1` (not mini) for LLM judge evaluators. Your coding agent uses this to produce correct evaluator configs and test sets from a short prompt.

<!-- test:manual reason="Coding agent prompt - non-deterministic generation" -->
Ask your coding agent:

```text
Create an evaluation set for the intake classifier agent with 5 test cases:

1. A clearly trivial request (e.g., deliver a letter) - no creature named, get_challenge_rating should not be called
2. A standard request (e.g., escort a caravan) - no creature named, get_challenge_rating should not be called
3. A heroic request naming a goblin (e.g., clear a goblin stronghold) - get_challenge_rating should be called exactly once, querying for a goblin, and no other creature
4. A legendary request naming a dragon (e.g., slay a dragon) - get_challenge_rating should be called exactly once, querying for a dragon, and no other creature
5. An edge case that's ambiguous on difficulty but also names no specific creature - get_challenge_rating should not be called; this tests that the agent doesn't over-call the tool just because a case is hard to classify

Use both a semantic similarity evaluator (to check the output) and a trajectory evaluator (to check whether get_challenge_rating was called, and with what search term, matching the expectations above).

Include evaluator config files in evaluations/evaluators/ and the eval set, named smoke-test.json, in evaluations/eval-sets/. Use gpt-4.1-2025-04-14 as the model in the evaluator configs. Each evaluator config must include a populated defaultEvaluationCriteria - use {"expectedOutput": {}} for the semantic evaluator and {"expectedAgentBehavior": ""} for the trajectory evaluator. Empty {} fails schema validation.
```

<!-- screenshot: step-08.png - eval set file structure in VS Code -->

* * *

## Step 9 - Run evaluations

Run the evaluation set locally:

<!-- test:manual reason="requires built agent project with evaluation files from Steps 5-8" -->
```bash
uip codedagent eval agent evaluations/eval-sets/smoke-test.json --workers 3 --output-file eval-results.json
```

The evaluation framework runs each test case through your agent and scores the results.

| Score | What it measures |
|---|---|
| **Semantic similarity** | How closely the agent's output matches the expected output |
| **Agent trajectory** | Whether the agent called `get_challenge_rating` when (and only when) it should have |

> **Trajectory now means something here.** With the tool in place, expect trajectory scores close to 1.0 across all five cases: no tool call on the trivial, standard, and ambiguous cases, and exactly one correctly-targeted tool call on the goblin and dragon cases. A low score tells you the agent called the tool when it should not have, skipped a call it should have made, or looked up the wrong creature, not just whether the final tier happens to be right.

For semantic similarity, scores above 0.8 are generally solid; expect the same for trajectory now that it is tracking something specific. Review `eval-results.json` to see how your agent performed.

After you connect to Studio Web in the next step, running `uip codedagent eval run` from the CLI uploads results to Studio Web automatically; they appear in the **Evaluation Sets** tab under Runs.

> **The Studio Web Run Evals button is not the same thing.** That button triggers a cloud robot execution requiring Python runtime support — a more involved setup outside the scope of this lab. Use `uip codedagent eval run` from the CLI instead; results appear in Studio Web either way.

<!-- screenshot: step-09.png - terminal showing eval results -->

* * *

With local evaluation results confirmed, you are ready to connect the project to Studio Web in the next section.

# Connect to Studio Web

## Step 10 - Connect to Studio Web

Your agent is built and evaluated locally. Now connect it to Studio Web so you get version history, evaluation traces, and the ability to test in the cloud UI.

You have three options:

| Option | What happens |
|---|---|
| **A: You set it up in Studio Web** | Open Studio Web, create a Coded Agent project, copy the project ID. You paste it into `.env` and push from the CLI. |
| **B: CLI packages and uploads** | `uip codedagent pack`, `publish`, or `deploy` package the agent and publish it to your [personal workspace](https://docs.uipath.com/orchestrator/automation-cloud/latest/user-guide/personal-workspaces) or tenant feed directly, without Studio Web setup. |
| **C: Local dev server only** | Run `uip codedagent dev` for a local web UI. Nothing is published to the cloud. |

For this lab, use **Option A**: it shows the connection model that underlies all three options.

### Option A - Connect via Studio Web

1. Log in to [UiPath Automation Cloud](https://cloud.uipath.com) and select **Studio Web** from the side navigation.

2. Select **Create New** and select **Agent**.

3. In the **Select agent type** dialog box, choose **Coded** as the agent type and select **Start Fresh**.

   <!-- screenshot: step-10a.png - Studio Web create new coded agent dialog -->

4. Studio Web displays a **Setup your coded agent** panel. Under **Sync from your IDE into Studio Web**, your `UIPATH_PROJECT_ID` appears with a copy button. Copy this value.

   <!-- screenshot: step-10b.png - Studio Web setup panel showing UIPATH_PROJECT_ID -->

5. Return to your IDE and open the `.env` file in your project root to add the project ID:

   <!-- test:manual reason="participant must paste their specific project ID" -->
   ```text
   UIPATH_PROJECT_ID=your-project-id-here
   ```

   :::note
   Only the project ID goes in `.env`. `uip login` stores your auth token globally; you do not need `UIPATH_URL` or `UIPATH_ACCESS_TOKEN` in `.env`. If you have used the UiPath Python SDK before and are used to running `uipath auth` to populate those fields, that step is no longer needed.
   :::

6. Add `.env` to the `.gitignore` file to avoid committing it:

   <!-- test:manual reason="requires .gitignore file in project root" -->
   ```bash
   echo ".env" >> .gitignore
   ```

7. Push your agent to Studio Web from the command line:

   <!-- test:manual reason="requires UIPATH_PROJECT_ID in .env and built project from Steps 4-8" -->
   ```bash
   uip codedagent push
   ```

A successful push returns confirmation and increments the version to `0.0.1`. Open your project in Studio Web; the agent definition, your evaluation sets, and version `0.0.1` appear in the version history.

<!-- screenshot: step-10c.png - Studio Web showing v0.0.1 agent with evaluation sets -->

* * *

## Step 11 - Iterate and improve *(optional)*

With evaluations in place and Studio Web connected, you can iterate on your agent and observe the effect on scores:

1. Review evaluation results in `eval-results.json` or in Studio Web.
2. Ask your coding agent to improve the agent based on the evaluation feedback.
3. Re-run evaluations to verify improvements.
4. Push the updated version to Studio Web.

<!-- test:manual reason="requires built project, eval files, and UIPATH_PROJECT_ID from prior steps" -->
```bash
uip codedagent eval agent evaluations/eval-sets/smoke-test.json --workers 3
```

<!-- test:manual reason="requires UIPATH_PROJECT_ID in .env" -->
```bash
uip codedagent push
```

Each push increments the version in Studio Web, giving you a full history of how the agent evolved.

* * *

## What you built

You have built a LangGraph agent on UiPath using the CLI and coding agent skills:

- Scaffolded a local Python project with the correct LangGraph structure using `uip codedagent new`.
- Used your coding agent to build the agent logic, guided by UiPath skills, not detailed prompts.
- Ran the agent locally and verified outputs before touching the cloud.
- Gave the agent a tool to verify its own answer against a live external API.
- Created an evaluation set, including a trajectory check on tool use, and scored the agent locally.
- Connected to Studio Web and pushed the first version with full evaluation history.

## What's next

- [UiPath LangGraph sample agents](https://github.com/UiPath/uipath-langchain-python/tree/main/samples) - working examples including ticket classification with human-in-the-loop, RAG, multi-agent supervisors, and MCP integration.
- [UiPath Python SDK docs](https://uipath.github.io/uipath-python/) - full reference for CLI commands, agent patterns, and SDK APIs.
- [Evaluation framework guide](https://uipath.github.io/uipath-python/eval/) - how to build, run, and interpret evaluation sets.
- [LangGraph docs](https://langchain-ai.github.io/langgraph/) - the orchestration framework used in this lab.
- [UiPath Community](https://community.uipath.com) - forums, how-tos, and developer discussion.
