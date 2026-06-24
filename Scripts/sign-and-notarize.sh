#!/bin/bash
set -euo pipefail

# Scroll Elevator — Sign and Notarize
# Builds a universal binary, signs with Developer ID + hardened runtime,
# notarizes with Apple, staples, and packages a distribution DMG for Gumroad.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

source version.env

# --- Configuration ---
SCHEME="ScrollElevator"
PROJECT="ScrollElevator.xcodeproj"
TEAM_ID="542GXYT5Z2"
SIGNING_IDENTITY="Developer ID Application: Kevin Tang ($TEAM_ID)"
APP_NAME="Scroll Elevator.app"
EXECUTABLE="Scroll Elevator"
DMG_BASENAME="ScrollElevator-${MARKETING_VERSION}.dmg"

RELEASE_DIR="$PROJECT_ROOT/release"
BUILD_DIR="$PROJECT_ROOT/build"

# Notarization credentials are kept out of source (this repo is public).
# Resolution order: explicit env vars, else the App Store Connect key + issuer
# in ~/.config/app-store-connect/ (AuthKey_<KEYID>.p8 and an `issuer_id` file).
KEY_DIR="$HOME/.config/app-store-connect"
API_KEY="${APP_STORE_CONNECT_API_KEY:-$(ls "$KEY_DIR"/AuthKey_*.p8 2>/dev/null | head -1)}"
KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
if [[ -z "$KEY_ID" && -n "${API_KEY:-}" ]]; then
    KEY_ID="$(basename "$API_KEY" .p8 | sed 's/^AuthKey_//')"
fi
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-$(cat "$KEY_DIR/issuer_id" 2>/dev/null || true)}"

echo "=== Sign and Notarize: Scroll Elevator ${MARKETING_VERSION} (${BUILD_NUMBER}) ==="

if [[ -z "${API_KEY:-}" || ! -f "$API_KEY" || -z "$KEY_ID" || -z "$ISSUER_ID" ]]; then
    echo "Warning: App Store Connect credentials not found — notarization will be skipped."
    echo "Provide APP_STORE_CONNECT_API_KEY / _KEY_ID / _ISSUER_ID, or put"
    echo "AuthKey_<KEYID>.p8 and an 'issuer_id' file in $KEY_DIR."
    SKIP_NOTARIZATION=1
else
    SKIP_NOTARIZATION=0
fi

# Regenerate the Xcode project (it is git-ignored / xcodegen-managed).
command -v xcodegen >/dev/null 2>&1 && xcodegen generate >/dev/null

echo "Cleaning previous build output..."
rm -rf "$RELEASE_DIR" "$BUILD_DIR"
mkdir -p "$RELEASE_DIR" "$BUILD_DIR"

echo ""
echo "=== Building Universal Binary (arm64 + x86_64) ==="
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH="NO" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    CODE_SIGN_STYLE="Manual" \
    ENABLE_HARDENED_RUNTIME="YES" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS="NO" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -allowProvisioningUpdates \
    build

APP_PATH="$(find "$BUILD_DIR" -name "$APP_NAME" -type d | head -1)"
[[ -n "$APP_PATH" ]] || { echo "Error: built app not found"; exit 1; }
echo "Built app: $APP_PATH"

echo ""
echo "=== Verifying Universal Binary ==="
ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE")"
echo "Architectures: $ARCHS"
[[ "$ARCHS" == *"arm64"* && "$ARCHS" == *"x86_64"* ]] || echo "Warning: not universal ($ARCHS)"

echo ""
echo "=== Verifying Code Signature ==="
codesign -vvv --deep --strict "$APP_PATH"

if [[ "$SKIP_NOTARIZATION" == "0" ]]; then
    NOTARIZE_ZIP="$RELEASE_DIR/ScrollElevator-notarize.zip"
    echo ""
    echo "=== Submitting for Notarization ==="
    /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --key "$API_KEY" --key-id "$KEY_ID" --issuer "$ISSUER_ID" --wait
    rm -f "$NOTARIZE_ZIP"

    echo ""
    echo "=== Stapling Ticket ==="
    xcrun stapler staple "$APP_PATH"
    spctl --assess --type execute --verbose=2 "$APP_PATH"
    echo "Notarization verified."
else
    echo ""
    echo "=== Skipping Notarization (signed only) ==="
fi

echo ""
echo "=== Creating Distribution DMG ==="
FINAL_DMG="$RELEASE_DIR/$DMG_BASENAME"
DMG_STAGING="$RELEASE_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "Scroll Elevator ${MARKETING_VERSION}" \
    -srcfolder "$DMG_STAGING" -ov -format UDZO "$FINAL_DMG"
rm -rf "$DMG_STAGING"

CHECKSUM="$(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')"
echo "$CHECKSUM  $DMG_BASENAME" > "$RELEASE_DIR/SHA256SUMS.txt"

echo ""
echo "=== Sign and Notarize Complete ==="
echo "Artifact: $FINAL_DMG"
echo "SHA-256:  $CHECKSUM"
