extends Node

signal unlocked(what: String, level: int)
signal factory_slot_unlocked(count: int)

var xp_table := {
	1: 0, 2: 30, 3: 60, 4: 100, 5: 150,
	6: 210, 7: 280, 8: 360, 9: 450, 10: 550,
	11: 2200, 12: 2680, 13: 3240, 14: 3900, 15: 4610,
	16: 5430, 17: 6320, 18: 7300, 19: 8320, 20: 9400
}

var unlocks := {
	1: {"materials": ["metal", "nails"], "factories": 2, "other": ["roads", "residential"]},
	2: {"materials": ["wood"], "factories": 3},
	3: {"materials": ["planks"], "factories": 4, "other": ["parks"]},
	4: {"materials": ["hammer"], "factories": 4, "other": ["storage_upgrade"]},
	5: {"materials": ["plastic"], "buildings": ["city_hall", "fire_station"]},
	6: {"materials": ["measuring_tape"], "factories": 5, "buildings": ["mayors_mansion"]},
	7: {"materials": ["seeds"]},
	8: {"materials": ["vegetables"]},
	9: {"materials": ["shovel"], "other": ["4lane_road"]},
	10: {"materials": ["chair"], "other": ["education", "transportation"]},
	11: {"materials": ["minerals"]},
	12: {"factories": 6},
	13: {"materials": ["chemicals", "bricks"]},
	14: {"materials": ["grass", "cement"]},
	15: {"materials": ["glue", "textiles"], "other": ["6lane_road", "beach"]},
	16: {"materials": ["paint", "table"], "buildings": ["epic_projects_department"]},
	17: {"materials": ["sugar_spices"]},
	18: {"materials": ["donut", "fruit"], "factories": 7},
	19: {"materials": ["glass"]},
	20: {"other": ["entertainment", "avenue"]},
	23: {"materials": ["animal_feed"]},
	24: {"factories": 8, "other": ["epic_projects"]},
	25: {"materials": ["coconut"], "buildings": ["island_cottage", "coconut_grove"], "other": ["sunny_isles"]},
	29: {"materials": ["electrical"]},
	30: {"factories": 9, "materials": ["snowberry"], "buildings": ["fjord_chalet", "snowberry_farm"], "other": ["frosty_fjords"]},
	35: {"materials": ["cactus_fruit"], "buildings": ["desert_hacienda", "cactus_farm"], "other": ["cactus_canyon"]},
	40: {"materials": ["herbs"], "buildings": ["valley_eco_home", "herb_garden"], "other": ["green_valley"]},
	45: {"materials": ["olives"], "buildings": ["cliffside_villa", "olive_grove"], "other": ["limestone_cliffs"]},
	37: {"factories": 10},
	46: {"factories": 11},
	58: {"factories": 12}
}

var population_unlocks := {
	4000: "basic_factory_upgrade",
	8000: "trade_depot",
	10000: "global_trade_hq",
	12000: "monster_trouble",
	20000: "cargo_ship",
	27000: "mass_production_factory",
	80000: "high_tech_factory",
	1500000: "nano_tech_factory"
}

var unlocked_materials: Array = ["metal", "nails"]
var unlocked_commercial: Array = ["building_supplies"]
var unlocked_services: Array = ["power", "water", "government", "trade"]
var max_factories: int = 2

const FACTORY_LIMITS := {1:2, 2:3, 3:4, 6:5, 12:6, 18:7, 24:8, 30:9, 37:10, 46:11, 58:12}
var unlocked_features: Array = ["roads", "residential"]

func _ready() -> void:
	print("[LevelProgression] Loaded - early game mirrors SimCity BuildIt")
	_apply_level(GameManager.level)

func _apply_level(level: int) -> void:
	for lv in range(1, level + 1):
		if not unlocks.has(lv):
			continue
		var data = unlocks[lv]
		for m in data.get("materials", []):
			if m not in unlocked_materials:
				unlocked_materials.append(m)
				unlocked.emit("material:" + m, lv)
		if data.has("factories") and data.factories > max_factories:
			max_factories = data.factories
			factory_slot_unlocked.emit(max_factories)
		for feature in data.get("other", []) + data.get("buildings", []):
			if feature not in unlocked_features:
				unlocked_features.append(feature)
				unlocked.emit("feature:" + feature, lv)

	_sync_commercial_unlocks(level)
	_sync_service_unlocks(level)

