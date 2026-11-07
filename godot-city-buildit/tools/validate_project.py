from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

for path in ROOT.rglob("*.gd"):
    source = path.read_text(encoding="utf-8")
    if source.rstrip().endswith(("extends Node3D", "extends Node", "mat = mate")):
        errors.append(f"Likely truncated script: {path.relative_to(ROOT)}")
    for resource in re.findall(r'"res://([^" ]+)"', source):
        if not (ROOT / resource).is_file():
            errors.append(f"Missing script resource {resource} in {path.relative_to(ROOT)}")

for path in ROOT.rglob("*.tscn"):
    source = path.read_text(encoding="utf-8")
    for resource in re.findall(r'path="res://([^"]+)"', source):
        if not (ROOT / resource).is_file():
            errors.append(f"Missing scene resource {resource} in {path.relative_to(ROOT)}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
for script in re.findall(r'="[*]res://([^"]+)"', project):
    if not (ROOT / script).is_file():
        errors.append(f"Missing autoload {script}")

build_manager = (ROOT / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/ui/HUD.gd").read_text(encoding="utf-8")
building_ids = set(re.findall(r'^[ \t]*"([a-z0-9_]+)"[ \t]*:[ \t]*[{]"name"', build_manager, re.M))
for selected in re.findall(r'BuildManager[.]select_building[(]"([a-z0-9_]+)"[)]', hud):
    if selected not in building_ids:
        errors.append(f"HUD references undefined building type: {selected}")
if "commercial_1" in hud:
    errors.append("Obsolete commercial_1 reference remains in HUD")

production = (ROOT / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
storage = (ROOT / "scripts/autoload/StorageManager.gd").read_text(encoding="utf-8")
for item in re.findall(r'"item"[ \t]*:[ \t]*"([a-z0-9_]+)"', production):
    if f'"{item}"' not in storage:
        errors.append(f"Upgrade material missing from storage definitions: {item}")

if errors:
    print("VALIDATION FAILED")
    for error in errors:
        print(error)
    sys.exit(1)

print("Static project validation passed.")

# Validate local UI sprite sheets and atlas references (no CDN/font fallback).
import struct

atlas_path = ROOT / "scripts/ui/IconAtlas.gd"
atlas = atlas_path.read_text(encoding="utf-8")
expected_sheets = [ROOT / "assets/icons/Sheet1.png", ROOT / "assets/icons/Sheet2.png", ROOT / "assets/icons/Sheet3.png"]
for sheet_index, sheet_path in enumerate(expected_sheets, start=1):
    if not sheet_path.is_file():
        errors.append(f"Missing local icon sheet {sheet_path.relative_to(ROOT)}")
        continue
    data = sheet_path.read_bytes()
    if len(data) < 24 or data[:8] != b"\\x89PNG\\r\\n\\x1a\\n":
        errors.append(f"Icon sheet {sheet_path.name} is not a valid PNG")
        continue
    width, height = struct.unpack(">II", data[16:24])
    if width < 1130 or height < 770:
        errors.append(f"Icon sheet {sheet_path.name} has unexpected dimensions {width}x{height}")
    if f'{sheet_index}: preload("res://assets/icons/{sheet_path.name}")' not in atlas:
        errors.append(f"Icon sheet {sheet_path.name} is not preloaded by IconAtlas.gd")

atlas_keys = set(re.findall(r'^\\s*"([a-z0-9_]+)"\\s*:\\s*\\[\\d+,\\s*Rect2i', atlas, re.M))
required_icons = {
    "road", "residential", "commercial", "industrial", "services",
    "specializations", "bulldoze", "power", "water", "fire", "parks",
    "storage", "trade", "save", "cancel", "education", "transportation",
    "entertainment", "gambling", "beach", "mountain", "landmark",
    "trade_depot", "global_trade", "epic", "regions"
}
for icon_key in sorted(required_icons - atlas_keys):
    errors.append(f"Required HUD icon is missing from atlas: {icon_key}")

toolbar_order = [
    '["road","Road"]',
    '["residential","Residential"]',
    '["commercial","Commercial"]',
    '["industrial","Industrial"]',
    '["services","Services"]',
    '["specializations","Specializations / Park"]',
    '["bulldoze","Bulldoze"]'
]
positions = [hud.find(entry) for entry in toolbar_order]
if any(position < 0 for position in positions) or positions != sorted(positions):
    errors.append("Right toolbar categories are missing or not in the required order")
