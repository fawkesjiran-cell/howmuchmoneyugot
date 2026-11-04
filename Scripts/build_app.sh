#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="How much money u got?"
EXECUTABLE="HowMuch"
APP="$ROOT/dist/$APP_NAME.app"
BUILD_HOME="$ROOT/.build/home"
MODULE_CACHE="$ROOT/.build/clang-module-cache"
SWIFT_CACHE="$ROOT/.build/swift-module-cache"
TMP="$ROOT/.build/tmp"

mkdir -p "$BUILD_HOME" "$MODULE_CACHE" "$SWIFT_CACHE" "$TMP" "$ROOT/.build/cache" "$ROOT/.build/config" "$ROOT/.build/security"

echo "==> Building $EXECUTABLE (release)"
HOME="$BUILD_HOME" \
TMPDIR="$TMP" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFT_MODULE_CACHE_PATH="$SWIFT_CACHE" \
swift build \
    -c release \
    --product "$EXECUTABLE" \
    --disable-sandbox \
    --cache-path "$ROOT/.build/cache" \
    --config-path "$ROOT/.build/config" \
    --security-path "$ROOT/.build/security"

BIN="$ROOT/.build/release/$EXECUTABLE"
if [[ ! -f "$BIN" ]]; then
    BIN="$(find "$ROOT/.build" -type f -name "$EXECUTABLE" -perm -111 | head -n 1)"
fi
if [[ -z "${BIN:-}" || ! -f "$BIN" ]]; then
    echo "Build succeeded but executable was not found." >&2
    exit 1
fi

echo "==> Packaging $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE"
chmod +x "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/FireTexture.png" "$APP/Contents/Resources/FireTexture.png"
cp -R "$ROOT/Resources/Fonts" "$APP/Contents/Resources/Fonts"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Done"
echo "$APP"
