# WeAreDevelopers World Congress 2026 — Workshop Submission

**Event:** WeAreDevelopers World Congress · 8–10 July 2026 · Berlin
**Format:** 2-hour hands-on workshop (18 seats) · Intermediate level
**Category:** AI – Engineering & Platforms
**Status:** Draft v3 — pending final scenario lock (exact agent task TBD at smoke test)

---

## Title
**Trust, but Verify: Building a Document Agent That Survives Production**

## Abstract

Let's ship an agent into production. You'll start with the easy part: a document comes in, an agent reads it, pulls the fields, hands off the result — the kind of thing you could wire together yourself from an agent framework and a workflow engine. We'll build that starting point live, then do the part the demos always skip: keeping it alive in production.

Real documents don't match your template, and the agent that worked at design time answers differently each time. Over two hours you'll grow a simple document flow into a governed agentic workflow: adding an agent with inspectable traces, writing evals that validate its output and trajectory, and catching a regression before it ships. Then you'll publish it to run on durable, recoverable orchestration. You'll leave with a running agent and a reusable eval set you can point at your own work.

## What you'll walk away with
- A document-processing agent you built and watched run
- Output and trajectory evals you can reuse on your own projects
- A feel for what "production-grade" actually takes: durable execution, governance, recovery

## Prerequisites
Comfort reading code and JSON. No platform experience needed. Laptop + browser.

---

### Notes (internal)
- ~145 words (WAD abstract median ≈ 139; middle band 90–185).
- Spine: deterministic document flow → add agent + traces → output & trajectory evals (catch a live regression) → publish to durable/governed orchestration. HITL shown as a placeholder node, not built.
- Build surface: Maestro Flow in Studio Web (browser) — chosen to eliminate setup churn; deliberately NOT the bring-your-own-coding-agent/CLI path.
- Positioning: validated against the UiPath "Your agent needed a platform. Now it has one." blog — thesis match ("the hard part was never the demo; it's production"). Brand kept light in public copy; speaker affiliation carries attribution.
- "Glue it together yourself" is a rhetorical foil (the without-platform path), not the in-room build.
