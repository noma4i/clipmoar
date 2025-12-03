#!/bin/bash
set -euo pipefail

echo "Cleaning build artifacts..."
swift package clean
rm -rf .build
echo "Clean complete."
