#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'A Mac with the full Xcode app is required. No Apple build was run.' >&2
  exit 2
fi
xcodebuild -project XenphiaGlass.xcodeproj -scheme XenphiaGlass \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
