#!/usr/bin/env bash
# Scripts/package_app.sh — builds Sparky.app bundle
# Usage: ./Scripts/package_app.sh [--dmg]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sparky"
BUNDLE_ID="com.yunior.sparky"
BUILD_DIR="$REPO_ROOT/.build/release"
DIST_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "▶ Building $APP_NAME (release)..."
cd "$REPO_ROOT"
swift build -c release 2>&1

echo "▶ Assembling .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist
cp "$REPO_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✓ Built: $APP_BUNDLE"

# Optional ad-hoc codesign (for local use without Developer ID)
if command -v codesign &>/dev/null; then
    echo "▶ Signing (ad-hoc)..."
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
    echo "✓ Signed"
fi

# Optional DMG
if [[ "${1:-}" == "--dmg" ]]; then
    echo "▶ Creating DMG..."
    DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" \
        -ov -format UDZO "$DMG_PATH" 2>&1
    echo "✓ DMG: $DMG_PATH"
fi

echo ""
echo "✅ Done. Run with: open \"$APP_BUNDLE\""
