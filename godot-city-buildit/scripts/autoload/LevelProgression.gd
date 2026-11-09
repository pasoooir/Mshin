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
	1: {"materials": ["metal", "nails"], "commercial": ["building_supplies"], "factories": 2, "services": ["power", "water"], "other": ["roads", "residential"]},
	2: {"materials": ["wood"], "factories": 3},
	3: {"materials": ["planks"], "factories": 4, "other": ["parks"]},
	4: {"materials": ["hammer"], "commercial": ["hardware_store"], "factories": 4, "other": ["storage_upgrade"]},
	5: {"materials": ["plastic"], "services": ["fire"], "buildings": ["city_hall", "fire_station"]},
	6: {"materials": ["measuring_tape"], "factories": 5, "buildings": ["mayors_mansion"]},
	7: {"materials": ["seeds"]},
	8: {"materials": ["vegetables"], "commercial": ["farmers_market"], "services": ["sewage"]},
	9: {"materials": ["shovel"], "other": ["4lane_road"]},
	10: {"materials": ["chair"], "commercial": ["furniture_store"], "other": ["education", "transportation"]},
	12: {"factories": 6, "services": ["police"]},
	13: {"materials": ["chemicals", "bricks"]},
	14: {"materials": ["grass", "cement"], "commercial": ["gardening_supplies"], "services": ["waste"]},
	15: {"materials": ["glue", "textiles"], "other": ["6lane_road", "beach"]},
	16: {"materials": ["paint", "table"], "services": ["health"]},
	18: {"materials": ["donut", "fruit"], "commercial": ["donut_shop"], "factories": 7},
	19: {"materials": ["glass"]},
	20: {"other": ["entertainment", "avenue"]},
	23: {"materials": ["animal_feed"]},
	24: {"factories": 8},
	29: {"materials": ["electrical"]},
	30: {"factories": 9},
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
		150000: "nano_tech_factory"
}

var unlocked_materials: Array = ["metal", "nails"]
var unlocked_commercial: Array = ["building_supplies"]
var unlocked_services: Array = ["power", "water"]
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
		for c in data.get("commercial", []):
			if c not in unlocked_commercial:
				unlocked_commercial.append(c)
				unlocked.emit("commercial:" + c, lv)
		for s in data.get("services", []):
			if s not in unlocked_services:
				unlocked_services.append(s)
				unlocked.emit("service:" + s, lv)
		if data.has("factories") and data.factories > max_factories:
			max_factories = data.factories
			factory_slot_unlocked.emit(max_factories)
		for feature in data.get("other", []) + data.get("buildings", []):
			if feature not in unlocked_features:
				unlocked_features.append(feature)
				unlocked.emit("feature:" + feature, lv)

func on_level_up(new_level: int) -> void:
	_apply_level(new_level)
	print("[LevelProgression] Level ", new_level, " applied. Factories: ", max_factories)

func get_factory_limit_for_level(level: int) -> int:
	var limit := 2
	for threshold in FACTORY_LIMITS:
		if level >= int(threshold):
			limit = int(FACTORY_LIMITS[threshold])
	return limit

func is_material_unlocked(id: String) -> bool:
	return id in unlocked_materials or (ProductionManager.raw_materials.has(id) and int(ProductionManager.raw_materials[id].get("level", 1)) <= GameManager.level)

func is_service_unlocked(id: String) -> bool:
	return id in unlocked_services

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
