#!/usr/bin/env python3
"""Build the app icon assets from the vector source in Resources/AppIcon.svg."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
SVG = RESOURCES / "AppIcon.svg"
PNG = RESOURCES / "AppIcon.png"
ICONSET = RESOURCES / "AppIcon.iconset"
ICNS = RESOURCES / "AppIcon.icns"

SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def main() -> None:
    if not SVG.exists():
        raise SystemExit(f"Missing icon source: {SVG}")

    # sips uses ImageIO, which renders the SVG including its alpha and rounded
    # squircle. Keep the 1024px PNG as the README/app icon source.
    run("sips", "-s", "format", "png", str(SVG), "--out", str(PNG))

    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir()

    for name, size in SIZES.items():
        run(
            "sips",
            "-z",
            str(size),
            str(size),
            str(PNG),
            "--out",
            str(ICONSET / name),
        )

    run("iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS))
    print(f"Wrote {PNG.relative_to(ROOT)} and {ICNS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
