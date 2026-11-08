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


# Validate all three local UI sprite sheets and their atlas references.
import struct

atlas_path = ROOT / "scripts/ui/IconAtlas.gd"
atlas = atlas_path.read_text(encoding="utf-8")
expected_sheets = [ROOT / "assets/icons/Sheet1.png", ROOT / "assets/icons/Sheet2.png", ROOT / "assets/icons/Sheet3.png"]
for sheet_index, sheet_path in enumerate(expected_sheets, start=1):
    if not sheet_path.is_file():
        errors.append(f"Missing local icon sheet {sheet_path.relative_to(ROOT)}")
        continue
    data = sheet_path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        errors.append(f"Icon sheet {sheet_path.name} is not a valid PNG")
        continue
    width, height = struct.unpack(">II", data[16:24])
    if width < 1130 or height < 770:
        errors.append(f"Icon sheet {sheet_path.name} has unexpected dimensions {width}x{height}")
    if f'{sheet_index}: preload("res://assets/icons/{sheet_path.name}")' not in atlas:
        errors.append(f"Icon sheet {sheet_path.name} is not preloaded by IconAtlas.gd")

if "CanvasItem.TEXTURE_FILTER_LINEAR" not in atlas:
    errors.append("UI atlas icons must use high-quality linear filtering")
if "TEXTURE_FILTER_LINEAR_WITH_MIPMAPS" in atlas or "mipmaps" in atlas.lower() and "no mipmaps" not in atlas.lower():
    errors.append("UI atlas icons must not generate or sample mipmaps")
if "ImageTexture.create_from_image" not in atlas:
    errors.append("UI atlas icons must be rebuilt as lossless runtime ImageTextures")
if "color.a = 0.0" not in atlas or "crop.set_pixel" not in atlas:
    errors.append("UI atlas background removal must write transparent alpha pixels")
if "Color(0.0, 0.0, 0.0, 0.0)" not in hud:
    errors.append("Toolbar buttons must have transparent normal backgrounds")

power_svg = ROOT / "assets/icons/power.svg"
if not power_svg.is_file():
    errors.append("Transparent local vector power icon is missing")
elif "res://assets/icons/power.svg" not in atlas:
    errors.append("HUD power icon is not mapped to the transparent local vector asset")

atlas_keys = set(re.findall(r'"([a-z0-9_]+)": \[\d+, Rect2i', atlas))
required_icons = {
    "road", "residential", "commercial", "industrial", "services",
    "bulldoze", "power", "water", "fire", "parks",
    "storage", "trade", "save", "cancel", "education", "transportation",
    "entertainment", "gambling", "beach", "mountain", "landmark",
    "trade_depot", "global_trade", "epic", "regions"
}
for icon_key in sorted(required_icons - atlas_keys):
    errors.append(f"Required HUD icon is missing from atlas: {icon_key}")

toolbar_order = [
    '["road", "Road", "road"]',
    '["residential", "Residential", "residential"]',
    '["commercial", "Commercial", "commercial"]',
    '["industrial", "Industrial", "industrial"]',
    '["services", "Services", "services"]',
    '["park", "Park", "parks"]',
    '["bulldoze", "Bulldozer", "bulldoze"]'
]
positions = [hud.find(entry) for entry in toolbar_order]
if any(position < 0 for position in positions) or positions != sorted(positions):
    errors.append("Right toolbar categories are missing or not in the required order")


# Visual-quality contracts: local Build SVGs, hidden roof labels, grounded trees and shared shadows.
building_source = (ROOT / "scripts/buildings/Building.gd").read_text(encoding="utf-8")
if "stage_label.visible = false" not in building_source or 'stage_label.text = ""' not in building_source:
    errors.append("Floating building stage labels must remain hidden and empty")
label_update = re.search(r"func _update_stage_label\(\).*?(?=\nfunc |\Z)", building_source, re.S)
if label_update is None or "visible = false" not in label_update.group(0):
    errors.append("Building stage-label updater can expose a floating Lv label")

world_source = (ROOT / "scripts/world/WorldPresentation.gd").read_text(encoding="utf-8")
for visual_contract in [
    "TreeContactShadows", "_create_tree_shadow_multimesh",
    "_create_bark_texture", "_create_foliage_texture",
    "SHADOW_CASTING_SETTING_ON", "sun.shadow_enabled = true",
    "sun.shadow_blur = 1.0"
]:
    if visual_contract not in world_source:
        errors.append(f"World visual contract is missing: {visual_contract}")
