# Third-party notices

## Geist

The Electron renderer bundles **Geist** for the interface.

- Source: https://github.com/vercel/geist-font
- Bundled file: `src/renderer/fonts/Geist.ttf`
- License: SIL Open Font License 1.1 — see `src/renderer/fonts/OFL.txt`.

## Electron / Chromium

Electron and Chromium are distributed under their respective open-source
licenses. The packaged application includes Electron's generated
`LICENSE.electron.txt` and `LICENSES.chromium.html` resources.


## electron-updater

The Electron app uses **electron-updater** for GitHub Releases updates.

- Source: https://github.com/electron-userland/electron-builder
- License: MIT

## Reicon

The renderer uses 18 inline SVG icons from **Reicon**, an open-source icon
library by Dev Chauhan.

- Source: https://github.com/dqev/reicon
- Version: 1.2.5
- License: MIT
- Local changes: the glyphs are inlined into `src/renderer/index.html`; no
  other changes.

MIT License

Copyright (c) 2025 REICON

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
