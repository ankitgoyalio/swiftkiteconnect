#!/usr/bin/env python3
"""Keep compiled examples identical to every Swift block in README.md and Usage.md (no network)."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
blocks = []
for document in ("README.md", "Documentation/Usage.md"):
    blocks += re.findall(r"```swift\n(.*?)\n```", (root / document).read_text(), re.S)
imports = sorted({line for block in blocks for line in block.splitlines() if line.startswith("import ")})
bodies = ["\n".join(line for line in block.splitlines() if not line.startswith("import ")).strip() for block in blocks]
expected = "// Generated from README.md and Documentation/Usage.md; run python3 Scripts/check-documentation-examples.py --write.\n" + "\n".join(imports) + "\n\n" + "\n\n".join(bodies) + "\n"
target = root / "Tests/KiteConnectTests/DocumentationExamples.swift"
if "--write" in sys.argv:
    target.write_text(expected)
if target.read_text() != expected:
    sys.exit("Documentation examples are stale; regenerate with --write and run swift test.")
print(f"Verified {len(blocks)} Swift documentation blocks match compiled test sources.")
