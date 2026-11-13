from pathlib import Path
import re
import sys
import struct

ROOT = Path(__file__).resolve().parents[1]
errors = []

for path in ROOT.rglob("*.gd"):
    source = path.read_text(encoding="utf-8")
    if source.rstrip().endswith(("extends Node3D", "extends Node", "mat = mate")):
        errors.append(f"Likely truncated script: {path.relative_to(ROOT)}")
    for resource in re.findall(r'"res://([^" ]+)"', source):
        if resource.endswith("/"):
            continue
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
service_manager_source = (ROOT / "scripts/autoload/ServiceManager.gd").read_text(encoding="utf-8")
happiness_manager_source = (ROOT / "scripts/autoload/HappinessManager.gd").read_text(encoding="utf-8")
gameplay_smoke_source = (ROOT / "tests/GameplaySmoke.gd").read_text(encoding="utf-8")
building_ids = set(re.findall(r'^[ \t]*"([a-z0-9_]+)"[ \t]*:[ \t]*[{]"name"', build_manager, re.M))
for selected in re.findall(r'BuildManager[.]select_building[(]"([a-z0-9_]+)"[)]', hud):
    if selected not in building_ids:
        errors.append(f"HUD references undefined building type: {selected}")
if "commercial_1" in hud:
    errors.append("Obsolete commercial_1 reference remains in HUD")

