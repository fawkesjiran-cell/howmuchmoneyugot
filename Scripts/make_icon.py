#!/usr/bin/env python3
"""Render the How much money u got? app icon at 1024px, then build the macOS iconset."""

from __future__ import annotations

import math
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
SCALE = 2
SIZE = 1024
CANVAS = SIZE * SCALE
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def px(value: float) -> int:
    return int(round(value * SCALE))


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def gradient_background() -> Image.Image:
    y, x = np.mgrid[0:CANVAS, 0:CANVAS].astype(np.float32)
    t = (x + y) / (2 * (CANVAS - 1))
    t = np.clip(t, 0, 1)

    start = np.array(hex_rgb("#063625"), dtype=np.float32)
    middle = np.array(hex_rgb("#0B5138"), dtype=np.float32)
    end = np.array(hex_rgb("#16845C"), dtype=np.float32)

    first = t < 0.55
    second = ~first
    colors = np.zeros((CANVAS, CANVAS, 3), dtype=np.float32)
    colors[first] = (
        start[None, None, :]
        + (middle - start)[None, None, :] * (t[first, None] / 0.55)
    )
    colors[second] = (
        middle[None, None, :]
        + (end - middle)[None, None, :] * ((t[second, None] - 0.55) / 0.45)
    )

    # Soft top-left light bloom.
    cx, cy = CANVAS * 0.22, CANVAS * 0.15
    distance = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (CANVAS * 0.72)
    bloom = np.clip(1 - distance, 0, 1)[..., None] ** 2
    colors = np.clip(colors + bloom * np.array([22, 55, 39]), 0, 255)

    rgba = np.zeros((CANVAS, CANVAS, 4), dtype=np.uint8)
    rgba[..., :3] = colors.astype(np.uint8)
    rgba[..., 3] = 255
    return Image.fromarray(rgba, "RGBA")


def squircle_mask() -> Image.Image:
    mask = Image.new("L", (CANVAS, CANVAS), 0)
    draw = ImageDraw.Draw(mask)
    inset = px(72)
    draw.rounded_rectangle(
        (inset, inset, CANVAS - inset, CANVAS - inset),
        radius=px(212),
        fill=255,
    )
    return mask


def add_shadow(base: Image.Image, mask: Image.Image, offset: int, blur: int, alpha: int) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, alpha), (0, 0), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow, (0, offset))


def draw_sparkle(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, color: tuple[int, int, int, int]) -> None:
    points = [
        (cx, cy - radius),
        (cx + radius * 0.18, cy - radius * 0.18),
        (cx + radius, cy),
        (cx + radius * 0.18, cy + radius * 0.18),
        (cx, cy + radius),
        (cx - radius * 0.18, cy + radius * 0.18),
        (cx - radius, cy),
        (cx - radius * 0.18, cy - radius * 0.18),
    ]
    draw.polygon(points, fill=color)


