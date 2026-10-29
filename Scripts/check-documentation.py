#!/usr/bin/env python3
"""Reject execution artifacts and broken local links in tracked documentation."""
import argparse
from pathlib import PurePosixPath
import posixpath
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


GUIDES = {"README.md", "Coverage.md", "CapabilityCoverage.md",
          "Publisher.md", "Verification.md", "SDKParity.md", "SandboxVerification.md",
          "DocC.md", "Pages.md", "DocCCoverage.json", "DocCCoveragePortfolio.json", "DocCCoverageOrders.json"}
ROOT_GUIDES = {"README.md", "AGENTS.md", "GLOSSARY.md"}
PROJECT_GUIDES = {"development.md", "sdk-spec.md", "sdk-spec-user-stories.md",
                  "agents/domain.md", "agents/issue-tracker.md", "agents/triage-labels.md"}


def project_markdown(name):
    path = PurePosixPath(name)
    return path.suffix == ".md" and (
        len(path.parts) == 1 or name.startswith(("Documentation/", "docs/")) or ".docc/" in name
    )


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
        if len(path.parts) == 1 and path.suffix == ".md" and name not in ROOT_GUIDES:
            errors.append(f"{name}: unregistered project guide; update an existing guide or register a durable topic in ROOT_GUIDES")
        if name.startswith("docs/"):
            relative = str(path.relative_to("docs"))
            adr = re.fullmatch(r"adr/\d{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md", relative)
            if relative not in PROJECT_GUIDES and not adr:
                errors.append(f"{name}: execution/history artifact or unregistered project guide; keep plans and publication records in GitHub Issues; register durable topics in PROJECT_GUIDES")
        if not name.startswith("Documentation/"):
            continue
        relative = str(path.relative_to("Documentation"))
        historical = re.match(r"(?:Evidence/|Ticket-\d+\.md$|Review\.md$|Partial-0x\.md$)", relative, re.I)
        snapshot = re.fullmatch(r"Snapshots/\d{4}-\d{2}-\d{2}/(?:[^/]+\.html|manifest\.json|inventory\.json)", relative)
        if historical or (relative not in GUIDES and not snapshot):
            errors.append(f"{name}: execution/history artifact or unregistered guide; use .test-results/, CI artifacts or the GitHub issue/PR; register intentional new guides in GUIDES")
    # Static Markdown links only; remote URLs and fragment-only links are not fetched.
    for name in sorted(paths):
        if not project_markdown(name):
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
