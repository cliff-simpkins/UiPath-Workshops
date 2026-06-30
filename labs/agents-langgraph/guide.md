# Getting Started with UiPath Agents using LangGraph

In this lab, you will install the UiPath CLI and coding agent skills, then use your coding agent to build, run, and evaluate a coded agent. You will do the following:

1. Install the UiPath CLI and coding agent skills
2. Scaffold a local project and build a LangGraph agent guided by skills
3. Run and evaluate the agent locally
4. Connect the project to UiPath Studio Web and push your first version

By the end, you will have a working coded agent built through your coding agent — guided by UiPath skills — with evaluation traces flowing to Studio Web.

There are a few approaches to create UiPath agents. This uses the LangGraph SDK; you can also create agents using the [low-code Agent Builder](../agents-lowcode/guide.md) and using the [UiPath CLI](../agents/guide.md).

**Estimated time:** 45–60 minutes

* * *

## Prerequisites

<!-- test:prereq name="Node.js" version=">=18" -->
```bash
node --version
```

<!-- test:prereq name="uv" version=">=0.4" -->
```bash
uv --version
```

- **CLI version** - validated against UiPath CLI v1.1.0 (installed in Step 1). Different versions may behave differently; report drift with `uip feedback send`.
- **UiPath account on cloud.uipath.com** - sign up or log in at [cloud.uipath.com](https://cloud.uipath.com) before starting.
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

# Workshop: UiPath Agents using LangGraph

## Step 1 - Install the UiPath CLI and Coded Agent Tool

The UiPath CLI (`uip`) is a cross-platform command-line tool for UiPath authentication, skills, and project tooling. It uses a modular tool system - the base CLI handles auth and skills, and you install additional tools for the workflow types you build.

Install the base CLI globally using npm:

<!-- test:command exit_code=0 stdout_matches="(added|changed|up to date)" timeout=180 -->
```bash
npm install -g @uipath/cli
```

Verify the installation:

<!-- test:command exit_code=0 stdout_matches="^\s*\d+\.\d+\.\d+" -->
```bash
uip --version
```

You should see a version number like `1.1.0`.

Now install the coded agent tool - this adds the `uip codedagent` command group used throughout this lab:

<!-- test:command exit_code=0 timeout=180 -->
```bash
uip tools install @uipath/codedagent-tool
```

Verify the tool is installed:

<!-- test:command exit_code=0 stdout_contains="codedagent-tool" -->
```bash
uip tools list
```

You should see `codedagent-tool` in the output.

<!-- screenshot: step-01.png - terminal showing uip --version and tools list output -->

* * *

## Step 2 - Install UiPath Skills for Your Coding Agent

Skills teach your coding agent how to build UiPath automations, agents, and workflows. They are reference files installed into your coding agent's configuration - covering project scaffolding, LLM integration patterns, evaluation frameworks, and deployment. Without skills, your coding agent would need detailed prompts for every UiPath-specific pattern. With skills, it already knows them.

Install skills for your coding agent:

<!-- test:command exit_code=0 stdout_contains="Success" timeout=120 -->
```bash
uip skills install --agent claude
```

If you are using a different coding agent, replace `claude` with your agent: `cursor`, `copilot`, `gemini`, or `codex`.

The command emits JSON listing the installed skills. The skill catalog grows with each CLI release - your output may include more skills than shown here. The following reflects CLI v1.1.0:

```json
{
  "Result": "Success",
  "Code": "SkillsInstall",
  "Data": {
    "RootDir": "C:\\Users\\<you>",
    "Skills": [
      "uipath-agents",
      "uipath-coded-apps",
      "uipath-data-fabric",
      "uipath-diagnostics",
      "uipath-feedback",
      "uipath-gov-access-policy",
      "uipath-gov-aops-policy",
      "uipath-human-in-the-loop",
      "uipath-interact",
      "uipath-maestro-case",
      "uipath-maestro-flow",
      "uipath-planner",
      "uipath-platform",
      "uipath-review",
      "uipath-rpa",
      "uipath-rpa-legacy",
      "uipath-solution-design",
      "uipath-tasks",
      "uipath-test"
    ],
    "Agents": ["claude"],
    "Installed": 19
  }
}
```

The skills are installed globally to your home directory (e.g., `~/.claude/skills/` for Claude Code). They are available in every project from this point forward.

<!-- screenshot: step-02.png - terminal showing skills install output -->

* * *

## Step 3 - Authenticate to UiPath

Authenticate the CLI to your UiPath account:

<!-- test:manual reason="uip login opens a browser and requires interactive tenant selection" -->
```bash
uip login
```

This opens a browser window where you will:
1. Sign in to your UiPath account
2. Select your tenant (if you have multiple)

Once complete, the terminal confirms you are logged in.

Verify your login status at any time with:

<!-- test:command exit_code=0 requires=auth -->
```bash
uip login status
```

> **One auth, one CLI.** A single `uip login` covers everything in this lab - agent runs, evaluations, and publishing all flow through the same credential store. No separate Python SDK auth step needed.

<!-- screenshot: step-03.png - terminal showing login status output -->

* * *

## Step 4 - Set Up the Local Project

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

This creates `pyproject.toml`, `main.py`, `langgraph.json`, `uipath.json`, `entry-points.json`, `bindings.json`, and coding agent context files (`AGENTS.md`, `CLAUDE.md`, `.agent/`). The `main.py` is a placeholder — your coding agent replaces it in Step 5.

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

The project has a placeholder entry point at this stage — you'll re-run `init` in Step 5 after your coding agent writes the real agent code.

<!-- screenshot: step-04.png - terminal showing uip codedagent new and init output -->

* * *

## Step 5 - Build the Agent with Your Coding Agent

This is where the UiPath skills pay off. Open your coding agent and prompt it to create the agent logic. The prompt below is short — it describes *what* the agent should do, not *how* to build it. The `uipath-agents` skill your coding agent has installed already knows the LangGraph integration patterns, correct SDK imports, Pydantic schema conventions, and the lazy LLM initialization requirement. Without skills, you would need to specify all of that in the prompt itself.

<!-- test:manual reason="Coding agent prompt - non-deterministic generation, requires human IDE interaction" -->
Use the following prompt (or adapt it to your use case):

```
Create a UiPath coded agent using LangGraph.

The agent is a quest intake classifier for a D&D adventurer's guild. Given a
description of an incoming quest, it classifies the difficulty as one of four tiers:
- Trivial: Simple errands anyone can handle (e.g., deliver a letter, clear rats from a cellar)
- Standard: Moderate quests requiring some skill (e.g., escort a merchant caravan)
- Heroic: Difficult quests requiring significant expertise (e.g., slay a wyvern, infiltrate a thieves' guild)
- Legendary: Extreme quests requiring top-tier heroes and special approval (e.g., defeat a lich, close a planar rift)

Return the classification tier and a brief reasoning.

Use these exact field names in the State schema:
- Input field: `description` (string)
- Output fields: `tier` (string) and `reasoning` (string)

Create a langgraph.json and an input.json with a sample D&D quest for testing.
```

> **Coding agents are non-deterministic.** Your generated code will differ from any examples shown here - that's expected. What matters is that `main.py` runs without errors and returns a classification.
>
> **If your coding agent asks how you want to deploy the agent** (a "Delivery" question with options like Studio Web, local dev server, or skip), select **Skip - I'm done** for now. This lab covers local run and evals first. You will connect to Studio Web in Step 9.

After the coding agent finishes, re-run init to pick up the updated entry points from the new Pydantic schemas:

<!-- test:manual reason="requires agent code generated by coding agent in prior step" -->
```bash
uip codedagent init
```

You should see output confirming the entry point was detected along with an ASCII graph diagram:

```
Created 'entry-points.json' file with 1 entrypoint(s).
```

Before continuing, open `pyproject.toml` and confirm an `authors` entry is present under `[project]`. Add it if missing - UiPath requires this to package the project:

```toml
authors = [{ name = "Your Name" }]
```

<!-- screenshot: step-05.png - terminal showing init output with entrypoint detected -->

* * *

## Step 6 - Run the Agent Locally

Run the agent with the sample input file your coding agent created:

<!-- test:manual reason="requires built agent project from Steps 4-5" -->
```bash
uip codedagent run agent --file input.json
```

You should see the agent classify the request and return a tier with reasoning.

You can also pass input inline. These examples use Bash single-quote syntax — if you are in PowerShell, use `--file` with a JSON file instead:

<!-- test:manual reason="requires built agent project from Steps 4-5" -->
```bash
uip codedagent run agent '{"description": "Clear the rats out of the inn cellar"}'
```

Try a few different inputs to verify the classifications make sense:

<!-- test:manual reason="requires built agent project" -->
```bash
uip codedagent run agent '{"description": "Slay the ancient red dragon terrorizing the countryside"}'
```

<!-- screenshot: step-06.png - terminal showing agent output with tier and reasoning -->

* * *

## Step 7 - Create Evaluation Tests

Evaluations test how well your agent performs across a range of inputs. The `uipath-agents` skill includes the complete evaluation framework reference — evaluator types, eval set schema, directory structure conventions, and best practices like using `gpt-4.1` (not mini) for LLM judge evaluators. Your coding agent uses this to produce correct evaluator configs and test sets from a short prompt.

<!-- test:manual reason="Coding agent prompt - non-deterministic generation" -->
Ask your coding agent:

```
Create an evaluation set for the intake classifier agent with 5 test cases:

1. A clearly trivial request (e.g., delivering a letter)
2. A standard request (e.g., escort a caravan)
3. A heroic request (e.g., clear a goblin stronghold)
4. A legendary request (e.g., slay a dragon)
5. An edge case with ambiguous difficulty

Use both a semantic similarity evaluator (to check the output) and a
trajectory evaluator (to check the agent's reasoning path).

Include evaluator config files in evaluations/evaluators/ and the eval
set in evaluations/eval-sets/. Use gpt-4.1-2025-04-14 as the model in
the evaluator configs. Each evaluator config must include a populated
defaultEvaluationCriteria - use {"expectedOutput": {}} for the
semantic evaluator and {"expectedAgentBehavior": ""} for the
trajectory evaluator. Empty {} fails schema validation.
```

<!-- screenshot: step-07.png - eval set file structure in VS Code -->

* * *

## Step 8 - Run Evaluations

Run the evaluation set locally:

<!-- test:manual reason="requires built agent project with evaluation files from Steps 5-7" -->
```bash
uip codedagent eval agent evaluations/eval-sets/smoke-test.json --workers 3 --output-file eval-results.json
```

The evaluation framework runs each test case through your agent and scores the results.

| Score | What it measures |
|---|---|
| **Semantic similarity** | How closely the agent's output matches the expected output |
| **Agent trajectory** | Whether the agent took the expected reasoning path |

Scores above 0.8 are generally solid. Review `eval-results.json` to see how your agent performed.

> **Expect trajectory scores of 0.0 on this agent.** Trajectory evaluators judge the agent's *reasoning path* — which tools it called, in what order, how it routed between nodes. An intake classifier with a single `classify` node has no meaningful trajectory to evaluate, so every test case will score 0.0 on that evaluator. Trajectory evaluation shines on multi-step agents that use tools or route between nodes — keep it in mind for the next lab, and lean on semantic similarity for single-step classifiers.

After you connect to Studio Web in the next step, running `uip codedagent eval run` from the CLI will upload results to Studio Web automatically — you will see them in the **Evaluation Sets** tab under Runs.

> **The Studio Web "Run Evals" button is not the same thing.** That button triggers a cloud execution of the agent, which requires a deployed robot with Python runtime support — a more involved setup outside the scope of this lab. For the development loop covered here, `uip codedagent eval run` from the CLI is the correct tool. The results appear in Studio Web either way.

<!-- screenshot: step-08.png - terminal showing eval results -->

* * *

## Step 9 - Connect to Studio Web

Your agent is built and evaluated locally. Now connect it to Studio Web so you get version history, evaluation traces, and the ability to test in the cloud UI.

You have three options:

| Option | What happens |
|---|---|
| **A — You set it up in Studio Web** | Open Studio Web, create a Coded Agent project, copy the project ID. You paste it into `.env` and push from the CLI. |
| **B — CLI packages and uploads** | CLI creates a solution, imports the agent, and uploads everything. No Studio Web setup required from you. |
| **C — Local dev server only** | Run `uip codedagent dev` to get a local web UI. Nothing is published. |

For this lab, use **Option A** — it shows the connection model that underlies all three options.

### Option A - Connect via Studio Web

1. Log in to [cloud.uipath.com](https://cloud.uipath.com) and select **Studio** from the side menu.

2. Select **Create New** and select **Agent**. Choose **Coded** as the agent type, then select **Start Fresh**.

   <!-- screenshot: step-09a.png - Studio Web create new coded agent dialog -->

3. Studio Web displays a **Setup your coded agent** panel. Under **Sync from your IDE into Studio**, you will see your `UIPATH_PROJECT_ID` with a copy button. Copy this value.

   <!-- screenshot: step-09b.png - Studio Web setup panel showing UIPATH_PROJECT_ID -->

4. Open the `.env` file in your project root and add the project ID:

   <!-- test:manual reason="participant must paste their specific project ID" -->
   ```text
   UIPATH_PROJECT_ID=your-project-id-here
   ```

   > **Only the project ID goes in `.env`.** `uip login` stores your auth token globally — you do not need `UIPATH_URL` or `UIPATH_ACCESS_TOKEN` in `.env`. If you have used the UiPath Python SDK before and are used to running `uipath auth` to populate those fields, that step is no longer needed.

5. Add `.env` to `.gitignore` to avoid committing it:

   <!-- test:manual reason="requires .gitignore file in project root" -->
   ```bash
   echo ".env" >> .gitignore
   ```

6. Push your agent to Studio Web:

   <!-- test:manual reason="requires UIPATH_PROJECT_ID in .env and built project from Steps 4-7" -->
   ```bash
   uip codedagent push
   ```

   A successful push returns confirmation and increments the version to `0.0.1`. Open your project in Studio Web — you will see the agent definition, your evaluation sets, and version `0.0.1` in the version history.

   <!-- screenshot: step-09c.png - Studio Web showing v0.0.1 agent with evaluation sets -->

* * *

## Step 10 - Iterate and Improve *(Optional)*

With evaluations in place and Studio Web connected, you can iterate on your agent and observe the effect on scores:

1. Review evaluation results in `eval-results.json` or in Studio Web
2. Ask your coding agent to improve the agent based on the evaluation feedback
3. Re-run evaluations to verify improvements
4. Push the updated version to Studio Web

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

## Congratulations

You've built a coded agent on UiPath using the CLI and coding agent skills:

- Scaffolded a local Python project with the correct LangGraph structure using `uip codedagent new`
- Used your coding agent to build the agent logic — guided by UiPath skills, not detailed prompts
- Ran the agent locally and verified outputs before touching the cloud
- Created an evaluation set and scored the agent locally
- Connected to Studio Web and pushed the first version with full evaluation history

## What's Next

- [UiPath LangGraph sample agents](https://github.com/UiPath/uipath-langchain-python/tree/main/samples) - working examples including ticket classification with human-in-the-loop, RAG, multi-agent supervisors, and MCP integration
- [UiPath Python SDK docs](https://uipath.github.io/uipath-python/) - full reference for CLI commands, agent patterns, and SDK APIs
- [Evaluation framework guide](https://uipath.github.io/uipath-python/eval/) - how to build, run, and interpret evaluation sets
- [LangGraph docs](https://langchain-ai.github.io/langgraph/) - the orchestration framework used in this lab
- [UiPath Community](https://community.uipath.com) - forums, how-tos, and developer discussion
