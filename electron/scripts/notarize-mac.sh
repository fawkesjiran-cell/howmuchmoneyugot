#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(node -p "require('$ROOT/package.json').version")"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "Skipping notarization: Apple credentials are not configured."
  exit 0
fi

for app_dir in "$ROOT"/release/mac-universal "$ROOT"/release/mac-arm64 "$ROOT"/release/mac-x64; do
  [[ -d "$app_dir" ]] || continue
  APP="$(find "$app_dir" -maxdepth 1 -name '*.app' -print -quit)"
  [[ -n "$APP" ]] || continue

  echo "==> Notarizing $(basename "$APP")"
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

  ARCH="${app_dir##*/mac-}"
  ZIP="$(find "$ROOT/release" -maxdepth 1 -name "How-Much-Money-U-Got-${VERSION}-macOS-Electron-${ARCH}.zip" -print -quit)"
  if [[ -n "$ZIP" ]]; then
    # Rebuild the distributed zip after stapling so the notarization ticket
    # travels with the app users download.
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    echo "==> Refreshed $(basename "$ZIP")"
  fi
done