production = (ROOT / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
# ProductionManager is the single source of truth for item identities. StorageManager
# derives display metadata at startup, so validate upgrade references against the
# authoritative raw/crafted catalog instead of expecting a duplicate storage list.
for item in re.findall(r'"item"[ \t]*:[ \t]*"([a-z0-9_]+)"', production):
    if not re.search(rf'"{re.escape(item)}"[ \t]*:', production):
        errors.append(f"Upgrade material missing from production catalog: {item}")


# The full transparent PNG catalog has a dedicated strict validator in CI.
icons_helper_path = ROOT / "scripts/ui/Icons.gd"
if not icons_helper_path.is_file():
    errors.append("Centralized PNG Icons.gd helper is missing")
else:
    icons_helper = icons_helper_path.read_text(encoding="utf-8")
    for contract in ["const ROOT := \"res://assets/icons/\"", "static func path(", "static func get_tex(", "ResourceLoader.exists(icon_path)", "ui/placeholder.png", "CanvasItem.TEXTURE_FILTER_LINEAR"]:
        if contract not in icons_helper:
            errors.append(f"PNG icon helper contract is missing: {contract}")
placeholder_icon = ROOT / "assets/icons/ui/placeholder.png"
if not placeholder_icon.is_file():
    errors.append("Transparent PNG fallback icon is missing")
if "const Icons = preload(\"res://scripts/ui/Icons.gd\")" not in (ROOT / "scripts/ui/IconAtlas.gd").read_text(encoding="utf-8"):
    errors.append("Legacy IconAtlas facade must delegate to the centralized PNG helper")
if "Color(0.0, 0.0, 0.0, 0.0)" not in hud:
    errors.append("Toolbar buttons must have transparent normal backgrounds")
if "class LevelBadgeVisual extends Control:" not in hud:
    errors.append("Procedural Mayor Level badge renderer is missing")
if 'Icons.make_icon("level"' in hud:
    errors.append("Mayor Level badge must not use the old raster PNG")
for contract in ["draw_circle(center", "draw_arc(center", "level_badge_visual.set_progress("]:
    if contract not in hud:
        errors.append(f"Procedural Mayor Level badge visual contract is missing: {contract}")

toolbar_order = [
    "residential", "commercial", "industrial", "services",
    "specializations", "road", "bulldoze"
]
toolbar_match = re.search(r"var tools := \[(.*?)\n\t\]", hud, re.S)
toolbar_ids = re.findall(r'\["([a-z_]+)",\s*"[^"]+",\s*"[^"]+"\]', toolbar_match.group(1)) if toolbar_match else []
if toolbar_ids != toolbar_order:
    errors.append("Right toolbar categories are missing or not in the required order")
smoke_order = [
    "Tool_Residential", "Tool_Commercial", "Tool_Industrial",
    "Tool_Services", "Tool_Specializations", "Tool_Road", "Tool_Bulldoze"
]
toolbar_smoke = (ROOT / "tests/GameplaySmoke.gd").read_text(encoding="utf-8")
if not all(f'"{name}"' in toolbar_smoke for name in smoke_order):
    errors.append("Gameplay smoke test is missing the canonical right-toolbar category order")

# Side rails and catalog cards must remain transparent in every interaction state.
for contract in [
    'category_scroll.scroll_deadzone = 4',
    'category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO',
    'category_scroll.mouse_filter = Control.MOUSE_FILTER_PASS',
    'submenu_scroll.scroll_deadzone = 4',
    'submenu_scroll.mouse_filter = Control.MOUSE_FILTER_PASS',
    'button.mouse_filter = Control.MOUSE_FILTER_PASS',
    'button.add_theme_stylebox_override(state, StyleBoxEmpty.new())'
]:
    if contract not in hud:
        errors.append(f"Touch/transparent catalog contract is missing: {contract}")
if '_toolbar_style(Color(0.08, 0.16, 0.21, 0.97)' in hud:
    errors.append("Build selection must not apply dark backgrounds to submenu cards")


# Visual-quality contracts: local Build SVGs, hidden roof labels, grounded trees and shared shadows.
building_source = (ROOT / "scripts/buildings/Building.gd").read_text(encoding="utf-8")
# The Building Supplies shop is the first detailed, colour-separated commercial hero asset.
for visual_contract in [
    'if building_type == "building_supplies" or subtype == "building_supplies":',
    "func _build_building_supplies_showcase(",
    "func _add_emissive_box(",
    "Rooftop stock:",
    "Compact rooftop jib crane:",
    "Shelves and colourful product stacks",
    "striped awning",
]:
    if visual_contract not in building_source:
        errors.append(f"Building Supplies visual contract is missing: {visual_contract}")

# Level-one villa visual contract: saturated separated colours and warm emissive windows.
for visual_contract in [
    'if upgrade_stage == 1 and residential_subtype == "villa":',
    "func _build_level_one_villa(",
    "Large warm windows with luminous inner panes",
    "Two-plane pitched roof with saturated red tiles",
    "Emissive wall sconces",
    "Flower boxes, tiny shrubs and a colourful front garden edge",
]:
    if visual_contract not in building_source:
        errors.append(f"Level-one residential villa visual contract is missing: {visual_contract}")

# Art Supplies is a separate gallery-style commercial hero, not the generic shop mesh.
for visual_contract in [
    'if building_type == "art_supplies" or subtype == "art":',
    "func _build_art_supplies_showcase(",
    "Rooftop artist's easel",
    "Framed miniature canvases",
    "Display racks on the side walls",
    "Individual vivid canopy panels",
]:
    if visual_contract not in building_source:
        errors.append(f"Art Supplies visual contract is missing: {visual_contract}")
    if visual_contract not in building_source:
        errors.append(f"Building Supplies visual contract is missing: {visual_contract}")
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
    "services": ("ui", "services"),
    "parks": ("ui", "parks"),
    "park": ("ui", "park"),
    "bulldoze": ("ui", "bulldoze"),
}
for icon_name, (category, icon_id) in build_icon_paths.items():
    icon_path = ROOT / "assets" / "icons" / category / f"{icon_id}.png"
    if not icon_path.is_file():
        errors.append(f"Required Build PNG icon is missing: {category}/{icon_id}.png")
        continue
    icon_data = icon_path.read_bytes()
    if len(icon_data) < 26 or icon_data[:8] != b"\x89PNG\r\n\x1a\n":
        errors.append(f"Required Build icon is not a valid PNG: {category}/{icon_id}.png")
        continue
    bit_depth, color_type = struct.unpack(">BB", icon_data[24:26])
    if bit_depth != 8 or color_type != 6:
        errors.append(f"Required Build icon must be PNG-32 RGBA: {category}/{icon_id}.png")

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
# Long-press building relocation must cover every requested buildable type and keep its core contracts.
build_manager_source = (ROOT / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
city_input_source = (ROOT / "scripts/systems/CityInput.gd").read_text(encoding="utf-8")
hud_source = (ROOT / "scripts/ui/HUD.gd").read_text(encoding="utf-8")
move_building_source = (ROOT / "scripts/buildings/Building.gd").read_text(encoding="utf-8")
required_movable_types = {
    "residential_1", "residential_villa", "residential_apartment", "residential_farm",
    "building_supplies", "shop_chain", "restaurant_traditional", "fast_food",
    "art_supplies", "hardware_store", "farmers_market", "furniture_store",
    "industrial_1", "industrial_2", "industrial_3",
    "power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear",
    "water_tower", "water_pump", "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "sewage_small", "sewage_basic", "sewage_deluxe", "waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling", "town_hall",
    "park_small"
}
move_list_match = re.search(r"const MOVABLE_BUILDING_TYPES := \[(.*?)\]", build_manager_source, re.S)
move_types = set(re.findall(r'"([a-z0-9_]+)"', move_list_match.group(1))) if move_list_match else set()
for type_id in sorted(required_movable_types - move_types):
    errors.append(f"Building type is missing from long-press Move whitelist: {type_id}")
for contract in ["func begin_move(", "func can_move_to(", "func preview_move_at(", "func finish_move(", "func cancel_move(", "func invalidate_move_preview(", "ServiceManager.recalculate_from_buildings()"]:
    if contract not in build_manager_source:
        errors.append(f"Building move contract is missing: {contract}")
for contract in ["LONG_PRESS_SECONDS", "_begin_move_from_screen(", "_update_move_from_screen(", "BuildManager.finish_move()", "BuildManager.cancel_move()"]:
    if contract not in city_input_source:
        errors.append(f"Mouse/touch Move input contract is missing: {contract}")
for contract in ["func set_move_preview(", "func _apply_move_transparency(", "TRANSPARENCY_ALPHA", "position.y = 0.55", "Color(0.20, 1.0, 0.36, 0.95)", "Color(1.0, 0.16, 0.12, 0.95)"]:
    if contract not in move_building_source:
        errors.append(f"Building move highlight contract is missing: {contract}")
if "var was_moving: bool = BuildManager.is_moving" not in hud_source or "BuildManager.cancel_move()" not in hud_source:
    errors.append("HUD Cancel button does not restore a building during Move mode")
gameplay_smoke = (ROOT / "tests/GameplaySmoke.gd").read_text(encoding="utf-8")
for contract in ["Long press on a completed residential building", "Touch release did not commit the valid building move", "Invalid move should not commit", "Cancel did not restore", "Mouse release did not commit the valid building move", "Move whitelist must include all 47"]:
    if contract not in gameplay_smoke:
        errors.append(f"Building move gameplay regression test is missing: {contract}")



# Services menu must expose all eight fixed groups in their prescribed order and every selectable service
# must resolve to a real BuildManager definition with explicit group metadata.
services_hud = hud[hud.find("const SERVICE_GROUPS"):hud.find("const SPECIALIZATION_GROUPS")]
for group_id in ["power", "water", "sewage", "waste", "fire", "police", "health", "government"]:
    if f'"id":"{group_id}"' not in services_hud:
        errors.append(f"Services group is missing or out of order: {group_id}")
for building_id in ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "sewage_small", "sewage_basic", "sewage_deluxe",
                    "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "town_hall"]:
    if f'"{building_id}": {{"name"' not in build_manager:
        errors.append(f"Services menu building definition is missing: {building_id}")
for service_id in ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "sewage_small", "sewage_basic", "sewage_deluxe",
                   "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "clinic_small", "clinic", "hospital", "town_hall"]:
    definition_line = next((line for line in build_manager.splitlines() if f'"{service_id}"' in line), "")
    if '"service_group"' not in definition_line:
        errors.append(f"Service building lacks service_group metadata: {service_id}")
health_contracts = {
    "clinic_small": (10, "Vector2i(2,2)", 14000),
    "clinic": (15, "Vector2i(2,2)", 21000),
    "hospital": (24, "Vector2i(4,2)", 58000),
}
for health_id, (expected_coverage, expected_size, expected_cost) in health_contracts.items():
    match = re.search(r'"' + health_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Health facility definition is missing: {health_id}")
        continue
    definition = match.group(1)
    if f'"coverage_tiles":{expected_coverage}' not in definition or '"level":16' not in definition:
        errors.append(f"Health facility coverage/unlock contract is incorrect: {health_id}")
    if f'"size":{expected_size}' not in definition or f'"cost":{expected_cost}' not in definition:
        errors.append(f"Health facility footprint/cost is incorrect: {health_id}")
    if '"health":1' not in definition or '"service_group":"health"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Health facility must use separate health service metadata: {health_id}")
    if '"fire":' in definition or '"police":' in definition or '"pollution":0' not in definition or '"pollution_radius":0.0' not in definition:
        errors.append(f"Health facility must be distinct from Fire/Police and pollution-free: {health_id}")


# Government is the final Services group and Town Hall is administrative, not an emergency provider.
service_group_section = services_hud
if service_group_section.rfind('"id":"government"') < service_group_section.rfind('"id":"health"'):
    errors.append("Government must be the final Services subgroup")
town_hall_match = re.search(r'"town_hall": \{([^\n]+)\}', build_manager)
if town_hall_match is None:
    errors.append("Town Hall definition is missing")
else:
    town_hall_definition = town_hall_match.group(1)
    if '"government":1' not in town_hall_definition or '"service_group":"government"' not in town_hall_definition:
        errors.append("Town Hall must carry separate government metadata")
    if any(f'"{key}":' in town_hall_definition for key in ["fire", "police", "health", "power", "water"]):
        errors.append("Town Hall must not provide emergency or utility coverage")
    if '"level":1' not in town_hall_definition or '"size":Vector2i(2,2)' not in town_hall_definition:
        errors.append("Town Hall must be available at Level 1 with a 2x2 footprint")

police_contracts = {
    "police_small": (10, "Vector2i(1,1)", 5100),
    "police_basic": (15, "Vector2i(2,2)", 9400),
    "police_precinct": (24, "Vector2i(4,2)", 36000),
}
for police_id, (expected_coverage, expected_size, expected_cost) in police_contracts.items():
    match = re.search(r'"' + police_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Police station definition is missing: {police_id}")
        continue
    definition = match.group(1)
    if f'"coverage_tiles":{expected_coverage}' not in definition or '"level":12' not in definition:
        errors.append(f"Police station coverage/unlock contract is incorrect: {police_id}")
    if f'"size":{expected_size}' not in definition or f'"cost":{expected_cost}' not in definition:
        errors.append(f"Police station footprint/cost is incorrect: {police_id}")
    if '"police":1' not in definition or '"service_group":"police"' not in definition:
        errors.append(f"Police station must use separate police service metadata: {police_id}")
    if '"fire":' in definition or '"health":' in definition or '"pollution":0' not in definition:
        errors.append(f"Police station must be distinct from Fire/Health and pollution-free: {police_id}")

for fire_id in ["fire_station_small", "fire_station", "fire_station_deluxe"]:
    definition_line = next((line for line in build_manager.splitlines() if f'"{fire_id}"' in line), "")
    if '"fire":1' not in definition_line:
        errors.append(f"Fire station must provide fire coverage: {fire_id}")

fire_contracts = {
    "fire_station_small": (10, "Vector2i(1,1)", 3100),
    "fire_station": (15, "Vector2i(2,2)", 5500),
    "fire_station_deluxe": (22, "Vector2i(4,2)", 21000),
}
for fire_id, (expected_coverage, expected_size, expected_cost) in fire_contracts.items():
    match = re.search(r'"' + fire_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Fire station definition is missing: {fire_id}")
        continue
    definition = match.group(1)
    if f'"coverage_tiles":{expected_coverage}' not in definition or f'"level":5' not in definition:
        errors.append(f"Fire station coverage/unlock contract is incorrect: {fire_id}")
    if f'"size":{expected_size}' not in definition or f'"cost":{expected_cost}' not in definition:
        errors.append(f"Fire station footprint/cost is incorrect: {fire_id}")
    if '"service_group":"fire"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Fire station lacks Fire service metadata: {fire_id}")
    if '"pollution":0' not in definition:
        errors.append(f"Fire station must be pollution-free: {fire_id}")
fire_manager_source = (ROOT / "scripts/autoload/FireHazardManager.gd").read_text(encoding="utf-8")
ghost_preview_source = (ROOT / "scripts/systems/GhostPreview.gd").read_text(encoding="utf-8")
for contract in ["func get_coverage_radius_world(", 'definition.get("coverage_tiles", COVERAGE_TILES)', 'int(definition.get("fire", 0)) > 0', "home_flat.distance_to(station_flat) <= station_radius"]:
    if contract not in fire_manager_source:
        errors.append(f"FireHazardManager dynamic coverage contract is missing: {contract}")
for contract in ["EmergencyCoveragePreview", "CoverageArea", "CoverageBoundary", "FireHazardManager.get_coverage_radius_world(definition)", 'int(definition.get("police", 0)) > 0', 'int(definition.get("health", 0)) > 0', "Color(0.18, 0.38, 0.98, 0.95)", "Color(0.20, 0.96, 0.62, 0.96)"]:
    if contract not in ghost_preview_source:
        errors.append(f"Fire placement coverage preview contract is missing: {contract}")

for contract in [
    'service_group == "sewage"',
    'service_group == "waste"',
    "HappinessManager.SEWAGE_COVERAGE_RADIUS",
    "HappinessManager.WASTE_COVERAGE_RADIUS",
    "Color(0.68, 0.76, 0.36, 0.96)",
    "Color(1.0, 0.58, 0.16, 0.96)",
]:
    if contract not in ghost_preview_source:
        errors.append(f"Sewage/Waste placement coverage preview contract is missing: {contract}")
for contract in [
    "var sewage_preview: Dictionary",
    "var waste_preview: Dictionary",
    "Sewage preview radius must match its happiness coverage radius",
    "Waste preview radius must match its happiness coverage radius",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Sewage/Waste coverage preview regression test is missing: {contract}")
if city_input_source.count("BuildManager.building_types.get(BuildManager.selected_building_type, {})") < 2:
    errors.append("CityInput must pass selected building metadata to both placement preview paths")

for water_id, expected_water, expected_level, expected_size in [("water_tower", 12, 1, "Vector2i(1,1)"), ("water_pump", 55, 12, "Vector2i(2,3)")]:
    match = re.search(r'"' + water_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Water facility definition is missing: {water_id}")
        continue
    definition = match.group(1)
    if f'"water":{expected_water}' not in definition or f'"level":{expected_level}' not in definition:
        errors.append(f"Water facility production/unlock contract is incorrect: {water_id}")
    if '"service_group":"water"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Water facility lacks service catalog metadata: {water_id}")
    if f'"size":{expected_size}' not in definition:
        errors.append(f"Water facility footprint is incorrect: {water_id}")
    if '"pollution":0' not in definition:
        errors.append(f"Water facility must not add air pollution: {water_id}")
if 'definition.get("water", 0)' not in service_manager_source:
    errors.append("ServiceManager must identify water providers by positive definition.water, not by building name")

# Sewage facilities are separate catalog entries with generic numeric capacity metadata.
for sewage_id, expected_capacity, expected_level, expected_size, expected_pollution, expected_radius in [
    ("sewage_small", 7, 8, "Vector2i(1,1)", 1, "10.0"),
    ("sewage_basic", 28, 8, "Vector2i(2,2)", 1, "12.0"),
    ("sewage_deluxe", 55, 14, "Vector2i(2,3)", 0, "0.0"),
]:
    match = re.search(r'"' + sewage_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Sewage facility definition is missing: {sewage_id}")
        continue
    definition = match.group(1)
    if f'"sewage":{expected_capacity}' not in definition or f'"level":{expected_level}' not in definition:
        errors.append(f"Sewage facility capacity/unlock contract is incorrect: {sewage_id}")
    if '"service_group":"sewage"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Sewage facility lacks separate service catalog metadata: {sewage_id}")
    if f'"size":{expected_size}' not in definition:
        errors.append(f"Sewage facility footprint is incorrect: {sewage_id}")
    if f'"pollution":{expected_pollution}' not in definition or f'"pollution_radius":{expected_radius}' not in definition:
        errors.append(f"Sewage facility pollution metadata is incorrect: {sewage_id}")
if '"sewage_pipe":' in build_manager or '"sewage_pipe"' in hud or '"sewage_pipe"' in happiness_manager_source:
    errors.append("Obsolete sewage_pipe ID must not remain in building, HUD or happiness logic")
for contract in [
    'const SEWAGE_SERVICE_IDS := ["sewage_small", "sewage_basic", "sewage_deluxe"]',
    "func _nearby_sewage_service(",
    "_nearby_sewage_service(home, 30.0)",
]:
    if contract not in happiness_manager_source:
        errors.append(f"Sewage happiness coverage contract is missing: {contract}")
for contract in [
    "func _test_sewage_service_happiness()",
    "Each sewage catalog tier must add the existing +6 happiness bonus",
    "outside the 30-unit radius",
    "under construction",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Sewage gameplay regression test is missing: {contract}")

# Every Fire, Police and Health catalog tier must feed the same service-group
# happiness lookup; checking only a single legacy building ID misses valid tiers.
for service_group, service_ids in {
    "fire": ["fire_station_small", "fire_station", "fire_station_deluxe"],
    "police": ["police_station", "police_small", "police_basic", "police_precinct"],
    "health": ["clinic_small", "clinic", "hospital"],
}.items():
    for service_id in service_ids:
        match = re.search(r'"' + service_id + r'": \{([^\n]+)\}', build_manager)
        if match is None or f'"service_group":"{service_group}"' not in match.group(1):
            errors.append(f"{service_group} service tier is missing its catalog group: {service_id}")
for contract in [
    "func _nearby_service_group(",
    '_nearby_service_group(home, FIRE_SERVICE_GROUP, 38.0)',
    '_nearby_service_group(home, POLICE_SERVICE_GROUP, 38.0)',
    '_nearby_service_group(home, HEALTH_SERVICE_GROUP, 42.0)',
]:
    if contract not in happiness_manager_source:
        errors.append(f"Emergency service-group happiness contract is missing: {contract}")
for contract in [
    "func _test_emergency_service_tier_happiness()",
    "Every completed emergency service tier must provide its existing happiness bonus",
    "outside its service radius",
    "under construction",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Emergency service-tier regression test is missing: {contract}")

# Solid-waste facilities remain distinct from sewage and expose generic numeric capacity.
for waste_id, expected_capacity, expected_level, expected_size, expected_pollution, expected_radius in [
    ("waste_dump_small", 15, 14, "Vector2i(2,2)", 1, "10.0"),
    ("waste_dump", 31, 14, "Vector2i(2,3)", 1, "12.0"),
    ("waste_incinerator", 40, 14, "Vector2i(2,2)", 1, "16.0"),
    ("waste_recycling", 70, 20, "Vector2i(3,2)", 0, "0.0"),
]:
    match = re.search(r'"' + waste_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Waste facility definition is missing: {waste_id}")
        continue
    definition = match.group(1)
    if f'"waste":{expected_capacity}' not in definition or f'"level":{expected_level}' not in definition:
        errors.append(f"Waste facility capacity/unlock contract is incorrect: {waste_id}")
    if '"service_group":"waste"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Waste facility lacks separate service catalog metadata: {waste_id}")
    if f'"size":{expected_size}' not in definition:
        errors.append(f"Waste facility footprint is incorrect: {waste_id}")
    if f'"pollution":{expected_pollution}' not in definition or f'"pollution_radius":{expected_radius}' not in definition:
        errors.append(f"Waste facility pollution metadata is incorrect: {waste_id}")
if '"pollution_severity":"heavy"' not in build_manager or '"pollution_label":"Heavy pollution"' not in build_manager:
    errors.append("Incinerator must carry an explicit heavy-pollution UI label")
if '"waste_omega":' in build_manager:
    errors.append("OMEGA waste facility is outside the current scope and must not be exposed")
for contract in [
    'const WASTE_SERVICE_GROUP := "waste"',
    "func _nearby_waste_service(",
    "_nearby_waste_service(home, 30.0)",
]:
    if contract not in happiness_manager_source:
        errors.append(f"Waste happiness coverage contract is missing: {contract}")
for contract in [
    "func _test_waste_service_happiness()",
    "Each Waste catalog tier must add the existing +6 Mshin service happiness bonus",
    "outside the 30-unit radius",
    "under construction",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Waste gameplay regression test is missing: {contract}")


for power_id, expected_power, expected_level in [("power_wind", 12, 1), ("power_coal", 12, 1), ("power_wind_deluxe", 22, 10), ("power_solar", 35, 15), ("power_oil", 40, 18), ("power_nuclear", 60, 22)]:
    match = re.search(r'"' + power_id + r'": \{([^\n]+)\}', build_manager)
    if match is None:
        errors.append(f"Power plant definition is missing: {power_id}")
        continue
    definition = match.group(1)
    if f'"power":{expected_power}' not in definition or f'"level":{expected_level}' not in definition:
        errors.append(f"Power plant production/unlock contract is incorrect: {power_id}")
    if '"service_group":"power"' not in definition or '"category":"service"' not in definition:
        errors.append(f"Power plant lacks service catalog metadata: {power_id}")
    if '"size":Vector2i(' not in definition:
        errors.append(f"Power plant footprint is missing: {power_id}")
for polluting_id in ["power_coal", "power_oil", "power_nuclear"]:
    line = next((line for line in build_manager.splitlines() if f'"{polluting_id}"' in line), "")
    if '"pollution":1' not in line or '"pollution_radius":' not in line:
        errors.append(f"Polluting power plant needs pollution and radius metadata: {polluting_id}")

if errors:
    print("VALIDATION FAILED")
    for error in errors:
        print(error)
    sys.exit(1)

print("Static project and icon-atlas validation passed.")

# Fire hazard coverage and web-safe black-smoke particle contracts.
fire_manager_path = ROOT / "scripts/autoload/FireHazardManager.gd"
if not fire_manager_path.is_file():
    errors.append("FireHazardManager autoload script is missing")
else:
    fire_manager = fire_manager_path.read_text(encoding="utf-8")
    for contract in [
        "WARNING_DELAY: float = 20.0", "COVERAGE_TILES: int = 15",
        "BuildManager.GRID_SIZE", "global_position.distance_to",
        'definition.get("fire", 0)', "func on_city_changed(",
        "func _evaluate_hazards(", "func reset_for_city_load(", "smoking_ids"
    ]:
        if contract not in fire_manager:
            errors.append(f"Fire hazard manager contract is missing: {contract}")
if 'FireHazardManager="*res://scripts/autoload/FireHazardManager.gd"' not in project:
    errors.append("FireHazardManager is not registered as an autoload")
if '"fire":1' not in build_manager:
    errors.append("Fire Station definition must expose the numeric fire coverage key")
save_manager_source = (ROOT / "scripts/autoload/SaveManager.gd").read_text(encoding="utf-8")
if "FireHazardManager.reset_for_city_load()" not in save_manager_source:
    errors.append("City load must restart fire warning timers from zero")
if "func set_fire_smoke(active: bool)" not in building_source or "CPUParticles3D.new()" not in building_source:
    errors.append("Building must expose the web-compatible black smoke particle API")
for fire_test in [
    "must not smoke before 20 seconds", "must start smoking after 20 seconds",
    "exactly 15 tiles away", "full 20-second warning timer",
    "Homes still under construction", "all fire hazard state cleared"
]:
    if fire_test not in gameplay_smoke:
        errors.append(f"Fire hazard gameplay regression test is missing: {fire_test}")
