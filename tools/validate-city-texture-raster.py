#!/usr/bin/env python3
"""Validate rasterized Mshin city textures before they are imported into Cocos."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/city/textures/generated"
EXPECTED = ("grass", "asphalt", "sidewalk", "brick", "concrete", "roof")
MIN_SIZE = 256

def main() -> int:
    failures = []
    for name in EXPECTED:
        path = OUTPUT / f"{name}.png"
        if not path.is_file():
            failures.append(f"missing: {path.relative_to(ROOT)}")
            continue
        try:
            with Image.open(path) as source:
                image = source.convert("RGB")
                width, height = image.size
                if width != height or width < MIN_SIZE:
                    failures.append(f"{name}: expected square texture >= {MIN_SIZE}px, got {width}x{height}")
                if image.getbbox() is None:
                    failures.append(f"{name}: texture is empty")
                if path.stat().st_size < 256:
                    failures.append(f"{name}: suspiciously small PNG ({path.stat().st_size} bytes)")
                print(f"OK {name}: {width}x{height}, {path.stat().st_size} bytes")
        except Exception as error:
            failures.append(f"{name}: cannot decode PNG ({error})")
    if failures:
        print("\n".join(f"FAIL {failure}" for failure in failures))
        return 1
    print(f"Validated {len(EXPECTED)} city texture PNGs.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
