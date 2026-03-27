# UiPath Workshops

Hands-on workshops for professional developers building coded agents on UiPath.

## Workshops

### [Getting Started with Coded UiPath Agents](Getting-Started-With-Agents/Getting-Started-With-Agents-in-IDE.md)
Build your first coded agent entirely from your IDE — no visual designer required. You'll generate an address validation agent using Claude Code and the UiPath Python SDK, extend it with a live USPS validation API, and evaluate its performance using UiPath's eval framework.

**Time:** ~60 min (45 min without the USPS API step)
**Prerequisites:** UiPath account, VS Code, Python 3.11+, uv, USPS developer account

---

### [Getting Started with Coded UiPath Agents — Studio Web](Getting-Started-With-Agents/Getting-Started-With-Agents.md)
Build a coded agent starting from UiPath Studio Web — use Autopilot to generate an agent from a prompt, clone it to your IDE to extend it with code, add a USPS validation API, and run evaluation sets from both your IDE and Studio Web.

**Time:** ~60 min (45 min without the USPS API step)
**Prerequisites:** UiPath account on [staging.uipath.com](https://staging.uipath.com), VS Code, Python 3.11+, uv, USPS developer account

---

## Prerequisites (both workshops)

- **UiPath account** — [staging.uipath.com](https://staging.uipath.com) (Studio Web workshop) or [cloud.uipath.com](https://cloud.uipath.com) (IDE-first workshop)
- **VS Code** with a Bash-compatible terminal (Git Bash recommended on Windows)
- **Python 3.11+**
- **uv** — fast Python package manager: `pip install uv` or [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/)
- **USPS developer account** — [register at cop.usps.com](https://cop.usps.com) (allow 15–20 min for first-time setup)

## Resources

- [UiPath Python SDK](https://github.com/UiPath/uipath-python)
- [SDK docs](https://uipath.github.io/uipath-python/)
- [Eval framework guide](https://uipath.github.io/uipath-python/eval/)
- [UiPath Community](https://community.uipath.com)
