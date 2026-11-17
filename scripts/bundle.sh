#!/usr/bin/env bash
# Builds a universal release binary and wraps it in LookFar.app (ad-hoc signed).
# Usage: scripts/bundle.sh   → build/LookFar.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/LookFar"

APP=build/LookFar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LookFar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will launch it locally. Real distribution needs
# a Developer ID signature and notarization.
codesign --force --sign - "$APP"
echo "Built $APP"
