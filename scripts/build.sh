#!/bin/bash
set -euo pipefail

CONFIG="${1:-debug}"

echo "Building ClipMoar ($CONFIG)..."
swift build -c "$CONFIG"
echo "Build complete."
