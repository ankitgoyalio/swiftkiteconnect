#!/usr/bin/env python3
"""Verify selected official bytes; inventory headings and endpoint tables independently of SDK code."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
snapshot = root / "Documentation/Snapshots/2026-10-27"

class Inventory(HTMLParser):
    def __init__(self):
        super().__init__()
        self.heading = None
        self.cell = None
        self.row = None
        self.headings = []
        self.rows = []
    def handle_starttag(self, tag, attrs):
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self.heading = []
        if tag == "tr":
            self.row = []
        if tag in ("td", "th"):
            self.cell = []
    def handle_data(self, data):
        if self.heading is not None:
            self.heading.append(data)
        if self.cell is not None:
            self.cell.append(data)
    def handle_endtag(self, tag):
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6") and self.heading is not None:
            self.headings.append(" ".join("".join(self.heading).split()).rstrip("¶"))
            self.heading = None
        if tag in ("td", "th") and self.cell is not None:
            if self.row is not None:
                self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        if tag == "tr" and self.row is not None:
            if self.row and self.row[0] in ("GET", "POST", "PUT", "DELETE"):
                self.rows.append(self.row)
            self.row = None

records = []
for source in json.loads((snapshot / "manifest.json").read_text())["sources"]:
    data = (snapshot / source["file"]).read_bytes()
    if hashlib.sha256(data).hexdigest() != source["sha256"] or len(data) != source["bytes"]:
        sys.exit(f"Snapshot mismatch: {source['file']}")
    parser = Inventory()
    parser.feed(data.decode())
    records.append(dict(file=source["file"], url=source["url"], sha256_verified=True,
                        bytes=len(data), headings=parser.headings, endpoint_table=parser.rows))
output = json.dumps(dict(snapshot="2026-10-27", sources=records), indent=2) + "\n"
target = root / "Documentation/Evidence/ticket-24-snapshot-inventory.json"
if "--write" in sys.argv:
    target.write_text(output)
if target.read_text() != output:
    sys.exit("Inventory differs; review and regenerate with --write.")
print(f"Verified {len(records)} source hashes/byte counts; {sum(len(r['endpoint_table']) for r in records)} endpoint table rows and {sum(len(r['headings']) for r in records)} headings inventoried.")

# Guard against stale/missing per-route API, test and compiled-example links.
# This checks inventory/symbol consistency, not semantic coverage or remote success.
import re
coverage = (root / "Documentation/Coverage.md").read_text()
route_rows = [line.strip("| ").split(" | ") for line in coverage.splitlines()
              if re.search(r"\| (GET|POST|PUT|DELETE) `", line)]
contracts = set()
for row in route_rows:
    method, route = re.fullmatch(r"(GET|POST|PUT|DELETE) `(.+)`", row[1]).groups()
    contracts.add((method, route))
    implementation = re.search(r"\]\((\.\./Sources/[^)]+)\): `([^`]+)`", row[2])
    source = (root / "Documentation" / implementation[1]).read_text()
    for symbol in re.findall(r"(\w+)\(", implementation[2]):
        if f"func {symbol}(" not in source:
            sys.exit(f"Missing implementation symbol: {symbol} for {route}")
    test_paths = re.findall(r"\]\((\.\./Tests/[^)]+)\)", row[3])
    tests = "\n".join((root / "Documentation" / path).read_text() for path in test_paths)
    symbols = re.findall(r"`([^`]+)`", row[3])
    if not symbols:
        sys.exit(f"Missing named test evidence: {route}")
    for group in symbols:
        for symbol in group.split("; "):
            if f"func {symbol}(" not in tests:
                sys.exit(f"Missing public test symbol: {symbol}")
    example = row[4].strip("`")
    if f"func {example}(" not in (root / "Tests/KiteConnectTests/DocumentationExamples.swift").read_text():
        sys.exit(f"Missing compiled usage: {example}")
expected_contracts = {(row[0], row[1]) for record in records for row in record["endpoint_table"]}
expected_contracts |= {("GET", "/user/margins"), ("POST", "/portfolio/holdings/authorise")}
if contracts != expected_contracts or len(route_rows) != 42:
    sys.exit(f"Route checklist mismatch: missing={expected_contracts - contracts}, extra={contracts - expected_contracts}")
print("Verified all 42 route/API/named-test/compiled-example mappings (semantic audit remains manual).")
