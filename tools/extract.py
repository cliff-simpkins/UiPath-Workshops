"""extract.py — generate test_lab.py from a lab guide.md.

Per ADR-0001 (.devrel/docs/decisions/0001-labs-as-code-artifact-shape.md):
- guide.md is the sole source of truth
- tests are defined inline via HTML-comment annotations on fenced code blocks
- this script walks guide.md and emits test_lab.py (pytest)

Per ADR-0002 (.devrel/docs/decisions/0002-do-not-commit-test-lab-py.md):
- test_lab.py is NOT committed; CI extracts on the fly
- --verify mode is retained as a local pre-commit convenience but is no longer
  the CI gate

Stdlib only. No external deps. Python 3.11+.

Usage:
    python tools/extract.py labs/agents-langgraph/guide.md
        # Writes labs/skills-and-cli/test_lab.py next to the guide

    python tools/extract.py labs/agents-langgraph/guide.md --verify
        # Exits 1 if an existing test_lab.py differs from generated
        # (Local convenience — CI does not depend on this.)

    python tools/extract.py labs/agents-langgraph/guide.md --stdout
        # Prints to stdout instead of writing

The input file's basename must be 'guide.md' (per the convention in ADR-0001).
Pass --no-validate-name to bypass for ad-hoc use.

See .devrel/docs/test-annotations.md for annotation grammar.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

ANNOTATION_RE = re.compile(r"<!--\s*test:(\w+)\s*(.*?)\s*-->")
FENCE_RE = re.compile(r"^(\s*)```(\w*)\s*$")


class ExtractError(Exception):
    """Raised on malformed annotations or grammar violations."""


@dataclass
class Annotation:
    kind: str  # command | manual | prereq | setup | teardown
    attrs: dict[str, object]
    line_no: int  # 1-indexed line where the annotation appears
    body: str = ""  # fenced code block body (empty for manual)
    body_lang: str = ""  # fenced code block language tag


@dataclass
class Frontmatter:
    id: str
    title: str
    target_time_min: int
    audience: str


@dataclass
class Lab:
    frontmatter: Frontmatter
    annotations: list[Annotation] = field(default_factory=list)


def parse_attrs(raw: str) -> dict[str, object]:
    """Parse annotation attrs: `key=value key2="v with spaces" flag`.

    - `key=value` -> {key: "value"}
    - `key="value"` -> {key: "value"} (strips quotes)
    - `key` (no =) -> {key: True}
    - Repeatable keys accumulate into a list (e.g., stdout_contains).
    """
    repeatable = {"stdout_contains"}
    attrs: dict[str, object] = {}

    # Tokenize: match key=value (with optional quotes) OR bare flag
    token_re = re.compile(
        r'(\w+)(?:=(?:"([^"]*)"|(\S+)))?'
    )
    for match in token_re.finditer(raw):
        key = match.group(1)
        quoted = match.group(2)
        bare = match.group(3)
        if quoted is not None:
            value: object = quoted
        elif bare is not None:
            value = bare
        else:
            value = True

        if key in repeatable:
            attrs.setdefault(key, []).append(value)
        else:
            if key in attrs:
                raise ExtractError(f"duplicate attribute {key!r}")
            attrs[key] = value

    return attrs


def parse_lab_yaml(lab_dir: Path) -> Frontmatter:
    """Read lab metadata from lab.yaml sidecar (per ADR-0003).

    Supports only `key: value` lines — adequate for lab metadata.
    """
    yaml_path = lab_dir / "lab.yaml"
    if not yaml_path.exists():
        raise ExtractError(
            f"lab.yaml not found in {lab_dir}; "
            "per ADR-0003 lab metadata belongs in lab.yaml alongside guide.md"
        )
    fields: dict[str, str] = {}
    for line in yaml_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            raise ExtractError(f"malformed lab.yaml line: {line!r}")
        key, _, value = line.partition(":")
        fields[key.strip()] = value.strip().strip('"').strip("'")

    required = {"id", "title", "target_time_min", "audience"}
    missing = required - fields.keys()
    if missing:
        raise ExtractError(f"lab.yaml missing required fields: {sorted(missing)}")

    try:
        target_time_min = int(fields["target_time_min"])
    except ValueError:
        raise ExtractError(
            f"target_time_min must be an int, got {fields['target_time_min']!r}"
        )

    return Frontmatter(
        id=fields["id"],
        title=fields["title"],
        target_time_min=target_time_min,
        audience=fields["audience"],
    )


def parse_lab(text: str, lab_dir: Path) -> Lab:
    """Walk markdown, pairing annotations with following fenced code blocks."""
    frontmatter = parse_lab_yaml(lab_dir)
    lab = Lab(frontmatter=frontmatter)

    lines = text.splitlines()
    i = 0

    pending: Annotation | None = None

    while i < len(lines):
        line = lines[i]
        annot_match = ANNOTATION_RE.search(line)

        if annot_match:
            if pending is not None:
                # An annotation was sitting unpaired — emit the previous one
                # as a manual if its kind allows, else error.
                if pending.kind == "manual":
                    lab.annotations.append(pending)
                else:
                    raise ExtractError(
                        f"annotation at line {pending.line_no} has no "
                        f"following code block"
                    )
                pending = None

            kind = annot_match.group(1)
            raw_attrs = annot_match.group(2)
            try:
                attrs = parse_attrs(raw_attrs)
            except ExtractError as e:
                raise ExtractError(
                    f"line {i + 1 + frontmatter_lines}: {e}"
                )
            pending = Annotation(
                kind=kind,
                attrs=attrs,
                line_no=i + 1,
            )
            i += 1
            continue

        # Check for opening fence
        fence_match = FENCE_RE.match(line)
        if fence_match and pending is not None and pending.kind != "manual":
            indent = fence_match.group(1)
            lang = fence_match.group(2)
            # Collect until closing fence at <= same indent
            body_lines: list[str] = []
            i += 1
            while i < len(lines):
                close_match = FENCE_RE.match(lines[i])
                if close_match and len(close_match.group(1)) <= len(indent):
                    break
                body_lines.append(lines[i])
                i += 1
            if i >= len(lines):
                raise ExtractError(
                    f"unclosed code fence after annotation at line "
                    f"{pending.line_no}"
                )
            # Strip the opening fence's indent from each body line
            if indent:
                body_lines = [
                    line[len(indent):] if line.startswith(indent) else line
                    for line in body_lines
                ]
            pending.body = "\n".join(body_lines)
            pending.body_lang = lang
            lab.annotations.append(pending)
            pending = None
            i += 1  # skip closing fence
            continue

        # A manual annotation terminates at a blank line, another annotation,
        # or a heading. For simplicity we emit it as soon as the next non-
        # empty structural thing arrives. But the code above already handles
        # that by emitting on the next annotation. We also emit at EOF.
        i += 1

    if pending is not None:
        if pending.kind == "manual":
            lab.annotations.append(pending)
        else:
            raise ExtractError(
                f"annotation at line {pending.line_no} has no following "
                f"code block"
            )

    validate(lab)
    return lab


def validate(lab: Lab) -> None:
    """Enforce grammar constraints that parse_lab cannot catch structurally."""
    valid_kinds = {"command", "manual", "prereq", "setup", "teardown"}
    valid_requires = {"auth", "network", "studio_web", "interactive"}
    valid_audiences = {"professional-developer", "rpa-developer", "citizen-developer"}

    if lab.frontmatter.audience not in valid_audiences:
        raise ExtractError(
            f"audience must be one of {sorted(valid_audiences)}, got "
            f"{lab.frontmatter.audience!r}"
        )

    for annot in lab.annotations:
        if annot.kind not in valid_kinds:
            raise ExtractError(
                f"unknown annotation type {annot.kind!r} at line "
                f"{annot.line_no} (valid: {sorted(valid_kinds)})"
            )

        if annot.kind == "manual":
            if "reason" not in annot.attrs:
                raise ExtractError(
                    f"test:manual at line {annot.line_no} missing `reason`"
                )
            continue

        if annot.kind == "prereq":
            for required in ("name", "version"):
                if required not in annot.attrs:
                    raise ExtractError(
                        f"test:prereq at line {annot.line_no} missing "
                        f"`{required}`"
                    )

        requires = annot.attrs.get("requires")
        if requires is not None:
            for marker in str(requires).split(","):
                marker = marker.strip()
                if marker and marker not in valid_requires:
                    raise ExtractError(
                        f"unknown `requires` marker {marker!r} at line "
                        f"{annot.line_no} (valid: {sorted(valid_requires)})"
                    )


# ---------------------------------------------------------------------------
# Test emission
# ---------------------------------------------------------------------------


FILE_HEADER = '''"""Generated by tools/extract.py from {source}.

