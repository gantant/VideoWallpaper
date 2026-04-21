#!/bin/sh
# One-shot macOS build (Debug). Uses project-local DerivedDataAgent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec xcodebuild \
  -project "$ROOT/VideoWallpaper.xcodeproj" \
  -scheme VideoWallpaper \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT/DerivedDataAgent" \
  build
