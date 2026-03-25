#!/bin/bash
#
# Creates a self-contained Sourcetrail.app bundle and optional .dmg for macOS.
#
# Usage:
#   ./bundle_macos.sh <build-dir>
#
# Example:
#   ./bundle_macos.sh /Users/you/dev-local/build/system-macos-release
#
# Prerequisites:
#   - Successful cmake build in <build-dir>
#   - macdeployqt on PATH (installed with Qt/Homebrew)
#   - sips (ships with macOS, used for icon generation)
#   - iconutil (ships with macOS)
#   - hdiutil (ships with macOS, for .dmg creation)

set -euo pipefail

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

abort()   { echo -e "${RED}Error:${RESET} $1"; exit 1; }
info()    { echo -e "${YELLOW}>>>${RESET} $1"; }
success() { echo -e "${GREEN}>>>${RESET} $1"; }

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

BUILD_DIR="${1:?Usage: $0 <build-dir>}"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Verify build output exists
[[ -x "$BUILD_DIR/app/Sourcetrail" ]] || abort "Sourcetrail binary not found in $BUILD_DIR/app/"
[[ -x "$BUILD_DIR/app/sourcetrail_indexer" ]] || abort "sourcetrail_indexer binary not found in $BUILD_DIR/app/"

# Extract version from the binary's parent CMakeCache
VERSION=$(grep "^CMAKE_PROJECT_VERSION:" "$BUILD_DIR/CMakeCache.txt" 2>/dev/null | cut -d= -f2 || echo "0.0.0")
VERSION_UNDERSCORE="${VERSION//./_}"

info "Bundling Sourcetrail $VERSION"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PACKAGE_NAME="Sourcetrail_${VERSION_UNDERSCORE}_macOS"
PACKAGE_DIR="$BUILD_DIR/$PACKAGE_NAME"
BUNDLE_PATH="$PACKAGE_DIR/Sourcetrail.app"
BIN_DIR="$BUNDLE_PATH/Contents/MacOS"
FRAMEWORK_DIR="$BUNDLE_PATH/Contents/Frameworks"
RES_DIR="$BUNDLE_PATH/Contents/Resources"

# Clean previous bundle
rm -rf "$PACKAGE_DIR"
rm -f "$BUILD_DIR/${PACKAGE_NAME}.dmg"

# ---------------------------------------------------------------------------
# Create bundle structure
# ---------------------------------------------------------------------------

info "Creating bundle structure"
mkdir -p "$BIN_DIR"
mkdir -p "$FRAMEWORK_DIR"
mkdir -p "$RES_DIR/data"

# ---------------------------------------------------------------------------
# Copy binaries
# ---------------------------------------------------------------------------

info "Copying binaries"
cp "$BUILD_DIR/app/Sourcetrail" "$BIN_DIR/Sourcetrail"
cp "$BUILD_DIR/app/sourcetrail_indexer" "$BIN_DIR/sourcetrail_indexer"

# ---------------------------------------------------------------------------
# Copy app data
# ---------------------------------------------------------------------------

info "Copying application data"

# Data directories from build output (includes clang headers, java jar, etc.)
if [[ -d "$BUILD_DIR/app/data" ]]; then
    cp -R "$BUILD_DIR/app/data/"* "$RES_DIR/data/"
fi

# User projects / fallback
if [[ -d "$BUILD_DIR/app/user" ]]; then
    cp -R "$BUILD_DIR/app/user" "$RES_DIR/user"
fi

# Symlinks from MacOS/ to Resources/ so the binary can find them
# (Sourcetrail resolves paths relative to argv[0])
ln -s ../Resources/data "$BIN_DIR/data"
ln -s ../Resources/user "$BIN_DIR/user"

# ---------------------------------------------------------------------------
# Info.plist
# ---------------------------------------------------------------------------

info "Writing Info.plist"
cat > "$BUNDLE_PATH/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Sourcetrail</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Sourcetrail</string>
	<key>CFBundleIdentifier</key>
	<string>de.sourcetrail.Sourcetrail</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Sourcetrail</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>CFBundleIconFile</key>
	<string>icon</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleTypeName</key>
			<string>Sourcetrail Project</string>
			<key>CFBundleTypeExtensions</key>
			<array>
				<string>srctrlprj</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

# ---------------------------------------------------------------------------
# App icon
# ---------------------------------------------------------------------------

