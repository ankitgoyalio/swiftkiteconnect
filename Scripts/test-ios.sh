#!/usr/bin/env bash
set -euo pipefail
mkdir -p .test-results
result_directory=$(mktemp -d .test-results/iOS.XXXXXX)
simulator_id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
inventory = json.load(sys.stdin)["devices"]
for runtime, devices in sorted(inventory.items(), reverse=True):
    if ".iOS-" in runtime:
        for device in devices:
            if device["name"].startswith("iPhone"):
                print(device["udid"])
                sys.exit(0)
sys.exit("No available iPhone simulator runtime; install one in Xcode.")
')
xcodebuild test -scheme KiteConnect \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -resultBundlePath "$result_directory/Results.xcresult" \
  CODE_SIGNING_ALLOWED=NO
