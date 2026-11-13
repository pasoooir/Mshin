extends Node

signal project_changed(building_id: String, project_state: Dictionary)
signal epic_building_created(building_id: String, tier: int)

const DEPARTMENT_LEVEL := 16
const PROJECT_LEVEL := 24
const PROJECT_TARGET_POINTS := 40
const PROJECT_DURATION_SECONDS := 86400
const SPECIALIZATION_RADIUS := 48.0
const EPIC_POPULATION_BONUS := 1.25

var active_projects: Dictionary = {}
var epic_tokens: Dictionary = {"turtle": 0, "llama": 0, "cheetah": 0}

func _process(_delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	for project_id in active_projects.keys():
		var state: Dictionary = active_projects[project_id]
		if str(state.get("status", "")) == "active" and int(state.get("expires_unix", 0)) > 0 and int(state.get("expires_unix", 0)) <= now:
			active_projects.erase(project_id)
			project_changed.emit(str(project_id), {})

func has_department() -> bool:
	if GameManager.level < DEPARTMENT_LEVEL:
		return false
	for building in BuildManager.buildings.values():
		if is_instance_valid(building) and str(building.get("building_type")) == "epic_department" and str(building.get("status")) == "completed":
			return true
	return false

func is_epic_building(home: Node) -> bool:
	return is_instance_valid(home) and int(home.get("epic_tier")) > 0

func get_nearby_specialization_sources(home: Node3D) -> Array:
	var sources: Array = []
	if not is_instance_valid(home):
		return sources
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or candidate.status != "completed":
			continue
		var points := int(candidate.definition.get("epic_points", 0))
		if points <= 0:
			continue
		if candidate.global_position.distance_to(home.global_position) <= SPECIALIZATION_RADIUS:
			sources.append(candidate)
	return sources

func get_nearby_specialization_points(home: Node3D) -> int:
	var total := 0
	for source in get_nearby_specialization_sources(home):
		total += int(source.definition.get("epic_points", 0))
	return total

func can_start_project(home: Node3D) -> bool:
	if not is_instance_valid(home) or GameManager.level < PROJECT_LEVEL or not has_department():
		return false
	var home_definition: Dictionary = home.get("definition")
	if str(home.get("status")) != "completed" or str(home_definition.get("category", "")) != "residential":
		return false
	if int(home.get("upgrade_stage")) < 6 or is_epic_building(home) or active_projects.has(str(home.get("building_id"))):
		return false
	return get_nearby_specialization_points(home) >= PROJECT_TARGET_POINTS

func get_start_block_reason(home: Node3D) -> String:
	if GameManager.level < DEPARTMENT_LEVEL:
		return "Department of Epic Projects unlocks at Level 16."
	if not has_department():
		return "Build and complete the Department of Epic Projects."
	if GameManager.level < PROJECT_LEVEL:
		return "Epic Projects unlock at Level 24."
	if not is_instance_valid(home) or str(home.get("status")) != "completed":
		return "Select a completed residential building."
	var home_definition: Dictionary = home.get("definition")
	if str(home_definition.get("category", "")) != "residential":
		return "Epic Projects apply to residential buildings only."
	if int(home.get("upgrade_stage")) < 6:
		return "Upgrade this home to Residential Level 6 first."
	if is_epic_building(home):
		return "This home is already an Epic Building."
	if active_projects.has(str(home.get("building_id"))):
		return "This home already has an active Epic Project."
	if get_nearby_specialization_points(home) < PROJECT_TARGET_POINTS:
		return "Build enough Parks within 48 meters to provide 40 Epic Points."
	return ""

func start_project(building_id: String) -> bool:
	var home = BuildManager.buildings.get(building_id)
	if not can_start_project(home):
		return false
	active_projects[building_id] = {
		"building_id": building_id,
		"points": 0,
		"target_points": PROJECT_TARGET_POINTS,
		"claimed_sources": [],
		"expires_unix": int(Time.get_unix_time_from_system()) + PROJECT_DURATION_SECONDS,
		"status": "active"
	}
	project_changed.emit(building_id, get_project_state(building_id))
	return true

func claim_specialization_points(source_building_id: String) -> int:
	var source = BuildManager.buildings.get(source_building_id)
	if not is_instance_valid(source) or str(source.get("status")) != "completed":
		return 0
	var source_definition: Dictionary = source.get("definition")
	var points := int(source_definition.get("epic_points", 0))
	if points <= 0:
		return 0
	var gained := 0
	for project_id in active_projects.keys():
		var state: Dictionary = active_projects[project_id]
		if str(state.get("status", "")) != "active":
			continue
		var home = BuildManager.buildings.get(str(project_id))
		if not is_instance_valid(home) or source.global_position.distance_to(home.global_position) > SPECIALIZATION_RADIUS:
			continue
		var claimed: Array = state.get("claimed_sources", [])
		if source_building_id in claimed:
			continue
		claimed.append(source_building_id)
		state["claimed_sources"] = claimed
		state["points"] = mini(int(state.get("target_points", PROJECT_TARGET_POINTS)), int(state.get("points", 0)) + points)
		if int(state["points"]) >= int(state.get("target_points", PROJECT_TARGET_POINTS)):
			state["status"] = "ready"
		active_projects[project_id] = state
		gained += points
		project_changed.emit(str(project_id), state.duplicate(true))
	return gained

func claim_project(building_id: String) -> bool:
	if not active_projects.has(building_id):
		return false
	var state: Dictionary = active_projects[building_id]
	if str(state.get("status", "")) != "ready":
		return false
	var home = BuildManager.buildings.get(building_id)
	if not is_instance_valid(home) or not home.has_method("set_epic_tier"):
		return false
	home.call("set_epic_tier", 1)
	home.set("current_population", roundi(float(home.get("current_population")) * EPIC_POPULATION_BONUS))
	epic_tokens["turtle"] = int(epic_tokens.get("turtle", 0)) + 1
	EconomyManager.add_experience(200)
	EconomyManager.add_simoleons(5000)
	active_projects.erase(building_id)
	epic_building_created.emit(building_id, 1)
	project_changed.emit(building_id, {})
	return true

func get_project_state(building_id: String) -> Dictionary:
	if not active_projects.has(building_id):
		return {}
	var state: Dictionary = active_projects[building_id]
	return state.duplicate(true)

func get_project_progress(building_id: String) -> float:
	var state := get_project_state(building_id)
	if state.is_empty():
		return 0.0
	return clampf(float(state.get("points", 0)) / maxf(1.0, float(state.get("target_points", PROJECT_TARGET_POINTS))), 0.0, 1.0)

func to_save_dict() -> Dictionary:
	return {
		"active_projects": active_projects.duplicate(true),
		"epic_tokens": epic_tokens.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	active_projects = data.get("active_projects", {}).duplicate(true)
	var saved_tokens: Dictionary = data.get("epic_tokens", {})
	for token_type in ["turtle", "llama", "cheetah"]:
		epic_tokens[token_type] = maxi(0, int(saved_tokens.get(token_type, 0)))
