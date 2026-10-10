#!/usr/bin/env python3
"""Render img/linkedin-release-banner.jpg from the official logo.

Usage:
  python3 scripts/render-linkedin-banner.py
  python3 scripts/render-linkedin-banner.py --version 0.6.0 --subtitle "ERC-4626 tokenized vaults"
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "img" / "logo.jpg"
OUT = ROOT / "img" / "linkedin-release-banner.jpg"

W, H = 1200, 627
BG = (245, 242, 236)
INK = (18, 18, 18)
MUTED = (70, 64, 56)
FOOT = (90, 84, 76)
GOLD = (184, 149, 80)

DIDOT = "/System/Library/Fonts/Supplemental/Didot.ttc"
TIMES = "/Library/Fonts/Times.ttc"


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
    title = ImageFont.truetype(DIDOT, 54)
    sub = ImageFont.truetype(DIDOT, 36)
    body = ImageFont.truetype(TIMES, 26)
    small = ImageFont.truetype(TIMES, 18)

    tx, ty = 620, 190
    draw.text((tx, ty), "NEW RELEASE", font=title, fill=INK)
    draw.line((tx, ty + 72, tx + 420, ty + 72), fill=GOLD, width=2)
    draw.text((tx, ty + 100), version, font=sub, fill=INK)
    draw.text((tx, ty + 152), args.subtitle, font=body, fill=MUTED)
    draw.text((tx, H - 72), args.url, font=small, fill=FOOT)

    canvas.save(OUT, "JPEG", quality=92, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
