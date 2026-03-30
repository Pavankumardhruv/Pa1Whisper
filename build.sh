#!/bin/bash
# Build Pa1Whisper and package into .app bundle
set -e

cd "$(dirname "$0")"

echo "Building Pa1Whisper..."
swift build -c debug 2>&1

APP_DIR="build/Pa1Whisper.app/Contents"
EXEC_SRC=".build/arm64-apple-macosx/debug/Pa1Whisper"
BUNDLE_SRC=".build/arm64-apple-macosx/debug/Pa1Whisper_Pa1Whisper.bundle"

# Create app bundle structure
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

# Copy executable
cp "$EXEC_SRC" "$APP_DIR/MacOS/Pa1Whisper"

# Copy resource bundle if exists
if [ -d "$BUNDLE_SRC" ]; then
    cp -R "$BUNDLE_SRC" "$APP_DIR/Resources/"
fi

# Copy Info.plist
cp Pa1Whisper/Info.plist "$APP_DIR/Info.plist"

# Build AppIcon.icns from the SVG-exported PNGs
ICONSET_DIR="/tmp/Pa1Whisper.iconset"
ASSET_DIR="Pa1Whisper/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET_DIR"
cp "$ASSET_DIR/icon_16x16.png"    "$ICONSET_DIR/icon_16x16.png"
cp "$ASSET_DIR/icon_32x32.png"    "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ASSET_DIR/icon_32x32.png"    "$ICONSET_DIR/icon_32x32.png"
cp "$ASSET_DIR/icon_64x64.png"    "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ASSET_DIR/icon_128x128.png"  "$ICONSET_DIR/icon_128x128.png"
cp "$ASSET_DIR/icon_256x256.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ASSET_DIR/icon_256x256.png"  "$ICONSET_DIR/icon_256x256.png"
cp "$ASSET_DIR/icon_512x512.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ASSET_DIR/icon_512x512.png"  "$ICONSET_DIR/icon_512x512.png"
cp "$ASSET_DIR/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

# Copy any framework dependencies
if [ -d ".build/arm64-apple-macosx/debug/PackageFrameworks" ]; then
    mkdir -p "$APP_DIR/Frameworks"
    cp -R .build/arm64-apple-macosx/debug/PackageFrameworks/* "$APP_DIR/Frameworks/" 2>/dev/null || true
fi

install_app() {
    if [ "${SKIP_INSTALL:-}" != "1" ]; then
        echo "Installing to /Applications..."
        rm -rf /Applications/Pa1Whisper.app
        cp -R build/Pa1Whisper.app /Applications/
        echo "  Installed at /Applications/Pa1Whisper.app"
        echo "  You can enable 'Launch at Login' in the app settings."
    fi
}

# Sign with persistent certificate (survives rebuilds — no need to re-grant Accessibility)
CERT_NAME="Pa1Whisper Developer"
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "Signing with '$CERT_NAME' certificate..."
    codesign --force --deep --sign "$CERT_NAME" "build/Pa1Whisper.app"
    echo ""
    echo "Done! App bundle at: build/Pa1Whisper.app"
    echo "  Signed with persistent certificate — Accessibility permission is preserved."
    install_app
else
    echo "No persistent certificate found, falling back to ad-hoc signing..."
    codesign --force --deep --sign - "build/Pa1Whisper.app"
    # Reset Accessibility TCC entry so the new binary gets a fresh grant
    echo "Resetting Accessibility permission (you'll need to re-grant it)..."
    tccutil reset Accessibility com.pa1whisper.app 2>/dev/null || true
    echo ""
    echo "Done! App bundle at: build/Pa1Whisper.app"
    echo ""
    echo "  IMPORTANT: After launching, grant Accessibility permission:"
    echo "  System Settings → Privacy & Security → Accessibility → Toggle ON Pa1Whisper"
    echo "  Then restart the app."
    install_app
fi
echo ""