LOGO="$REPO_ROOT/src/resources/icon/logo_1024_1024.png"
if [[ -f "$LOGO" ]]; then
    info "Generating app icon"
    ICON_SET="$RES_DIR/icon.iconset"
    mkdir -p "$ICON_SET"

    for SIZE in 16 32 64 128 256 512 1024; do
        sips -z $SIZE $SIZE "$LOGO" --out "$ICON_SET/icon_${SIZE}x${SIZE}.png" >/dev/null 2>&1
    done
    # Retina variants
    cp "$ICON_SET/icon_32x32.png"   "$ICON_SET/icon_16x16@2x.png"
    cp "$ICON_SET/icon_64x64.png"   "$ICON_SET/icon_32x32@2x.png"
    cp "$ICON_SET/icon_256x256.png" "$ICON_SET/icon_128x128@2x.png"
    cp "$ICON_SET/icon_512x512.png" "$ICON_SET/icon_256x256@2x.png"
    cp "$ICON_SET/icon_1024x1024.png" "$ICON_SET/icon_512x512@2x.png"
    # Remove non-standard sizes
    rm -f "$ICON_SET/icon_64x64.png" "$ICON_SET/icon_1024x1024.png"

    iconutil -c icns -o "$RES_DIR/icon.icns" "$ICON_SET"
    rm -rf "$ICON_SET"
else
    info "Logo not found at $LOGO, skipping icon generation"
fi

# ---------------------------------------------------------------------------
# macdeployqt — bundle Qt frameworks and plugins
# ---------------------------------------------------------------------------

MACDEPLOYQT=$(command -v macdeployqt 2>/dev/null || echo "")
if [[ -z "$MACDEPLOYQT" ]]; then
    # Try common Homebrew locations
    for p in /opt/homebrew/bin/macdeployqt /usr/local/bin/macdeployqt; do
        [[ -x "$p" ]] && MACDEPLOYQT="$p" && break
    done
fi
[[ -n "$MACDEPLOYQT" ]] || abort "macdeployqt not found. Install Qt or set PATH."

info "Running macdeployqt"
"$MACDEPLOYQT" "$BUNDLE_PATH" \
    -executable="$BIN_DIR/sourcetrail_indexer" \
    -verbose=1 2>&1 | grep -v "^ERROR:" || true

# ---------------------------------------------------------------------------
# Ad-hoc codesign (no Apple Developer account needed)
# ---------------------------------------------------------------------------

info "Ad-hoc codesigning"

# Sign frameworks and plugins first, then binaries, then the bundle
find "$FRAMEWORK_DIR" -name "*.dylib" -exec codesign --force --sign - {} \; 2>/dev/null || true
find "$BUNDLE_PATH/Contents/PlugIns" -name "*.dylib" -exec codesign --force --sign - {} \; 2>/dev/null || true
for fw in "$FRAMEWORK_DIR"/*.framework; do
    [[ -d "$fw" ]] && codesign --force --sign - "$fw" 2>/dev/null || true
done

codesign --force --sign - "$BIN_DIR/sourcetrail_indexer"
codesign --force --sign - "$BIN_DIR/Sourcetrail"
codesign --force --sign - "$BUNDLE_PATH"

# Verify (without --deep since non-code files like tutorial sources would fail)
codesign --verify --strict "$BUNDLE_PATH" && \
    success "Code signature valid" || \
    abort "Code signature verification failed"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

BUNDLE_SIZE=$(du -sh "$BUNDLE_PATH" | cut -f1)
success "Bundle created: $BUNDLE_PATH ($BUNDLE_SIZE)"

# ---------------------------------------------------------------------------
# Optional: create .dmg
# ---------------------------------------------------------------------------

echo ""
read -p "Create .dmg disk image? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    DMG_PATH="$BUILD_DIR/${PACKAGE_NAME}.dmg"
    info "Creating DMG at $DMG_PATH"

    # Add Applications symlink for drag-to-install
    ln -sf /Applications "$PACKAGE_DIR/Applications"

    hdiutil create \
        -fs HFS+ \
        -volname "Sourcetrail $VERSION" \
        -srcfolder "$PACKAGE_DIR" \
        "$DMG_PATH"

    rm -f "$PACKAGE_DIR/Applications"

    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    success "DMG created: $DMG_PATH ($DMG_SIZE)"
else
    info "Skipping DMG creation"
fi

echo ""
success "Done! To run: open $BUNDLE_PATH"
echo ""
echo "Note: On another Mac, right-click > Open to bypass Gatekeeper"
echo "      (ad-hoc signed apps trigger the unidentified developer warning)."
