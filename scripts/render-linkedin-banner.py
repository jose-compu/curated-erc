#!/usr/bin/env python3
"""Render img/linkedin-release-banner.jpg from the official logo.

Uses vendored Playfair Display (OFL) under assets/fonts/ for identical output
on Linux and macOS. Lining figures: +lnum via libraqm when available;
otherwise GFSDidot-Regular.ttf for lines that contain digits (version,
subtitle, detail).

Usage:
  python3 scripts/render-linkedin-banner.py
  python3 scripts/render-linkedin-banner.py --version 0.7.0 --subtitle "ERC-7751 wrapped reverts"
  python3 scripts/render-linkedin-banner.py --version 0.7.0 \\
    --subtitle "ERC-7751 wrapped reverts" \\
    --detail "Failed inner calls now revert with WrappedError, keeping the target, selector and original revert reason."
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from PIL import features as pil_features

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "fonts"
PLAYFAIR = FONT_DIR / "PlayfairDisplay[wght].ttf"
LINING_FALLBACK = FONT_DIR / "GFSDidot-Regular.ttf"
LOGO = ROOT / "img" / "logo.jpg"
OUT = ROOT / "img" / "linkedin-release-banner.jpg"

W, H = 1200, 627
BG = (245, 242, 236)
INK = (18, 18, 18)
MUTED = (70, 64, 56)
DETAIL = (58, 54, 48)
FOOT = (90, 84, 76)
GOLD = (184, 149, 80)

TEXT_X = 620
TEXT_MAX_W = W - TEXT_X - 56
LINE = 1.28
FOOT_Y = H - 68
FOOT_CLEARANCE = 24
DETAIL_MAX_LINES = 3
DETAIL_MIN_PX = 20
DETAIL_MAX_PX = 28

_HAS_RAQM = pil_features.check("raqm")
_LNUM = ["+lnum"] if _HAS_RAQM else None


def playfair(size: int, weight: int) -> ImageFont.FreeTypeFont:
    if not PLAYFAIR.is_file():
        raise FileNotFoundError(f"Missing vendored font: {PLAYFAIR}")
    kwargs: dict = {}
    if _HAS_RAQM:
        kwargs["layout_engine"] = ImageFont.Layout.RAQM
    font = ImageFont.truetype(PLAYFAIR, size, **kwargs)
    font.set_variation_by_axes([weight])
    return font


def lining_fallback(size: int) -> ImageFont.FreeTypeFont:
    if not LINING_FALLBACK.is_file():
        raise FileNotFoundError(f"Missing lining fallback font: {LINING_FALLBACK}")
    return ImageFont.truetype(LINING_FALLBACK, size)


def draw_font_for(text: str, playfair_font: ImageFont.FreeTypeFont) -> ImageFont.FreeTypeFont:
    if _HAS_RAQM:
        return playfair_font
    if any(ch.isdigit() for ch in text):
        return lining_fallback(playfair_font.size)
    return playfair_font


def text_width(
    draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont
) -> float:
    if _LNUM:
        return draw.textlength(text, font=font, features=_LNUM)
    return draw.textlength(text, font=font)


def draw_line(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
) -> None:
    use_font = draw_font_for(text, font)
    if _LNUM:
        draw.text(xy, text, font=use_font, fill=fill, features=_LNUM)
    else:
        draw.text(xy, text, font=use_font, fill=fill)


def wrap_text(
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


def assert_words_preserved(source: str, lines: list[str]) -> None:
    if " ".join(source.split()) != " ".join(lines):
        raise RuntimeError(
            "wrap_text dropped words: "
            f"source={source!r} wrapped={' | '.join(lines)!r}"
        )


def fit_subtitle(
    draw: ImageDraw.ImageDraw, text: str
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    for size, weight in ((36, 600), (34, 600), (32, 500), (30, 500)):
        font = playfair(size, weight)
        lines = wrap_text(draw, text, font, TEXT_MAX_W)
        assert_words_preserved(text, lines)
        line_h = size * LINE
        block_h = line_h * len(lines)
        if block_h <= 120 and len(lines) <= 2:
            return font, lines
    font = playfair(30, 500)
    lines = wrap_text(draw, text, font, TEXT_MAX_W)
    assert_words_preserved(text, lines)
    return font, lines


def fit_detail(
    draw: ImageDraw.ImageDraw, text: str, start_y: float
) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    max_bottom = FOOT_Y - FOOT_CLEARANCE
    for size in range(DETAIL_MAX_PX, DETAIL_MIN_PX - 1, -1):
        font = playfair(size, 500 if size >= 26 else 400)
        lines = wrap_text(draw, text, font, TEXT_MAX_W)
        assert_words_preserved(text, lines)
        if len(lines) > DETAIL_MAX_LINES:
            continue
        line_h = size * LINE
        if start_y + line_h * len(lines) <= max_bottom:
            return font, lines
    raise SystemExit(
        f"Detail text does not fit within {DETAIL_MAX_LINES} lines down to "
        f"{DETAIL_MIN_PX}px between y={start_y:.0f} and footer: {text!r}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Render the LinkedIn release banner JPEG.")
    parser.add_argument("--version", default="vX.Y.Z", help="Release version (v prefix optional)")
    parser.add_argument("--subtitle", default="Foundry-native ERC library", help="Primary release line")
    parser.add_argument(
        "--detail",
        default="",
        help="Optional one-sentence improvement summary (up to 3 lines, Playfair)",
    )
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

    ty = 168 if args.detail.strip() else 178
    draw_line(draw, (TEXT_X, ty), "NEW RELEASE", title_font, INK)
    rule_y = ty + 70
    draw.line((TEXT_X, rule_y, TEXT_X + 420, rule_y), fill=GOLD, width=2)

    vy = rule_y + 28
    draw_line(draw, (TEXT_X, vy), version, version_font, INK)

    sub_y = vy + 50
    sub_line_h = subtitle_font.size * LINE
    for line in subtitle_lines:
        draw_line(draw, (TEXT_X, int(sub_y)), line, subtitle_font, MUTED)
        sub_y += sub_line_h

    detail_text = args.detail.strip()
    if detail_text:
        detail_font, detail_lines = fit_detail(draw, detail_text, sub_y + 14)
        detail_y = sub_y + 14
        detail_line_h = detail_font.size * LINE
        for line in detail_lines:
            draw_line(draw, (TEXT_X, int(detail_y)), line, detail_font, DETAIL)
            detail_y += detail_line_h
        assert_words_preserved(detail_text, detail_lines)

    draw_line(draw, (TEXT_X, FOOT_Y), args.url, foot_font, FOOT)

    canvas.save(OUT, "JPEG", quality=92, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()