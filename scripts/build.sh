#!/bin/bash
set -euo pipefail

CONFIG="${1:-debug}"

echo "Formatting..."
swiftformat ClipMoar/ Tests/ --quiet 2>/dev/null || true

echo "Building ClipMoar ($CONFIG)..."
swift build -c "$CONFIG"
echo "Build complete."

# Always create .app bundle
./scripts/release.sh "$CONFIG"

# Always restart
pkill -x ClipMoar 2>/dev/null || true
sleep 0.5
mkdir -p dist
rm -rf dist/ClipMoar.app
cp -R ".build/$CONFIG/ClipMoar.app" dist/
open dist/ClipMoar.app
echo "ClipMoar started."
