#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="$ROOT/dist/How much money u got?.app"
OUT="$ROOT/dist/How-Much-Money-U-Got-${VERSION}-macOS-Swift.zip"
[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }
rm -f "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"
echo "$OUT"