DO NOT EDIT BY HAND. Edit the source guide.md and re-run extract.py.
Changes here will be reverted by the `extract.py --verify` CI check.

Lab: {title}
Target time: {target_time_min} min
Audience: {audience}
"""
from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Marker-based skipping
# ---------------------------------------------------------------------------


def _env_flag(name: str) -> bool:
    return os.environ.get(name, "").lower() in ("1", "true", "yes")


def pytest_configure(config):  # pragma: no cover
    # Registered in the generated file so pytest recognizes the markers.
    # Runners should prefer pytest.ini/pyproject.toml config for this, but
    # keeping it here means the generated test module is self-contained.
    for marker in ("requires_auth", "requires_network",
                   "requires_studio_web", "requires_interactive"):
        config.addinivalue_line("markers", marker)


REQUIRES_AUTH = pytest.mark.skipif(
    not _env_flag("UIPATH_TEST_AUTH"),
    reason="requires authenticated UiPath session (set UIPATH_TEST_AUTH=1)",
)
REQUIRES_STUDIO_WEB = pytest.mark.skipif(
    not _env_flag("UIPATH_TEST_STUDIO_WEB"),
    reason="requires Studio Web (set UIPATH_TEST_STUDIO_WEB=1)",
)
REQUIRES_INTERACTIVE = pytest.mark.skipif(
    not _env_flag("UIPATH_TEST_INTERACTIVE"),
    reason="requires interactive input (set UIPATH_TEST_INTERACTIVE=1)",
)


# ---------------------------------------------------------------------------
# Scratch workspace fixture
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def scratch(tmp_path_factory):
    path = tmp_path_factory.mktemp("lab-{id}")
    os.environ["SCRATCH"] = str(path)
    return path


# ---------------------------------------------------------------------------
# Command runner
# ---------------------------------------------------------------------------


def run_command(
    cmd: str, cwd: Path, timeout: int = 60, lang: str = "bash"
) -> subprocess.CompletedProcess:
    """Run a shell command, capturing stdout/stderr.

    Labs document bash as a prerequisite. On Windows, git-bash is expected.
    Python's shell=True uses cmd.exe on Windows which breaks bash syntax
    (single-quote strings, $VAR, pipes), so we route bash commands through
    `bash -c` explicitly.
    """
    if lang in ("bash", "sh", ""):
        argv = ["bash", "-c", cmd]
    elif lang in ("powershell", "pwsh"):
        argv = ["powershell", "-NoProfile", "-Command", cmd]
    elif lang == "cmd":
        argv = ["cmd", "/c", cmd]
    else:
        # Unknown lang — fall back to bash. Annotations should prefer
        # lang=bash or omit.
        argv = ["bash", "-c", cmd]
    return subprocess.run(
        argv,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def assert_command(
    result: subprocess.CompletedProcess,
    *,
    exit_code: int = 0,
    stdout_contains: list[str] | None = None,
    stdout_matches: str | None = None,
    stdout_json_length: str | None = None,
) -> None:
    """Assert command result against expectations. Raises AssertionError."""
    if result.returncode != exit_code:
        raise AssertionError(
            f"exit_code mismatch: expected {{exit_code}}, got "
            f"{{result.returncode}}\\nstdout: {{result.stdout[:500]}}\\n"
            f"stderr: {{result.stderr[:500]}}"
        )
    if stdout_contains:
        for needle in stdout_contains:
            if needle not in result.stdout:
                raise AssertionError(
                    f"stdout missing expected substring {{needle!r}}\\n"
                    f"stdout: {{result.stdout[:500]}}"
                )
    if stdout_matches:
        if not re.search(stdout_matches, result.stdout):
            raise AssertionError(
                f"stdout did not match pattern {{stdout_matches!r}}\\n"
                f"stdout: {{result.stdout[:500]}}"
            )
    if stdout_json_length:
        m = re.match(r"(>=|<=|==|>|<|=)\\s*(\\d+)", stdout_json_length)
        if not m:
            raise AssertionError(
                f"malformed stdout_json_length: {{stdout_json_length!r}}"
            )
        op, n_str = m.group(1), m.group(2)
        n = int(n_str)
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise AssertionError(
                f"stdout was not valid JSON: {{e}}\\n"
                f"stdout: {{result.stdout[:500]}}"
            )
        actual = len(data) if hasattr(data, "__len__") else 0
        if op in ("==", "="):
            ok = actual == n
        elif op == ">=":
            ok = actual >= n
        elif op == "<=":
            ok = actual <= n
        elif op == ">":
            ok = actual > n
        elif op == "<":
            ok = actual < n
        else:  # pragma: no cover
            ok = False
        if not ok:
            raise AssertionError(
                f"stdout JSON length: expected {{op}} {{n}}, got {{actual}}"
            )


'''


def emit(lab: Lab, source: Path) -> str:
    """Emit the generated pytest module as a single string."""
    fm = lab.frontmatter
    parts: list[str] = [
        FILE_HEADER.format(
            source=source.as_posix(),
            title=fm.title,
            target_time_min=fm.target_time_min,
            audience=fm.audience,
            id=fm.id.replace("-", "_"),
        )
    ]

    # Session-level setup/teardown
    setups = [a for a in lab.annotations if a.kind == "setup"]
    teardowns = [a for a in lab.annotations if a.kind == "teardown"]
    if setups or teardowns:
        parts.append("@pytest.fixture(scope=\"session\", autouse=True)\n")
        parts.append("def session_setup(scratch):\n")
        for a in setups:
            parts.append(
                f"    run_command({a.body.strip()!r}, "
                f"cwd=scratch, timeout={int(a.attrs.get('timeout', 60))}, "
                f"lang={a.body_lang!r})\n"
            )
        parts.append("    yield\n")
        for a in teardowns:
            parts.append(
                f"    run_command({a.body.strip()!r}, "
                f"cwd=scratch, timeout={int(a.attrs.get('timeout', 60))}, "
                f"lang={a.body_lang!r})\n"
            )
        parts.append("\n\n")

    # Prereq tests
    prereq_index = 0
    for a in lab.annotations:
        if a.kind != "prereq":
            continue
        prereq_index += 1
        name_slug = re.sub(
            r"[^a-z0-9]+", "_",
            str(a.attrs["name"]).lower(),
        ).strip("_")
        parts.append(
            f"def test_prereq_{prereq_index:02d}_{name_slug}(scratch):\n"
        )
        parts.append(f'    """Prereq: {a.attrs["name"]} {a.attrs["version"]}"""\n')
        parts.append(
            f"    result = run_command({a.body.strip()!r}, cwd=scratch, "
            f"timeout={int(a.attrs.get('timeout', 60))}, "
            f"lang={a.body_lang!r})\n"
        )
        parts.append(
            "    if result.returncode != 0:\n"
            f"        pytest.fail(\n"
            f'            f"prereq {a.attrs["name"]} failed: "\n'
            f"            f\"{{result.stderr or result.stdout}}\"\n"
            "        )\n"
        )
        parts.append("\n\n")

    # Command tests (and manual placeholders)
    cmd_index = 0
    for a in lab.annotations:
        if a.kind not in ("command", "manual"):
            continue
        cmd_index += 1
        markers: list[str] = []
        requires = a.attrs.get("requires")
        if requires:
            for marker in str(requires).split(","):
                marker = marker.strip()
                if marker == "auth":
                    markers.append("REQUIRES_AUTH")
                elif marker == "studio_web":
                    markers.append("REQUIRES_STUDIO_WEB")
                elif marker == "interactive":
                    markers.append("REQUIRES_INTERACTIVE")
                # network has no marker — runs by default

        if a.kind == "manual":
            reason = a.attrs["reason"]
            parts.append(
                f"@pytest.mark.skip(reason={str(reason)!r})\n"
            )
            parts.append(
                f"def test_cmd_{cmd_index:02d}_manual():\n"
            )
            parts.append(
                f'    """Manual step at guide.md line {a.line_no}."""\n'
            )
            parts.append("    pass\n\n\n")
            continue

        if a.attrs.get("skip_in_test"):
            parts.append(
                f'@pytest.mark.skip(reason="skip_in_test=true")\n'
            )

        for m in markers:
            parts.append(f"@{m}\n")

        parts.append(f"def test_cmd_{cmd_index:02d}(scratch):\n")
        parts.append(f'    """Command at guide.md line {a.line_no}."""\n')

        cwd_attr = a.attrs.get("cwd")
        if cwd_attr:
            parts.append(f"    cwd = scratch / {str(cwd_attr)!r}\n")
            parts.append("    cwd.mkdir(parents=True, exist_ok=True)\n")
        else:
            parts.append("    cwd = scratch\n")

        timeout = int(a.attrs.get("timeout", 60))
        cmd_body = a.body.strip()
        parts.append(
            f"    result = run_command({cmd_body!r}, cwd=cwd, "
            f"timeout={timeout}, lang={a.body_lang!r})\n"
        )

        # Build assert_command kwargs
        kwargs: list[str] = []
        exit_code = a.attrs.get("exit_code", "0")
        kwargs.append(f"exit_code={int(exit_code)}")
        sc = a.attrs.get("stdout_contains")
        if sc:
            if isinstance(sc, list):
                kwargs.append(f"stdout_contains={[str(x) for x in sc]!r}")
            else:
                kwargs.append(f"stdout_contains={[str(sc)]!r}")
        sm = a.attrs.get("stdout_matches")
        if sm:
            kwargs.append(f"stdout_matches={str(sm)!r}")
        sjl = a.attrs.get("stdout_json_length")
        if sjl:
            kwargs.append(f"stdout_json_length={str(sjl)!r}")

        parts.append(
            "    assert_command(\n"
            "        result,\n"
            + "".join(f"        {k},\n" for k in kwargs)
            + "    )\n\n\n"
        )

    return "".join(parts)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("guide", type=Path, help="path to lab guide.md")
    ap.add_argument(
        "--verify",
        action="store_true",
        help="local convenience: exit 1 if existing test_lab.py differs from "
             "fresh extraction (not used by CI; see ADR-0002)",
    )
    ap.add_argument(
        "--stdout",
        action="store_true",
        help="print to stdout instead of writing file",
    )
    ap.add_argument(
        "--no-validate-name",
        action="store_true",
        help="skip the basename=='guide.md' check (for ad-hoc use)",
    )
    args = ap.parse_args()

    if not args.guide.exists():
        print(f"error: guide not found: {args.guide}", file=sys.stderr)
        return 2

    if not args.no_validate_name and args.guide.name != "guide.md":
        print(
            f"error: input must be named 'guide.md' (got {args.guide.name!r}); "
            f"per ADR-0001 the lab convention is labs/<slug>/guide.md. "
            f"Pass --no-validate-name to bypass.",
            file=sys.stderr,
        )
        return 2

    try:
        text = args.guide.read_text(encoding="utf-8")
        lab = parse_lab(text, args.guide.parent)
        generated = emit(lab, args.guide)
    except ExtractError as e:
        print(f"extract error: {e}", file=sys.stderr)
        return 2

    target = args.guide.with_name("test_lab.py")

    if args.stdout:
        sys.stdout.write(generated)
        return 0

    if args.verify:
        if not target.exists():
            print(
                f"verify failed: {target} does not exist; run without --verify",
                file=sys.stderr,
            )
            return 1
        existing = target.read_text(encoding="utf-8")
        if existing != generated:
            print(
                f"verify failed: {target} is out of sync with {args.guide}\n"
                f"regenerate with: python tools/extract.py {args.guide}",
                file=sys.stderr,
            )
            return 1
        return 0

    target.write_text(generated, encoding="utf-8")
    print(f"wrote {target} ({generated.count(chr(10))} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
