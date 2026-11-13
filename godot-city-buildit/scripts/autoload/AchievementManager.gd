extends Node

signal achievement_unlocked(id: String, title: String, simoleons_reward: int, xp_reward: int)
signal state_changed

const SCAN_INTERVAL_SECONDS := 1.0
const DEFINITIONS := [
	{"id":"first_home", "title":"First Home", "description":"Complete your first residential building.", "metric":"homes", "target":1, "simoleons":100, "xp":10},
	{"id":"home_builder", "title":"Growing Neighborhood", "description":"Complete five residential buildings.", "metric":"homes", "target":5, "simoleons":250, "xp":20},
	{"id":"city_of_1000", "title":"A Thousand Neighbors", "description":"Reach a population of 1,000.", "metric":"population", "target":1000, "simoleons":300, "xp":25},
	{"id":"metropolis", "title":"Rising Metropolis", "description":"Reach a population of 10,000.", "metric":"population", "target":10000, "simoleons":1000, "xp":60},
	{"id":"mayor_level_5", "title":"Experienced Mayor", "description":"Reach Mayor Level 5.", "metric":"level", "target":5, "simoleons":200, "xp":15},
	{"id":"mayor_level_10", "title":"Veteran Mayor", "description":"Reach Mayor Level 10.", "metric":"level", "target":10, "simoleons":600, "xp":35},
	{"id":"industrialist", "title":"Industrial District", "description":"Complete three factories.", "metric":"factories", "target":3, "simoleons":350, "xp":25},
	{"id":"green_city", "title":"Green City", "description":"Complete three parks.", "metric":"parks", "target":3, "simoleons":300, "xp":25},
	{"id":"road_network", "title":"Connected City", "description":"Build 50 road tiles.", "metric":"roads", "target":50, "simoleons":300, "xp":20},
	{"id":"trade_seller", "title":"First Sale", "description":"Collect your first Trade Depot sale.", "metric":"sales", "target":1, "simoleons":150, "xp":15},
	{"id":"global_buyer", "title":"Global Shopper", "description":"Buy your first Global Trade offer.", "metric":"market_purchases", "target":1, "simoleons":150, "xp":15},
	{"id":"cargo_captain", "title":"Cargo Captain", "description":"Send your first cargo ship.", "metric":"ship_departures", "target":1, "simoleons":400, "xp":30},
	{"id":"epic_master", "title":"Epic Masterpiece", "description":"Create your first Epic Building.", "metric":"epic_buildings", "target":1, "simoleons":500, "xp":35}
]

var unlocked: Dictionary = {}
var progress: Dictionary = {}
var unlocked_at: Dictionary = {}
var _scan_elapsed := 0.0

func _process(delta: float) -> void:
	_scan_elapsed += delta
	if _scan_elapsed < SCAN_INTERVAL_SECONDS:
		return
	_scan_elapsed = 0.0
	_check_achievements()

func _collect_metrics() -> Dictionary:
	var metrics := {
		"homes": 0,
		"factories": 0,
		"parks": 0,
		"epic_buildings": 0,
		"population": GameManager.population,
		"level": GameManager.level,
		"roads": 0,
		"sales": TradeManager.completed_sales,
		"market_purchases": TradeManager.market_purchases,
		"ship_departures": TradeManager.ship_departures
	}
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or str(building.get("status")) != "completed":
			continue
		var definition: Dictionary = building.get("definition")
		var category := str(definition.get("category", ""))
		if category == "residential":
			metrics["homes"] = int(metrics["homes"]) + 1
		elif category == "industrial":
			metrics["factories"] = int(metrics["factories"]) + 1
		elif category == "park":
			metrics["parks"] = int(metrics["parks"]) + 1
		if bool(building.get("is_epic_building")):
			metrics["epic_buildings"] = int(metrics["epic_buildings"]) + 1
	var scene := get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if is_instance_valid(road_system) and road_system.has_method("get_road_count"):
		metrics["roads"] = int(road_system.get_road_count())
	return metrics

func _check_achievements() -> void:
	var metrics := _collect_metrics()
	var changed := false
	for definition in DEFINITIONS:
		var id := str(definition.get("id", ""))
		var target := maxi(1, int(definition.get("target", 1)))
		var current := clampi(int(metrics.get(str(definition.get("metric", "")), 0)), 0, target)
		if int(progress.get(id, -1)) != current:
			progress[id] = current
			changed = true
		if bool(unlocked.get(id, false)) or current < target:
			continue
		unlocked[id] = true
		unlocked_at[id] = int(Time.get_unix_time_from_system())
		var simoleons_reward := int(definition.get("simoleons", 0))
		var xp_reward := int(definition.get("xp", 0))
		if simoleons_reward > 0:
			EconomyManager.add_simoleons(simoleons_reward)
		if xp_reward > 0:
			GameManager.add_experience(xp_reward)
		achievement_unlocked.emit(id, str(definition.get("title", id)), simoleons_reward, xp_reward)
		changed = true
	if changed:
		state_changed.emit()

func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var metrics := _collect_metrics()
	for definition in DEFINITIONS:
		var entry: Dictionary = definition.duplicate(true)
		var id := str(entry.get("id", ""))
		var target := maxi(1, int(entry.get("target", 1)))
		var current := int(metrics.get(str(entry.get("metric", "")), 0))
		entry["progress"] = mini(target, current)
		entry["unlocked"] = bool(unlocked.get(id, false))
		entry["unlocked_at"] = int(unlocked_at.get(id, 0))
		result.append(entry)
	return result

func get_unlocked_count() -> int:
	var count := 0
	for definition in DEFINITIONS:
		if bool(unlocked.get(str(definition.get("id", "")), false)):
			count += 1
	return count

func get_total_count() -> int:
	return DEFINITIONS.size()

func to_save_dict() -> Dictionary:
	return {
		"unlocked": unlocked.duplicate(true),
		"progress": progress.duplicate(true),
		"unlocked_at": unlocked_at.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	unlocked = data.get("unlocked", {}).duplicate(true)
	progress = data.get("progress", {}).duplicate(true)
	unlocked_at = data.get("unlocked_at", {}).duplicate(true)
	for definition in DEFINITIONS:
		var id := str(definition.get("id", ""))
		if not unlocked.has(id):
			unlocked[id] = false
		if not progress.has(id):
			progress[id] = 0
	state_changed.emit()
