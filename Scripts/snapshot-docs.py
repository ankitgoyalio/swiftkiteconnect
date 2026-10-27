#!/usr/bin/env python3
"""Capture official documentation provenance; review before changing release coverage."""
import concurrent.futures
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import subprocess

PAGES = ["", "user", "response-structure", "exceptions", "orders", "gtt", "alerts", "portfolio", "market-quotes", "historical", "mutual-funds", "margins", "websocket", "postbacks", "basket", "publisher", "sandbox"]
CAPTURE_DATE = datetime.now(timezone.utc).date().isoformat()
ROOT = Path(__file__).resolve().parents[1] / "Documentation" / "Snapshots" / CAPTURE_DATE

def capture(page):
    url = "https://kite.trade/docs/connect/v3/" + (page + "/" if page else "")
    content = subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location", "--max-time", "30", url], check=True, capture_output=True).stdout
    filename = (page or "index") + ".html"
    (ROOT / filename).write_bytes(content)
    return {"url": url, "file": filename, "sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content)}

if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        manifest = list(executor.map(capture, PAGES))
    (ROOT / "manifest.json").write_text(json.dumps({"captured_date": CAPTURE_DATE, "sources": manifest}, indent=2) + "\n")
