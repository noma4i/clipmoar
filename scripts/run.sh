#!/bin/bash
set -euo pipefail

pkill -x ClipMoar 2>/dev/null || true
sleep 0.5

./scripts/release.sh debug
mkdir -p dist
rm -rf dist/ClipMoar.app
cp -R .build/debug/ClipMoar.app dist/
open dist/ClipMoar.app
