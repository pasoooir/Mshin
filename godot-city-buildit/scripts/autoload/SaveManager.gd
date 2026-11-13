extends Node

signal save_completed(path: String)
signal load_completed(success: bool)

const RoadSystemScript = preload("res://scripts/systems/RoadSystem.gd")

const SAVE_PATH: String = "user://pasoo_city_buildit_save.json"
const SAVE_VERSION: int = 3
const AUTOSAVE_INTERVAL: float = 30.0

var autosave_elapsed: float = 0.0
var is_loading: bool = false

func _process(delta: float) -> void:
	if is_loading:
		return
	autosave_elapsed += delta
	if autosave_elapsed >= AUTOSAVE_INTERVAL:
		autosave_elapsed = 0.0
		save_game()

func capture_region_snapshot() -> Dictionary:
	var scene = get_tree().current_scene
	if scene == null or scene.get_node_or_null("World/RoadSystem") == null:
		return {}
	var road_system = scene.get_node("World/RoadSystem")
	var road_data: Array = []
	for cell in road_system.roads.keys():
		road_data.append([int(cell.x), int(cell.y), road_system.get_road_level(cell)])
	var gateway_position: Vector2i = RoadSystemScript.GATEWAY_ROAD_CELL
	var gateway_saved := false
	for saved_road in road_data:
		if Vector2i(int(saved_road[0]), int(saved_road[1])) == gateway_position:
			gateway_saved = true
			break
	if not gateway_saved:
		road_data.append([gateway_position.x, gateway_position.y, 1])
	var building_data: Array = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		building_data.append({
			"type": building.building_type,
			"grid": [int(building.grid_pos.x), int(building.grid_pos.y)],
			"rotation_quarters": posmod(roundi(building.rotation.y / (PI * 0.5)), 4),
			"stage": int(building.upgrade_stage),
			"status": str(building.status),
			"population": int(building.current_population),
			"is_epic_building": bool(building.is_epic_building),
			"epic_tier": int(building.epic_tier),
			"production": {
				"construction_finish_unix": building.construction_finish_unix,
				"current_product": building.current_product,
				"is_producing": building.is_producing,
				"has_ready_product": building.has_ready_product,
				"production_finish_unix": building.production_finish_unix,
				"upgrade_in_progress": building.upgrade_in_progress,
				"upgrade_finish_unix": building.upgrade_finish_unix,
				"store_star_level": building.production_component.store_star_level if is_instance_valid(building.production_component) else 0,
				"slots": building.production_component.to_save_array() if is_instance_valid(building.production_component) else []
			}
		})
	return {
		"roads": road_data,
		"buildings": building_data,
		"epic_projects": EpicProjectManager.to_save_dict(),
		"happiness": GameManager.happiness
	}