if "Vector3(0.0, 0.018, 0.0)" not in world_source:
    errors.append("Tree contact shadows are not anchored immediately above the terrain")
if "multimesh.use_colors = true" not in world_source:
    errors.append("Tree instances must use per-instance natural color variation")

build_icon_paths = {
    "services": "assets/icons/services.svg",
    "parks": "assets/icons/parks.svg",
    "park": "assets/icons/park.svg",
    "bulldoze": "assets/icons/bulldozer.svg",
}
for icon_name, relative_path in build_icon_paths.items():
    icon_path = ROOT / relative_path
    if not icon_path.is_file():
        errors.append(f"Required Build icon is missing: {relative_path}")
        continue
    icon_source = icon_path.read_text(encoding="utf-8")
    if not all(token in icon_source for token in ['viewBox="0 0 128 128"', "<linearGradient", "<ellipse", "stroke-width="]):
        errors.append(f"Build icon does not follow the shared dimensional gradient illustration style: {icon_name}")
    if "<rect" in icon_source and re.search(r'<rect[^>]+fill="#[0-9A-Fa-f]{6}"', icon_source):
        errors.append(f"Build icon contains an opaque rectangular background: {icon_name}")
    if "res://assets/icons/" + Path(relative_path).name not in atlas:
        errors.append(f"Build icon is not directly mapped to its local SVG: {icon_name}")

# Road rendering must be neighbor-driven, connected, seamless and independent from gameplay rules.
road_source = (ROOT / "scripts/systems/RoadSystem.gd").read_text(encoding="utf-8")
for road_contract in [
    "func get_road_connections(", "func get_road_tile_kind(",
    "TILE_END", "TILE_STRAIGHT", "TILE_CORNER", "TILE_T", "TILE_CROSS",
    "func _refresh_road_neighborhood(", "func _refresh_road_mesh(",
    "func _create_road_mesh(", "SurfaceTool.new()", "ArrayMesh.new()",
    "func _create_asphalt_textures(", "normal_enabled = true",
    "ROAD_TEXTURE_WORLD_SCALE", "func _add_road_markings(",
    "func _add_crosswalk(", "func _get_sidewalk_material(",
    "func _get_curb_material(", "road_placed.emit(grid_pos)",
    "road_removed.emit(grid_pos)", "EconomyManager.spend_simoleons(ROAD_COST)",
    "func get_road_placement_error("
]:
    if road_contract not in road_source:
        errors.append(f"Road visual/gameplay contract is missing: {road_contract}")
if "BoxMesh.new()" in road_source or "line_mesh" in road_source:
    errors.append("Road tiles must use the combined neighbor-driven mesh, not isolated BoxMesh strips")
if "func _refresh_road_neighborhood" in road_source:
    refresh_body = re.search(r"func _refresh_road_neighborhood\(.*?(?=\nfunc |\Z)", road_source, re.S)
    if refresh_body is None or "CARDINAL_DIRECTIONS" not in refresh_body.group(0):
        errors.append("Placing/removing a road must refresh all four neighboring road meshes")
if "func _create_asphalt_textures" in road_source:
    asphalt_body = re.search(r"func _create_asphalt_textures\(.*?(?=\nfunc |\Z)", road_source, re.S)
    if asphalt_body is None or "normal_image" not in asphalt_body.group(0) or "fine_grain" not in asphalt_body.group(0) or "image.generate_mipmaps()" not in asphalt_body.group(0) or "normal_image.generate_mipmaps()" not in asphalt_body.group(0):
        errors.append("Asphalt must include natural grain variation and a generated normal map")
gameplay_smoke = (ROOT / "tests/GameplaySmoke.gd").read_text(encoding="utf-8")
for road_test in [
    "three-neighbor starter-road tile", "must be an End/stub",
    "must produce a Straight tile", "must produce a T-junction",
    "must produce a Cross intersection", "refresh the center to Corner",
    "mesh was not refreshed after deleting the connecting road",
    "Road placement must retain the existing 50-Simoleon cost"
]:
    if road_test not in gameplay_smoke:
        errors.append(f"Road auto-tiling regression test is missing: {road_test}")


if errors:
    print("VALIDATION FAILED")
    for error in errors:
        print(error)
    sys.exit(1)

print("Static project and icon-atlas validation passed.")
