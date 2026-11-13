extends Node

signal epic_state_changed

const DEPARTMENT_UNLOCK_LEVEL := 16
const PROJECT_UNLOCK_LEVEL := 24
const PROJECT_DURATION_SECONDS := 86400
const TOKEN_PART_INTERVAL_SECONDS := 86400
const MAX_ACTIVE_TASKS := 8
const EPIC_POPULATION_MULTIPLIER := 1.31
const TIER_THRESHOLDS := {"bronze": 40, "silver": 100, "gold": 200}

var active_project: Dictionary = {}
var epic_buildings: Dictionary = {}
var token_parts: Dictionary = {"bronze": 0, "silver": 0, "gold": 0}

func _process(_delta: float) -> void:
	if active_project.is_empty() or bool(active_project.get("finished", false)):
		return
	var deadline := int(active_project.get("deadline_unix", 0))
	if deadline > 0 and int(Time.get_unix_time_from_system()) >= deadline:
		_finish_active_project()
		epic_state_changed.emit()

func has_department() -> bool:
	if GameManager.level < DEPARTMENT_UNLOCK_LEVEL:
		return false
	for building in BuildManager.buildings.values():
		if is_instance_valid(building) and str(building.get("building_type")) == "epic_projects_department" and str(building.get("status")) == "completed":
			return true
	return false

func _get_specialization_buildings() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or str(building.get("status")) != "completed":
			continue
		var definition: Dictionary = building.get("definition")
		if bool(definition.get("epic_specialization", false)) or str(definition.get("category", "")) == "park":
			result.append(building)
	return result

func get_start_block_reason(building: Node3D) -> String:
	if not is_instance_valid(building):
		return "Select a residential building."
	if str(building.get("status")) != "completed" or str(building.get("definition", {}).get("category", "")) != "residential":
		return "Epic Projects require a completed residential building."
	if bool(building.get("is_epic_building")):
		return "This home is already an Epic Building."
	if int(building.get("upgrade_stage")) < 6:
		return "Upgrade this home to Level 6 first."
	if GameManager.level < PROJECT_UNLOCK_LEVEL:
		return "Epic Projects unlock at Mayor Level 24."
	if not has_department():
		return "Build the Department of Epic Projects (unlocks at Level 16)."
	if not active_project.is_empty():
		return "Only one Epic Project can run at a time."
	if _get_specialization_buildings().is_empty():
		return "Build and complete a specialization building, such as a Small Park."
	return ""

func can_start_project(building: Node3D) -> bool:
	return get_start_block_reason(building).is_empty()

func start_project(building_id: String) -> bool:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or not can_start_project(building):
		return false
	var now := int(Time.get_unix_time_from_system())
	active_project = {
		"building_id": building_id,
		"started_unix": now,
		"deadline_unix": now + PROJECT_DURATION_SECONDS,
		"finished_unix": 0,
		"points": 0,
		"tier": "none",
		"finished": false,
		"tasks": []
	}
	_generate_tasks()
	epic_state_changed.emit()
	return true

func _generate_tasks() -> void:
	if active_project.is_empty():
		return
	var tasks: Array[Dictionary] = []
	for building in _get_specialization_buildings():
		if tasks.size() >= MAX_ACTIVE_TASKS:
			break
		tasks.append(_create_task(str(building.get("building_id"))))
	active_project["tasks"] = tasks

func _create_task(building_id: String) -> Dictionary:
	var item_pool: Array[String] = []
	for item_id in ProductionManager.raw_materials.keys():
		if int(ProductionManager.raw_materials[item_id].get("level", 1)) <= GameManager.level:
			item_pool.append(str(item_id))
	for item_id in ProductionManager.crafted_items.keys():
		if int(ProductionManager.crafted_items[item_id].get("level", 1)) <= GameManager.level:
			item_pool.append(str(item_id))
	if item_pool.is_empty():
		item_pool.append("metal")
	item_pool.shuffle()
	var item_id := item_pool[0]
	return {
		"id": "%s_%d" % [building_id, Time.get_ticks_msec()],
		"building_id": building_id,
		"item_id": item_id,
		"amount": randi_range(1, 5),
		"points": randi_range(1, 6)
	}

