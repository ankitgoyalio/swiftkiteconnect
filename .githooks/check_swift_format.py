"""Lint staged Swift blobs with the staged repository configuration."""

import os
import subprocess
import sys
import tempfile

SWIFTFORMAT_VERSION = "0.64.3"


def check_swift_format(files):
    swift_files = [(path, oid) for path, oid in files if path.endswith(b".swift")]
    if not swift_files:
        return 0

    try:
        version = subprocess.run(
            ["swiftformat", "--version"], capture_output=True, check=True,
        ).stdout.decode().strip()
    except (OSError, subprocess.CalledProcessError):
        version = "unavailable"
    if version != SWIFTFORMAT_VERSION:
        print(
            f"Commit blocked: SwiftFormat {SWIFTFORMAT_VERSION} is required "
            f"(found {version}). See docs/development.md for installation.",
            file=sys.stderr,
        )
        return 1

    config = subprocess.run(
        ["git", "show", ":.swiftformat"], capture_output=True,
    )
    if config.returncode:
        print("Commit blocked: stage the root .swiftformat configuration first.", file=sys.stderr)
        return 1

    failed = False
    with tempfile.TemporaryDirectory(prefix="swiftkiteconnect-format-") as directory:
        config_path = os.path.join(directory, ".swiftformat")
        with open(config_path, "wb") as output:
            output.write(config.stdout)
        for path, object_id in swift_files:
            content = subprocess.run(
                ["git", "cat-file", "blob", object_id], capture_output=True, check=True,
            ).stdout
            result = subprocess.run(
                ["swiftformat", "stdin", "--lint", "--config", config_path,
                 "--stdin-path", os.fsdecode(path), "--cache", "ignore"],
                input=content, capture_output=True,
            )
            if result.returncode:
                failed = True
                print(f"SwiftFormat failed for staged {os.fsdecode(path)!r}:", file=sys.stderr)
                sys.stderr.buffer.write(result.stderr)
    if failed:
        print(
            "Commit blocked: run swiftformat <file> --config .swiftformat, review "
            "the changes, then stage the intended hunks and retry. "
            "The hook leaves the index and working tree unchanged.",
            file=sys.stderr,
        )
    return int(failed)
