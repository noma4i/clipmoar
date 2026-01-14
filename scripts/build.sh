#!/bin/bash
set -euo pipefail

CONFIG="${1:-debug}"

echo "Formatting..."
swiftformat ClipMoar/ Tests/ --quiet 2>/dev/null || true

echo "Building ClipMoar ($CONFIG)..."
swift build -c "$CONFIG"
echo "Build complete."

if pgrep -x ClipMoar > /dev/null 2>&1; then
    echo "Restarting ClipMoar..."
    pkill -x ClipMoar 2>/dev/null || true
    sleep 0.5
    ./scripts/release.sh "$CONFIG"
    mkdir -p dist
    rm -rf dist/ClipMoar.app
    cp -R ".build/$CONFIG/ClipMoar.app" dist/
    open dist/ClipMoar.app
fi
