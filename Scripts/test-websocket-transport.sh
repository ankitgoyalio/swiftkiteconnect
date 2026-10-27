#!/usr/bin/env bash
# Controlled real loopback tests only. No Kite account or remote API access.
set -euo pipefail
swift --version
uname -a
if [[ "$(uname -s)" == Linux ]]; then
  cat /etc/os-release
fi
swift test --filter 'realLocalWebSocket|webSocketAdapter'
