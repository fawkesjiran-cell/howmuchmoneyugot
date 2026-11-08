# Releasing the apps

Pushing a `v*` tag runs `.github/workflows/electron-release.yml`, which builds
and publishes four app variants:

1. **macOS Swift — Updater** — native SwiftUI app with the in-app GitHub updater.
2. **Windows Electron — Updater** — NSIS installer/portable/zip with the in-app GitHub updater.
3. **macOS Swift — Offline** — native SwiftUI app compiled without the updater.
4. **Windows Electron — Offline** — Windows app built without the updater and with all web requests blocked.

There is no macOS Electron build.

## Network promises

- **Updater builds (1, 2):** the only network traffic is the update check,
  metadata download, update package download and installer download from
  GitHub. Chromium background networking, spellcheck downloads and permissions
  are disabled; any renderer HTTP(S)/WebSocket request is blocked except the
  GitHub update hosts.
- **Offline builds (3, 4):** no updater is compiled/loaded, no update IPC is
  registered, and all HTTP(S)/WebSocket requests are cancelled. The macOS
  offline binary is compiled with `HOWMUCH_OFFLINE`, which removes the updater
  entirely.

## 1. Bump both versions

The tag must match both versions:

- `electron/package.json` → `"version"`
- `Resources/Info.plist` → `CFBundleShortVersionString`

Run `npm install --package-lock-only` inside `electron/` if dependencies change.

## 2. Signing

### macOS Swift — both variants

Add these repository secrets:

| Secret | Value |
| --- | --- |
| `MAC_CERTIFICATE_P12` | base64 of an exported **Developer ID Application** `.p12` |
| `MAC_CERTIFICATE_PASSWORD` | password used when exporting the `.p12` |
| `MAC_KEYCHAIN_PASSWORD` | any temporary password used for the CI keychain |
| `APPLE_ID` | Apple ID enrolled in the Apple Developer Program |
| `APPLE_APP_SPECIFIC_PASSWORD` | app-specific password for that Apple ID |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

The workflow signs both the updater and offline Swift apps, notarizes them,
staples them, and rebuilds both zips.

### Windows Electron — both variants

| Secret | Value |
| --- | --- |
| `WIN_CSC_LINK` | base64 of the `.pfx` code-signing certificate |
| `WIN_CSC_KEY_PASSWORD` | certificate password |

electron-builder signs both the updater and offline Windows installers when
these are present. Without signing, SmartScreen may warn on first launch.

## 3. Tag and publish

```bash
git tag v1.6.0
git push origin v1.6.0
```

The workflow creates a GitHub Release with:

- `How-Much-Money-U-Got-<version>-macOS-Swift.zip` — macOS updater build
- `How-Much-Money-U-Got-<version>-macOS-Offline.zip` — macOS offline build
- `How-Much-Money-U-Got-Setup-<version>.exe` — Windows updater installer
- `How-Much-Money-U-Got-<version>-Windows-Electron-x64.exe` — Windows updater portable
- `How-Much-Money-U-Got-<version>-Windows-Electron-x64.zip` — Windows updater zip
- `How-Much-Money-U-Got-Offline-Setup-<version>.exe` — Windows offline installer
- `How-Much-Money-U-Got-<version>-Windows-Electron-Offline-x64.exe` — Windows offline portable
- `How-Much-Money-U-Got-<version>-Windows-Electron-Offline-x64.zip` — Windows offline zip
- `latest.yml` + `*.blockmap` — Windows updater metadata only
- `SHA256SUMS.txt`

The offline Windows build uses `electron-builder.offline.yml`, writes to
`release-offline`, and does not publish update metadata. macOS update packages
are selected by the native updater from the `macOS-Swift` zip; the offline zip
deliberately does not contain that name.

## 4. Inspect the release

Confirm the release contains the four variants and that `latest.yml` points at
the **online** Windows NSIS installer. Never upload `release-offline/latest.yml`
or a macOS Electron zip.
