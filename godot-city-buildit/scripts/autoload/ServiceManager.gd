extends Node

signal power_changed(total: int, demand: int)
signal water_changed(total: int, demand: int)
signal sewage_changed(total: int, demand: int)
signal waste_changed(total: int, demand: int)

var total_power: int = 0
var demand_power: int = 0
var used_power: int = 0
var total_water: int = 0
var demand_water: int = 0
var used_water: int = 0
var total_sewage: int = 0
var demand_sewage: int = 0
var used_sewage: int = 0
var total_waste: int = 0
var demand_waste: int = 0
var used_waste: int = 0
var coverage_radius: float = 28.0
var power_served_ids: Dictionary = {}
var water_served_ids: Dictionary = {}
var sewage_served_ids: Dictionary = {}
var waste_served_ids: Dictionary = {}

func _ready() -> void:
	print("[ServiceManager] Power/water/sewage/waste capacity network online")

func get_home_service_demand(home: Node3D) -> int:
	if not is_instance_valid(home):
		return 1
	return maxi(1, int(home.definition.get("service_demand", 1)))

func register_power(_amount: int) -> void:
	recalculate_from_buildings()

func register_water(_amount: int) -> void:
	recalculate_from_buildings()

func register_sewage(_amount: int) -> void:
	recalculate_from_buildings()

func register_waste(_amount: int) -> void:
	recalculate_from_buildings()

func _has_nearby_utility(building: Node3D, utility_key: String) -> bool:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if int(candidate.definition.get(utility_key, 0)) <= 0:
			continue
		# A disconnected facility must not provide a service merely because it
		# happens to be within the geometric coverage radius.
		if not _has_gateway_road_access(candidate):
			continue
		if candidate.global_position.distance_to(building.global_position) <= coverage_radius:
			return true
	return false

func _has_gateway_road_access(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var size: Vector2i = building.definition.get("size", Vector2i(2, 2))
	return BuildManager.has_road_access(building.grid_pos, size)

func is_building_served(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	return power_served_ids.has(building.building_id) and water_served_ids.has(building.building_id)

func is_sewage_served(building: Node3D) -> bool:
	return is_instance_valid(building) and sewage_served_ids.has(building.building_id)

func is_waste_served(building: Node3D) -> bool:
	return is_instance_valid(building) and waste_served_ids.has(building.building_id)

func recalculate_from_buildings() -> void:
	total_power = 0
	demand_power = 0
	used_power = 0
	total_water = 0
	demand_water = 0
	used_water = 0
	total_sewage = 0
	demand_sewage = 0
	used_sewage = 0
	total_waste = 0
	demand_waste = 0
	used_waste = 0
	power_served_ids.clear()
	water_served_ids.clear()
	sewage_served_ids.clear()
	waste_served_ids.clear()

	var homes: Array = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var definition: Dictionary = building.definition
		var category := str(definition.get("category", ""))
		if category == "residential":
			homes.append(building)
			demand_power += get_home_service_demand(building)
			demand_water += get_home_service_demand(building)
			demand_sewage += get_home_service_demand(building)
			demand_waste += get_home_service_demand(building)
		elif str(definition.get("service_group", "")) == "sewage" and _has_gateway_road_access(building):
			total_sewage += int(definition.get("sewage", 0))
		elif str(definition.get("service_group", "")) == "waste" and _has_gateway_road_access(building):
			total_waste += int(definition.get("waste", 0))
		# Capacity is operational only while the facility itself is connected
		# to the Gateway. Disconnected plants must not inflate city totals.
		if _has_gateway_road_access(building):
			total_power += int(definition.get("power", 0))
			total_water += int(definition.get("water", 0))

	# Power and water keep their local-radius service model, but demand is
	# derived from each home's explicit low/medium/high service-demand value.
	for home in homes:
		# Every household service requires a continuous road connection to the
		# permanent Gateway; otherwise capacity remains available but unserved.
		if not _has_gateway_road_access(home):
			continue
		var demand := get_home_service_demand(home)
		if used_power + demand <= total_power and _has_nearby_utility(home, "power"):
			used_power += demand
			power_served_ids[home.building_id] = true
		if used_water + demand <= total_water and _has_nearby_utility(home, "water"):
			used_water += demand
			water_served_ids[home.building_id] = true

	# Sewage and waste are city-wide capacity services: facilities and homes
	# must both be connected to the Gateway road network; no local radius applies.
	var sewage_remaining := total_sewage
	var waste_remaining := total_waste
	for home in homes:
		if not _has_gateway_road_access(home):
			continue
		var demand := get_home_service_demand(home)
		if sewage_remaining >= demand:
			sewage_remaining -= demand
			used_sewage += demand
			sewage_served_ids[home.building_id] = true
		if waste_remaining >= demand:
			waste_remaining -= demand
			used_waste += demand
			waste_served_ids[home.building_id] = true

	power_changed.emit(total_power, demand_power)
	water_changed.emit(total_water, demand_water)
	sewage_changed.emit(total_sewage, demand_sewage)
	waste_changed.emit(total_waste, demand_waste)
	if has_node("/root/HappinessManager"):
		HappinessManager.recalculate_city()
