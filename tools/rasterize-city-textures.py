#!/usr/bin/env python3
"""Rasterize Mshin's original seamless SVG city texture masters to PNG.

Requires Pillow and CairoSVG:
  python -m pip install pillow cairosvg
  python tools/rasterize-city-textures.py --size 512
"""
from __future__ import annotations

import argparse
from pathlib import Path

import cairosvg
from PIL import Image
from io import BytesIO

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "city" / "textures"
OUTPUT = SOURCE / "generated"

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=512)
    args = parser.parse_args()
    if args.size < 128 or args.size > 2048:
        parser.error("--size must be between 128 and 2048")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = sorted(SOURCE.glob("*.svg"))
    if not sources:
        raise SystemExit("No SVG texture masters found")
    for source in sources:
        png = cairosvg.svg2png(url=str(source), output_width=args.size, output_height=args.size)
        image = Image.open(BytesIO(png)).convert("RGB")
        target = OUTPUT / f"{source.stem}.png"
        image.save(target, format="PNG", optimize=True)
        print(f"{source.name} -> {target.relative_to(ROOT)} ({args.size}x{args.size})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
