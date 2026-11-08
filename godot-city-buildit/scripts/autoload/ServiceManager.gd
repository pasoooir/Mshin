extends Node

signal power_changed(total: int, used: int)
signal water_changed(total: int, used: int)

const HOME_POWER_DEMAND: int = 2
const HOME_WATER_DEMAND: int = 2

var total_power: int = 0
var used_power: int = 0
var total_water: int = 0
var used_water: int = 0
var coverage_radius: float = 28.0
var power_served_ids: Dictionary = {}
var water_served_ids: Dictionary = {}

func _ready() -> void:
	print("[ServiceManager] Power/water network online")

func register_power(_amount: int) -> void:
	recalculate_from_buildings()

func register_water(_amount: int) -> void:
	recalculate_from_buildings()

func _has_nearby_utility(building: Node3D, utility_key: String) -> bool:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if int(candidate.definition.get(utility_key, 0)) <= 0:
			continue
		if candidate.global_position.distance_to(building.global_position) <= coverage_radius:
			return true
	return false

func is_building_served(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	return power_served_ids.has(building.building_id) and water_served_ids.has(building.building_id)

func recalculate_from_buildings() -> void:
	total_power = 0
	total_water = 0
	used_power = 0
	used_water = 0
	power_served_ids.clear()
	water_served_ids.clear()
	var homes: Array = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var definition: Dictionary = building.definition
		total_power += int(definition.get("power", 0))
		total_water += int(definition.get("water", 0))
		if definition.get("category", "") == "residential":
			homes.append(building)

	for home in homes:
		if used_power + HOME_POWER_DEMAND <= total_power and _has_nearby_utility(home, "power"):
			used_power += HOME_POWER_DEMAND
			power_served_ids[home.building_id] = true
		if used_water + HOME_WATER_DEMAND <= total_water and _has_nearby_utility(home, "water"):
			used_water += HOME_WATER_DEMAND
			water_served_ids[home.building_id] = true

	power_changed.emit(total_power, used_power)
	water_changed.emit(total_water, used_water)
	if has_node("/root/HappinessManager"):
		HappinessManager.recalculate_city()
