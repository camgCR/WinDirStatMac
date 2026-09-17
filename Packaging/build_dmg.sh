#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds WinDirStatMac in release mode, assembles it into a real .app bundle
# (Info.plist, icon, ad-hoc code signature), and packages that into a .dmg.
#
# This produces something you can run and share informally: macOS Gatekeeper
# will still flag it as from an "unidentified developer" (right-click > Open
# the first time) since it isn't signed with a paid Developer ID certificate
# or notarized by Apple. See README.md for what real distribution needs.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGING_DIR="$ROOT_DIR/Packaging"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_NAME="WinDirStatMac"
APP_BUNDLE="$PACKAGING_DIR/dist/$APP_NAME.app"
DMG_STAGING="$PACKAGING_DIR/dist/dmg-staging"
DMG_PATH="$PACKAGING_DIR/dist/$APP_NAME.dmg"

echo "==> Building release binary"
cd "$ROOT_DIR"
swift build -c release

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PACKAGING_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PACKAGING_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc signing (no paid Developer ID cert available yet)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Building $APP_NAME.dmg"
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo "==> Done: $DMG_PATH"
