# Getting Started with UiPath Skills & CLI

In this workshop, you will install the UiPath CLI and coding agent skills, then use your coding agent to build, run, and evaluate a coded agent - without leaving your IDE. We will do the following:

1. Install the UiPath CLI and coding agent skills
2. Authenticate and create a coded agent project in UiPath Studio
3. Set up a local project connected to Studio from the start
4. Build a coded agent using your coding agent (guided by skills)
5. Run the agent locally, evaluate its performance, and push versions to Studio

By the end of the workshop, you will have a working coded agent built entirely through your coding agent, guided by UiPath skills.

**Estimated time:** 45–60 minutes

* * *

## Prerequisites

This lab assumes you have the following:
- **CLI version** - validated against UiPath CLI v0.9.1 (installed in Step 1). Different versions may behave differently; report drift with `uip feedback send`.
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


# Workshop: UiPath Skills & CLI

## Step 1 - Install the UiPath CLI and Coded Agent Tool

The UiPath CLI (`uip`) is a cross-platform command-line tool for UiPath authentication, skills, and project tooling. It uses a modular tool system - the base CLI handles auth and skills, and you install additional tools for the workflow types you build.

Install the base CLI globally using npm:

```bash
npm install -g @uipath/cli
```

Verify the installation:

```bash
uip --version
```

You should see a version number like `0.9.1`.

Now install the coded agent tool - this adds the `uip codedagent` command group used throughout this lab:

```bash
uip tools install @uipath/codedagent-tool
```

Verify the tool is installed:

```bash
uip tools list
```

You should see `codedagent-tool` in the output.

<!-- screenshot: step-01.png - terminal showing uip --version and tools list output -->


## Step 2 - Install UiPath Skills for Your Coding Agent

Skills teach your coding agent how to build UiPath automations, agents, and workflows. They are reference files installed into your coding agent's configuration - covering project scaffolding, LLM integration patterns, evaluation frameworks, and deployment. Without skills, your coding agent would need detailed prompts for every UiPath-specific pattern. With skills, it already knows them.

Install skills for your coding agent:

```bash
uip skills install --agent claude
```

If you are using a different coding agent, replace `claude` with your agent: `cursor`, `copilot`, `gemini`, or `codex`.

The command emits JSON listing the installed skills. The skill catalog grows with each CLI release - your output may include more skills than shown here. The following reflects CLI v0.9.1:

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


## Step 3 - Authenticate to UiPath

Authenticate the CLI to your UiPath account:

```bash
uip login
```

This opens a browser window where you will:
1. Sign in to your UiPath account
2. Select your tenant (if you have multiple)

Once complete, the terminal confirms you are logged in.

Verify your login status at any time with:

```bash
uip login status
```

> **One auth, one CLI.** A single `uip login` covers everything in this lab - authentication, project init, agent runs, push to Studio, and evaluations all flow through the same credential store. No separate Python SDK auth step needed.

<!-- screenshot: step-03.png - terminal showing login status output -->


## Step 4 - Create a Coded Agent Project in UiPath Studio

Before setting up our local project, we will create a coded agent project in UiPath Studio. This gives us a Project ID that connects our local development to the platform - enabling evaluation traces, deployment, and version management from the start.

