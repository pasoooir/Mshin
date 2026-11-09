extends Node

signal home_smoking_changed(building_id: String, smoking: bool)
signal smoking_count_changed(count: int)

const WARNING_DELAY: float = 20.0
const COVERAGE_TILES: int = 15
const CHECK_INTERVAL: float = 0.25

var coverage_radius: float = 0.0
var unprotected_time: Dictionary = {} # building_id -> continuous uncovered seconds
var smoking_ids: Dictionary = {} # building_id -> true
var _check_elapsed: float = 0.0
var _radius_initialized: bool = false

func _ready() -> void:
	_update_coverage_radius()
	print("[FireHazardManager] Fire coverage online: %.1f world units" % coverage_radius)

func _update_coverage_radius() -> void:
	if _radius_initialized:
		return
	if not is_instance_valid(BuildManager):
		return
	coverage_radius = float(COVERAGE_TILES) * float(BuildManager.GRID_SIZE)
	_radius_initialized = true

func _process(delta: float) -> void:
	_check_elapsed += delta
	if _check_elapsed < CHECK_INTERVAL:
		return
	var elapsed := _check_elapsed
	_check_elapsed = 0.0
	_evaluate_hazards(elapsed)

func on_city_changed() -> void:
	_update_coverage_radius()
	_evaluate_hazards(0.0)

func _evaluate_hazards(delta: float) -> void:
	_update_coverage_radius()
	if not _radius_initialized:
		return

	var homes: Array[Node3D] = []
	var stations: Array[Node3D] = []
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		var definition: Dictionary = candidate.definition
		if str(definition.get("category", "")) == "residential":
			homes.append(candidate)
		elif int(definition.get("fire", 0)) > 0:
			stations.append(candidate)

	var active_home_ids: Dictionary = {}
	for home in homes:
		var building_id := str(home.building_id)
		active_home_ids[building_id] = true
		var covered := false
		for station in stations:
			if home.global_position.distance_to(station.global_position) <= coverage_radius:
				covered = true
				break

		if covered:
			unprotected_time.erase(building_id)
			if smoking_ids.has(building_id):
				smoking_ids.erase(building_id)
				if home.has_method("set_fire_smoke"):
					home.set_fire_smoke(false)
				home_smoking_changed.emit(building_id, false)
		else:
			var elapsed := float(unprotected_time.get(building_id, 0.0)) + delta
			unprotected_time[building_id] = elapsed
			if elapsed >= WARNING_DELAY and not smoking_ids.has(building_id):
				smoking_ids[building_id] = true
				if home.has_method("set_fire_smoke"):
					home.set_fire_smoke(true)
				home_smoking_changed.emit(building_id, true)

	var changed := false
	for building_id in unprotected_time.keys():
		if not active_home_ids.has(building_id):
			unprotected_time.erase(building_id)
			if smoking_ids.has(building_id):
				smoking_ids.erase(building_id)
				changed = true
			changed = true
	if changed:
		smoking_count_changed.emit(smoking_ids.size())
	elif smoking_ids.size() >= 0:
		# Keep the count signal useful to HUD listeners after the first evaluation.
		smoking_count_changed.emit(smoking_ids.size())
