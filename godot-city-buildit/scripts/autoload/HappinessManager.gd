extends Node

signal happiness_recalculated(city_average: float, home_scores: Dictionary)
signal household_population_changed(building_id: String, population: int)

const BASE_HAPPINESS := 30.0
const LOW_HAPPINESS_ABANDONMENT_THRESHOLD := 25.0
const ABANDONMENT_GRACE_SECONDS := 90.0
const RECALC_INTERVAL := 5.0
const PARK_RADIUS := 24.0
const INDUSTRIAL_POLLUTION_RADIUS := 42.0

var home_scores: Dictionary = {}
var low_happiness_time: Dictionary = {}
var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= RECALC_INTERVAL:
		_elapsed = 0.0
		recalculate_city()

func recalculate_city() -> void:
	var homes: Array = []
	var scores: Dictionary = {}
	var population_total := 0
	var happiness_total := 0.0
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		if str(building.definition.get("category", "")) != "residential":
			continue
		homes.append(building)
		var score := calculate_home_happiness(building)
		scores[building.building_id] = score
		happiness_total += score
		var capacity := _capacity_for_home(building)
		var service_factor := _service_capacity_factor(building)
		var target_population := roundi(float(capacity) * (score / 100.0) * service_factor)
		if score < LOW_HAPPINESS_ABANDONMENT_THRESHOLD:
			var elapsed := float(low_happiness_time.get(building.building_id, 0.0)) + RECALC_INTERVAL
			low_happiness_time[building.building_id] = elapsed
			if elapsed >= ABANDONMENT_GRACE_SECONDS:
				target_population = maxi(0, target_population - maxi(1, int(ceil(float(capacity) * 0.05))))
		else:
			low_happiness_time.erase(building.building_id)
		target_population = clampi(target_population, 0, capacity)
		if int(building.current_population) != target_population:
			building.current_population = target_population
			household_population_changed.emit(building.building_id, target_population)
		population_total += target_population

	var average := 100.0 if homes.is_empty() else happiness_total / float(homes.size())
	home_scores = scores
	GameManager.set_happiness(average)
	GameManager.set_population(population_total)
	happiness_recalculated.emit(average, home_scores)

func calculate_home_happiness(home: Node3D) -> float:
	var score := BASE_HAPPINESS
	var size: Vector2i = home.definition.get("size", Vector2i(2, 2))
	if not BuildManager.has_road_access(home.grid_pos, size):
		score -= 40.0

	# Do not punish a brand-new city before the player has unlocked/placed utility
	# infrastructure. Once a utility network exists, uncovered homes incur penalties.
	if ServiceManager.total_power > 0 and not ServiceManager.power_served_ids.has(home.building_id):
		score -= 25.0
	elif ServiceManager.power_served_ids.has(home.building_id):
		score += 15.0
	if ServiceManager.total_water > 0 and not ServiceManager.water_served_ids.has(home.building_id):
		score -= 20.0
	elif ServiceManager.water_served_ids.has(home.building_id):
		score += 15.0

	var park_bonus := _nearby_bonus(home, "park", PARK_RADIUS, 15.0)
	score += park_bonus
	var industrial_distance := _nearest_category_distance(home, "industrial")
	if industrial_distance < INDUSTRIAL_POLLUTION_RADIUS:
		score -= lerpf(30.0, 15.0, clampf(industrial_distance / INDUSTRIAL_POLLUTION_RADIUS, 0.0, 1.0))

	if _nearby_service(home, "fire_station", 38.0):
		score += 8.0
	if _nearby_service(home, "police_station", 38.0):
		score += 8.0
	if _nearby_service(home, "sewage_pipe", 30.0):
		score += 6.0
	if _nearby_service(home, "hospital", 42.0):
		score += 8.0
	return clampf(score, 0.0, 100.0)

func _capacity_for_home(home: Node3D) -> int:
	var base_capacity := int(home.definition.get("population", 15))
	return maxi(base_capacity, ProductionManager.get_population_for_stage(home.upgrade_stage))

func _service_capacity_factor(home: Node3D) -> float:
	var factor := 1.0
	if ServiceManager.total_power > 0 and not ServiceManager.power_served_ids.has(home.building_id):
		factor *= 0.65
	if ServiceManager.total_water > 0 and not ServiceManager.water_served_ids.has(home.building_id):
		factor *= 0.70
	return factor

func _nearby_bonus(home: Node3D, category: String, radius: float, bonus: float) -> float:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if str(candidate.definition.get("category", "")) == category and candidate.global_position.distance_to(home.global_position) <= radius:
			return bonus
	return 0.0

func _nearby_service(home: Node3D, type_id: String, radius: float) -> bool:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if candidate.building_type == type_id and candidate.global_position.distance_to(home.global_position) <= radius:
			return true
	return false

func _nearest_category_distance(home: Node3D, category: String) -> float:
	var nearest := INF
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if str(candidate.definition.get("category", "")) == category:
			nearest = minf(nearest, candidate.global_position.distance_to(home.global_position))
	return nearest

func get_home_happiness(building_id: String) -> float:
	return float(home_scores.get(building_id, BASE_HAPPINESS))
