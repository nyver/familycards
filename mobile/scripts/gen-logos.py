#!/usr/bin/env python3
"""Generates placeholder logo plaques for the bundled store catalog.

Reads assets/stores/catalog.json and, for every entry, renders a simple
WebP image: the entry's brand color as a flat background with the store's
initials centered on top. These are intentionally NOT downloaded
third-party logos (per FamilyCards_SQLite_Master_Prompt.md §8) - they are
generated locally so the app ships no scraped brand assets.

Usage: python scripts/gen-logos.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "assets" / "stores" / "catalog.json"
LOGOS_DIR = ROOT / "assets" / "stores" / "logos"
SIZE = 256


def initials_for(names: list[str]) -> str:
    name = names[0]
    words = re.findall(r"[^\W\d_]+", name, flags=re.UNICODE)
    if not words:
        return "?"
    if len(words) == 1:
        return words[0][:2].upper()
    return (words[0][0] + words[1][0]).upper()


def relative_luminance(hex_color: str) -> float:
    r = int(hex_color[1:3], 16) / 255
    g = int(hex_color[3:5], 16) / 255
    b = int(hex_color[5:7], 16) / 255
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def load_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/segoeuib.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def render_logo(hex_color: str, initials: str) -> Image.Image:
    img = Image.new("RGB", (SIZE, SIZE), hex_color)
    draw = ImageDraw.Draw(img)
    text_color = "#FFFFFF" if relative_luminance(hex_color) < 0.55 else "#000000"
    font = load_font(SIZE // 2)
    bbox = draw.textbbox((0, 0), initials, font=font)
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pos = ((SIZE - text_w) / 2 - bbox[0], (SIZE - text_h) / 2 - bbox[1])
    draw.text(pos, initials, fill=text_color, font=font)
    return img


def main() -> int:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    LOGOS_DIR.mkdir(parents=True, exist_ok=True)
    generated = 0
    for entry in catalog:
        img = render_logo(entry["color"], initials_for(entry["names"]))
        out_path = LOGOS_DIR / entry["logo"]
        img.save(out_path, format="WEBP", quality=90)
        generated += 1
    print(f"Generated {generated} logo plaques in {LOGOS_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
