# UiPath Workshops

Hands-on workshops for professional developers building agents on UiPath - coded (Python) and low-code.

## Workshops

### Low-code agents

#### [Getting Started with UiPath Agents](labs/agents/guide.md)

Build a low-code Monster Selector agent from the terminal using the UiPath CLI. Scaffold the solution, configure the system prompt and schemas, validate, and upload to Studio Web. Produces a Monster Selector agent used as the entry point for the tools and evals labs.

**Time:** 30-45 min
**Prerequisites:** UiPath account, Node.js 18+, Bash terminal

---

#### [Adding Tools to Your UiPath Agent](labs/agents-tools/guide.md)

Build a live API connector in Studio Web that searches the D&D 5e SRD, then connect it to your Monster Selector agent as a tool. The agent decides what to search for, calls the API, and selects the best match from live results - no pre-populated list required.

**Time:** 30-45 min
**Prerequisites:** UiPath account, Monster Selector agent from the previous lab (or the starter)

---

#### [Getting Started with Agent Evals](Getting-Started-With-Agent-Evals/Getting-Started-With-Agent-Evals.md)

Evaluate the tool-using Monster Selector agent you built in the previous lab. Build an evaluation set, run cloud evaluations, and use the scores to drive prompt iteration.

**Time:** 45-60 min
**Prerequisites:** UiPath account, tool-using Monster Selector agent from the previous lab

---

### Coded agents (Python)

#### [Getting Started with UiPath Agents using LangGraph](labs/agents-langgraph/guide.md)

Install the UiPath CLI and coding-agent skills, then use your coding agent to build, run, evaluate, and deploy a coded agent end-to-end from the IDE. Skills teach your coding agent LangGraph integration patterns, SDK imports, and evaluation framework conventions so a short prompt produces correct working code. Builds an intake classifier.

**Time:** 45-60 min
**Prerequisites:** UiPath account, VS Code with a coding agent (Claude Code, Cursor, Copilot), Node.js 18+, Bash terminal, uv

---

#### [Getting Started with Coded UiPath Agents (IDE-first and Python SDK)](Getting-Started-With-Agents/Getting-Started-With-Agents-in-IDE.md)

Build your first coded agent entirely from your IDE - no visual designer required. You'll generate an address validation agent using Claude Code and the UiPath Python SDK, extend it with a live USPS validation API, and evaluate its performance using UiPath's eval framework.

**Time:** ~60 min (45 min without the USPS API step)
**Prerequisites:** UiPath account, VS Code, Python 3.11+, uv, USPS developer account

---

#### [Getting Started with Coded UiPath Agents - Studio Web](Getting-Started-With-Agents/Getting-Started-With-Agents.md)

Build a coded agent starting from UiPath Studio Web - use Autopilot to generate an agent from a prompt, clone it to your IDE to extend it with code, add a USPS validation API, and run evaluation sets from both your IDE and Studio Web.

**Time:** ~60 min (45 min without the USPS API step)
**Prerequisites:** UiPath account on [staging.uipath.com](https://staging.uipath.com), VS Code, Python 3.11+, uv, USPS developer account

---

## Starters

Reusable agent and workflow artifacts that workshops produce or consume. Clone a starter when you want a running reference without walking through the full lab. See [starters/README.md](starters/) for the current list.

## Resources

- [UiPath Python SDK](https://github.com/UiPath/uipath-python)
- [SDK docs](https://uipath.github.io/uipath-python/)
- [Eval framework guide](https://uipath.github.io/uipath-python/eval/)
- [UiPath Community](https://community.uipath.com)
