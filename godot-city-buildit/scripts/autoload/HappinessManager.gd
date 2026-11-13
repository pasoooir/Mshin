extends Node

signal happiness_recalculated(city_average: float, home_scores: Dictionary)
signal household_population_changed(building_id: String, population: int)
signal immigrants_arrived(amount: int, city_population: int)
signal immigration_advice(message: String)

const BASE_HAPPINESS := 100.0
const LOW_HAPPINESS_ABANDONMENT_THRESHOLD := 25.0
const ABANDONMENT_GRACE_SECONDS := 90.0
const RECALC_INTERVAL := 5.0
const IMMIGRATION_INTERVAL := 10.0
const IMMIGRATION_MIN_HAPPINESS := 60.0
const PARK_RADIUS := 24.0
const INDUSTRIAL_POLLUTION_RADIUS := 42.0
const FIRE_SERVICE_GROUP := "fire"
const POLICE_SERVICE_GROUP := "police"
const HEALTH_SERVICE_GROUP := "health"

var home_scores: Dictionary = {}
var low_happiness_time: Dictionary = {}
var _elapsed := 0.0
var _high_happiness_elapsed := 0.0
var _immigration_elapsed := 0.0
var _immigration_fractional_carry := 0.0
var _immigration_advice_elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	_immigration_elapsed += delta
	_immigration_advice_elapsed += delta
	if _elapsed >= RECALC_INTERVAL:
		_elapsed = 0.0
		recalculate_city()
	if _immigration_elapsed >= IMMIGRATION_INTERVAL:
		_immigration_elapsed = 0.0
		_process_immigration()

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
		# Establish the initial occupied population once. Immigration fills
		# vacant capacity gradually and is not overwritten by periodic refreshes.
		if not building.has_meta("immigration_population_initialized"):
			var initial_service_factor := _service_capacity_factor(building)
			building.current_population = roundi(float(capacity) * (score / 100.0) * initial_service_factor)
			building.current_population = clampi(building.current_population, 0, capacity)
			building.set_meta("immigration_population_initialized", true)
			household_population_changed.emit(building.building_id, building.current_population)
		if score < LOW_HAPPINESS_ABANDONMENT_THRESHOLD:
			var elapsed := float(low_happiness_time.get(building.building_id, 0.0)) + RECALC_INTERVAL
			low_happiness_time[building.building_id] = elapsed
			if elapsed >= ABANDONMENT_GRACE_SECONDS:
				building.current_population = maxi(0, int(building.current_population) - 1)
				household_population_changed.emit(building.building_id, building.current_population)
		else:
			low_happiness_time.erase(building.building_id)
		building.current_population = clampi(int(building.current_population), 0, capacity)
		population_total += int(building.current_population)

	var average := 100.0 if homes.is_empty() else happiness_total / float(homes.size())
	if not homes.is_empty() and average >= 80.0:
		_high_happiness_elapsed += RECALC_INTERVAL
		if _high_happiness_elapsed >= 60.0:
			_high_happiness_elapsed = 0.0
			GameManager.add_experience(5)
	else:
		_high_happiness_elapsed = 0.0
	home_scores = scores
	GameManager.set_happiness(average)
	GameManager.set_population(population_total)
	EconomyManager.set_tax_income(roundi(float(population_total) * (average / 100.0) * 0.15))
	happiness_recalculated.emit(average, home_scores)

 
func _process_immigration() -> void:
	var homes: Array = []
	var total_capacity := 0
	var current_population := 0
	var city_has_power := false
	var city_has_water := false
	var city_has_extra_service := false
	var has_abandoning_house := false
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		if str(building.definition.get("category", "")) != "residential":
			continue
		homes.append(building)
		total_capacity += _capacity_for_home(building)
		current_population += int(building.current_population)
		city_has_power = city_has_power or ServiceManager.power_served_ids.has(building.building_id)
		city_has_water = city_has_water or ServiceManager.water_served_ids.has(building.building_id)
		city_has_extra_service = city_has_extra_service or _home_has_extra_service(building)
		if float(low_happiness_time.get(building.building_id, 0.0)) > 0.0:
			has_abandoning_house = true

	var empty_capacity := maxi(0, total_capacity - current_population)
	if homes.is_empty() or empty_capacity <= 0:
		_immigration_fractional_carry = 0.0
		return
	var average_happiness := GameManager.happiness
	if average_happiness < 25.0:
		_immigration_fractional_carry = 0.0
		return
	if average_happiness < IMMIGRATION_MIN_HAPPINESS or has_abandoning_house:
		if _immigration_advice_elapsed >= 30.0:
			immigration_advice.emit("Citizens need better services and parks. Improve city coverage to attract more residents.")
			_immigration_advice_elapsed = 0.0
		return

	var happiness_factor := _immigration_happiness_factor(average_happiness)
	var service_factor := _immigration_service_factor(city_has_power, city_has_water, city_has_extra_service)
	var attraction_rate := float(empty_capacity) * happiness_factor * service_factor * 0.12
	_immigration_fractional_carry += attraction_rate
	var new_people := mini(empty_capacity, int(floor(_immigration_fractional_carry)))
	if new_people <= 0:
		return
	_immigration_fractional_carry -= float(new_people)

	homes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _immigration_priority(a) > _immigration_priority(b)
	)
	var remaining := new_people
	while remaining > 0:
		var assigned_this_round := 0
		for home in homes:
			if remaining <= 0:
				break
			if int(home.current_population) >= _capacity_for_home(home):
				continue
			if get_home_happiness(home.building_id) < IMMIGRATION_MIN_HAPPINESS:
				continue
			home.current_population += 1
			remaining -= 1
			assigned_this_round += 1
			household_population_changed.emit(home.building_id, home.current_population)
		if assigned_this_round == 0:
			break

	var arrived := new_people - remaining
	if arrived > 0:
		var updated_population := current_population + arrived
		GameManager.set_population(updated_population)
		immigrants_arrived.emit(arrived, updated_population)

