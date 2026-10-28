#!/usr/bin/env python3
"""Reject execution artifacts and broken local links in tracked documentation."""
import argparse
from pathlib import PurePosixPath
import posixpath
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


GUIDES = {"README.md", "Usage.md", "Contracts.md", "Coverage.md", "CapabilityCoverage.md",
          "Publisher.md", "Verification.md", "SandboxVerification.md",
          "DocC.md", "DocCCoverage.json", "DocCCoveragePortfolio.json", "DocCCoverageOrders.json"}


def git(*args):
    return subprocess.check_output(["git", *args])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true", help="Read staged blobs, not working copies")
    args = parser.parse_args()
    paths = set(git("ls-files", "--cached", "-z").decode().strip("\0").split("\0")) - {""}
    errors = []
    for name in sorted(paths):
        path = PurePosixPath(name)
        if not name.startswith("Documentation/"):
            continue
        relative = str(path.relative_to("Documentation"))
        historical = re.match(r"(?:Evidence/|Ticket-\d+\.md$|Review\.md$|Partial-0x\.md$)", relative, re.I)
        snapshot = re.fullmatch(r"Snapshots/\d{4}-\d{2}-\d{2}/(?:[^/]+\.html|manifest\.json|inventory\.json)", relative)
        if historical or (relative not in GUIDES and not snapshot):
            errors.append(f"{name}: execution/history artifact or unregistered guide; use .test-results/, CI artifacts or the GitHub issue/PR; register intentional new guides in GUIDES")
    # Static Markdown links only; remote URLs and fragment-only links are not fetched.
    for name in sorted(paths):
        if not (name.endswith(".md") and (name.startswith("Documentation/") or name == "README.md" or ".docc/" in name)):
            continue
        text = (git("show", ":" + name).decode() if args.staged else open(name, encoding="utf-8").read())
        for target in re.findall(r"\]\(([^)]+)\)", text):
            target = target.strip().strip("<>")
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            local = unquote(parsed.path)
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), local))
            if resolved not in paths and not any(p.startswith(resolved + "/") for p in paths):
                errors.append(f"{name}: broken local link {target}")
    if errors:
        print("Documentation check failed:\n" + "\n".join(errors), file=sys.stderr)
        return 1
    print("Documentation layout and tracked local links verified" + (" (staged)" if args.staged else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
