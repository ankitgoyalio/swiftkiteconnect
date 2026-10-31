#!/usr/bin/env bash
set -euo pipefail
mkdir -p .test-results
result_directory=$(mktemp -d .test-results/iOS.XXXXXX)
simulator_id=$(xcrun simctl list devices available -j | python3 -c '
import json, os, sys
inventory = json.load(sys.stdin)["devices"]
requested_runtime = os.environ.get("IOS_SIMULATOR_RUNTIME")
requested_name = os.environ.get("IOS_SIMULATOR_NAME")
for runtime, devices in sorted(inventory.items(), reverse=True):
    if requested_runtime and runtime != requested_runtime:
        continue
    if ".iOS-" in runtime:
        for device in devices:
            if requested_name and device["name"] != requested_name:
                continue
            if device["name"].startswith("iPhone"):
                print(device["udid"])
                sys.exit(0)
sys.exit(f"No available iPhone simulator matching runtime={requested_runtime!r}, "
         f"name={requested_name!r}; install the requested simulator in Xcode.")
')
echo "Testing on simulator $simulator_id (runtime=${IOS_SIMULATOR_RUNTIME:-automatic}, name=${IOS_SIMULATOR_NAME:-automatic})"
set -- test -scheme KiteConnect
if [[ -n "${CI_XCODE_PACKAGE_CACHE:-}" ]]; then
  set -- "$@" -packageCachePath "$CI_XCODE_PACKAGE_CACHE" \
    -clonedSourcePackagesDirPath "$CI_XCODE_PACKAGE_CLONES" \
    -onlyUsePackageVersionsFromResolvedFile
fi
xcodebuild "$@" \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -parallel-testing-enabled NO \
  -destination-timeout 60 \
  -resultBundlePath "$result_directory/Results.xcresult" \
  CODE_SIGNING_ALLOWED=NO
