#!/bin/bash
set -euo pipefail

if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint not found. Install: brew install swiftlint"
    exit 1
fi

echo "Linting..."
swiftlint lint --path ClipMoar/