def main() -> None:
    RESOURCES.mkdir(parents=True, exist_ok=True)

    mask = squircle_mask()
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    add_shadow(icon, mask, offset=px(22), blur=px(42), alpha=95)

    background = gradient_background()
    background.putalpha(mask)
    icon.alpha_composite(background)

    draw = ImageDraw.Draw(icon, "RGBA")

    # Inner rim light.
    inset = px(72)
    draw.rounded_rectangle(
        (inset, inset, CANVAS - inset, CANVAS - inset),
        radius=px(212),
        outline=(255, 255, 255, 42),
        width=px(2),
    )
    draw.rounded_rectangle(
        (inset + px(6), inset + px(6), CANVAS - inset - px(6), CANVAS - inset - px(6)),
        radius=px(206),
        outline=(0, 0, 0, 28),
        width=px(2),
    )

    # Coin shadow.
    coin_cx, coin_cy, coin_r = 512, 520, 252
    coin_shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(coin_shadow)
    shadow_draw.ellipse(
        (
            px(coin_cx - coin_r),
            px(coin_cy - coin_r + 18),
            px(coin_cx + coin_r),
            px(coin_cy + coin_r + 18),
        ),
        fill=(0, 14, 8, 130),
    )
    coin_shadow = coin_shadow.filter(ImageFilter.GaussianBlur(px(28)))
    icon.alpha_composite(coin_shadow)

    # Gold clock ring behind the cream coin.
    ring_box = (
        px(coin_cx - coin_r - 41),
        px(coin_cy - coin_r - 41),
        px(coin_cx + coin_r + 41),
        px(coin_cy + coin_r + 41),
    )
    draw.arc(ring_box, start=17, end=73, fill=(236, 190, 107, 225), width=px(7))
    draw.arc(ring_box, start=107, end=150, fill=(236, 190, 107, 125), width=px(5))
    draw.arc(ring_box, start=219, end=260, fill=(236, 190, 107, 125), width=px(5))

    # Clock tick marks.
    for angle in (-58, -34, 12, 44, 92, 138, 188, 224):
        radians = math.radians(angle)
        inner = coin_r + 27
        outer = coin_r + 39
        x1 = coin_cx + inner * math.cos(radians)
        y1 = coin_cy + inner * math.sin(radians)
        x2 = coin_cx + outer * math.cos(radians)
        y2 = coin_cy + outer * math.sin(radians)
        draw.line(
            (px(x1), px(y1), px(x2), px(y2)),
            fill=(242, 205, 137, 185),
            width=px(4),
        )

    # Gold dot at the top-right of the clock ring.
    dot_angle = math.radians(18)
    dot_cx = coin_cx + (coin_r + 41) * math.cos(dot_angle)
    dot_cy = coin_cy + (coin_r + 41) * math.sin(dot_angle)
    draw.ellipse(
        (px(dot_cx - 12), px(dot_cy - 12), px(dot_cx + 12), px(dot_cy + 12)),
        fill=(245, 199, 115, 255),
    )
    draw.ellipse(
        (px(dot_cx - 5), px(dot_cy - 5), px(dot_cx + 5), px(dot_cy + 5)),
        fill=(255, 237, 196, 220),
    )

    # Cream coin.
    coin_box = (
        px(coin_cx - coin_r),
        px(coin_cy - coin_r),
        px(coin_cx + coin_r),
        px(coin_cy + coin_r),
    )
    draw.ellipse(coin_box, fill=(246, 233, 205, 255))
    draw.ellipse(coin_box, outline=(236, 203, 143, 255), width=px(4))

    # Subtle coin shading.
    shade = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    shade_draw.ellipse(
        (
            px(coin_cx - coin_r),
            px(coin_cy - coin_r + 10),
            px(coin_cx + coin_r),
            px(coin_cy + coin_r + 20),
        ),
        fill=(111, 78, 28, 32),
    )
    shade = shade.filter(ImageFilter.GaussianBlur(px(26)))
    coin_mask = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(coin_mask).ellipse(coin_box, fill=255)
    shade.putalpha(Image.composite(shade.getchannel("A"), Image.new("L", shade.size, 0), coin_mask))
    icon.alpha_composite(shade)

    # Inner ring.
    inner_r = coin_r - 38
    draw.ellipse(
        (
            px(coin_cx - inner_r),
            px(coin_cy - inner_r),
            px(coin_cx + inner_r),
            px(coin_cy + inner_r),
        ),
        outline=(193, 156, 92, 72),
        width=px(2),
    )

    # Soft highlight on the top edge of the coin.
    highlight = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.arc(
        (
            px(coin_cx - coin_r + 25),
            px(coin_cy - coin_r + 22),
            px(coin_cx + coin_r - 25),
            px(coin_cy + coin_r - 22),
        ),
        start=200,
        end=338,
        fill=(255, 255, 255, 150),
        width=px(9),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(px(7)))
    highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", highlight.size, 0), coin_mask))
    icon.alpha_composite(highlight)

    # Yen mark.
    font = ImageFont.truetype(FONT_PATH, px(372))
    draw.text(
        (px(coin_cx), px(coin_cy + 2)),
        "¥",
        font=font,
        fill=(9, 66, 47, 255),
        anchor="mm",
        stroke_width=px(1),
        stroke_fill=(9, 66, 47, 255),
    )

    # Small green underline/coin detail under the glyph.
    draw.rounded_rectangle(
        (px(coin_cx - 58), px(coin_cy + 154), px(coin_cx + 58), px(coin_cy + 166)),
        radius=px(6),
        fill=(203, 155, 77, 110),
    )

    # Sparkles in the upper right.
    draw_sparkle(draw, px(774), px(250), px(31), (250, 220, 157, 240))
    draw_sparkle(draw, px(834), px(330), px(17), (255, 235, 189, 205))
    draw_sparkle(draw, px(282), px(790), px(12), (255, 235, 189, 130))

    icon = icon.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    icon.save(RESOURCES / "AppIcon.png")

    iconset = RESOURCES / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir()

    sizes = {
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
    for name, size in sizes.items():
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(iconset / name)

    subprocess.run(
        ["iconutil", "-c", "icns", str(iconset), "-o", str(RESOURCES / "AppIcon.icns")],
        check=True,
    )
    print(f"Wrote {RESOURCES / 'AppIcon.icns'}")


if __name__ == "__main__":
    main()
