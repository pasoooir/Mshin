from pathlib import Path
import base64
import json
import re
import sys
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
errors = []

def _resource_paths_from_load_calls(source: str) -> list[str]:
    """Return only literal project paths used by Godot resource-loading calls."""
    pattern = r'\b(?:preload|load|load_threaded_request)\s*\(\s*["\']res://([^"\']+)["\']'
    return re.findall(pattern, source)


def _test_resource_path_scanner() -> None:
    # Regression: res:// strings used as API/test inputs are not dependencies.
    fixture = '''
    const VALID := preload("res://scripts/example.gd")
    var loaded = load("res://scenes/example.tscn")
    ResourceLoader.load("res://assets/models/example.glb")
    BuildingModelLoader.is_supported_model_path("res://assets/models/missing.glb")
    BuildingModelLoader.is_supported_model_path("res://assets/models/../outside.glb")
    '''
    expected = ["scripts/example.gd", "scenes/example.tscn", "assets/models/example.glb"]
    actual = _resource_paths_from_load_calls(fixture)
    if actual != expected:
        raise AssertionError(f"Resource-load scanner regression: expected {expected}, got {actual}")


_test_resource_path_scanner()


def _validate_embedded_gltf(path: Path) -> None:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"Invalid GLTF JSON {path.relative_to(ROOT)}: {error}")
        return

    buffers = document.get("buffers", [])
    if len(buffers) != 1:
        errors.append(f"GLTF must use one self-contained buffer: {path.relative_to(ROOT)}")
        return
    uri = buffers[0].get("uri", "")
    if not uri.startswith("data:application/octet-stream;base64,"):
        errors.append(f"GLTF buffer must be embedded Base64: {path.relative_to(ROOT)}")
        return
    try:
        binary = base64.b64decode(uri.split(",", 1)[1], validate=True)
    except (ValueError, base64.binascii.Error) as error:
        errors.append(f"Invalid embedded GLTF buffer {path.relative_to(ROOT)}: {error}")
        return
    if len(binary) != int(buffers[0].get("byteLength", -1)):
        errors.append(f"GLTF buffer length mismatch: {path.relative_to(ROOT)}")

    for view in document.get("bufferViews", []):
        start = int(view.get("byteOffset", 0))
        length = int(view.get("byteLength", -1))
        if view.get("buffer") != 0 or start < 0 or length < 0 or start + length > len(binary):
            errors.append(f"Invalid GLTF bufferView: {path.relative_to(ROOT)}")
            break

    for accessor in document.get("accessors", []):
        view_index = int(accessor.get("bufferView", -1))
        if view_index < 0 or view_index >= len(document.get("bufferViews", [])):
            errors.append(f"Invalid GLTF accessor bufferView: {path.relative_to(ROOT)}")
            break

    textures = document.get("textures", [])
    images = document.get("images", [])
    for image in images:
        image_uri = image.get("uri", "")
        if not image_uri.startswith("data:image/png;base64,"):
            errors.append(f"GLTF image must be embedded PNG: {path.relative_to(ROOT)}")
            continue
        try:
            png = base64.b64decode(image_uri.split(",", 1)[1], validate=True)
        except (ValueError, base64.binascii.Error) as error:
            errors.append(f"Invalid embedded PNG {path.relative_to(ROOT)}: {error}")
            continue
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            errors.append(f"Invalid PNG signature in {path.relative_to(ROOT)}")
            continue
        offset = 8
        saw_iend = False
        while offset + 12 <= len(png):
            chunk_length = struct.unpack(">I", png[offset:offset + 4])[0]
            chunk_type = png[offset + 4:offset + 8]
            chunk_end = offset + 12 + chunk_length
            if chunk_end > len(png):
                errors.append(f"Truncated PNG chunk in {path.relative_to(ROOT)}")
                break
            chunk_data = png[offset + 8:offset + 8 + chunk_length]
            expected_crc = struct.unpack(">I", png[offset + 8 + chunk_length:chunk_end])[0]
            if zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF != expected_crc:
                errors.append(f"PNG CRC mismatch in {path.relative_to(ROOT)}")
                break
            offset = chunk_end
            if chunk_type == b"IEND":
                saw_iend = True
                break
        if not saw_iend:
            errors.append(f"PNG IEND chunk missing in {path.relative_to(ROOT)}")

    for material in document.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        for texture_info in [pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"), material.get("normalTexture")]:
            if texture_info is None or int(texture_info.get("index", -1)) not in range(len(textures)):
                errors.append(f"GLTF material is missing a valid PBR texture reference: {path.relative_to(ROOT)}")
                break
    for texture in textures:
        source = int(texture.get("source", -1))
        if source not in range(len(images)):
            errors.append(f"GLTF texture source is invalid: {path.relative_to(ROOT)}")

    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            required = ["POSITION", "NORMAL", "TEXCOORD_0"]
            if any(key not in attributes for key in required):
                errors.append(f"GLTF primitive is missing position/normal/UV data: {path.relative_to(ROOT)}")
                continue
            for key in required:
                index = int(attributes[key])
                if index < 0 or index >= len(document.get("accessors", [])):
                    errors.append(f"GLTF primitive accessor is invalid ({key}): {path.relative_to(ROOT)}")
                    break
            if int(primitive.get("material", -1)) not in range(len(document.get("materials", []))):
                errors.append(f"GLTF primitive material is invalid: {path.relative_to(ROOT)}")

    # Keep the recorded physical dimensions tied to the actual position accessor bounds.
    position_accessors = []
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            position_index = primitive.get("attributes", {}).get("POSITION")
            if position_index is not None and int(position_index) in range(len(document.get("accessors", []))):
                position_accessors.append(document["accessors"][int(position_index)])
    extras = document.get("asset", {}).get("extras", {})
    recorded = extras.get("dimensions_m", {})
    if position_accessors:
        measured_min = [min(float(item["min"][axis]) for item in position_accessors) for axis in range(3)]
        measured_max = [max(float(item["max"][axis]) for item in position_accessors) for axis in range(3)]
        measured = {
            "width": measured_max[0] - measured_min[0],
            "height": measured_max[1] - measured_min[1],
            "depth": measured_max[2] - measured_min[2],
        }
        for dimension, value in measured.items():
            if dimension not in recorded or abs(float(recorded[dimension]) - value) > 0.01:
                errors.append(f"GLTF measured {dimension} does not match asset metadata: {path.relative_to(ROOT)}")
    if extras.get("license") != "CC0-1.0":
        errors.append(f"GLTF asset license metadata is missing or incorrect: {path.relative_to(ROOT)}")


for gltf_path in (ROOT / "assets/models").rglob("*.gltf"):
    _validate_embedded_gltf(gltf_path)

for path in ROOT.rglob("*.gd"):
    source = path.read_text(encoding="utf-8")
    if source.rstrip().endswith(("extends Node3D", "extends Node", "mat = mate")):
        errors.append(f"Likely truncated script: {path.relative_to(ROOT)}")
    # Only validate paths passed to actual Godot resource-loading calls.
    # Arbitrary res:// strings are also used as test inputs (including deliberately
    # missing/traversal paths) and must not be mistaken for project dependencies.
    for resource in _resource_paths_from_load_calls(source):
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
if not re.search(r"(?m)^textures/vram_compression/import_etc2_astc=true\\s*$", project):
    errors.append("Android export requires ETC2/ASTC texture import to be enabled in project.godot")
for script in re.findall(r'="[*]res://([^"]+)"', project):
    if not (ROOT / script).is_file():
        errors.append(f"Missing autoload {script}")

build_manager = (ROOT / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/ui/HUD.gd").read_text(encoding="utf-8")
city_input_source = (ROOT / "scripts/systems/CityInput.gd").read_text(encoding="utf-8")
service_manager_source = (ROOT / "scripts/autoload/ServiceManager.gd").read_text(encoding="utf-8")
traffic_manager_source = (ROOT / "scripts/autoload/TrafficManager.gd").read_text(encoding="utf-8")
traffic_vehicle_source = (ROOT / "scripts/systems/TrafficVehicle.gd").read_text(encoding="utf-8")
road_system_source = (ROOT / "scripts/systems/RoadSystem.gd").read_text(encoding="utf-8")
happiness_manager_source = (ROOT / "scripts/autoload/HappinessManager.gd").read_text(encoding="utf-8")
gameplay_smoke_source = (ROOT / "tests/GameplaySmoke.gd").read_text(encoding="utf-8")
haptics_manager_source = (ROOT / "scripts/autoload/HapticsManager.gd").read_text(encoding="utf-8")
production_component_source = (ROOT / "scripts/production/ProductionComponent.gd").read_text(encoding="utf-8")
trade_manager_source = (ROOT / "scripts/autoload/TradeManager.gd").read_text(encoding="utf-8")
world_presentation_source = (ROOT / "scripts/world/WorldPresentation.gd").read_text(encoding="utf-8")
cargo_ship_visual_source = (ROOT / "scripts/world/CargoShipVisual.gd").read_text(encoding="utf-8")
citizen_feedback_source = (ROOT / "scripts/ui/CitizenFeedbackBubbles.gd").read_text(encoding="utf-8")
epic_project_manager_source = (ROOT / "scripts/autoload/EpicProjectManager.gd").read_text(encoding="utf-8")
achievement_manager_source = (ROOT / "scripts/autoload/AchievementManager.gd").read_text(encoding="utf-8")
region_manager_source = (ROOT / "scripts/autoload/RegionManager.gd").read_text(encoding="utf-8")
save_manager_source = (ROOT / "scripts/autoload/SaveManager.gd").read_text(encoding="utf-8")

for contract in [
    "func pulse_for(event_name: String) -> bool:",
    "JavaScriptBridge.eval",
    "navigator.vibrate",
    "PLACE_DURATION_MS := 18",
    "COLLECT_DURATION_MS := 26",
    "duration_ms <= 0",
]:
    if contract not in haptics_manager_source:
        errors.append(f"Mobile Web haptics contract is missing: {contract}")
if 'HapticsManager="*res://scripts/autoload/HapticsManager.gd"' not in project:
    errors.append("HapticsManager is not registered as an autoload")
if 'HapticsManager.pulse_for("place")' not in city_input_source:
    errors.append("Successful building placement must trigger optional haptic feedback")
if 'HapticsManager.pulse_for("collect")' not in production_component_source:
    errors.append("Successful product collection must trigger optional haptic feedback")
for contract in [
    "func _test_mobile_haptics_contract()",
    "must use the short 18 ms haptic pulse",
    "must use the 26 ms haptic pulse",
    "zero-duration haptic request must be rejected safely",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Mobile haptics regression test is missing: {contract}")
for contract in [
    "func is_depot_operational() -> bool:",
    "func is_global_trade_operational() -> bool:",
    "func list_for_sale(item_id: String, amount: int = 1) -> bool:",
    "func collect_sale(slot_index: int) -> bool:",
    "func buy_global_offer(offer_index: int) -> bool:",
    "var market_refresh_unix: int = 0",
    "var ship_return_unix: int = 0",
    '"finish_unix": int(Time.get_unix_time_from_system()) + int(SELL_LISTING_SECONDS)',
    "market_refresh_unix = now + int(MARKET_REFRESH_SECONDS)",
    "ship_return_unix = int(Time.get_unix_time_from_system()) + int(SHIP_RETURN_SECONDS)",
    "func to_save_dict() -> Dictionary:",
    "func from_save_dict(data: Dictionary) -> void:",
    '"ready": false',
    '"sold": false',
]:
    if contract not in trade_manager_source:
        errors.append(f"Trade system core contract is missing: {contract}")
if '"trade_depot":' not in build_manager or '"global_trade_hq":' not in build_manager:
    errors.append("Trade Depot and Global Trade HQ building definitions are required")
for contract in [
    "func get_population_build_lock_reason(type_id: String) -> String:",
    '"population_required":8000',
    '"population_required":10000',
]:
    if contract not in build_manager:
        errors.append(f"Trade building population gate is missing: {contract}")
if 'HapticsManager="*res://scripts/autoload/HapticsManager.gd"' not in project:
    errors.append("HapticsManager autoload is missing")
if 'TradeManager="*res://scripts/autoload/TradeManager.gd"' not in project:
    errors.append("TradeManager autoload is missing")
for contract in [
    "func open_trade_panel(tab: String = \"depot\") -> void:",
    "func _build_trade_depot_content(parent: VBoxContainer) -> void:",
    "func _build_global_trade_content(parent: VBoxContainer) -> void:",
    "live player-to-player trading is not connected",
]:
    if contract not in hud:
        errors.append(f"Trade HUD contract is missing: {contract}")
if 'open_trade_panel(trade_role)' not in city_input_source:
    errors.append("Trade buildings must open their matching trade panel")
if "TradeManager.to_save_dict()" not in save_manager_source or 'TradeManager.from_save_dict(parsed.get("trade", {}))' not in save_manager_source:
    errors.append("Trade Depot and Global Trade state must be persisted and restored")
for contract in [
    "func is_cargo_ship_operational() -> bool:",
    "func deliver_ship_crate(crate_index: int) -> bool:",
    "func _generate_ship_manifest() -> void:",
    "SHIP_CRATE_COUNT := 3",
    "SHIP_RETURN_SECONDS := 180.0",
    "EconomyManager.add_keys(1)",
    '"ship_crates": ship_crates.duplicate(true)',
    '"ship_departed": ship_departed',
]:
    if contract not in trade_manager_source:
        errors.append(f"Cargo Ship delivery contract is missing: {contract}")
if '"cargo_port": {"name":"Cargo Port"' not in build_manager or '"population_required":20000' not in build_manager:
    errors.append("Cargo Port must be a placeable 20,000-population trade building")
if '20000: "cargo_ship"' not in (ROOT / "scripts/autoload/LevelProgression.gd").read_text(encoding="utf-8"):
    errors.append("Cargo Ship 20,000 population milestone is missing")
if "CargoShipVisualScript" not in world_presentation_source or "CargoShipVisual" not in world_presentation_source:
    errors.append("WorldPresentation must include the visible cargo ship")
if 'EpicProjectManager="*res://scripts/autoload/EpicProjectManager.gd"' not in project:
    errors.append("EpicProjectManager must be registered as an autoload")
for contract in [
    "PROJECT_UNLOCK_LEVEL := 24",
    "PROJECT_DURATION_SECONDS := 86400",
    "TOKEN_PART_INTERVAL_SECONDS := 86400",
    "EPIC_POPULATION_MULTIPLIER := 1.31",
    "TIER_THRESHOLDS :=",
    "func start_project(building_id: String) -> bool:",
    "func contribute_to_task(task_id: String) -> bool:",
    "func claim_project() -> bool:",
    "func collect_token_part(building_id: String) -> bool:",
    "func to_save_dict() -> Dictionary:",
    "func from_save_dict(data: Dictionary) -> void:",
]:
    if contract not in epic_project_manager_source:
        errors.append(f"Epic Project manager contract is missing: {contract}")
if '"epic_projects_department": {"name":"Department of Epic Projects"' not in build_manager:
    errors.append("Department of Epic Projects building definition is missing")
if '16: {"materials": ["paint", "table"], "services": ["health"], "buildings": ["epic_projects_department"]}' not in (ROOT / "scripts/autoload/LevelProgression.gd").read_text(encoding="utf-8"):
    errors.append("Department of Epic Projects must unlock at Level 16")
if '24: {"factories": 8, "other": ["epic_projects"]}' not in (ROOT / "scripts/autoload/LevelProgression.gd").read_text(encoding="utf-8"):
    errors.append("Epic Projects must unlock at Level 24")
if "func set_epic_tier(tier: int) -> void:" not in (ROOT / "scripts/buildings/Building.gd").read_text(encoding="utf-8"):
    errors.append("Building must persist and render its Epic tier")
if "EpicProjectManager.EPIC_POPULATION_MULTIPLIER" not in happiness_manager_source:
    errors.append("Epic Buildings must increase residential capacity by the Epic multiplier")
if 'AchievementManager="*res://scripts/autoload/AchievementManager.gd"' not in project:
    errors.append("AchievementManager must be registered as an autoload")
for contract in [
    "signal achievement_unlocked(id: String, title: String, simoleons_reward: int, xp_reward: int)",
    "func _collect_metrics() -> Dictionary:",
    "func _check_achievements() -> void:",
    "func get_entries() -> Array[Dictionary]:",
    "func to_save_dict() -> Dictionary:",
    "func from_save_dict(data: Dictionary) -> void:",
    '"id":"cargo_captain"',
    '"id":"epic_master"',
]:
    if contract not in achievement_manager_source:
        errors.append(f"Achievement manager contract is missing: {contract}")
if "AchievementManager.to_save_dict()" not in save_manager_source or 'AchievementManager.from_save_dict(parsed.get("achievements", {}))' not in save_manager_source:
    errors.append("Achievement progress must be saved and restored")
for contract in [
    "AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)",
    "AchievementManager.state_changed.connect(_on_achievement_state_changed)",
    "func open_achievements_panel() -> void:",
    "func _on_achievements_pressed() -> void:",
    "AchievementManager.get_entries()",
]:
    if contract not in hud:
        errors.append(f"Achievement HUD contract is missing: {contract}")
for contract in [
    "var completed_sales: int = 0",
    "var market_purchases: int = 0",
    "completed_sales += 1",
    "market_purchases += 1",
]:
    if contract not in trade_manager_source:
        errors.append(f"Trade achievement counter contract is missing: {contract}")
for contract in [
    "func _test_achievements() -> void:",
    "Achievement should unlock from its real city metric",
    "Achievement unlocks must survive save/load",
    "A collected sale must increment the persistent trade achievement counter",
    "A completed Global Trade purchase must increment its achievement counter",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Achievement regression test is missing: {contract}")

if 'RegionManager="*res://scripts/autoload/RegionManager.gd"' not in project:
    errors.append("RegionManager must be registered as an autoload")
for contract in [
    '"id":"sunny_isles", "name":"Sunny Isles", "unlock_level":25',
    '"id":"frosty_fjords", "name":"Frosty Fjords", "unlock_level":30',
    '"id":"cactus_canyon", "name":"Cactus Canyon", "unlock_level":35',
    '"id":"green_valley", "name":"Green Valley", "unlock_level":40',
    '"id":"limestone_cliffs", "name":"Limestone Cliffs", "unlock_level":45',
    "func switch_region(region_id: String, persist_after_switch: bool = true) -> bool:",
    "func to_save_dict() -> Dictionary:",
    "func from_save_dict(data: Dictionary) -> void:",
]:
    if contract not in region_manager_source:
        errors.append(f"Region manager contract is missing: {contract}")
for contract in [
    "func capture_region_snapshot() -> Dictionary:",
    "func load_region_snapshot(snapshot: Dictionary) -> bool:",
    '"regions": RegionManager.to_save_dict()',
    "RegionManager.store_active_region_snapshot(capture_region_snapshot())",
    "RegionManager.from_save_dict(parsed.get(\"regions\", {}))",
]:
    if contract not in save_manager_source:
        errors.append(f"Region save/load contract is missing: {contract}")
for contract in [
    "func open_regions_panel() -> void:",
    "RegionManager.switch_region(region_id)",
    "RegionManager.region_changed.connect(_on_region_changed)",
]:
    if contract not in hud:
        errors.append(f"Region selector HUD contract is missing: {contract}")
for contract in [
    "func _apply_region_climate(sky_material: ProceduralSkyMaterial, environment: Environment) -> void:",
    "func refresh_region_appearance() -> void:",
    "RegionManager.region_changed.connect(_on_region_changed)",
]:
    if contract not in world_presentation_source:
        errors.append(f"Region climate rendering contract is missing: {contract}")
for contract in [
    "func _test_region_city_snapshots() -> void:",
    "must open as an independent region",
    "must restore its independent road layout",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Region snapshot regression test is missing: {contract}")

regional_catalog = [
    ("sunny_isles", "island_cottage", "coconut_grove", "coconut", 25),
    ("frosty_fjords", "fjord_chalet", "snowberry_farm", "snowberry", 30),
    ("cactus_canyon", "desert_hacienda", "cactus_farm", "cactus_fruit", 35),
    ("green_valley", "valley_eco_home", "herb_garden", "herbs", 40),
    ("limestone_cliffs", "cliffside_villa", "olive_grove", "olives", 45),
]
production_manager_source = (ROOT / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
level_progression_source = (ROOT / "scripts/autoload/LevelProgression.gd").read_text(encoding="utf-8")
icons_source = (ROOT / "scripts/ui/Icons.gd").read_text(encoding="utf-8")
for region_id, home_id, factory_id, material_id, level in regional_catalog:
    if f'"{home_id}": {{"name"' not in build_manager or f'"{factory_id}": {{"name"' not in build_manager:
        errors.append(f"Regional home/resource factory definitions are missing for {region_id}")
    if f'"{material_id}": {{"name"' not in production_manager_source:
        errors.append(f"Regional material definition is missing: {material_id}")
    if f'"{factory_id}":["{material_id}"]' not in production_manager_source:
        errors.append(f"Regional factory must produce its matching material: {factory_id}")
    if f'{level}: {{"materials": ["{material_id}"]' not in level_progression_source:
        if not (level == 30 and '30: {"factories": 9, "materials": ["snowberry"]' in level_progression_source):
            errors.append(f"Regional material unlock level is missing: {material_id}")
    if f'"{home_id}"' not in icons_source or f'"{factory_id}"' not in icons_source or f'"{material_id}"' not in icons_source:
        errors.append(f"Regional building/material icon identity is missing: {region_id}")
for contract in [
    "func get_region_build_lock_reason(type_id: String) -> String:",
    'if get_region_build_lock_reason(type_id) != "":',
    'if get_region_build_lock_reason(chosen) != "":',
    "counts_toward_factory_limit",
]:
    if contract not in build_manager:
        errors.append(f"Regional building placement contract is missing: {contract}")
if "ProductionManager.get_factory_material_ids(factory_type).has(item_id)" not in production_component_source:
    errors.append("Regional factory production must use the factory-specific material catalog")
for contract in [
    "func _test_regional_building_and_material_gates() -> void:",
    "Regional resource factory must produce only its matching local material",
    "Regional home must be locked outside its own region",
    "Sunny Isles Resource Factory must start its local Coconut production.",
    "Regional factory output must collect into shared city storage.",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Regional building/material regression test is missing: {contract}")

if "EpicProjectManager.to_save_dict()" not in save_manager_source or "EpicProjectManager.from_save_dict(epic_data)" not in save_manager_source:
    errors.append("Epic Project state must be saved and restored per region")
for contract in [
    "func _open_epic_project_panel(building: Building) -> void:",
    "EpicProjectManager.start_project(building.building_id)",
    "EpicProjectManager.contribute_to_task(task_id)",
    "EpicProjectManager.claim_project()",
    "EpicProjectManager.collect_token_part(building.building_id)",
]:
    if contract not in hud:
        errors.append(f"Epic Project HUD contract is missing: {contract}")
for contract in [
    "func _test_epic_project_core()",
    "must remain locked below Mayor Level 24",
    "must receive its full 24-hour deadline",
    "must finish the project at Gold tier",
    "must convert the home into an Epic Building",
    "must grant one Gold token part",
    "must survive save/load",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Epic Project gameplay regression test is missing: {contract}")

if "CitizenFeedbackBubbles.gd" not in (ROOT / "scenes/main.tscn").read_text(encoding="utf-8"):
    errors.append("Main scene must instantiate the citizen feedback bubble layer")
for contract in [
    "func get_feedback_for_home(home: Node3D) -> Dictionary:",
    "MAX_VISIBLE_BUBBLES := 3",
    "BUBBLE_SHOW_SECONDS := 5.5",
    "BUBBLE_HIDE_SECONDS := 2.5",
    "func _select_feedback_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:",
    "_priority_offsets[priority] = (offset + count) % group.size()",
    "BuildManager.has_road_access(grid_pos, size)",
    "ServiceManager.power_served_ids.has(home_id)",
    "ServiceManager.water_served_ids.has(home_id)",
    "func _on_bubble_pressed(building_id: String) -> void:",
    "open_residential_panel(building)",
]:
    if contract not in citizen_feedback_source:
        errors.append(f"Citizen feedback bubble contract is missing: {contract}")
for contract in [
    "func set_departed(value: bool) -> void:",
    "const OPEN_WATER_X := 142.0",
    "CargoHull",
    "Container_A",
    "Bridge",
]:
    if contract not in cargo_ship_visual_source:
        errors.append(f"Procedural cargo ship visual contract is missing: {contract}")
if "const SAVE_VERSION: int = 3" not in save_manager_source:
    errors.append("Save format must be version 3 for persisted trade state")
for contract in [
    "func _test_trade_depot_and_global_market()",
    "must accept a valid item listing",
    "must not pay out before its sale timer completes",
    "must complete an affordable market purchase",
    "must preserve sold market offers",
    "TradeManager.deliver_ship_crate(0)",
    "must accept a crate when its required items are in storage",
    "must send the ship away exactly once",
    "must grant one Golden Key",
    "must receive a fresh three-crate manifest",
    "must persist an absolute completion timestamp",
    "must refresh from their persisted wall-clock deadline",
    "must persist an absolute return timestamp",
    "Legacy sale saves must derive a deadline from their remaining time",
    "Legacy market saves must derive a refresh deadline from their remaining time",
    "Legacy ship saves must derive a return deadline from their remaining time",
    "CargoShipVisual",
    "func _test_citizen_feedback_bubbles()",
    "must produce a road feedback bubble",
    "must explain the missing road access",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Trade gameplay regression test is missing: {contract}")
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

# Residential levels must have separate authored architectural silhouettes. A generic
# category GLTF must not replace these level-specific procedural forms.
for level_contract in [
    'func _build_residential_level_architecture(',
    'var is_starter_villa := str(definition.get("category", "")) == "residential" and building_type != "residential_2" and str(definition.get("subtype", "villa")) == "villa" and upgrade_stage == 1',
    'if category == "residential" and upgrade_stage > 1:',
    'elif category == "commercial":',
    'elif category == "industrial":',
    '_build_commercial_identity(w, d, commercial_body_h, d * 0.5, upgrade_stage)',
    '_build_industrial_identity(w, d, height, upgrade_stage)',
    '_build_service_identity(w, d, height)',
    '_build_park(w, d, color)',

    'BuildingModelLoader.attach_model(mesh_root, model_path, model_scale) != null:',
    'match stage:',
    '# Stage 2: expanded suburban home with attached garage and new roof wing.',
    '# Stage 3: true two-storey redesign with offset upper floor and balcony.',
    '# Stage 4: contemporary glass sunroom, cantilevered terrace and pergola.',
    '# Stage 5: modernist split-level villa with roof garden and solar canopy.',
    '# Stage 6: premium contemporary residence;',
    'if is_farm:',
    'if is_apartment:',
    'CylinderMesh.new()',
]:
    if level_contract not in building_source:
        errors.append(f"Residential level architecture contract is missing: {level_contract}")

# Every non-residential category also has a type-specific identity path.
for identity_contract in [
    'func _build_commercial_identity(',
    '"shop_chain":',
    '"restaurant_traditional":',
    '"fast_food":',
    '"hardware_store":',
    '"farmers_market":',
    '"furniture_store":',
    '"gardening_supplies":',
    '"donut_shop":',
    '"home_appliances":',
    '"fashion_store":',
    '"sports_shop":',
    '"toy_store":',
    '"restoration_office":',
    '"farmers_store":',
    '"dessert_shop":',
    'func _build_industrial_identity(',
    '"hightech", "factory_hightech":',
    '"nano", "factory_nano":',
    'func _build_service_identity(',
    '"power_wind", "power_wind_deluxe":',
    '"water_tower":',
    '"water_pump":',
    '"fire_station_small", "fire_station", "fire_station_deluxe":',
    '"police_small", "police_station", "police_basic", "police_precinct":',
    '"clinic_small", "clinic", "hospital":',
    '"sewage_small", "sewage_basic", "sewage_deluxe":',
    '"waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling":',
    'func _build_park(w: float, d: float, color: Color) -> void:',
    'a paved entry, crossing path, planted beds, seating and',
]:
    if identity_contract not in building_source:
        errors.append(f"Building identity visual contract is missing: {identity_contract}")

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
for contract in ["Long press on a completed residential building", "Touch release did not commit the valid building move", "Invalid move should not commit", "Cancel did not restore", "Mouse release did not commit the valid building move", "Move whitelist must include all 61"]:
    if contract not in gameplay_smoke:
        errors.append(f"Building move gameplay regression test is missing: {contract}")



# Services menu must expose all nine fixed groups in their prescribed order and every selectable service
# must resolve to a real BuildManager definition with explicit group metadata.
services_hud = hud[hud.find("const SERVICE_GROUPS"):hud.find("const SPECIALIZATION_GROUPS")]
for group_id in ["power", "water", "sewage", "waste", "fire", "police", "health", "government", "trade"]:
    if f'"id":"{group_id}"' not in services_hud:
        errors.append(f"Services group is missing or out of order: {group_id}")
for building_id in ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "sewage_small", "sewage_basic", "sewage_deluxe",
                    "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "town_hall", "trade_depot", "global_trade_hq", "cargo_port"]:
    if f'"{building_id}": {{"name"' not in build_manager:
        errors.append(f"Services menu building definition is missing: {building_id}")
for service_id in ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "sewage_small", "sewage_basic", "sewage_deluxe",
                   "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "clinic_small", "clinic", "hospital", "town_hall", "trade_depot", "global_trade_hq", "cargo_port"]:
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
camera_controller_source = (ROOT / "scripts/systems/CameraController.gd").read_text(encoding="utf-8")
city_input_source = (ROOT / "scripts/systems/CityInput.gd").read_text(encoding="utf-8")
for contract in ["func get_coverage_radius_world(", 'definition.get("coverage_tiles", COVERAGE_TILES)', "ServiceManager.fire_served_ids.has(building_id)"]:
    if contract not in fire_manager_source:
        errors.append(f"FireHazardManager dynamic coverage contract is missing: {contract}")
for contract in [
    "func _process(delta: float) -> void:",
    "pan_velocity * delta",
    "rotation_degrees.y += rad_to_deg(orbit_velocity * delta)",
    "static func decay_pan_velocity(",
    "static func decay_orbit_velocity(",
    "pan_inertia_damping",
    "orbit_inertia_damping",
    "func focus_on(target_position: Vector3) -> void:",
    "static func interpolate_focus(",
]:
    if contract not in camera_controller_source:
        errors.append(f"Camera inertia implementation contract is missing: {contract}")
for contract in [
    "func rotate_placement() -> bool:",
    "func get_building_size(type_id: String, rotation_quarters: int = 0) -> Vector2i:",
    '"rotation_y": float(applied_rotation) * PI * 0.5',
]:
    if contract not in build_manager:
        errors.append(f"Building placement rotation contract is missing: {contract}")
for contract in [
    "event.keycode == KEY_R and BuildManager.is_placing",
    "BuildManager.rotate_placement()",
    "placement_rotate_pointer",
    "LONG_PRESS_SECONDS",
]:
    if contract not in city_input_source:
        errors.append(f"CityInput placement rotation contract is missing: {contract}")
if "rotation.y = rotation_y" not in ghost_preview_source:
    errors.append("GhostPreview must rotate with the selected building orientation.")
save_manager_rotation_source = (ROOT / "scripts/autoload/SaveManager.gd").read_text(encoding="utf-8")
for contract in [
    '"rotation_quarters": posmod(roundi(building.rotation.y / (PI * 0.5)), 4)',
    'int(saved_building.get("rotation_quarters", 0))',
]:
    if contract not in save_manager_rotation_source:
        errors.append(f"SaveManager rotation persistence contract is missing: {contract}")

if "camera_rig.focus_on(building.global_position)" not in city_input_source:
    errors.append("Selecting a building must smoothly focus the city camera on its world position.")
for contract in [
    "func _test_camera_focus_math()",
    "Camera focus interpolation must move toward the selected building",
    "Camera focus must ease toward the building instead of teleporting instantly",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Camera building-focus regression test is missing: {contract}")

for contract in [
    "func _test_camera_inertia_math()",
    "Camera pan inertia must decay over time",
    "Camera orbit inertia must decay over time",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Camera inertia regression test is missing: {contract}")

for contract in ["EmergencyCoveragePreview", "CoverageArea", "CoverageBoundary", "FireHazardManager.get_coverage_radius_world(definition)", 'int(definition.get("police", 0)) > 0', 'int(definition.get("health", 0)) > 0', "Color(0.18, 0.38, 0.98, 0.95)", "Color(0.20, 0.96, 0.62, 0.96)"]:
    if contract not in ghost_preview_source:
        errors.append(f"Fire placement coverage preview contract is missing: {contract}")

for contract in [
    'service_group == "sewage" or service_group == "waste"',
    '"network_required": true',
    '"network_scope": "citywide"',
]:
    if contract not in ghost_preview_source:
        errors.append(f"Sewage/Waste city-wide network preview contract is missing: {contract}")
for contract in [
    "ServiceManager.served_fire_homes, ServiceManager.demand_fire_homes",
    "ServiceManager.served_police_homes, ServiceManager.demand_police_homes",
    "ServiceManager.served_health_homes, ServiceManager.demand_health_homes",
    'context_header_subtitle.text.contains("Fire")',
    "context_header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART",
    "long City Services summary must wrap within the mobile header",
    "Emergency service HUD metrics must report covered homes against all completed homes",
]:
    if contract not in gameplay_smoke_source and contract not in hud:
        errors.append(f"Emergency service coverage UI contract is missing: {contract}")

for contract in [
    "var sewage_preview: Dictionary",
    "var waste_preview: Dictionary",
    "Sewage placement must communicate city-wide road-network service",
    "Waste placement must communicate city-wide road-network service",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Sewage/Waste city-wide network regression test is missing: {contract}")
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

for contract in [
    "if not _has_gateway_road_access(candidate):",
    "if _has_gateway_road_access(building):",
    "if not _has_gateway_road_access(home):",
    "func _has_nearby_emergency_facility(",
    "var fire_served_ids: Dictionary = {}",
    "var police_served_ids: Dictionary = {}",
    "var health_served_ids: Dictionary = {}",
    "DEFAULT_EMERGENCY_COVERAGE_TILES",
    'fire_served_ids[home.building_id] = true',
    'police_served_ids[home.building_id] = true',
    'health_served_ids[home.building_id] = true',
    "func is_home_served_by_group(",
]:
    if contract not in service_manager_source:
        errors.append(f"Power/water Gateway connectivity contract is missing: {contract}")
for contract in [
    "func _test_emergency_service_tier_happiness() -> void:",
    "Emergency service must not serve a home without Gateway road access",
    "Cutting the home's Gateway road must revoke every emergency service.",
    "A fire station disconnected from Gateway must not suppress residential fire hazards.",
    "_test_emergency_service_tier_happiness()",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Emergency service coverage regression test is missing: {contract}")

for contract in [
    "func _test_power_water_gateway_access() -> void:",
    "ServiceManager.total_power == 0 and ServiceManager.total_water == 0",
    "Connected local utility coverage must serve a connected nearby home.",
    "_test_power_water_gateway_access()",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Power/water Gateway regression test is missing: {contract}")

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
    "func _nearby_sewage_service(home: Node3D",
    "ServiceManager.sewage_served_ids.has(home.building_id)",
    "GameManager.level >= 8",
]:
    if contract not in happiness_manager_source:
        errors.append(f"Sewage city-wide service contract is missing: {contract}")
for contract in [
    "func get_city_service_warnings() -> Dictionary:",
    "func _service_group_is_unlocked(service_group: String) -> bool:",
    'counts["power"] += 1',
    'counts["water"] += 1',
    'counts["sewage"] += 1',
    'counts["waste"] += 1',
    'counts["fire"] += 1',
    'counts["police"] += 1',
    'counts["health"] += 1',
]:
    if contract not in happiness_manager_source:
        errors.append(f"Persistent city service-warning contract is missing: {contract}")
for contract in [
    "HappinessManager.happiness_recalculated.connect(_on_city_happiness_recalculated)",
    "func _build_service_warning_banner() -> void:",
    "func _update_service_warning_banner() -> void:",
    "service_warning_panel.visible = not summary.is_empty()",
]:
    if contract not in hud:
        errors.append(f"Persistent HUD service-warning contract is missing: {contract}")
for contract in [
    "HappinessManager.get_city_service_warnings()",
    'get("counts", {}).get("power", 0)',
    "Persistent city service warnings must count completed homes missing available power coverage.",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Persistent city service-warning regression test is missing: {contract}")

for contract in [
    "func _test_sewage_service_happiness()",
    "ServiceManager.total_sewage == expected_capacity",
    "ServiceManager.demand_sewage == 9",
    "ServiceManager.used_sewage == 3",
    "A sewage facility disconnected from the Gateway must not contribute capacity",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Sewage capacity/demand regression test is missing: {contract}")

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
    "GATEWAY_ROAD_CELL",
    "func get_gateway_connected_roads()",
    "func is_road_connected_to_gateway(",
    "func invalidate_road_connectivity_cache()",
    "func clear_roads()",
    "Road must connect to the active highway network.",
    "if grid_pos == GATEWAY_ROAD_CELL or not roads.has(grid_pos):",
]:
    if contract not in road_system_source:
        errors.append(f"Road gateway connectivity contract is missing: {contract}")
if "road_system.is_road_connected_to_gateway(" not in build_manager:
    errors.append("Building road access must require a path-connected road tile.")
for contract in [
    "func _test_road_gateway_connectivity(",
    "must disconnect the far road segment from the highway gateway",
    "must not extend a disconnected road segment",
    "Restoring the bridge must reconnect the far road segment",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Road gateway connectivity regression test is missing: {contract}")

for contract in [
    "func _test_emergency_service_tier_happiness() -> void:",
    "Every connected emergency service tier must serve a connected home inside its catalog radius",
    "Emergency service must not serve a home without Gateway road access",
    "An emergency facility under construction must not provide coverage",
    "An emergency facility outside its tier coverage radius must not serve a home",
    "An emergency facility disconnected from Gateway must not serve a nearby home",
    "Cutting the home's Gateway road must revoke every emergency service.",
    "Restoring Gateway road access must restore Fire coverage.",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Emergency service-tier regression test is missing: {contract}")

# City-wide base-service demand uses the SimCity BuildIt low/medium/high units.
for residential_id, expected_demand in [
    ("residential_1", 1),
    ("residential_2", 2),
    ("residential_villa", 1),
    ("residential_apartment", 2),
    ("residential_farm", 1),
]:
    match = re.search(r'"' + residential_id + r'": \{([^\n]+)\}', build_manager)
    if match is None or f'"service_demand":{expected_demand}' not in match.group(1):
        errors.append(f"Residential service-demand tier is incorrect: {residential_id}")
for contract in [
    "func get_home_service_demand(home: Node3D)",
    "var total_sewage: int",
    "var demand_sewage: int",
    "var total_waste: int",
    "var demand_waste: int",
    "used_waste = 0",
    "func _has_gateway_road_access(building: Node3D)",
    "demand_sewage += get_home_service_demand(building)",
    "demand_waste += get_home_service_demand(building)",
    "if sewage_remaining >= demand:",
    "if waste_remaining >= demand:",
]:
    if contract not in service_manager_source:
        errors.append(f"City-wide service capacity/demand contract is missing: {contract}")

# A real 3D vehicle must traverse the connected Gateway graph and return.
for contract in [
    "func build_gateway_round_trip_route() -> Array[Vector2i]",
    "var start: Vector2i = road_system.GATEWAY_ROAD_CELL",
    "func spawn_vehicle_now() -> TrafficVehicle:",
    "vehicle.route_completed.connect(_on_vehicle_route_completed)",
    "func _validate_active_vehicle_route(connected_roads: Dictionary)",
]:
    if contract not in traffic_manager_source:
        errors.append(f"Gateway vehicle route contract is missing: {contract}")
for contract in [
    "class_name TrafficVehicle",
    "extends Node3D",
    "signal route_completed",
    "func _process(delta: float) -> void:",
    "global_position = from_position.lerp(to_position, progress)",
    'instance.name = node_name',
]:
    if contract not in traffic_vehicle_source:
        errors.append(f"3D traffic vehicle movement contract is missing: {contract}")
for contract in [
    "func _test_gateway_vehicle_route(",
    "The simulated vehicle route must start and finish at the permanent Gateway",
    "The simulated vehicle must advance along its road route",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Gateway vehicle route regression test is missing: {contract}")

# Road tier changes must alter the network's traffic capacity and city happiness.
for contract in [
    "RESIDENTS_PER_TRAFFIC_UNIT: int = 50",
    "var traffic_demand: int = 0",
    "var road_capacity: int = 0",
    "func recalculate_from_roads()",
    "var lane_count: int = road_system.get_road_level(road_cell) * 2",
    "func get_happiness_penalty() -> float:",
    "if congestion_ratio >= 1.0:",
]:
    if contract not in traffic_manager_source:
        errors.append(f"Road traffic-capacity contract is missing: {contract}")
for contract in [
    "TrafficManager.traffic_changed.connect(_on_traffic_changed)",
    "TrafficManager.traffic_demand, TrafficManager.road_capacity",
    "TrafficManager.get_congestion_percent()",
]:
    if contract not in hud:
        errors.append(f"Traffic demand/capacity UI contract is missing: {contract}")
for contract in [
    "func _test_road_traffic_capacity(",
    "Fifty connected two-lane road tiles must provide 100 traffic units of capacity",
    "Five Avenue tiles must add 30 traffic-capacity units to the Gateway network",
    "Road capacity upgrades must remove the traffic happiness penalty",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Road traffic-capacity regression test is missing: {contract}")

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
    "func _nearby_waste_service(home: Node3D",
    "ServiceManager.waste_served_ids.has(home.building_id)",
    "GameManager.level >= 14",
]:
    if contract not in happiness_manager_source:
        errors.append(f"Waste city-wide service contract is missing: {contract}")
for contract in [
    "func _test_waste_service_happiness()",
    "ServiceManager.total_waste == expected_capacity",
    "ServiceManager.demand_waste == 19",
    "ServiceManager.used_waste == 15",
    "ServiceManager.waste_served_ids.size() == 13",
    "A waste facility disconnected from the Gateway must not contribute capacity",
]:
    if contract not in gameplay_smoke_source:
        errors.append(f"Waste capacity/demand regression test is missing: {contract}")


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
if "road_system.clear_roads()" not in save_manager_source or "RoadSystemScript.GATEWAY_ROAD_CELL" not in save_manager_source:
    errors.append("City load must clear the old road network and restore its gateway before other road tiles")
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
