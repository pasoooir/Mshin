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
var workforce_available: int = 0
var workforce_assigned: int = 0
var workforce_assigned_by_id: Dictionary = {}
var operational_blockers_by_id: Dictionary = {}

const DEFAULT_EMERGENCY_COVERAGE_TILES := 15.0
const MSHIN_WORKFORCE_SUPPLY_RATIO: float = 0.40

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
		if not _has_workforce_for_provider(candidate):
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

func get_operational_blockers(building: Node3D) -> Array[String]:
	if not is_instance_valid(building):
		return ["Building is unavailable"]
	var requirements := BuildManager.get_operational_requirements(str(building.building_type))
	if requirements.is_empty():
		return []
	var stored: Array = operational_blockers_by_id.get(str(building.building_id), [])
	var result: Array[String] = []
	for reason in stored:
		result.append(str(reason))
	if result.is_empty() and not operational_blockers_by_id.has(str(building.building_id)):
		result.append("Operational services have not been recalculated")
	return result

func is_building_operational(building: Node3D) -> bool:
	return is_instance_valid(building) and get_operational_blockers(building).is_empty()

func _has_workforce_for_provider(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var requirements := BuildManager.get_operational_requirements(str(building.building_type))
	var workforce_needed := int(requirements.get("workforce", 0))
	return workforce_needed <= 0 or workforce_assigned_by_id.has(str(building.building_id))

func is_building_served(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	return power_served_ids.has(building.building_id) and water_served_ids.has(building.building_id)

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
		if not _has_workforce_for_provider(candidate):
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

func _workforce_priority(building: Node3D) -> int:
	var category := str(building.definition.get("category", ""))
	if category == "service":
		return 0
	if category == "industrial":
		return 1
	if category == "commercial":
		return 2
	return 3

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
	workforce_available = maxi(0, int(floor(float(GameManager.population) * MSHIN_WORKFORCE_SUPPLY_RATIO)))
	workforce_assigned = 0
	workforce_assigned_by_id.clear()
	operational_blockers_by_id.clear()

	var homes: Array[Node3D] = []
	var operating_buildings: Array[Node3D] = []
	var completed_buildings: Array[Node3D] = []
	for building_variant in BuildManager.buildings.values():
		if not is_instance_valid(building_variant) or building_variant.status != "completed":
			continue
		var building := building_variant as Node3D
		completed_buildings.append(building)
		var definition: Dictionary = building.definition
		var category := str(definition.get("category", ""))
		if category == "residential":
			homes.append(building)
			demand_power += get_home_service_demand(building)
			demand_water += get_home_service_demand(building)
			demand_sewage += get_home_service_demand(building)
			demand_waste += get_home_service_demand(building)
		else:
			var requirements := BuildManager.get_operational_requirements(str(building.building_type))
			if not requirements.is_empty():
				operating_buildings.append(building)

	# Allocate workforce deterministically: service providers first, then
	# industrial production, then commercial shops. Mshin uses 40% of residents
	# as its available workforce pool; this is a game-design rule, not SCBI data.
	operating_buildings.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_priority := int(a.definition.get("workforce_priority", _workforce_priority(a)))
		var b_priority := int(b.definition.get("workforce_priority", _workforce_priority(b)))
		if a_priority == b_priority:
			return str(a.building_id) < str(b.building_id)
		return a_priority < b_priority
	)
	for building in operating_buildings:
		var requirements := BuildManager.get_operational_requirements(str(building.building_type))
		var required_workforce := maxi(0, int(requirements.get("workforce", 0)))
		var blockers: Array[String] = []
		if not _has_gateway_road_access(building):
			blockers.append("Road access: building is disconnected from the Gateway")
		if required_workforce > 0:
			var remaining_workforce := workforce_available - workforce_assigned
			if remaining_workforce >= required_workforce:
				workforce_assigned += required_workforce
				workforce_assigned_by_id[str(building.building_id)] = required_workforce
			else:
				blockers.append("Workforce: requires %d, only %d unassigned" % [required_workforce, maxi(0, remaining_workforce)])
		operational_blockers_by_id[str(building.building_id)] = blockers

	# Only staffed, road-connected utility buildings contribute capacity.
	for building in completed_buildings:
		var definition: Dictionary = building.definition
		if not _has_gateway_road_access(building):
			continue
		var requirements := BuildManager.get_operational_requirements(str(building.building_type))
		if int(requirements.get("workforce", 0)) > 0 and not workforce_assigned_by_id.has(str(building.building_id)):
			continue
		if str(definition.get("service_group", "")) == "sewage":
			total_sewage += int(definition.get("sewage", 0))
		elif str(definition.get("service_group", "")) == "waste":
			total_waste += int(definition.get("waste", 0))
		total_power += int(definition.get("power", 0))
		total_water += int(definition.get("water", 0))

	# Household allocation retains its existing priority and local utility model.
	for home in homes:
		if not _has_gateway_road_access(home):
			continue
		var demand := get_home_service_demand(home)
		if used_power + demand <= total_power and _has_nearby_utility(home, "power"):
			used_power += demand
			power_served_ids[home.building_id] = true
		if used_water + demand <= total_water and _has_nearby_utility(home, "water"):
			used_water += demand
			water_served_ids[home.building_id] = true

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

	# Allocate remaining utility capacity to commercial/industrial buildings.
	# Each requirement is independent and every shortage is retained as a
	# player-readable blocker instead of silently stopping production.
	for building in operating_buildings:
		var building_id := str(building.building_id)
		var blockers: Array[String] = operational_blockers_by_id.get(building_id, [])
		var requirements := BuildManager.get_operational_requirements(str(building.building_type))
		if not _has_gateway_road_access(building):
			operational_blockers_by_id[building_id] = blockers
			continue
		if int(requirements.get("workforce", 0)) > 0 and not workforce_assigned_by_id.has(building_id):
			operational_blockers_by_id[building_id] = blockers
			continue
		var power_need := maxi(0, int(requirements.get("power", 0)))
		if power_need > 0:
			demand_power += power_need
			if used_power + power_need <= total_power and _has_nearby_utility(building, "power"):
				used_power += power_need
				power_served_ids[building_id] = true
			else:
				blockers.append("Power: requires %d capacity and a connected nearby utility" % power_need)
		var water_need := maxi(0, int(requirements.get("water", 0)))
		if water_need > 0:
			demand_water += water_need
			if used_water + water_need <= total_water and _has_nearby_utility(building, "water"):
				used_water += water_need
				water_served_ids[building_id] = true
			else:
				blockers.append("Water: requires %d capacity and a connected nearby utility" % water_need)
		var sewage_need := maxi(0, int(requirements.get("sewage", 0)))
		if sewage_need > 0:
			demand_sewage += sewage_need
			if sewage_remaining >= sewage_need:
				sewage_remaining -= sewage_need
				used_sewage += sewage_need
				sewage_served_ids[building_id] = true
			else:
				blockers.append("Sewage: requires %d unassigned capacity" % sewage_need)
		var waste_need := maxi(0, int(requirements.get("waste", 0)))
		if waste_need > 0:
			demand_waste += waste_need
			if waste_remaining >= waste_need:
				waste_remaining -= waste_need
				used_waste += waste_need
				waste_served_ids[building_id] = true
			else:
				blockers.append("Waste: requires %d unassigned capacity" % waste_need)
		for emergency_group in ["fire", "police", "health"]:
			if int(requirements.get(emergency_group, 0)) <= 0:
				continue
			if _has_nearby_emergency_facility(building, emergency_group):
				match emergency_group:
					"fire": fire_served_ids[building_id] = true
					"police": police_served_ids[building_id] = true
					"health": health_served_ids[building_id] = true
			else:
				blockers.append("%s coverage is unavailable" % emergency_group.capitalize())
		operational_blockers_by_id[building_id] = blockers

	# Residential emergency-service coverage remains a local, non-capacity system.
	for home in homes:
		if _has_nearby_emergency_facility(home, "fire"):
			fire_served_ids[home.building_id] = true
		if _has_nearby_emergency_facility(home, "police"):
			police_served_ids[home.building_id] = true
		if _has_nearby_emergency_facility(home, "health"):
			health_served_ids[home.building_id] = true

	demand_fire_homes = homes.size()
	served_fire_homes = homes.filter(func(home: Node3D) -> bool: return fire_served_ids.has(str(home.building_id))).size()
	demand_police_homes = homes.size()
	served_police_homes = homes.filter(func(home: Node3D) -> bool: return police_served_ids.has(str(home.building_id))).size()
	demand_health_homes = homes.size()
	served_health_homes = homes.filter(func(home: Node3D) -> bool: return health_served_ids.has(str(home.building_id))).size()

	power_changed.emit(total_power, demand_power)
	water_changed.emit(total_water, demand_water)
	sewage_changed.emit(total_sewage, demand_sewage)
	waste_changed.emit(total_waste, demand_waste)
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	if has_node("/root/HappinessManager"):
		HappinessManager.recalculate_city()
