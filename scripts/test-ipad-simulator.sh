#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'A Mac with Xcode and an installed iPad simulator is required. Tests were not run.' >&2
  exit 2
fi
simulator_id="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
runtime_devices=json.load(sys.stdin)["devices"]
pads=[d for runtime,values in runtime_devices.items() if "iOS" in runtime for d in values if d.get("isAvailable") and "iPad" in d.get("name", "")]
if not pads: raise SystemExit("Install an iPad simulator runtime in Xcode first.")
pads.sort(key=lambda d:d.get("state") != "Booted")
print(pads[0]["udid"])
')"
xcodebuild -project XenphiaGlass.xcodeproj -scheme XenphiaGlass \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
