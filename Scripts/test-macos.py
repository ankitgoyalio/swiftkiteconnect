#!/usr/bin/env python3
"""Bound the built macOS suite and retain process samples if teardown stalls."""
import os
from pathlib import Path
import signal
import subprocess
import sys


def descendants(pid):
    children = subprocess.run(
        ["pgrep", "-P", str(pid)], capture_output=True, text=True, check=False
    )
    result = []
    for child in children.stdout.split():
        child = int(child)
        result.extend(descendants(child))
        result.append(child)
    return result


def main():
    process = subprocess.Popen(["swift", "test", "--skip-build"], start_new_session=True)
    try:
        return process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        print("::error::macOS tests exceeded 90 seconds; capturing teardown diagnostics", flush=True)
        directory = Path(".test-results")
        directory.mkdir(exist_ok=True)
        try:
            for pid in descendants(process.pid) + [process.pid]:
                try:
                    subprocess.run(
                        ["sample", str(pid), "2", "-file", str(directory / f"macos-timeout-{pid}.txt")],
                        timeout=10, check=False,
                    )
                except (OSError, subprocess.TimeoutExpired) as error:
                    print(f"Could not sample PID {pid}: {type(error).__name__}", flush=True)
        finally:
            # Kill the test runner and its helper together; a cancelled async test
            # cannot unwind a stranded NIO promise on an already retired event loop.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        return 1


if __name__ == "__main__":
    sys.exit(main())
