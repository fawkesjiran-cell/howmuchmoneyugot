#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="$ROOT/dist/How much money u got?.app"
ZIP="$ROOT/dist/How-Much-Money-U-Got-${VERSION}-macOS-Swift.zip"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "Skipping Swift notarization: Apple credentials are not configured."
    exit 0
fi
[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }

TMP="$(mktemp -d)"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$TMP/app.zip"
xcrun notarytool submit "$TMP/app.zip" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -rf "$TMP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "Notarized and packaged $ZIP"
