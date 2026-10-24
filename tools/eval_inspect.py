"""eval_inspect.py — inspect a Studio Web agent evaluation run from the terminal.

Pulls one evaluation set run for a low-code agent and prints, per case:
- each evaluator's score and justification
- the tool calls the agent actually made (from the run's trace)
- the tool calls the trajectory evaluator was shown (from its AgentRunHistory)

The last two columns differ when the evaluator's view of the run doesn't
match what happened (for example, UV-17182: each tool call shows up twice in
AgentRunHistory, the first with an empty `{}` response).

Wraps the `uip` CLI (must be installed and logged in):
  uip solution download         - local copy of the solution (cached)
  uip agent eval run list       - pick the run
  uip agent eval run results    - scores + justifications (--verbose)
  uip traces spans get          - the run's trace (trace id = run id)

Stdlib only. Python 3.11+.

Usage:
    python tools/eval_inspect.py <solution-id> --set "Quest Classifier with Tools"
        # Latest run of the set

    python tools/eval_inspect.py <solution-id> --set "..." --run <eval-set-run-id>
        # A specific run

    python tools/eval_inspect.py <solution-id> --set "..." --list
        # List recent runs and exit

    python tools/eval_inspect.py <solution-id> --set "..." --case relic --history
        # Only cases whose name contains "relic", plus the full AgentRunHistory

Options:
    --agent <name>    Agent project folder, if the solution has more than one
    --refresh         Re-download the solution instead of using the cache
    --no-trace        Skip the trace lookup (faster; no tool-call columns)
    --json <file>     Also write the collected data as JSON

The solution cache lives in .devrel/eval-cache/<solution-id>/ (gitignored).
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_ROOT = REPO_ROOT / ".devrel" / "eval-cache"


# --- uip CLI ---------------------------------------------------------------

def uip(*args: str) -> object:
    """Run a uip command with --output json and return its Data field."""
    exe = shutil.which("uip")
    if not exe:
        sys.exit("error: `uip` not found on PATH. Install the UiPath CLI and run `uip login`.")
    proc = subprocess.run(
        [exe, *args, "--output", "json"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    out = proc.stdout
    start = out.find("{")
    if start < 0:
        sys.exit(f"error: no JSON from `uip {' '.join(args)}`:\n{out}\n{proc.stderr}")
    try:
        envelope = json.loads(out[start:])
    except json.JSONDecodeError as exc:
        sys.exit(f"error: could not parse `uip {' '.join(args)}` output: {exc}")
    if envelope.get("Result") != "Success":
        sys.exit(f"error: `uip {' '.join(args)}` failed: {envelope.get('Message') or envelope}")
    return envelope.get("Data")


# --- solution cache --------------------------------------------------------

def solution_dir(solution_id: str, refresh: bool) -> Path:
    target = CACHE_ROOT / solution_id
    extracted = target / "x"
    if extracted.exists() and not refresh:
        return extracted
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    data = uip("solution", "download", solution_id, "-d", str(target))
    archive = Path(data["Output"]) if isinstance(data, dict) and data.get("Output") else None
    if archive is None or not archive.exists():
        archives = list(target.glob("*.uis"))
        if not archives:
            sys.exit(f"error: solution download produced no .uis in {target}")
        archive = archives[0]
    with zipfile.ZipFile(archive) as zf:
        zf.extractall(extracted)
    return extracted


def find_agent(root: Path, name: str | None) -> Path:
    agents = sorted(p.parent for p in root.glob("*/agent.json") if (p.parent / "evals").exists())
    if name:
        agents = [a for a in agents if a.name == name]
    if not agents:
        sys.exit(f"error: no agent project with evals found in {root}" + (f" named {name!r}" if name else ""))
    if len(agents) > 1:
        names = ", ".join(a.name for a in agents)
        sys.exit(f"error: several agent projects ({names}); pick one with --agent")
    return agents[0]


def trajectory_evaluators(agent: Path) -> set[str]:
    """Names of evaluators in the trajectory category (category 3)."""
    names = set()
    for f in (agent / "evals" / "evaluators").glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if d.get("category") == 3:
            names.add(d.get("name", ""))
    return names


# --- parsing ---------------------------------------------------------------

def parse_scores(text: str) -> dict[str, str]:
    scores = {}
    for part in (text or "").split(","):
        if ":" in part:
            name, value = part.rsplit(":", 1)
            scores[name.strip()] = value.strip()
    return scores


def parse_justifications(text: str) -> dict[str, str]:
    found = {}
    for m in re.finditer(r"\[([^\]]+)\]\s*(.*?)(?=\s*\|\s*\[[^\]]+\]|\Z)", text or "", re.S):
        found[m.group(1).strip()] = m.group(2).strip()
    return found


def _attrs(span: dict) -> dict:
    a = span.get("Attributes") or {}
    if isinstance(a, str):
        try:
            a = json.loads(a)
        except json.JSONDecodeError:
            a = {}
    return a


def _find_text(obj: object, marker: str) -> str | None:
    """Return the first string anywhere inside obj that contains marker."""
    if isinstance(obj, str):
        return obj if marker in obj else None
    items = obj.values() if isinstance(obj, dict) else obj if isinstance(obj, list) else ()
    for item in items:
        found = _find_text(item, marker)
        if found:
            return found
    return None


def trace_by_case(run_id: str) -> dict[str, dict]:
    """Map case name -> {'calls': [...search inputs], 'history': str|None}."""
    spans = uip("traces", "spans", "get", run_id) or []
    by_id = {s["Id"]: s for s in spans}
    case_names = {}
    for s in spans:
        if s.get("SpanType") == "evaluation":
            a = _attrs(s)
            case_names[a.get("eval_item_id") or a.get("execution.id")] = a.get("eval_item_name", "?")

    def case_of(span: dict) -> str | None:
        seen = 0
        while span and seen < 50:
            a = _attrs(span)
            cid = a.get("eval_item_id") or a.get("execution.id")
            if cid in case_names:
                return case_names[cid]
            span = by_id.get(span.get("ParentId"))
            seen += 1
        return None

    out: dict[str, dict] = {}
    for s in spans:
        a = _attrs(s)
        if s.get("SpanType") == "toolCall":
            name = case_of(s)
            if name:
                inp = a.get("input")
                term = inp.get("searchName", json.dumps(inp)) if isinstance(inp, dict) else str(inp)
                out.setdefault(name, {"calls": [], "history": None})["calls"].append(
                    f"{a.get('toolName', s.get('Name'))}({term})")
        elif s.get("SpanType") == "function_call_async":
            prompt = _find_text(a, "AgentRunHistory:")
            if prompt:
                name = case_of(s)
                if name:
                    out.setdefault(name, {"calls": [], "history": None})["history"] = \
                        prompt.split("AgentRunHistory:", 1)[-1].strip()
    return out


def history_call_count(history: str | None) -> str:
    if history is None:
        return "?"
    calls = len(re.findall(r"Tool Call Response", history))
    empty = len(re.findall(r"Tool Call Response[^\n]*:\s*\n?\s*\{\}", history))
    return f"{calls}" + (f" ({empty} empty)" if empty else "")


# --- main ------------------------------------------------------------------

def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("solution_id")
    ap.add_argument("--set", required=True, dest="eval_set", help="Evaluation set name or ID")
    ap.add_argument("--run", help="Evaluation set run ID (default: latest)")
    ap.add_argument("--agent", help="Agent project folder name")
    ap.add_argument("--case", help="Only cases whose name contains this text")
    ap.add_argument("--list", action="store_true", help="List recent runs and exit")
    ap.add_argument("--history", action="store_true", help="Print each case's AgentRunHistory")
    ap.add_argument("--refresh", action="store_true", help="Re-download the solution")
    ap.add_argument("--no-trace", action="store_true", help="Skip the trace lookup")
    ap.add_argument("--json", help="Write collected data to this JSON file")
    args = ap.parse_args()

    agent = find_agent(solution_dir(args.solution_id, args.refresh), args.agent)
    common = ["--set", args.eval_set, "--path", str(agent)]

    runs = uip("agent", "eval", "run", "list", *common) or []
    if args.list:
        for r in runs[:15]:
            print(f"{r['EvalSetRunId']}  {r['CreatedAt'][:19]}  cases={r['TestCases']}  {r['EvaluatorScores']}")
        return
    if not runs:
        sys.exit(f"error: no runs for set {args.eval_set!r}")
    run = next((r for r in runs if r["EvalSetRunId"] == args.run), None) if args.run else runs[0]
    if run is None:
        sys.exit(f"error: run {args.run} not found in set {args.eval_set!r} (try --list)")

    run_id = run["EvalSetRunId"]
    results = uip("agent", "eval", "run", "results", run_id, *common, "--verbose") or []
    trace = {} if args.no_trace else trace_by_case(run_id)
    traj_names = trajectory_evaluators(agent)

    print(f"Run {run_id}  {run['CreatedAt'][:19]}  {run['Status']}  {run['EvaluatorScores']}")
    print(f"Agent: {agent.name}   Set: {args.eval_set}\n")

    collected = []
    for case in results:
        name = case["TestCase"]
        if args.case and args.case.lower() not in name.lower():
            continue
        scores = parse_scores(case.get("EvaluatorScores", ""))
        justs = parse_justifications(case.get("Justifications", ""))
        t = trace.get(name, {"calls": [], "history": None})
        print(f"## {name}")
        for ev, score in scores.items():
            tag = " (trajectory)" if ev in traj_names else ""
            print(f"  {ev}{tag}: {score}")
        if not args.no_trace:
            calls = ", ".join(t["calls"]) or "none"
            print(f"  Tool calls in trace: {len(t['calls'])}  [{calls}]")
            print(f"  Tool calls the trajectory evaluator saw: {history_call_count(t['history'])}")
        for ev, text in justs.items():
            print(f"  [{ev}] {text}")
        if args.history and t["history"]:
            print("  --- AgentRunHistory ---")
            for line in t["history"].splitlines():
                print(f"    {line}")
        print()
        collected.append({"case": name, "scores": scores, "justifications": justs,
                          "trace_tool_calls": t["calls"], "agent_run_history": t["history"]})

    if args.json:
        Path(args.json).write_text(json.dumps({"run": run, "cases": collected}, indent=2), encoding="utf-8")
        print(f"Wrote {args.json}")


if __name__ == "__main__":
    main()
