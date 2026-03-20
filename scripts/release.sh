#!/bin/bash
set -euo pipefail

APP_NAME="ClipMoar"
CONFIG="${1:-debug}"
BUILD_DIR=".build/$CONFIG"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp ClipMoar/Resources/Info.plist "$APP_BUNDLE/Contents/"

cat > "$APP_BUNDLE/Contents/PkgInfo" << 'EOF'
APPL????
EOF

# Copy CoreData model bundle
BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$BUILD_DIR/$BUNDLE_NAME" ]; then
    cp -R "$BUILD_DIR/$BUNDLE_NAME" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy assets
if [ -d "assets" ]; then
    cp -R assets/* "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Copy JSON resources
for json in ClipMoar/Resources/*.json; do
    [ -f "$json" ] && cp "$json" "$APP_BUNDLE/Contents/Resources/"
done

# Copy LICENSE
if [ -f "LICENSE" ]; then
    cp LICENSE "$APP_BUNDLE/Contents/Resources/"
fi

echo "App bundle created: $APP_BUNDLE"