func contribute_to_task(task_id: String) -> bool:
	if active_project.is_empty() or bool(active_project.get("finished", false)):
		return false
	var tasks: Array = active_project.get("tasks", [])
	for index in range(tasks.size()):
		var task: Dictionary = tasks[index]
		if str(task.get("id", "")) != task_id:
			continue
		var building_id := str(task.get("building_id", ""))
		var specialization = BuildManager.buildings.get(building_id)
		if not is_instance_valid(specialization) or str(specialization.get("status")) != "completed":
			return false
		var item_id := str(task.get("item_id", ""))
		var amount := int(task.get("amount", 0))
		var requested: Dictionary = {}
		requested[item_id] = amount
		if item_id.is_empty() or amount <= 0 or not StorageManager.remove_items(requested):
			return false
		active_project["points"] = int(active_project.get("points", 0)) + int(task.get("points", 0))
		tasks[index] = _create_task(building_id)
		active_project["tasks"] = tasks
		if int(active_project.get("points", 0)) >= int(TIER_THRESHOLDS.gold):
			_finish_active_project()
		epic_state_changed.emit()
		return true
	return false

func _tier_for_points(points: int) -> String:
	if points >= int(TIER_THRESHOLDS.gold):
		return "gold"
	if points >= int(TIER_THRESHOLDS.silver):
		return "silver"
	if points >= int(TIER_THRESHOLDS.bronze):
		return "bronze"
	return "none"

func _finish_active_project() -> void:
	if active_project.is_empty() or bool(active_project.get("finished", false)):
		return
	active_project["finished"] = true
	active_project["finished_unix"] = int(Time.get_unix_time_from_system())
	active_project["tier"] = _tier_for_points(int(active_project.get("points", 0)))

func get_project_remaining_seconds() -> int:
	if active_project.is_empty() or bool(active_project.get("finished", false)):
		return 0
	return maxi(0, int(active_project.get("deadline_unix", 0)) - int(Time.get_unix_time_from_system()))

func dismiss_finished_project() -> bool:
	if active_project.is_empty() or not bool(active_project.get("finished", false)) or str(active_project.get("tier", "none")) != "none":
		return false
	active_project.clear()
	epic_state_changed.emit()
	return true

func claim_project() -> bool:
	if active_project.is_empty() or not bool(active_project.get("finished", false)):
		return false
	var tier := str(active_project.get("tier", "none"))
	if tier == "none":
		return false
	var building_id := str(active_project.get("building_id", ""))
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or str(building.get("status")) != "completed":
		return false
	var tier_rank := 1 if tier == "bronze" else (2 if tier == "silver" else 3)
	var old_population := int(building.get("current_population"))
	building.set_epic_tier(tier_rank)
	var new_capacity := HappinessManager._capacity_for_home(building)
	building.current_population = mini(new_capacity, maxi(old_population, roundi(float(old_population) * EPIC_POPULATION_MULTIPLIER)))
	GameManager.add_population(building.current_population - old_population)
	epic_buildings[building_id] = {
		"tier": tier,
		"next_token_part_unix": int(Time.get_unix_time_from_system()) + TOKEN_PART_INTERVAL_SECONDS
	}
	active_project.clear()
	epic_state_changed.emit()
	return true

func collect_token_part(building_id: String) -> bool:
	if not epic_buildings.has(building_id):
		return false
	var entry: Dictionary = epic_buildings[building_id]
	var now := int(Time.get_unix_time_from_system())
	if now < int(entry.get("next_token_part_unix", 0)):
		return false
	var tier := str(entry.get("tier", "bronze"))
	if not token_parts.has(tier):
		return false
	token_parts[tier] = int(token_parts[tier]) + 1
	entry["next_token_part_unix"] = now + TOKEN_PART_INTERVAL_SECONDS
	epic_buildings[building_id] = entry
	epic_state_changed.emit()
	return true

func get_token_part_count(tier: String) -> int:
	return int(token_parts.get(tier, 0))

func to_save_dict() -> Dictionary:
	return {
		"active_project": active_project.duplicate(true),
		"epic_buildings": epic_buildings.duplicate(true),
		"token_parts": token_parts.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	active_project = data.get("active_project", {}).duplicate(true)
	epic_buildings = data.get("epic_buildings", {}).duplicate(true)
	token_parts = {"bronze": 0, "silver": 0, "gold": 0}
	for tier in token_parts.keys():
		token_parts[tier] = maxi(0, int(data.get("token_parts", {}).get(tier, 0)))
	for building_id in epic_buildings.keys():
		var building = BuildManager.buildings.get(str(building_id))
		if is_instance_valid(building):
			var tier := str(epic_buildings[building_id].get("tier", "bronze"))
			building.set_epic_tier(1 if tier == "bronze" else (2 if tier == "silver" else 3))
	if not active_project.is_empty() and not is_instance_valid(BuildManager.buildings.get(str(active_project.get("building_id", "")))):
		active_project.clear()
	epic_state_changed.emit()
