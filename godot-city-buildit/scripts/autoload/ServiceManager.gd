extends Node

signal power_changed(total: int, demand: int)
signal water_changed(total: int, demand: int)
signal sewage_changed(total: int, demand: int)
signal waste_changed(total: int, demand: int)
signal workforce_changed(available: int, demand: int, employed: int)

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
var available_workers: int = 0
var demand_workers: int = 0
var employed_workers: int = 0
var workforce_served_ids: Dictionary = {}
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

# Mshin operating profiles: commercial and industrial production draw
# power, water, sewage, waste and workforce. Sewage/waste are gated only after
# their unlock levels; per-building operating_*_demand values override defaults.
const NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES := {
	"commercial": {"power": 1, "water": 1, "sewage": 1, "waste": 1, "workers": 1},
	"industrial": {"power": 2, "water": 1, "sewage": 2, "waste": 2, "workers": 2}
}
# Emergency stations are real operating buildings, not passive map decorations.
# Their Mshin service profile is intentionally explicit and separate from EA data.
const EMERGENCY_SERVICE_OPERATING_PROFILES := {
	"fire": {"power": 1, "water": 1, "sewage": 0, "waste": 0, "workers": 1},
	"police": {"power": 1, "water": 1, "sewage": 0, "waste": 0, "workers": 1},
	"health": {"power": 2, "water": 2, "sewage": 0, "waste": 0, "workers": 2},
	# Treatment and waste facilities must be staffed before their capacity is
	# counted. They do not consume their own sewage/waste service, avoiding a
	# circular dependency in the city-wide capacity calculation.
	"sewage": {"power": 0, "water": 0, "sewage": 0, "waste": 0, "workers": 1},
	"waste": {"power": 0, "water": 0, "sewage": 0, "waste": 0, "workers": 1}
}
# Mshin design assumption: 45% of residents are available for city employment.
# This is a transparent balancing parameter, not an EA-published demographic.
const WORKFORCE_SHARE := 0.45

func get_building_service_capacity(building: Node3D, capacity_key: String) -> int:
	if not is_instance_valid(building):
		return 0
	var base_capacity := maxi(0, int(building.definition.get(capacity_key, 0)))
	if str(building.definition.get("category", "")) != "service":
		return base_capacity
	var stage := maxi(1, int(building.get("upgrade_stage")))
	if stage <= 1 or base_capacity <= 0:
		return base_capacity
	# Mshin-only service-building upgrade effect: +10% capacity per completed
	# non-residential stage. This is a balance rule, not an EA value.
	return maxi(base_capacity, roundi(float(base_capacity) * (1.0 + 0.10 * float(stage - 1))))

func get_building_operating_profile(building: Node3D) -> Dictionary:
	if not is_instance_valid(building):
		return {}
	var category := str(building.definition.get("category", ""))
	if NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES.has(category):
		return NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES[category]
	var service_group := str(building.definition.get("service_group", ""))
	return EMERGENCY_SERVICE_OPERATING_PROFILES.get(service_group, {})

func get_building_utility_demand(building: Node3D, utility_key: String) -> int:
	if not is_instance_valid(building):
		return 0
	var definition: Dictionary = building.definition
	# Sewage and solid-waste systems unlock later in the mayor progression.
	# Before those systems are available, early-game production is not silently
	# hard-locked by infrastructure the player cannot yet build.
	if utility_key == "sewage" and GameManager.level < 8:
		return 0
	if utility_key == "waste" and GameManager.level < 14:
		return 0
	var override_key := "operating_%s_demand" % utility_key
	if definition.has(override_key):
		return maxi(0, int(definition.get(override_key, 0)))
	var profile := get_building_operating_profile(building)
	return maxi(0, int(profile.get(utility_key, 0)))

