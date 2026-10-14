"""open5e_check.py - check the Open5e search results a lab guide relies on.

The tools labs (agents-tools, agents-langgraph) make concrete claims about the
Open5e v2 API: "search rat and you get 7 results", "dragon matches 43", "the
Ancient Red Dragon is challenge rating 24". Open5e's data can change, and it
silently ignores query parameters it does not recognize, so these claims are
worth re-checking before a guide ships or a video is recorded.

Stdlib only. No external deps. Python 3.11+.

Usage:
    python tools/open5e_check.py rat dragon "ancient red"
        # Count and list matches for each search in SRD 2024

    python tools/open5e_check.py rat=7 dragon=43 goblin=5
        # Same, but exit 1 if any count differs from the expected number

    python tools/open5e_check.py goblin --doc srd-2014
        # Search a different document; --doc none drops the filter

    python tools/open5e_check.py rat --param name_icontains=rat --no-name-filter
        # Send arbitrary query parameters, for example to show what a
        # misspelled filter returns (Open5e ignores it and returns everything)

Searches use the same parameters the agents-tools API Workflow sends:
name__icontains, document__key, limit, and fields.
"""
import argparse
import json
import sys
import urllib.parse
import urllib.request

API = "https://api.open5e.com/v2/creatures/"
DEFAULT_FIELDS = "key,name,challenge_rating"


def search(term: str | None, doc: str, limit: int, fields: str, extra: dict) -> dict:
    params = {"limit": str(limit), "fields": fields}
    if term is not None:
        params["name__icontains"] = term
    if doc.lower() != "none":
        params["document__key"] = doc
    params.update(extra)
    url = API + "?" + urllib.parse.urlencode(params)
    # Open5e's CDN rejects Python's default User-Agent with a 403, so send one.
    req = urllib.request.Request(url, headers={"User-Agent": "UiPath-Workshops-open5e-check/1.0",
                                               "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.load(resp)


def parse_target(raw: str) -> tuple[str, int | None]:
    """"rat=7" -> ("rat", 7); "ancient red" -> ("ancient red", None)."""
    if "=" in raw:
        term, _, expected = raw.rpartition("=")
        if expected.isdigit():
            return term, int(expected)
    return raw, None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("searches", nargs="+", help='search terms, optionally with an expected count ("rat=7")')
    parser.add_argument("--doc", default="srd-2024", help='document__key filter (default srd-2024; "none" to drop it)')
    parser.add_argument("--limit", type=int, default=10, help="limit parameter (default 10, as in the labs)")
    parser.add_argument("--fields", default=DEFAULT_FIELDS, help=f"fields parameter (default {DEFAULT_FIELDS})")
    parser.add_argument("--param", action="append", default=[], metavar="KEY=VALUE",
                        help="extra query parameter; repeatable")
    parser.add_argument("--no-name-filter", action="store_true",
                        help="do not send name__icontains (use with --param to test a misspelled filter)")
    args = parser.parse_args()

    extra = {}
    for p in args.param:
        key, sep, value = p.partition("=")
        if not sep:
            parser.error(f"--param needs KEY=VALUE, got {p!r}")
        extra[key] = value

    failures = 0
    for raw in args.searches:
        term, expected = parse_target(raw)
        try:
            data = search(None if args.no_name_filter else term, args.doc, args.limit, args.fields, extra)
        except Exception as exc:  # network, HTTP, or JSON errors
            print(f"{term}: ERROR {exc}")
            failures += 1
            continue

        count = data.get("count")
        status = ""
        if expected is not None:
            if count == expected:
                status = f"  OK (expected {expected})"
            else:
                status = f"  MISMATCH (expected {expected})"
                failures += 1
        print(f"{term}: {count} result(s){status}")
        for row in data.get("results", []):
            cr = row.get("challenge_rating", "")
            print(f"    {row.get('key', '?'):<40} {row.get('name', '?'):<32} {cr}")
        if count and count > len(data.get("results", [])):
            print(f"    ... showing the first {len(data.get('results', []))} (limit {args.limit})")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
