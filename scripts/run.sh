#!/bin/bash
set -euo pipefail

echo "Building ClipMoar..."
swift build
echo "Running ClipMoar..."
swift run
