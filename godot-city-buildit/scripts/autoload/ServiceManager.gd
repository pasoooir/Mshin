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
var fire_served_ids: Dictionary = {}
var police_served_ids: Dictionary = {}
var health_served_ids: Dictionary = {}
var demand_fire_homes: int = 0
var served_fire_homes: int = 0
var demand_police_homes: int = 0
var served_police_homes: int = 0
var demand_health_homes: int = 0
var served_health_homes: int = 0

const DEFAULT_EMERGENCY_COVERAGE_TILES := 15.0

# Mshin operating-cost profiles: commercial production buildings require one
# unit each of power/water; industrial producers require two power and one
# water. Per-building operating_*_demand values override these design defaults.
const NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES := {
	"commercial": {"power": 1, "water": 1},
	"industrial": {"power": 2, "water": 1}
}

func get_building_utility_demand(building: Node3D, utility_key: String) -> int:
	if not is_instance_valid(building):
		return 0
	var definition: Dictionary = building.definition
	var override_key := "operating_%s_demand" % utility_key
	if definition.has(override_key):
		return maxi(0, int(definition.get(override_key, 0)))
	var category := str(definition.get("category", ""))
	var profile: Dictionary = NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES.get(category, {})
	return maxi(0, int(profile.get(utility_key, 0)))

func requires_operational_utilities(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var category := str(building.definition.get("category", ""))
	if not NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES.has(category):
		return false
	return get_building_utility_demand(building, "power") > 0 or get_building_utility_demand(building, "water") > 0

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
	if not requires_operational_utilities(building):
		return true
	var power_demand := get_building_utility_demand(building, "power")
	var water_demand := get_building_utility_demand(building, "water")
	var power_ok := power_demand <= 0 or power_served_ids.has(building.building_id)
	var water_ok := water_demand <= 0 or water_served_ids.has(building.building_id)
	return power_ok and water_ok

func is_sewage_served(building: Node3D) -> bool:
	return is_instance_valid(building) and sewage_served_ids.has(building.building_id)

func is_waste_served(building: Node3D) -> bool:
	return is_instance_valid(building) and waste_served_ids.has(building.building_id)

func is_home_served_by_group(home: Node3D, service_group: String) -> bool:
	if not is_instance_valid(home):
		return false
	match service_group:
		"power":
			return power_served_ids.has(home.building_id)
		"water":
			return water_served_ids.has(home.building_id)
		"sewage":
			return sewage_served_ids.has(home.building_id)
		"waste":
			return waste_served_ids.has(home.building_id)
		"fire":
			return fire_served_ids.has(home.building_id)
		"police":
			return police_served_ids.has(home.building_id)
		"health":
			return health_served_ids.has(home.building_id)
		_:
			return false

func _has_nearby_emergency_facility(home: Node3D, service_group: String) -> bool:
	if not _has_gateway_road_access(home):
		return false
	var home_flat := Vector2(home.global_position.x, home.global_position.z)
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		var definition: Dictionary = candidate.definition
		if str(definition.get("service_group", "")) != service_group:
			continue
		# Emergency coverage is only operational when the station is connected
		# to the permanent Gateway road network.
		if not _has_gateway_road_access(candidate):
			continue
		var coverage_tiles := maxf(0.0, float(definition.get("coverage_tiles", DEFAULT_EMERGENCY_COVERAGE_TILES)))
		var radius := coverage_tiles * float(BuildManager.GRID_SIZE)
		var facility_flat := Vector2(candidate.global_position.x, candidate.global_position.z)
		if home_flat.distance_to(facility_flat) <= radius:
			return true
	return false

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
	fire_served_ids.clear()
	police_served_ids.clear()
	health_served_ids.clear()
	demand_fire_homes = 0
	served_fire_homes = 0
	demand_police_homes = 0
	served_police_homes = 0
	demand_health_homes = 0
	served_health_homes = 0

	var homes: Array = []
	var non_residential_consumers: Array = []
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
		elif NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES.has(category):
			non_residential_consumers.append(building)
			demand_power += get_building_utility_demand(building, "power")
			demand_water += get_building_utility_demand(building, "water")
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

	# Non-residential production is allocated after household demand so
	# industrial/commercial buildings cannot silently consume the household
	# utility reserve. A producer needs both a Gateway road and local utility
	# coverage before its ProductionComponent may run.
	for consumer in non_residential_consumers:
		if not _has_gateway_road_access(consumer):
			continue
		var power_need := get_building_utility_demand(consumer, "power")
		var water_need := get_building_utility_demand(consumer, "water")
		if power_need <= 0 or (used_power + power_need <= total_power and _has_nearby_utility(consumer, "power")):
			if power_need > 0:
				used_power += power_need
				power_served_ids[consumer.building_id] = true
		if water_need <= 0 or (used_water + water_need <= total_water and _has_nearby_utility(consumer, "water")):
			if water_need > 0:
				used_water += water_need
				water_served_ids[consumer.building_id] = true

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

	# Fire, Police and Health are local coverage services rather than city-wide
	# capacity pools. A home and its provider must both be Gateway-connected.
	# Coverage distance is read from each catalog tier's coverage_tiles metadata.
	for home in homes:
		if _has_nearby_emergency_facility(home, "fire"):
			fire_served_ids[home.building_id] = true
		if _has_nearby_emergency_facility(home, "police"):
			police_served_ids[home.building_id] = true
		if _has_nearby_emergency_facility(home, "health"):
			health_served_ids[home.building_id] = true

	# These three services are area-coverage systems, not numerical capacity
	# pools. Expose covered-home counts so the HUD reports measurable coverage.
	demand_fire_homes = homes.size()
	served_fire_homes = fire_served_ids.size()
	demand_police_homes = homes.size()
	served_police_homes = police_served_ids.size()
	demand_health_homes = homes.size()
	served_health_homes = health_served_ids.size()

	power_changed.emit(total_power, demand_power)
	water_changed.emit(total_water, demand_water)
	sewage_changed.emit(total_sewage, demand_sewage)
	waste_changed.emit(total_waste, demand_waste)
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	if has_node("/root/HappinessManager"):
		HappinessManager.recalculate_city()
