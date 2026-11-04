<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="How much money u got? app icon">
</p>

<h1 align="center">How much money u got?</h1>
<p align="center"><strong>A quiet little earnings ticker for macOS and Windows.</strong></p>

<p align="center">
  <a href="https://github.com/fawkesjiran-cell/howmuchmoneyugot/releases">Download the latest release</a>
</p>

![How much money u got? dashboard](docs/dashboard-light.png)

## Features

- **Live earnings** — clock in and watch the amount grow in real time.
- **Normal and overtime pay** — separate rates, with overtime calculated at your own multiplier.
- **A complete workday** — clock in, clock out, start overtime, and finish in one compact panel.
- **Fire in the numbers** — overtime digits burn with a living flame, without covering the card.
- **All-time total** — completed sessions stay in the ledger, so the menu bar total never drops.
- **Safe reset** — reset the current session or clear everything, always with confirmation.
- **Menu bar / system tray** — open the panel from the tray and see the running total at a glance.
- **Two languages** — English and Simplified Chinese switch instantly.
- **Eight currencies** — CNY, USD, EUR, GBP, JPY, HKD, KRW, and SGD, with display symbols only.
- **Light, dark, or system** — one compact button cycles through all three and remembers your choice.
- **Built to last** — timestamps survive sleep and restarts; no interval drift.
- **Local-first** — settings and earnings never leave your computer.

| Normal | Overtime |
| --- | --- |
| ![Normal earnings](docs/dashboard-light.png) | ![Overtime earnings](docs/overtime-light.png) |

## Available for

| Platform | Build |
| --- | --- |
| macOS 13+ | Native Swift app (universal) and Electron app (universal) |
| Windows 10/11 | Electron app (x64) |

Both macOS variants and the Windows build are available from the
[Releases](https://github.com/fawkesjiran-cell/howmuchmoneyugot/releases) page.

## Tech stack

- **Native macOS** — Swift, SwiftUI, AppKit
- **macOS and Windows** — Electron, JavaScript, HTML/CSS
- **Overtime motion** — Vortex on Swift, Canvas on Electron

## Credits

- Created by [fawkesjiran-cell](https://github.com/fawkesjiran-cell).
- **Geist** typeface by [Vercel](https://github.com/vercel/geist-font), licensed under the SIL Open Font License 1.1.
- **Vortex** particle system by [Paul Hudson](https://github.com/twostraws/Vortex), licensed under the MIT License.
- App icon artwork created for this project.
- Built with [Electron](https://www.electronjs.org) and Chromium; their licenses apply to the cross-platform build.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full third-party license text.

## License

[MIT](LICENSE) © 2026 fawkesjiran-cell
