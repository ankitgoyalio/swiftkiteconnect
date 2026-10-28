#!/usr/bin/env bash
# Run on an existing Ubuntu 24.04 host with Swift 6.4, Python 3 and Node installed.
# This script provisions nothing and performs no Kite API requests.
set -euo pipefail
if [[ "$(uname -s)" != Linux ]]; then
  echo 'Qualification requires a real Ubuntu 24.04 runtime.' >&2
  exit 1
fi
source /etc/os-release
if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 ]]; then
  echo 'Qualification requires Ubuntu 24.04.' >&2
  exit 1
fi
swift --version
swift --version | grep -q 'Swift version 6.4'
cat /etc/os-release
python3 Scripts/check-documentation.py
python3 Scripts/audit-snapshot.py
python3 Scripts/check-documentation-examples.py
node --test Tests/Publisher.test.cjs
# Includes actual HTTP/WebSocket loopback, TLS trust rejection and controlled protocol tests.
swift test
