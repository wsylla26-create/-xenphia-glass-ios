#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'A Mac with Xcode and an installed iPad simulator is required. Tests were not run.' >&2
  exit 2
fi
simulator_id="$(xcrun simctl list devices available -j | python3 -c '
import json,sys,re
runtime_devices=json.load(sys.stdin)["devices"]
pads=[]
for runtime,values in runtime_devices.items():
    match=re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match or tuple(map(int, match.groups())) < (18,4): continue
    pads.extend(d for d in values if d.get("isAvailable") and "iPad" in d.get("name", ""))
if not pads: raise SystemExit("Install an iPad simulator runtime for iOS 18.4 or later in Xcode first.")
pads.sort(key=lambda d:d.get("state") != "Booted")
print(pads[0]["udid"])
')"
# Xcode 16.4 / iOS 18.5 simulator has a documented WebKit overlay loader bug
# for targets <=18.3. Override only this simulator test build; project minimum stays 17.
# https://bugs.webkit.org/show_bug.cgi?id=293831
xcodebuild -project XenphiaGlass.xcodeproj -scheme XenphiaGlass \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  IPHONEOS_DEPLOYMENT_TARGET=18.4 CODE_SIGNING_ALLOWED=NO test
