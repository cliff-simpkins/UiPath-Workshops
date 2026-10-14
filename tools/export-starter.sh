#!/usr/bin/env bash
# export-starter.sh - export a Studio Web solution into starters/<name>/.
#
# Wraps the manual steps for building a tenant-neutral starter:
#   1. download the solution with `uip solution download --extract`
#   2. copy it into starters/<name>/ without tenant-specific files
#      (SolutionStorage.json, userProfile/, .output/, .env) or the
#      AGENTS.md / CLAUDE.md briefing files that --extract adds
#   3. scan the result for your organization, tenant, and identity names
#   4. run `uip agent validate` on every agent project in the solution
#
# It does not upload. Uploading from the tenant you exported from overwrites
# the original solution (the .uipx keeps its SolutionId), so test a fresh
# import from a different tenant or account instead.
#
# Usage (Git Bash, from the repo root):
#   tools/export-starter.sh <solution-id> <starter-name>
#   tools/export-starter.sh <solution-id> <starter-name> --force   # replace an existing starter
#   tools/export-starter.sh <solution-id> <starter-name> --dest <dir>  # write somewhere else (for a dry run)
#
# Find the solution ID in the Studio Web address bar (solutionId=...).

set -euo pipefail

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

[[ $# -lt 2 ]] && usage
SOLUTION_ID="$1"; NAME="$2"; shift 2
FORCE=0; DEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dest) DEST="$2"; shift 2 ;;
    *) usage ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${DEST:-$REPO_ROOT/starters/$NAME}"

if [[ -e "$TARGET" && $FORCE -ne 1 ]]; then
  echo "Target already exists: $TARGET"
  echo "Re-run with --force to replace it."
  exit 1
fi

# Org, tenant, and identity names to scan for afterwards.
STATUS_JSON="$(uip login status --output json)"
read -r ORG TENANT IDENTITY < <(python -c '
import json, sys
d = json.load(sys.stdin).get("Data", {})
print(d.get("Organization", ""), d.get("Tenant", ""), d.get("Identity", "").split("@")[0])
' <<<"$STATUS_JSON")
if [[ -z "$ORG" || -z "$TENANT" ]]; then
  echo "Not logged in (uip login status shows no organization or tenant). Run: uip login"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== Downloading solution $SOLUTION_ID"
uip solution download "$SOLUTION_ID" -d "$WORK" -n export --extract --output json >/dev/null
[[ -d "$WORK/export" ]] || { echo "Download did not produce an extracted folder."; exit 1; }

echo "== Copying into $TARGET (without tenant-specific files)"
rm -rf "$TARGET"
mkdir -p "$TARGET"
( cd "$WORK/export" && tar \
    --exclude='SolutionStorage.json' --exclude='userProfile' --exclude='.output' \
    --exclude='.env' --exclude='AGENTS.md' --exclude='CLAUDE.md' \
    -cf - . ) | tar -xf - -C "$TARGET"

echo "== Scanning for tenant names ($ORG, $TENANT, $IDENTITY)"
PATTERN="$ORG|$TENANT"
[[ -n "$IDENTITY" ]] && PATTERN="$PATTERN|$IDENTITY"
if HITS="$(grep -rlE "$PATTERN" "$TARGET")"; then
  echo "Tenant-specific values found in:"
  echo "$HITS"
  echo "Clean these before committing."
  SCAN_OK=0
else
  echo "clean"
  SCAN_OK=1
fi

echo "== Validating agent projects"
VALID_OK=1
FOUND=0
while IFS= read -r -d '' agent_json; do
  project_dir="$(dirname "$agent_json")"
  FOUND=1
  echo "-- $(basename "$project_dir")"
  if ! ( cd "$TARGET" && uip agent validate "$(basename "$project_dir")" --output json \
        | python -c 'import json,sys; d=json.load(sys.stdin); x=d.get("Data",{}); print(" ", d.get("Result"), x.get("Status",""), x.get("Validated",""))' ); then
    VALID_OK=0
  fi
done < <(find "$TARGET" -mindepth 2 -maxdepth 2 -name agent.json -print0)
[[ $FOUND -eq 0 ]] && echo "  (no agent projects found)"

echo
echo "Starter written to: $TARGET"
echo "Next steps:"
echo "  1. Write $TARGET/README.md (model it on starters/monster-selector/README.md)."
echo "  2. Add a row to starters/README.md."
echo "  3. Test a fresh import from a different tenant: cd $TARGET && uip login && uip solution upload ."
[[ $SCAN_OK -eq 1 && $VALID_OK -eq 1 ]] || exit 1
