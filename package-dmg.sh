#!/bin/bash
set -e

# ─── Configuration ─────────────────────────────────────────────────────────────
APP_NAME="MacTimer"
VERSION="${1:-1.0.0}"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR=".dmg_staging"
ENTITLEMENTS="entitlements.plist"
# ──────────────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==============================================${NC}"
echo -e "${CYAN}  Building & Packaging ${APP_NAME} v${VERSION}${NC}"
echo -e "${CYAN}==============================================${NC}"
echo ""

# 1. Build the .app bundle using existing make-app.sh
if [ -f "./make-app.sh" ]; then
    echo -e "${CYAN}🔨 Step 1: Compiling and bundling application...${NC}"
    ./make-app.sh
else
    echo -e "${RED}Error: make-app.sh not found!${NC}"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}Error: $APP_BUNDLE was not created.${NC}"
    exit 1
fi

# 2. Code Signing
echo ""
echo -e "${CYAN}🔏 Step 2: Code signing...${NC}"

# Detect signing identity
SIGN_IDENTITY="${APPLE_SIGNING_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    # Auto-detect Developer ID Application certificate if available
    SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Developer ID Application:" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo -e "${GREEN}✓ Found Apple Developer ID identity: ${SIGN_IDENTITY}${NC}"
    echo "  Signing with Hardened Runtime and entitlements..."
    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
else
    echo -e "${YELLOW}⚠️  No Apple Developer ID certificate found.${NC}"
    echo "  Applying Ad-hoc code signature (-s -)..."
    codesign --force --deep -s - "$APP_BUNDLE"
    echo -e "${YELLOW}  Note: Users downloading from the web will need to right-click -> Open on first launch.${NC}"
fi

# Verify signature
codesign --verify --deep --strict "$APP_BUNDLE"
echo -e "${GREEN}✓ Code signature verified.${NC}"

# 3. Create DMG Staging
echo ""
echo -e "${CYAN}📦 Step 3: Preparing DMG layout...${NC}"
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy the .app bundle
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create symlink to /Applications for standard drag-and-drop installer
ln -s /Applications "$STAGING_DIR/Applications"

# 4. Generate Compressed DMG
echo ""
echo -e "${CYAN}💿 Step 4: Creating $DMG_NAME...${NC}"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Cleanup staging directory
rm -rf "$STAGING_DIR"

# 5. Sign & Notarize DMG if Developer ID is available
if [ -n "$SIGN_IDENTITY" ]; then
    echo ""
    echo -e "${CYAN}🔏 Step 5: Signing DMG...${NC}"
    codesign --sign "$SIGN_IDENTITY" "$DMG_NAME"

    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo -e "${CYAN}☁️  Submitting DMG to Apple Notarization service (${NOTARY_PROFILE})...${NC}"
        xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
        echo -e "${CYAN}📎 Stapling notarization ticket to DMG...${NC}"
        xcrun stapler staple "$DMG_NAME"
        echo -e "${GREEN}✓ DMG is notarized and stapled!${NC}"
    else
        echo -e "${YELLOW}ℹ️  Tip: To automatically notarize with Apple, set NOTARY_PROFILE in your environment.${NC}"
        echo "    e.g. export NOTARY_PROFILE=\"AC_PASSWORD\" (configured via 'xcrun notarytool store-credentials')"
    fi
fi

# 6. Summary & Checksum
echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}🎉  Release DMG created successfully!${NC}"
echo -e "${GREEN}==============================================${NC}"
ls -lh "$DMG_NAME"
echo ""
echo "SHA256 Checksum:"
shasum -a 256 "$DMG_NAME"
echo ""
echo "🚀 Next steps for GitHub Release:"
echo "  1. Push your latest code: git push origin main"
echo "  2. Go to: https://github.com/vijaymurugann/MacTimer/releases/new"
echo "  3. Create tag v${VERSION} and upload '${DMG_NAME}'"
echo ""
