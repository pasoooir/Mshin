#!/usr/bin/env python3
"""Convert every icon SVG to a transparent, 512x512 RGBA PNG and migrate references."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ICON_ROOT = ROOT / "assets" / "icons"

try:
    import cairosvg
except ImportError:
    print("Missing dependency: install CairoSVG before converting icon assets.", file=sys.stderr)
    raise

svg_files = sorted(ICON_ROOT.rglob("*.svg"))
if not svg_files:
    print("No SVG icon assets found; conversion is already complete.")
    raise SystemExit(0)

converted = []
for source in svg_files:
    destination = source.with_suffix(".png")
    if destination.exists():
        destination = source.with_name(source.stem + "_from_svg.png")
    if destination.exists():
        raise SystemExit(f"Refusing to overwrite an existing converted asset: {destination.relative_to(ROOT)}")
    cairosvg.svg2png(bytestring=source.read_bytes(), write_to=str(destination), output_width=512, output_height=512)
    data = destination.read_bytes()
    if len(data) < 64 or data[:8] != bytes((137, 80, 78, 71, 13, 10, 26, 10)):
        raise SystemExit(f"Output is not a valid PNG: {destination}")
    converted.append((source, destination))

# Replace exact asset paths, preserving unrelated SVG resources elsewhere.
updated_files = []
for path in ROOT.rglob("*"):
    if not path.is_file() or path.suffix.lower() in {".svg", ".png", ".jpg", ".jpeg", ".webp", ".glb", ".gltf", ".zip", ".apk"}:
        continue
    if ".git" in path.parts or "__pycache__" in path.parts:
        continue
    try:
        original = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    updated = original
    for source, destination in converted:
        old_path = "assets/icons/" + source.relative_to(ICON_ROOT).as_posix()
        new_path = "assets/icons/" + destination.relative_to(ICON_ROOT).as_posix()
        updated = updated.replace(old_path, new_path)
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        updated_files.append(path.relative_to(ROOT).as_posix())

for source, _ in converted:
    source.unlink()

remaining = list(ICON_ROOT.rglob("*.svg"))
if remaining:
    raise SystemExit("SVG icon files remain: " + ", ".join(str(p.relative_to(ROOT)) for p in remaining))
print(f"Converted {len(converted)} SVG icons to 512x512 RGBA PNG; updated {len(updated_files)} text files.")
