<!-- Internal operational file — not for attendees -->
# Paper Cuts — WAD2026 Workshop

Friction logged during build, eval setup, and smoke testing. Routes to product, content, or facilitator backlog.

## CLI / Tooling

| When | Friction Observed | Category | Suggested Action |
|---|---|---|---|
| Eval setup (2026-06-13) | `uip agent eval run start --path <agent_dir>` fails with "SolutionStorage.json not found" when the agent is inside a solution directory — CLI does not walk up to find the file | product | CLI should traverse up from `--path` to locate `SolutionStorage.json`; workaround: pass `--solution-id 578864c4-dd92-415a-6a1e-08dec6ebd11a` explicitly on every eval command |
| Eval setup (2026-06-13) | `uip agent validate` rejects `"source": "firstSuccessfulRun"` — value is written by Studio Web debug runs but is not in the CLI schema's allowed list (`debugRun\|manual\|runtimeRun\|simulatedRun\|autopilotUserInitiated`) | product | CLI schema and Studio Web should use the same source enum values; workaround: rewrite `firstSuccessfulRun` → `debugRun` in eval set JSON |

## Infrastructure / Environment

| When | Friction Observed | Category | Suggested Action |
|---|---|---|---|
| Eval run (2026-06-13) | DIA Meridian eval case fails with `ContextGroundingIndex 'Vendor_Contracts' not found` — the agent correctly calls the tool but the index is not provisioned in the staging tenant (MVPSummit26). Trajectory evaluator receives empty run history on failed evals, making trajectory scores unreliable until the index is available. | environment | Provision the Vendor_Contracts context grounding index in the MVPSummit26 staging tenant before smoke test; verify from shared workspace (not just personal workspace). Also flagged in workshop-design.md open items. |

## Flow / Studio Web

| When | Friction Observed | Category | Suggested Action |
|---|---|---|---|
| Flow debug (2026-06-15) | Script node `return { briefing }` works at runtime but the static design-time validator cannot inspect JavaScript return values — so `$vars.script1.output.briefing` referenced in a downstream autonomous agent prompt fails with "variable is not available in this scope." The script is correct; the validator just can't see it. | product | Platform should either (a) expose a declarative output schema on script nodes (like agent nodes have), or (b) skip static scope validation for `$vars.<scriptId>.output.*` references. Workaround: create a named flow variable (`emailBriefing`), use "Update variable" in the script node to assign to it, and reference `$vars.emailBriefing` in downstream prompts instead. |
| Flow debug (2026-06-15) | "Run node" button in Flow does not resolve flow variables — variables appear null when a node is executed in isolation. Only resolves correctly in a full end-to-end run. Misleading during debugging when you expect the last-run variable values to be available. | product | "Run node" should optionally use last-run variable values as context; or UI should surface a clear "variables unavailable in isolated run" warning. |
| Flow debug (2026-06-15) | Inline autonomous agents in Flow do not use `agentInputVariables` — they read `$vars` directly from the flow context. The empty `agentInputVariables: []` array in the flow definition is by design, not a misconfiguration. Confusing for developers who expect the same input-binding pattern as coded agents or other node types. | product/docs | Document clearly that inline autonomous agents access flow variables directly via `$vars`; distinguish from coded agents which require explicit input binding. |
| Flow UI (2026-06-15) | Pressing `ESC` in the code node text editor (e.g., when stuck in variable auto-complete) exits the editor dialog entirely and returns to the flow canvas — losing focus on the code node. Expected behavior: `ESC` should dismiss the auto-complete popup only, not close the editor. | product | `ESC` should cancel the active auto-complete/popup without closing the editor; require an explicit close action (e.g., click outside, dedicated close button) to exit the code editor. |

## Solution Upload / Studio Web Sync

| When | Friction Observed | Category | Suggested Action |
|---|---|---|---|
| Eval iteration (2026-06-15) | `uip solution upload --force` overwrites Studio Web agent config (system prompt, context grounding index) with local files, silently. Local files are typically stale when agent has been edited in Studio Web between pushes. Lost: prompt fix + Vendor_Contracts context grounding index mapping. Both required manual re-apply in Studio Web. | product/workflow | CLI should warn when server-side project was modified after last local sync. Workaround: before any solution push, pull/export the current agent state from Studio Web to local first; never push without confirming local files match server state. |

## Eval Infrastructure

| When | Friction Observed | Category | Suggested Action |
|---|---|---|---|
| Eval setup (2026-06-15) | Studio Web eval set UI requires `discrepancies` array to be non-empty to enable the Save button — blocks saving a valid perfect-match expected output with `"discrepancies": []`. Workaround: use `[{}]` (array with empty object) to satisfy UI validation; semantic meaning is preserved for the LLM evaluator. | product | UI should allow empty arrays for fields that are semantically valid empty. |
| Eval run (2026-06-15) | Trajectory evaluator errors (~5/100) when `AgentRunHistory` is empty and `expectedAgentBehavior` describes positive actions — evaluator has no evidence to score against. **Resolved pattern:** explicitly state the absence as intent: *"There should be no agent run history because no tool calls were required and everything can be handled within the LLM."* Evaluator scored 95/100 on empty history with this framing. Also: removing `expectedAgentBehavior` entirely causes an Error (not a score) — always include it. | pattern | Document this pattern in eval authoring guidance. |

## Model Sensitivity

| Agent | Observation | Category | Notes |
|---|---|---|---|
| Discrepancy Investigator Agent | Switching from GPT-5.4 to Claude Sonnet produces dramatically different eval scores (Output 92% → 64%, Trajectory 93% → 46%). Root cause: Claude checks Vendor_Contracts even on perfect-match invoices, surfacing minor contract-coverage observations (SKUs not in Exhibit A) with delta=0. Final recommendation is still "approve/not escalated" but the discrepancies list is no longer empty — causing output eval to score low against expected `[{}]`. Claude's behavior is arguably more thorough; it's a model-sensitivity issue in the eval, not a correctness issue. | eval design | Workshop is calibrated to GPT-5.4. Facilitator note: switching to Sonnet is a good "try this" aside that demonstrates model sensitivity without being in the critical path. |

## Agent Behavior

| Agent | Case | Friction Observed | Category | Suggested Action |
|---|---|---|---|---|
| Vendor Research Agent | Apex Global Solutions / United Supply Co. (unrelated) | Agent returns `relationship: unknown, flag: review, confidence: low` instead of `unrelated/reject/high` — narrative reasoning is correct but structured output is too cautious when no relationship is found | agent prompt | Tighten system prompt: explicit instruction that absence of a documented relationship is a confident `unrelated` classification, not an unknown — agent should not hedge when searches return no results |