func requires_operational_utilities(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var profile := get_building_operating_profile(building)
	return not profile.is_empty() and (get_building_utility_demand(building, "power") > 0 or get_building_utility_demand(building, "water") > 0)

func requires_operational_sewage(building: Node3D) -> bool:
	return is_instance_valid(building) and get_building_utility_demand(building, "sewage") > 0

func requires_operational_waste(building: Node3D) -> bool:
	return is_instance_valid(building) and get_building_utility_demand(building, "waste") > 0

func get_building_worker_demand(building: Node3D) -> int:
	if not is_instance_valid(building):
		return 0
	var definition: Dictionary = building.definition
	if definition.has("operating_workers_required"):
		return maxi(0, int(definition.get("operating_workers_required", 0)))
	return maxi(0, int(get_building_operating_profile(building).get("workers", 0)))

func requires_operational_workforce(building: Node3D) -> bool:
	return is_instance_valid(building) and get_building_worker_demand(building) > 0 and not get_building_operating_profile(building).is_empty()

func is_workforce_served(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	if not requires_operational_workforce(building):
		return true
	return workforce_served_ids.has(building.building_id)

func _recalculate_workforce(consumers: Array, phase: String = "all") -> void:
	if phase == "providers" or phase == "all":
		available_workers = maxi(0, floori(float(GameManager.population) * WORKFORCE_SHARE))
		demand_workers = 0
		employed_workers = 0
		workforce_served_ids.clear()
		for consumer in consumers:
			demand_workers += get_building_worker_demand(consumer)
	# Treatment providers are staffed before their capacity is counted. They
	# need road access and configured non-circular prerequisites, but never the
	# sewage/waste service capacity that they themselves supply.
	for consumer in consumers:
		var service_group := str(consumer.definition.get("service_group", ""))
		var is_treatment_provider := service_group in ["sewage", "waste"]
		if phase == "providers" and not is_treatment_provider:
			continue
		if phase == "consumers" and is_treatment_provider:
			continue
		if not _has_gateway_road_access(consumer):
			continue
		var prerequisites_met := is_building_served(consumer) if phase == "providers" else is_building_services_served(consumer)
		if not prerequisites_met:
			continue
		var required := get_building_worker_demand(consumer)
		if required <= 0 or employed_workers + required > available_workers:
			continue
		employed_workers += required
		workforce_served_ids[consumer.building_id] = true
	if phase == "consumers" or phase == "all":
		workforce_changed.emit(available_workers, demand_workers, employed_workers)

func _ready() -> void:
	GameManager.level_changed.connect(_on_mayor_level_changed)
	print("[ServiceManager] Power/water/sewage/waste capacity network online")

func _on_mayor_level_changed(_new_level: int) -> void:
	# Re-evaluate every existing household immediately after a service unlock.
	recalculate_from_buildings()

func get_home_service_demand(home: Node3D) -> int:
	if not is_instance_valid(home):
		return 1
	return maxi(1, int(home.definition.get("service_demand", 1)))

func get_home_utility_demand(home: Node3D, utility_key: String) -> int:
	if not is_instance_valid(home):
		return 0
	# Household utilities are phased in with their infrastructure unlocks.
	if utility_key in ["power", "water"] and GameManager.level < 2:
		return 0
	if utility_key == "sewage" and GameManager.level < 8:
		return 0
	if utility_key == "waste" and GameManager.level < 14:
		return 0
	return get_home_service_demand(home)

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
		var definition: Dictionary = candidate.definition
		# Water suppliers are identified by their actual positive catalog
		# capacity, never by display name or a hard-coded building ID.
		if utility_key == "water":
			if int(definition.get("water", 0)) <= 0:
				continue
		elif int(definition.get(utility_key, 0)) <= 0:
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
	var power_demand := get_building_utility_demand(building, "power")
	var water_demand := get_building_utility_demand(building, "water")
	var power_ok := power_demand <= 0 or power_served_ids.has(building.building_id)
	var water_ok := water_demand <= 0 or water_served_ids.has(building.building_id)
	return power_ok and water_ok

func is_sewage_served(building: Node3D) -> bool:
	return is_instance_valid(building) and (not requires_operational_sewage(building) or sewage_served_ids.has(building.building_id))

func is_waste_served(building: Node3D) -> bool:
	return is_instance_valid(building) and (not requires_operational_waste(building) or waste_served_ids.has(building.building_id))

func is_building_services_served(building: Node3D) -> bool:
	if not is_instance_valid(building) or not is_building_served(building):
		return false
	if not is_sewage_served(building) or not is_waste_served(building):
		return false
	return true

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
		# Coverage is delivered only by an operational station: road, power,
		# water and the station's allocated workforce must all be present.
		if not BuildManager.is_building_operational(candidate):
			continue
		var coverage_tiles := maxf(0.0, float(definition.get("coverage_tiles", DEFAULT_EMERGENCY_COVERAGE_TILES)))
		coverage_tiles *= 1.0 + 0.05 * float(maxi(0, int(candidate.get("upgrade_stage")) - 1))
		var radius := coverage_tiles * float(BuildManager.GRID_SIZE)
		var facility_flat := Vector2(candidate.global_position.x, candidate.global_position.z)
		if home_flat.distance_to(facility_flat) <= radius:
			return true
	return false

func recalculate_from_buildings() -> void:
	# Synchronize occupied household population against the previous completed
	# service snapshot before allocating staff. This prevents workforce from
	# using a stale GameManager.population during a same-frame service outage or
	# household occupancy change. Final happiness is recalculated after the new
	# service/coverage maps are committed below.
	if has_node("/root/HappinessManager"):
		HappinessManager.recalculate_city()
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
	var operating_consumers: Array = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var definition: Dictionary = building.definition
		var category := str(definition.get("category", ""))
		var service_group := str(definition.get("service_group", ""))
		if category == "residential":
			homes.append(building)
			demand_power += get_home_utility_demand(building, "power")
			demand_water += get_home_utility_demand(building, "water")
			demand_sewage += get_home_utility_demand(building, "sewage")
			demand_waste += get_home_utility_demand(building, "waste")
		elif NON_RESIDENTIAL_UTILITY_DEMAND_PROFILES.has(category) or EMERGENCY_SERVICE_OPERATING_PROFILES.has(service_group):
			operating_consumers.append(building)
			demand_power += get_building_utility_demand(building, "power")
			demand_water += get_building_utility_demand(building, "water")
			demand_sewage += get_building_utility_demand(building, "sewage")
			demand_waste += get_building_utility_demand(building, "waste")
		# Sewage/waste providers are included in operating_consumers so their
		# staff can be allocated before their capacity is counted below.
		# Capacity is operational only while the facility itself is connected
		# to the Gateway. Disconnected plants must not inflate city totals.
		if _has_gateway_road_access(building):
			total_power += get_building_service_capacity(building, "power")
			total_water += get_building_service_capacity(building, "water")

	# Power and water keep their local-radius service model, but household demand
	# begins only at Level 2. Before unlock, each home is treated as satisfied.
	for home in homes:
		var power_demand := get_home_utility_demand(home, "power")
		var water_demand := get_home_utility_demand(home, "water")
		if power_demand <= 0:
			power_served_ids[home.building_id] = true
		if water_demand <= 0:
			water_served_ids[home.building_id] = true
		if not _has_gateway_road_access(home):
			continue
		if power_demand > 0 and used_power + power_demand <= total_power and _has_nearby_utility(home, "power"):
			used_power += power_demand
			power_served_ids[home.building_id] = true
		if water_demand > 0 and used_water + water_demand <= total_water and _has_nearby_utility(home, "water"):
			used_water += water_demand
			water_served_ids[home.building_id] = true

	# Non-residential production is allocated after household demand so
	# industrial/commercial buildings cannot silently consume the household
	# utility reserve. A producer needs both a Gateway road and local utility
	# coverage before its ProductionComponent may run.
	for consumer in operating_consumers:
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

	# Staff treatment and waste facilities before counting their city-wide
	# capacity. An unstaffed/disconnected plant contributes zero capacity.
	_recalculate_workforce(operating_consumers, "providers")
	for provider in BuildManager.buildings.values():
		if not is_instance_valid(provider) or provider.status != "completed":
			continue
		var provider_group := str(provider.definition.get("service_group", ""))
		if provider_group == "sewage" and BuildManager.is_building_operational(provider):
			total_sewage += get_building_service_capacity(provider, "sewage")
		elif provider_group == "waste" and BuildManager.is_building_operational(provider):
			total_waste += get_building_service_capacity(provider, "waste")

	# Sewage and waste are city-wide services and household demand starts only
	# at their own unlock levels. Unlocked demand still has household priority.
	var sewage_remaining := total_sewage
	var waste_remaining := total_waste
	for home in homes:
		var sewage_demand := get_home_utility_demand(home, "sewage")
		var waste_demand := get_home_utility_demand(home, "waste")
		if sewage_demand <= 0:
			sewage_served_ids[home.building_id] = true
		if waste_demand <= 0:
			waste_served_ids[home.building_id] = true
		if not _has_gateway_road_access(home):
			continue
		if sewage_demand > 0 and sewage_remaining >= sewage_demand:
			sewage_remaining -= sewage_demand
			used_sewage += sewage_demand
			sewage_served_ids[home.building_id] = true
		if waste_demand > 0 and waste_remaining >= waste_demand:
			waste_remaining -= waste_demand
			used_waste += waste_demand
			waste_served_ids[home.building_id] = true
	for consumer in operating_consumers:
		if not _has_gateway_road_access(consumer):
			continue
		var sewage_need := get_building_utility_demand(consumer, "sewage")
		var waste_need := get_building_utility_demand(consumer, "waste")
		if sewage_need <= 0 or sewage_remaining >= sewage_need:
			if sewage_need > 0:
				sewage_remaining -= sewage_need
				used_sewage += sewage_need
				sewage_served_ids[consumer.building_id] = true
		if waste_need <= 0 or waste_remaining >= waste_need:
			if waste_need > 0:
				waste_remaining -= waste_need
				used_waste += waste_need
				waste_served_ids[consumer.building_id] = true

	# Staff remaining producers and emergency facilities after their complete
	# road, utility, sewage and waste service prerequisites have been allocated.
	_recalculate_workforce(operating_consumers, "consumers")

	# Fire, Police and Health coverage is valid only while the provider itself
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
	if has_node("/root/HappinessManager"):
		# Apply the newly established emergency coverage to final home scores.
		HappinessManager.recalculate_city()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
