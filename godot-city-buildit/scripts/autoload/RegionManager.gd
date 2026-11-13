extends Node

signal region_changed(region_id: String)
signal region_state_changed

const REGION_DEFINITIONS := [
	{"id":"capital", "name":"Capital City", "unlock_level":1, "climate":"temperate", "description":"Your original coastal city.", "signature_material":"—", "signature_building":"—"},
	{"id":"sunny_isles", "name":"Sunny Isles", "unlock_level":25, "climate":"tropical", "description":"Warm islands and bright coastal weather.", "signature_material":"Coconut", "signature_building":"Island Residence"},
	{"id":"frosty_fjords", "name":"Frosty Fjords", "unlock_level":30, "climate":"arctic", "description":"Cold fjords, snow and evergreen forests.", "signature_material":"Snowberry", "signature_building":"Fjord Chalet"},
	{"id":"cactus_canyon", "name":"Cactus Canyon", "unlock_level":35, "climate":"desert", "description":"Dry canyons and sun-baked neighborhoods.", "signature_material":"Cactus Fruit", "signature_building":"Desert Hacienda"},
	{"id":"green_valley", "name":"Green Valley", "unlock_level":40, "climate":"lush", "description":"A green inland valley with rich vegetation.", "signature_material":"Herbs", "signature_building":"Valley Eco Home"},
	{"id":"limestone_cliffs", "name":"Limestone Cliffs", "unlock_level":45, "climate":"mediterranean", "description":"Rocky limestone coast and Mediterranean light.", "signature_material":"Olives", "signature_building":"Cliffside Villa"}
]

var active_region_id := "capital"
var unlocked_regions: Array[String] = ["capital"]
var region_states: Dictionary = {}

func _ready() -> void:
	GameManager.level_changed.connect(_on_mayor_level_changed)
	_refresh_unlocks()

func _on_mayor_level_changed(_level: int) -> void:
	_refresh_unlocks()

func _refresh_unlocks() -> void:
	var changed := false
	for region in REGION_DEFINITIONS:
		var region_id := str(region.get("id", ""))
		if GameManager.level >= int(region.get("unlock_level", 1)) and region_id not in unlocked_regions:
			unlocked_regions.append(region_id)
			changed = true
	if changed:
		region_state_changed.emit()

func get_region_definition(region_id: String) -> Dictionary:
	for region in REGION_DEFINITIONS:
		if str(region.get("id", "")) == region_id:
			return region.duplicate(true)
	return {}

func get_active_region() -> Dictionary:
	return get_region_definition(active_region_id)

func get_region_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region in REGION_DEFINITIONS:
		var entry: Dictionary = region.duplicate(true)
		entry["unlocked"] = str(region.get("id", "")) in unlocked_regions
		entry["active"] = str(region.get("id", "")) == active_region_id
		entry["population"] = _population_from_snapshot(region_states.get(str(region.get("id", "")), {}))
		result.append(entry)
	return result

func _population_from_snapshot(snapshot: Dictionary) -> int:
	var population := 0
	for saved_building in snapshot.get("buildings", []):
		if not saved_building is Dictionary or str(saved_building.get("status", "")) != "completed":
			continue
		if str(saved_building.get("type", "")).begins_with("residential"):
			population += int(saved_building.get("population", 0))
	return population

func get_active_snapshot() -> Dictionary:
	return region_states.get(active_region_id, {}).duplicate(true)

func store_active_region_snapshot(snapshot: Dictionary) -> void:
	region_states[active_region_id] = snapshot.duplicate(true)

func switch_region(region_id: String) -> bool:
	if region_id == active_region_id or region_id not in unlocked_regions or get_region_definition(region_id).is_empty():
		return false
	var previous_region := active_region_id
	var current_snapshot := SaveManager.capture_region_snapshot()
	if current_snapshot.is_empty():
		return false
	store_active_region_snapshot(current_snapshot)
	active_region_id = region_id
	var target_snapshot: Dictionary = region_states.get(region_id, {}).duplicate(true)
	if not SaveManager.load_region_snapshot(target_snapshot):
		active_region_id = previous_region
		SaveManager.load_region_snapshot(current_snapshot)
		return false
	region_changed.emit(active_region_id)
	region_state_changed.emit()
	SaveManager.save_game()
	return true

func to_save_dict() -> Dictionary:
	return {
		"active_region_id": active_region_id,
		"unlocked_regions": unlocked_regions.duplicate(),
		"region_states": region_states.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	active_region_id = str(data.get("active_region_id", "capital"))
	if get_region_definition(active_region_id).is_empty():
		active_region_id = "capital"
	unlocked_regions.clear()
	for region_id in data.get("unlocked_regions", ["capital"]):
		if not get_region_definition(str(region_id)).is_empty() and str(region_id) not in unlocked_regions:
			unlocked_regions.append(str(region_id))
	if "capital" not in unlocked_regions:
		unlocked_regions.append("capital")
	region_states = data.get("region_states", {}).duplicate(true)
	_refresh_unlocks()
	region_state_changed.emit()
