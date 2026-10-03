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

# Sign with a stable identity so the Accessibility permission survives rebuilds
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Apple Development: Alexander Tsirel (7538B6Y8M3)}"
if ! security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
    echo "Identity '$SIGN_IDENTITY' not found, using ad-hoc signature"
    SIGN_IDENTITY="-"
fi
APP=".build/$CONFIG/ClipMoar.app"
if [ "$CONFIG" = "release" ]; then
    codesign -f --options runtime --timestamp --entitlements ClipMoar/Resources/ClipMoar.entitlements \
        -s "${NOTARIZE_IDENTITY:-Developer ID Application: Alexander Tsirel (89QF7X66FR)}" "$APP"
    ditto -c -k --keepParent "$APP" .build/ClipMoar-notarize.zip
    xcrun notarytool submit .build/ClipMoar-notarize.zip --keychain-profile clipmoar --wait
    xcrun stapler staple "$APP"
    rm -f .build/ClipMoar-notarize.zip
else
    codesign -fs "$SIGN_IDENTITY" "$APP"
fi

# Always restart
pkill -x ClipMoar 2>/dev/null || true
sleep 0.5
mkdir -p dist
rm -rf dist/ClipMoar.app
cp -R ".build/$CONFIG/ClipMoar.app" dist/
open dist/ClipMoar.app
echo "ClipMoar started."