func _immigration_happiness_factor(happiness: float) -> float:
	if happiness >= 90.0:
		return 1.0
	if happiness >= 80.0:
		return 0.8
	if happiness >= 70.0:
		return 0.55
	return 0.3

func _immigration_service_factor(has_power: bool, has_water: bool, has_extra: bool) -> float:
	if has_power and has_water:
		return 1.15 if has_extra else 1.0
	if has_power or has_water:
		return 0.7
	return 0.4

func _home_has_extra_service(home: Node3D) -> bool:
	if _nearby_bonus(home, "park", PARK_RADIUS, 1.0) > 0.0:
		return true
	if _nearby_service_group(home, FIRE_SERVICE_GROUP, 38.0):
		return true
	if _nearby_service_group(home, POLICE_SERVICE_GROUP, 38.0):
		return true
	if _nearby_sewage_service(home):
		return true
	if _nearby_waste_service(home):
		return true
	if _nearby_service_group(home, HEALTH_SERVICE_GROUP, 42.0):
		return true
	return false

func _immigration_priority(home: Node3D) -> float:
	var score := get_home_happiness(home.building_id) * 2.0
	if ServiceManager.power_served_ids.has(home.building_id):
		score += 12.0
	if ServiceManager.water_served_ids.has(home.building_id):
		score += 12.0
	if _home_has_extra_service(home):
		score += 10.0
	var nearest_service := INF
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		var category := str(candidate.definition.get("category", ""))
		if category == "service" or category == "park":
			nearest_service = minf(nearest_service, candidate.global_position.distance_to(home.global_position))
	if nearest_service < INF:
		score += maxf(0.0, 20.0 - nearest_service * 0.25)
	return score


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

	if _nearby_service_group(home, FIRE_SERVICE_GROUP, 38.0):
		score += 8.0
	if _nearby_service_group(home, POLICE_SERVICE_GROUP, 38.0):
		score += 8.0
	# Sewage demand begins at City Level 8; Waste Management begins at Level 14.
	# A served home keeps the existing +6 Mshin service bonus; an unmet demand
	# applies the corresponding -6 shortage penalty.
	if GameManager.level >= 8 and ServiceManager.demand_sewage > 0:
		if ServiceManager.sewage_served_ids.has(home.building_id):
			score += 6.0
		else:
			score -= 6.0
	if GameManager.level >= 14 and ServiceManager.demand_waste > 0:
		if ServiceManager.waste_served_ids.has(home.building_id):
			score += 6.0
		else:
			score -= 6.0
	if _nearby_service_group(home, HEALTH_SERVICE_GROUP, 42.0):
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

func _nearby_service_group(home: Node3D, service_group: String, radius: float) -> bool:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if str(candidate.definition.get("service_group", "")) != service_group:
			continue
		if candidate.global_position.distance_to(home.global_position) <= radius:
			return true
	return false

func _nearby_service(home: Node3D, type_id: String, radius: float) -> bool:
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		if candidate.building_type == type_id and candidate.global_position.distance_to(home.global_position) <= radius:
			return true
	return false

func _nearby_sewage_service(home: Node3D, _radius: float = 0.0) -> bool:
	return is_instance_valid(home) and ServiceManager.sewage_served_ids.has(home.building_id)

func _nearby_waste_service(home: Node3D, _radius: float = 0.0) -> bool:
	return is_instance_valid(home) and ServiceManager.waste_served_ids.has(home.building_id)

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