func save_game() -> bool:
	var region_snapshot := capture_region_snapshot()
	if region_snapshot.is_empty():
		return false
	RegionManager.store_active_region_snapshot(region_snapshot)
	var road_data: Array = region_snapshot.get("roads", [])
	var building_data: Array = region_snapshot.get("buildings", [])
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"starter_grant_claimed": true,
		"game": {
			"level": GameManager.level,
			"experience": GameManager.experience,
			"population": GameManager.population,
			"happiness": GameManager.happiness
		},
		"economy": {
			"simoleons": EconomyManager.simoleons,
			"golden_keys": EconomyManager.golden_keys,
			"sim_cash": EconomyManager.sim_cash
		},
		"storage": StorageManager.to_save_dict(),
		"trade": TradeManager.to_save_dict(),
		"achievements": AchievementManager.to_save_dict(),
		"regions": RegionManager.to_save_dict(),
		"roads": road_data,
		"buildings": building_data
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write city save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	save_completed.emit(SAVE_PATH)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		load_completed.emit(false)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read city save file: %s" % FileAccess.get_open_error())
		load_completed.emit(false)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) < 1 or int(parsed.get("version", 0)) > SAVE_VERSION:
		push_warning("City save is invalid or uses an unsupported version.")
		load_completed.emit(false)
		return false

	var scene = get_tree().current_scene
	if scene == null or scene.get_node_or_null("World/RoadSystem") == null:
		load_completed.emit(false)
		return false

	is_loading = true
	var game_data: Dictionary = parsed.get("game", {})
	var economy_data: Dictionary = parsed.get("economy", {})
	var storage_data: Dictionary = parsed.get("storage", {})

	GameManager.level = maxi(1, int(game_data.get("level", 1)))
	LevelProgression._apply_level(GameManager.level)
	RegionManager.from_save_dict(parsed.get("regions", {}))
	var region_snapshot: Dictionary = RegionManager.get_active_snapshot()
	var region_roads: Array = region_snapshot.get("roads", parsed.get("roads", []))
	var region_buildings: Array = region_snapshot.get("buildings", parsed.get("buildings", []))
	var region_epic_projects: Dictionary = region_snapshot.get("epic_projects", parsed.get("epic_projects", {}))
	EconomyManager.simoleons = 100000000
	EconomyManager.golden_keys = int(economy_data.get("golden_keys", 5))
	EconomyManager.sim_cash = int(economy_data.get("sim_cash", 0))

	StorageManager.from_save_dict(storage_data)
	TradeManager.from_save_dict(parsed.get("trade", {}))

	if not _restore_region_world(region_roads, region_buildings, region_epic_projects, false):
		is_loading = false
		load_completed.emit(false)
		return false

	EconomyManager.simoleons = int(economy_data.get("simoleons", 5000))
	# One-time welcome grant for cities created before the starter-economy update.
	if not bool(parsed.get("starter_grant_claimed", false)):
		EconomyManager.simoleons += 20000
		EconomyManager.golden_keys += 5
		EconomyManager.sim_cash += 25
	StorageManager.storage_changed.emit()
	StorageManager.capacity_changed.emit(StorageManager.max_capacity)
	ServiceManager.recalculate_from_buildings()
	# Reapply the saved city totals after services recalculate household coverage.
	# Per-home residents are restored above, so future happiness refreshes preserve
	# the same population instead of reinitializing households from scratch.
	GameManager.level = maxi(1, int(game_data.get("level", 1)))
	GameManager.experience = int(game_data.get("experience", 0))
	var restored_population := 0
	for restored_building in BuildManager.buildings.values():
		if not is_instance_valid(restored_building) or restored_building.status != "completed":
			continue
		if str(restored_building.definition.get("category", "")) == "residential":
			restored_population += int(restored_building.current_population)
		else:
			restored_population += int(restored_building.definition.get("population", 0))
	GameManager.population = maxi(0, restored_population)
	GameManager.happiness = float(region_snapshot.get("happiness", game_data.get("happiness", 100.0)))
	RegionManager.store_active_region_snapshot(capture_region_snapshot())
	AchievementManager.from_save_dict(parsed.get("achievements", {}))
	GameManager.level_changed.emit(GameManager.level)
	GameManager.population_changed.emit(GameManager.population)
	GameManager.happiness_changed.emit(GameManager.happiness)
	EconomyManager.simoleons_changed.emit(EconomyManager.simoleons)
	EconomyManager.keys_changed.emit(EconomyManager.golden_keys)
	is_loading = false
	if has_node("/root/FireHazardManager"):
		FireHazardManager.reset_for_city_load()
	load_completed.emit(true)
	return true


