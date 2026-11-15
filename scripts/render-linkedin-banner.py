#!/usr/bin/env python3
"""Render img/linkedin-release-banner.jpg from the official logo.

Uses vendored Playfair Display (OFL) under assets/fonts/ for identical output
on Linux and macOS.

Usage:
  python3 scripts/render-linkedin-banner.py
  python3 scripts/render-linkedin-banner.py --version 0.7.0 --subtitle "ERC-7751 wrapped reverts"
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "fonts"
PLAYFAIR = FONT_DIR / "PlayfairDisplay[wght].ttf"
LOGO = ROOT / "img" / "logo.jpg"
OUT = ROOT / "img" / "linkedin-release-banner.jpg"

W, H = 1200, 627
BG = (245, 242, 236)
INK = (18, 18, 18)
MUTED = (70, 64, 56)
FOOT = (90, 84, 76)
GOLD = (184, 149, 80)

TEXT_X = 620
TEXT_MAX_W = W - TEXT_X - 56
LINE = 1.28


def playfair(size: int, weight: int) -> ImageFont.FreeTypeFont:
    if not PLAYFAIR.is_file():
        raise FileNotFoundError(f"Missing vendored font: {PLAYFAIR}")
    font = ImageFont.truetype(PLAYFAIR, size)
    font.set_variation_by_axes([weight])
    return font


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> float:
    return draw.textlength(text, font=font)


def wrap_subtitle(
    draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: float
) -> list[str]:
    words = text.split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if text_width(draw, trial, font) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def fit_subtitle(
    draw: ImageDraw.ImageDraw, text: str
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    for size, weight in ((36, 600), (34, 600), (32, 500), (30, 500)):
        font = playfair(size, weight)
        lines = wrap_subtitle(draw, text, font, TEXT_MAX_W)
        line_h = size * LINE
        block_h = line_h * len(lines)
        if block_h <= 120 and len(lines) <= 2:
            return font, lines
    font = playfair(30, 500)
    return font, wrap_subtitle(draw, text, font, TEXT_MAX_W)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="vX.Y.Z")
    parser.add_argument("--subtitle", default="Foundry-native ERC library")
    parser.add_argument("--url", default="github.com/jose-compu/curated-erc")
    args = parser.parse_args()
    version = args.version if args.version.startswith("v") else f"v{args.version}"

    canvas = Image.new("RGB", (W, H), BG)
    logo = Image.open(LOGO).convert("RGB")
    max_logo = 500
    ratio = min(max_logo / logo.width, max_logo / logo.height)
    logo = logo.resize((int(logo.width * ratio), int(logo.height * ratio)), Image.Resampling.LANCZOS)
    canvas.paste(logo, (56, (H - logo.height) // 2))

    draw = ImageDraw.Draw(canvas)
    title_font = playfair(54, 700)
    version_font = playfair(36, 600)
    subtitle_font, subtitle_lines = fit_subtitle(draw, args.subtitle)
    foot_font = playfair(19, 400)

    ty = 178
    draw.text((TEXT_X, ty), "NEW RELEASE", font=title_font, fill=INK)
    rule_y = ty + 70
    draw.line((TEXT_X, rule_y, TEXT_X + 420, rule_y), fill=GOLD, width=2)

    vy = rule_y + 28
    draw.text((TEXT_X, vy), version, font=version_font, fill=INK)

    sub_y = vy + 50
    sub_line_h = subtitle_font.size * LINE
    for line in subtitle_lines:
        draw.text((TEXT_X, int(sub_y)), line, font=subtitle_font, fill=MUTED)
        sub_y += sub_line_h

    draw.text((TEXT_X, H - 68), args.url, font=foot_font, fill=FOOT)

    canvas.save(OUT, "JPEG", quality=92, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()