func _sync_commercial_unlocks(level: int) -> void:
	# BuildManager is the single source of truth for commercial unlock levels.
	# Keep the progression list in sync for systems that consume unlock signals.
	for type_id in BuildManager.building_types:
		var definition: Dictionary = BuildManager.building_types[type_id]
		if str(definition.get("category", "")) != "commercial" or bool(definition.get("legacy_only", false)):
			continue
		if int(definition.get("level", 1)) > level:
			continue
		if type_id not in unlocked_commercial:
			unlocked_commercial.append(type_id)
			unlocked.emit("commercial:" + str(type_id), int(definition.get("level", 1)))

func is_commercial_unlocked(type_id: String, level_override: int = -1) -> bool:
	if not BuildManager.building_types.has(type_id):
		return false
	var definition: Dictionary = BuildManager.building_types[type_id]
	if str(definition.get("category", "")) != "commercial" or bool(definition.get("legacy_only", false)):
		return false
	var effective_level := GameManager.level if level_override < 0 else level_override
	return effective_level >= int(definition.get("level", 1))

func on_level_up(new_level: int) -> void:
	_apply_level(new_level)
	print("[LevelProgression] Level ", new_level, " applied. Factories: ", max_factories)

func get_factory_limit_for_level(level: int) -> int:
	var limit := 2
	var thresholds: Array = FACTORY_LIMITS.keys()
	thresholds.sort()
	for threshold in thresholds:
		if level >= int(threshold):
			limit = int(FACTORY_LIMITS[threshold])
	return limit

func is_material_unlocked(id: String) -> bool:
	return id in unlocked_materials or (ProductionManager.raw_materials.has(id) and int(ProductionManager.raw_materials[id].get("level", 1)) <= GameManager.level)

func _get_service_group_ids() -> Array[String]:
	var group_ids: Array[String] = []
	for type_id in BuildManager.building_types:
		var definition: Dictionary = BuildManager.building_types[type_id]
		if str(definition.get("category", "")) != "service":
			continue
		var group_id := str(definition.get("service_group", ""))
		if not group_id.is_empty() and group_id not in group_ids:
			group_ids.append(group_id)
	group_ids.sort()
	return group_ids

func get_service_unlock_level(id: String) -> int:
	# The earliest building level in a service group is the group's unlock.
	# This keeps group cards aligned with the actual building catalog.
	var earliest_level := 0
	for type_id in BuildManager.building_types:
		var definition: Dictionary = BuildManager.building_types[type_id]
		if str(definition.get("category", "")) != "service" or str(definition.get("service_group", "")) != id:
			continue
		var building_level := maxi(1, int(definition.get("level", 1)))
		if earliest_level == 0 or building_level < earliest_level:
			earliest_level = building_level
	return earliest_level

func is_service_unlocked(id: String) -> bool:
	var required_level := get_service_unlock_level(id)
	return required_level > 0 and GameManager.level >= required_level

func is_service_building_unlocked(type_id: String, level_override: int = -1) -> bool:
	if not BuildManager.building_types.has(type_id):
		return false
	var definition: Dictionary = BuildManager.building_types[type_id]
	if str(definition.get("category", "")) != "service":
		return false
	var effective_level := GameManager.level if level_override < 0 else level_override
	return effective_level >= maxi(1, int(definition.get("level", 1)))

func _sync_service_unlocks(level: int) -> void:
	for group_id in _get_service_group_ids():
		var required_level := get_service_unlock_level(group_id)
		if required_level <= 0 or level < required_level or group_id in unlocked_services:
			continue
		unlocked_services.append(group_id)
		unlocked.emit("service:" + group_id, required_level)

func is_feature_unlocked(id: String) -> bool:
	return id in unlocked_features

func get_xp_for_level(level: int) -> int:
	return xp_table.get(level, level * 500)

func check_population_unlocks(pop: int) -> void:
	for threshold in population_unlocks:
		if pop >= threshold:
			var feature = population_unlocks[threshold]
			if feature not in unlocked_features:
				unlocked_features.append(feature)
				unlocked.emit("population:" + feature, threshold)