func _restore_region_world(road_data: Array, building_data: Array, epic_data: Dictionary, _allow_empty_region: bool) -> bool:
	var scene = get_tree().current_scene
	if scene == null:
		return false
	var road_system = scene.get_node_or_null("World/RoadSystem")
	if road_system == null:
		return false
	BuildManager.cancel_placement()
	if BuildManager.is_moving:
		BuildManager.cancel_move()
	for building in BuildManager.buildings.values():
		if is_instance_valid(building):
			building.queue_free()
	BuildManager.buildings.clear()
	road_system.clear_roads()
	var pending_roads: Array = road_data.duplicate(true)
	var gateway_position: Vector2i = RoadSystemScript.GATEWAY_ROAD_CELL
	var gateway_index := -1
	for index in range(pending_roads.size()):
		var road: Variant = pending_roads[index]
		if road is Array and road.size() >= 2 and Vector2i(int(road[0]), int(road[1])) == gateway_position:
			gateway_index = index
			break
	if gateway_index < 0:
		if not pending_roads.is_empty():
			push_error("Saved region road network is missing its permanent highway gateway tile.")
			return false
		if not road_system.place_road(gateway_position):
			return false
	else:
		if not road_system.place_road(gateway_position):
			push_error("Saved region highway gateway could not be restored.")
			return false
		pending_roads.remove_at(gateway_index)
	while not pending_roads.is_empty():
		var placed_road_this_pass := false
		for index in range(pending_roads.size() - 1, -1, -1):
			var road: Variant = pending_roads[index]
			if not (road is Array) or road.size() < 2:
				pending_roads.remove_at(index)
				continue
			var road_position := Vector2i(int(road[0]), int(road[1]))
			if road_system.has_road(road_position):
				pending_roads.remove_at(index)
				placed_road_this_pass = true
				continue
			var connected := false
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if road_system.is_road_connected_to_gateway(road_position + direction):
					connected = true
					break
			if connected and road_system.place_road(road_position):
				var saved_road_level := int(road[2]) if road.size() >= 3 else 1
				road_system.restore_road_level(road_position, saved_road_level)
				pending_roads.remove_at(index)
				placed_road_this_pass = true
		if not placed_road_this_pass:
			push_error("Saved region road network contains disconnected or invalid tiles.")
			return false
	for saved_building in building_data:
		if not (saved_building is Dictionary):
			continue
		var grid: Array = saved_building.get("grid", [])
		var type_id := str(saved_building.get("type", ""))
		if grid.size() != 2 or not BuildManager.building_types.has(type_id):
			continue
		var restored := BuildManager.place_building(
			Vector2i(int(grid[0]), int(grid[1])),
			type_id,
			int(saved_building.get("stage", 1)),
			str(saved_building.get("status", "constructing")),
			int(saved_building.get("rotation_quarters", 0))
		)
		if not restored:
			push_error("Could not restore region building: " + type_id)
			return false
		var restored_building = BuildManager.building_at_cell(Vector2i(int(grid[0]), int(grid[1])))
		if restored_building != null:
			restored_building.restore_production_state(saved_building.get("production", {}))
		if restored_building != null and bool(saved_building.get("is_epic_building", false)):
			restored_building.set_epic_tier(int(saved_building.get("epic_tier", 1)))
		if restored_building != null and str(restored_building.definition.get("category", "")) == "residential":
			if str(saved_building.get("status", "constructing")) == "completed":
				restored_building.current_population = clampi(int(saved_building.get("population", restored_building.current_population)), 0, HappinessManager._capacity_for_home(restored_building))
			else:
				restored_building.current_population = maxi(0, int(restored_building.current_population))
			if restored_building.status == "completed":
				restored_building.set_meta("immigration_population_initialized", true)
	EpicProjectManager.from_save_dict(epic_data)
	return true

func load_region_snapshot(snapshot: Dictionary) -> bool:
	var scene = get_tree().current_scene
	if scene == null or scene.get_node_or_null("World/RoadSystem") == null:
		return false
	is_loading = true
	var previous_simoleons := EconomyManager.simoleons
	EconomyManager.simoleons = 100000000
	var success := _restore_region_world(
		snapshot.get("roads", []),
		snapshot.get("buildings", []),
		snapshot.get("epic_projects", {}),
		true
	)
	EconomyManager.simoleons = previous_simoleons
	if not success:
		is_loading = false
		return false
	StorageManager.storage_changed.emit()
	StorageManager.capacity_changed.emit(StorageManager.max_capacity)
	ServiceManager.recalculate_from_buildings()
	var restored_population := 0
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or building.status != "completed":
			continue
		if str(building.definition.get("category", "")) == "residential":
			restored_population += int(building.current_population)
		else:
			restored_population += int(building.definition.get("population", 0))
	GameManager.population = maxi(0, restored_population)
	GameManager.happiness = float(snapshot.get("happiness", 100.0))
	GameManager.population_changed.emit(GameManager.population)
	GameManager.happiness_changed.emit(GameManager.happiness)
	is_loading = false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
