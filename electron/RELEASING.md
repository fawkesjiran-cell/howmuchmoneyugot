# Releasing the apps

Pushing a `v*` tag runs `.github/workflows/electron-release.yml`, which builds
and publishes three app variants:

- **macOS Swift** — the original SwiftUI app, universal (arm64 + x64)
- **macOS Electron** — the Electron app, universal (arm64 + x64)
- **Windows Electron** — x64 installer, portable exe, and zip

## 1. Bump both versions

The tag must match both versions:

- `electron/package.json` → `"version"`
- `Resources/Info.plist` → `CFBundleShortVersionString`

Run `npm install --package-lock-only` inside `electron/` if dependencies change.

## 2. Add signing secrets (recommended for directly runnable downloads)

Without signing, macOS will still require right-click → Open after download,
and Windows may show SmartScreen. The workflow builds unsigned artifacts if
these are absent.

### macOS — Developer ID Application + notarization

Add these repository secrets:

| Secret | Value |
| --- | --- |
| `MAC_CERTIFICATE_P12` | base64 of an exported **Developer ID Application** `.p12` |
| `MAC_CERTIFICATE_PASSWORD` | password used when exporting the `.p12` |
| `MAC_KEYCHAIN_PASSWORD` | any temporary password used for the CI keychain |
| `APPLE_ID` | Apple ID enrolled in the Developer Program |
| `APPLE_APP_SPECIFIC_PASSWORD` | app-specific password for that Apple ID |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

Export the certificate with its private key, then base64 it:

```bash
base64 -i DeveloperID.p12 | pbcopy
```

The workflow imports the certificate into a temporary keychain. The Swift job
signs with hardened runtime and notarizes its universal app; the Electron job
lets electron-builder sign with hardened runtime and then notarizes/staples its
universal app. Both zips are rebuilt after stapling.

### Windows — code signing

Add:

| Secret | Value |
| --- | --- |
| `WIN_CSC_LINK` | base64 of the `.pfx` code-signing certificate |
| `WIN_CSC_KEY_PASSWORD` | certificate password |

To base64 the PFX on Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("codesign.pfx")) | Set-Clipboard
```

electron-builder signs the installer, portable `.exe`, and the app executable
inside the zip when these are present. Without them, SmartScreen may warn on
first launch.

## 3. Tag and publish

```bash
git tag v1.5.3
git push origin v1.5.3
```

The workflow creates a GitHub Release with:

- `How-Much-Money-U-Got-<version>-macOS-Swift.zip`
- `How-Much-Money-U-Got-<version>-macOS-Electron-universal.zip`
- `How-Much-Money-U-Got-Setup-<version>.exe`
- `How-Much-Money-U-Got-<version>-Windows-Electron-x64.exe` (portable)
- `How-Much-Money-U-Got-<version>-Windows-Electron-x64.zip`
- `SHA256SUMS.txt`

## Unsigned fallback

If no Apple / Windows secrets are set, the release still builds, but:

- macOS users need to right-click the `.app` and choose **Open**, or remove the
  quarantine attribute manually.
- Windows users may see SmartScreen and need **More info → Run anyway**.

For a frictionless download, configure the signing secrets above.