1. Log into [cloud.uipath.com](https://cloud.uipath.com) and select **Studio** from the side menu.

2. Click **Create New** and select **Agent**. Choose **Coded** as the agent type and click **Start Fresh**.

   <!-- screenshot: step-04a.png - Studio Web create new coded agent -->

3. Studio Web displays a **Setup your coded agent** panel with two options. Under **Sync from your IDE into Studio**, you will see your `UIPATH_PROJECT_ID` with a copy button. Copy this value - you will add it to your local project in the next step.

   <!-- screenshot: step-04b.png - Studio Web setup panel showing project key and push command -->


## Step 5 - Set Up the Local Project

Create a new empty folder for your agent project and open it in VS Code (**File → Open Folder**). This folder will be your project workspace - all commands in the lab run from its root.

1. Initialize a Python project and add the UiPath LangGraph integration:

   ```bash
   uv init
   uv add uipath-langchain
   ```

   > **Python version:** `uv` manages Python for you. If you don't have Python 3.11+ on your PATH, `uv` will download and manage an appropriate version automatically.

   > **Note:** `uv init` creates a default `main.py` with a "Hello" placeholder - your coding agent will overwrite this in Step 6.

2. Initialize the UiPath project to generate configuration files:

   ```bash
   uip codedagent init
   ```

   This creates `.env`, `uipath.json`, `entry-points.json`, `bindings.json`, `project.uiproj`, `.uipath/studio_metadata.json`, `AGENTS.md` and `CLAUDE.md` files, and coding agent skill references in `.agent/` and `.claude/`. The `AGENTS.md`/`CLAUDE.md` files and `.agent/` folder provide your coding agent with project-specific context - CLI commands, SDK references, and required project structure - that complements the global skills you installed in Step 2. The project doesn't have any agent code yet, so the entry points will be empty - that's expected.

3. Open the newly created `.env` file and add the Project ID from Step 4:

   ```
   UIPATH_PROJECT_ID=your-project-id-here
   ```

   This is the only entry you need in `.env`.

   > **Don't expect to see UiPath credentials in `.env`.** `uip login` from Step 3 stores your access token in your user profile (not in the project), and `uip codedagent run`, `push`, and `eval` all read from that global store at runtime. If you've used UiPath's Python SDK before, you may be used to running `uipath auth` to populate `UIPATH_URL` and `UIPATH_ACCESS_TOKEN` into `.env` - that step is no longer needed. The only thing `.env` carries now is the project ID, which is project-specific.

4. Add `.env` to your `.gitignore` to avoid accidentally committing it later:

   ```bash
   echo ".env" >> .gitignore
   ```

<!-- screenshot: step-05.png - terminal showing uip codedagent init output -->


## Step 6 - Build the Agent with Your Coding Agent

This is where the UiPath skills pay off. Open your coding agent and prompt it to create a coded agent. Notice that the prompt below is short - it describes *what* the agent should do, not *how* to build it. Compare this to a prompt without skills, which would need to specify the LangGraph StateGraph pattern, `UiPathAzureChatOpenAI` import path, lazy LLM initialization (required so `uipath init` works), async node requirements, Pydantic input/output schemas, and the `langgraph.json` config format. The skills handle all of that.

> **Skills value:** The `uipath-agents` skill gives your coding agent knowledge of LangGraph integration patterns, UiPath LLM models, correct SDK imports (`from uipath.platform import UiPath`), the lazy LLM initialization rule (LLM clients must be created inside functions, never at module level - otherwise `uip codedagent init` will fail), and reusable agent patterns. This is what allows a short prompt to produce correct, working code.

Use the following prompt (or adapt it to your use case):

```
Create a UiPath coded agent using LangGraph.

The agent is an intake classifier. Given a text description of a request,
it classifies the difficulty as one of four tiers:
- Trivial: Simple, routine tasks anyone can handle
- Standard: Moderate tasks requiring some skill or experience
- Heroic: Difficult tasks requiring significant expertise and coordination
- Legendary: Extreme tasks requiring top-tier expertise, large teams, and special approval

Return the classification tier and a brief reasoning.
Create a langgraph.json and an input.json with a sample request for testing.
```

> **Coding agents are non-deterministic.** Your generated code will differ from any examples shown here - that's expected. What matters is that `main.py` runs without errors and returns a classification.

After the coding agent finishes, re-run init to pick up the new entry points:

```bash
uip codedagent init
```

You should see output confirming the entry point was detected, along with an ASCII graph diagram:

```
Created 'entry-points.json' file with 1 entrypoint(s).
```

<!-- screenshot: step-06a.png - terminal showing init with entrypoint detected and graph diagram -->

Before pushing, add an `authors` entry to your `pyproject.toml` - UiPath requires this to package the project. Open `pyproject.toml` and add the `authors` line if it is not already present:

```toml
authors = [{ name = "Your Name" }]
```

Now push your agent to UiPath Studio - this creates the first version of your agent in the platform:

```bash
uip codedagent push
```

You can verify the push by opening your project in UiPath Studio. The Definition page will show your entrypoint, and the version will be `0.0.1`.

<!-- screenshot: step-06b.png - Studio Web showing v0.0.1 agent definition -->


## Step 7 - Run the Agent Locally

Run the agent with the sample input:

```bash
uip codedagent run agent --file input.json
```

Or pass input directly:

```bash
uip codedagent run agent '{"description": "Clear the rats out of the inn cellar"}'
```

You should see the agent classify the request and return a tier with reasoning.

Try a few different inputs to verify the classifications make sense:

```bash
uip codedagent run agent '{"description": "Slay the ancient red dragon terrorizing the countryside"}'
```

<!-- screenshot: step-07.png - terminal showing agent output -->


## Step 8 - Create Evaluation Tests

Evaluations test how well your agent performs across a range of inputs. Without skills, setting up evaluations requires knowing the evaluator config JSON format, the eval set schema, which evaluator types are available, and where to put each file. With skills, your coding agent already knows all of this.

> **Skills value:** The `uipath-agents` skill includes the complete evaluation framework reference - 9+ evaluator types (semantic similarity, trajectory, exact match, JSON similarity, tool call validators), the eval set JSON schema, directory structure conventions, and best practices like using `gpt-4.1` (not mini) for LLM judge evaluators. Your coding agent uses this to produce correct evaluator configs and test sets from a simple prompt.

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
defaultEvaluationCriteria - use `{"expectedOutput": {}}` for the
semantic evaluator and `{"expectedAgentBehavior": ""}` for the
trajectory evaluator. Empty `{}` fails schema validation.
```

Your coding agent will create the evaluator configuration and test cases using the evaluation patterns from the UiPath skills - no need to manually copy reference files.

<!-- screenshot: step-08a.png - eval set file structure -->

With evaluations added, push again to create a new version in Studio:

```bash
uip codedagent push
```

Open your project in UiPath Studio and you will see the version has incremented - your evaluation sets are now visible in the **Evaluation Sets** panel alongside your agent code.

<!-- screenshot: step-08b.png - Studio Web showing version history and evaluation sets -->


## Step 9 - Run Evaluations

Run the evaluation set:

```bash
uip codedagent eval agent evaluations/eval-sets/smoke-test.json --workers 3 --output-file eval-results.json
```

The evaluation framework runs each test case through your agent and scores the results.

| Score | What it measures |
|---|---|
| **Semantic similarity** | How closely the agent's output matches the expected output - are the right fields populated with the right values? |
| **Agent trajectory** | Whether the agent took the expected reasoning path - catches cases where the right answer was reached the wrong way |

Scores above 0.8 are generally solid. Review the output in `eval-results.json` to see how your agent performed.

> **Expect trajectory scores of 0.0 on this agent.** Trajectory evaluators judge the agent's *reasoning path* - which tools it called, in what order, how it routed between nodes. An intake classifier with a single `classify` node has no meaningful trajectory to evaluate, so every test case will score 0.0 on that evaluator. Trajectory evaluation shines on multi-step agents that use tools or route between nodes - keep it in mind for your next agent, and lean on semantic similarity for single-step classifiers.

Because you added your `UIPATH_PROJECT_ID` in Step 5, evaluation results are automatically reported to UiPath Studio. You can view detailed traces, scores, and agent trajectory analysis in the Studio Web **Evaluation Sets** panel.

<!-- screenshot: step-09.png - terminal showing eval results -->


## Step 10 - Iterate and Improve *(Optional)*

With evaluations in place, you can iterate on your agent:

1. Review evaluation scores and traces in UiPath Studio
2. Ask your coding agent to improve the agent based on evaluation feedback
3. Re-run evaluations to verify improvements
4. Push updated code back to Studio

```bash
uip codedagent eval agent evaluations/eval-sets/smoke-test.json --workers 3
uip codedagent push
```

* * *

## Congratulations!

You've built a coded agent on UiPath using the CLI and coding agent skills:
- You installed the UiPath CLI and skills that teach your coding agent UiPath development patterns
- Your coding agent built a LangGraph agent guided by skills - handling project structure, LLM integration, and evaluation patterns without detailed prompts
- You ran the agent locally and evaluated its performance with both semantic and trajectory evaluators
- You pushed multiple versions to UiPath Studio throughout development - with evaluation traces flowing from the start

## What's Next

- [UiPath LangGraph sample agents](https://github.com/UiPath/uipath-langchain-python/tree/main/samples) - working examples including ticket classification with human-in-the-loop, RAG, multi-agent supervisors, and MCP integration
- [UiPath Python SDK docs](https://uipath.github.io/uipath-python/) - full reference for CLI commands, agent patterns, and SDK APIs
- [Evaluation framework guide](https://uipath.github.io/uipath-python/eval/) - how to build, run, and interpret evaluation sets
- [LangGraph docs](https://langchain-ai.github.io/langgraph/) - the orchestration framework used in this lab
- [UiPath Community](https://community.uipath.com) - forums, how-tos, and developer discussion
