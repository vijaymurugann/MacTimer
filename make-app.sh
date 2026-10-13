#!/bin/bash
set -e

# ─── Config ───────────────────────────────────────────────────────────────────
APP_NAME="MacTimer"
BUNDLE_ID="com.vijay.mactimer"
VERSION="1.0.0"
# ──────────────────────────────────────────────────────────────────────────────

APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🔨  Building release binary..."
swift build -c release

echo "📦  Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the compiled binary
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy AppIcon if exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# ── Info.plist ─────────────────────────────────────────────────────────────────
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Vijay. All rights reserved.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacTimer requires permission to detect the active website domain in Google Chrome, Brave, and Safari to provide detailed screen time analytics.</string>
</dict>
</plist>
PLIST

echo ""
echo "✅  Done! $APP_BUNDLE is ready."
echo ""
echo "──────────────────────────────────────────"
echo "  To install (move to /Applications):"
echo "    cp -r $APP_BUNDLE /Applications/"
echo ""
echo "  Or just double-click $APP_BUNDLE to run now."
echo "──────────────────────────────────────────"
