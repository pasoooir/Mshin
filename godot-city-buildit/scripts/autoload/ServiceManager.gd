extends Node

signal power_changed(total: int, used: int)
signal water_changed(total: int, used: int)

var total_power := 0
var used_power := 0
var total_water := 0
var used_water := 0
var coverage_radius := 28.0

func _ready() -> void:
	print("[ServiceManager] Power/water network online")

func register_power(_amount: int) -> void:
	recalculate_from_buildings()

func register_water(_amount: int) -> void:
	recalculate_from_buildings()

func has_enough_power() -> bool:
	return used_power <= total_power

func has_enough_water() -> bool:
	return used_water <= total_water

func get_power_status() -> String:
	return "%d/%d" % [used_power, total_power]

func get_water_status() -> String:
	return "%d/%d" % [used_water, total_water]

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
	return total_power >= used_power and total_water >= used_water and _has_nearby_utility(building, "power") and _has_nearby_utility(building, "water")

func recalculate_from_buildings() -> void:
	total_power = 0
	total_water = 0
	used_power = 0
	used_water = 0
	var homes: Array = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var definition: Dictionary = building.definition
		total_power += int(definition.get("power", 0))
		total_water += int(definition.get("water", 0))
		if definition.get("category") == "residential":
			homes.append(building)
	for home in homes:
		used_power += 2
		used_water += 2
	power_changed.emit(total_power, used_power)
	water_changed.emit(total_water, used_water)
	var served := 0
	for home in homes:
		if is_building_served(home):
			served += 1
	if not homes.is_empty():
		GameManager.set_happiness(100.0 * float(served) / float(homes.size()))
