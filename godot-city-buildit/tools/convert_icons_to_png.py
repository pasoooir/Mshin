#!/usr/bin/env python3
"""Convert every icon SVG to a transparent, 512x512 RGBA PNG and migrate references."""
from pathlib import Path
import re
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
        raise SystemExit(f"Refusing to overwrite existing PNG without review: {destination.relative_to(ROOT)}")
    raw = source.read_bytes()
    cairosvg.svg2png(bytestring=raw, write_to=str(destination), output_width=512, output_height=512)
    if not destination.is_file() or destination.stat().st_size < 64:
        raise SystemExit(f"PNG conversion failed or produced an empty file: {destination}")
    data = destination.read_bytes()
    if data[:8] != b"\\x89PNG\\r\\n\\x1a\\n":
        raise SystemExit(f"Output is not a real PNG: {destination}")
    converted.append((source, destination))

# Update every textual reference to assets inside this icon tree, not unrelated
# project artwork such as the Godot application icon.
pattern = re.compile(r'((?:res://)?(?:[^"\\s<>]*?/)?assets/icons/[^"\\s<>]*?)\\.svg')
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
    updated = pattern.sub(r"\\1.png", original)
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        updated_files.append(path.relative_to(ROOT).as_posix())

for source, _ in converted:
    source.unlink()

remaining = list(ICON_ROOT.rglob("*.svg"))
if remaining:
    raise SystemExit("SVG icon files remain: " + ", ".join(str(p.relative_to(ROOT)) for p in remaining))
print(f"Converted {len(converted)} SVG icons to 512x512 RGBA PNG; updated {len(updated_files)} text files.")
