#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
VARIANT="${HOWMUCH_SWIFT_VARIANT:-online}"
if [[ "$VARIANT" == "offline" ]]; then
    ASSET_VARIANT="macOS-Offline"
else
    ASSET_VARIANT="macOS-Swift"
fi
APP="$ROOT/dist/How much money u got?.app"
OUT="$ROOT/dist/How-Much-Money-U-Got-${VERSION}-${ASSET_VARIANT}.zip"
[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }
rm -f "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"
echo "$OUT"
