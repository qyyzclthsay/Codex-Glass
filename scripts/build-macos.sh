#!/bin/bash
# Native SwiftUI/AppKit build. Run on a Mac with Xcode command-line tools.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS and Xcode command-line tools are required.' >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(uname -m)"
VERSION=0.6.0-beta.1
OUT="$ROOT/dist/macos-$ARCH"
APP="$OUT/Codex Glass.app"
export MACOSX_DEPLOYMENT_TARGET=13.0
cd "$ROOT/macos"
if [[ "${1:-}" != --skip-tests ]]; then swift test --parallel; fi
swift build -c release --arch "$ARCH"
BIN="$(swift build -c release --arch "$ARCH" --show-bin-path)"
mkdir -p "$OUT"
# Only remove this script's generated application, never user installations.
[[ "$APP" == "$ROOT/dist/macos-$ARCH/Codex Glass.app" ]] || exit 1
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/CodexGlass" "$APP/Contents/MacOS/"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
cp -R "$BIN/CodexGlass_CodexGlass.bundle" "$APP/Contents/Resources/"
cp "$ROOT/LICENSE" "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
cp -R "$ROOT/licenses" "$APP/Contents/Resources/"
ICONSET="$OUT/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$ROOT/assets/icon.png" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$ROOT/assets/icon.png" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
# Ad-hoc signing permits local Apple Silicon execution; it is NOT Developer ID
# signing, notarization, or a claim that Gatekeeper trusts a downloaded build.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ZIP="$OUT/Codex-Glass-$VERSION-macOS-$ARCH.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
STAGE="$OUT/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Codex Glass.app"
ln -sfn /Applications "$STAGE/Applications"
hdiutil create -volname 'Codex Glass' -srcfolder "$STAGE" -ov -format UDZO "$OUT/Codex-Glass-$VERSION-macOS-$ARCH.dmg"
(cd "$OUT"; shasum -a 256 "$(basename "$ZIP")" "Codex-Glass-$VERSION-macOS-$ARCH.dmg" > "SHA256SUMS-macOS-$ARCH.txt")
echo "Built $APP ($ARCH). Distribution is ad-hoc signed and not notarized."
