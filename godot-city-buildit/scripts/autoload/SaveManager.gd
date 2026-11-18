extends Node

signal save_completed(path: String)
signal save_failed(reason: String)
signal load_completed(success: bool)

const RoadSystemScript = preload("res://scripts/systems/RoadSystem.gd")

const SAVE_PATH: String = "user://pasoo_city_buildit_save.json"
const SAVE_VERSION: int = 5
const AUTOSAVE_INTERVAL: float = 30.0

var autosave_elapsed: float = 0.0
var is_loading: bool = false
var persistence_ready: bool = false
var _save_debounce_timer: Timer
var _save_pending := false

const DEFAULT_NOTIFICATION_PREFERENCES := {
	"building_alerts": true,
	"city_updates": true
}
var _notification_preferences: Dictionary = DEFAULT_NOTIFICATION_PREFERENCES.duplicate(true)

func _ready() -> void:
	_save_debounce_timer = Timer.new()
	_save_debounce_timer.name = "PlayerJsonSaveDebounce"
	_save_debounce_timer.one_shot = true
	_save_debounce_timer.wait_time = 0.75
	_save_debounce_timer.timeout.connect(_flush_scheduled_save)
	add_child(_save_debounce_timer)
	call_deferred("_connect_persistence_signals")


func _connect_persistence_signals() -> void:
	if StorageManager.has_signal("storage_changed") and not StorageManager.storage_changed.is_connected(schedule_save):
		StorageManager.storage_changed.connect(schedule_save)
	if EconomyManager.has_signal("simoleons_changed"):
		EconomyManager.simoleons_changed.connect(_on_economy_balance_changed)
		EconomyManager.sim_cash_changed.connect(_on_economy_balance_changed)
		EconomyManager.keys_changed.connect(_on_economy_balance_changed)
		EconomyManager.transaction_completed.connect(_on_economy_transaction_completed)
		EconomyManager.ledger_changed.connect(schedule_save)
	if AchievementManager.has_signal("state_changed"):
		AchievementManager.state_changed.connect(schedule_save)
	if RegionManager.has_signal("region_state_changed"):
		RegionManager.region_state_changed.connect(schedule_save)
		RegionManager.region_changed.connect(_on_region_changed_for_save)
	if BuildManager.has_signal("building_placed"):
		BuildManager.building_placed.connect(_on_building_placed_for_save)
		BuildManager.building_removed.connect(_on_building_removed_for_save)
		BuildManager.construction_started.connect(_on_building_id_changed_for_save)
		BuildManager.construction_finished.connect(_on_building_id_changed_for_save)


func schedule_save() -> void:
	if is_loading:
		return
	_save_pending = true
	if persistence_ready and is_instance_valid(_save_debounce_timer):
		_save_debounce_timer.start(0.75)


func _flush_scheduled_save() -> void:
	if not _save_pending or is_loading or not persistence_ready:
		return
	_save_pending = false
	if not save_game():
		_save_pending = true
		if is_instance_valid(_save_debounce_timer):
			_save_debounce_timer.start(5.0)


func _on_economy_balance_changed(_amount: int) -> void:
	schedule_save()


func _on_economy_transaction_completed(_transaction_type: String, _amount: int) -> void:
	schedule_save()


func _on_region_changed_for_save(_region_id: String) -> void:
	schedule_save()


func _on_building_placed_for_save(_building_data: Dictionary) -> void:
	schedule_save()


func _on_building_removed_for_save(_building_id: String) -> void:
	schedule_save()


func _on_building_id_changed_for_save(_building_id: String) -> void:
	schedule_save()


func get_active_save_path() -> String:
	if has_node("/root/PlayerAccountManager") and PlayerAccountManager.is_authenticated():
		return PlayerAccountManager.get_local_save_path()
	return SAVE_PATH

func get_notification_preferences() -> Dictionary:
	return _notification_preferences.duplicate(true)


func set_notification_preference(key: String, enabled: bool) -> bool:
	if not DEFAULT_NOTIFICATION_PREFERENCES.has(key):
		return false
	var previous_value := bool(_notification_preferences.get(key, true))
	_notification_preferences[key] = enabled
	_apply_notification_preferences_to_scene()
	if not is_loading and not save_game():
		_notification_preferences[key] = previous_value
		_apply_notification_preferences_to_scene()
		return false
	return true


func load_preferences_from_active_save() -> bool:
	var active_save_path := get_active_save_path()
	if not FileAccess.file_exists(active_save_path):
		_load_legacy_notification_preferences()
		_apply_notification_preferences_to_scene()
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(active_save_path))
	if not parsed is Dictionary:
		push_warning("Player settings JSON is invalid; keeping current preferences.")
		return false
	var preferences: Dictionary = parsed.get("preferences", {})
	var saved_notifications: Variant = preferences.get("notifications", {})
	_notification_preferences = DEFAULT_NOTIFICATION_PREFERENCES.duplicate(true)
	if saved_notifications is Dictionary:
		for key in DEFAULT_NOTIFICATION_PREFERENCES.keys():
			if saved_notifications.has(key):
				_notification_preferences[key] = bool(saved_notifications[key])
	AudioManager.from_save_dict(preferences.get("audio", {}))
	HapticsManager.from_save_dict(preferences.get("haptics", {}))
	GraphicsSettingsManager.from_save_dict(preferences.get("graphics", {}))
	_apply_notification_preferences_to_scene()
	return true


func _load_legacy_notification_preferences() -> void:
	_notification_preferences = DEFAULT_NOTIFICATION_PREFERENCES.duplicate(true)
	# Never copy a guest device's notification choices into a newly signed-in account.
	if has_node("/root/PlayerAccountManager") and PlayerAccountManager.is_authenticated():
		return
	var config := ConfigFile.new()
	if config.load("user://notification_preferences.cfg") != OK:
		return
	for key in DEFAULT_NOTIFICATION_PREFERENCES.keys():
		_notification_preferences[key] = bool(config.get_value("notifications", key, DEFAULT_NOTIFICATION_PREFERENCES[key]))


func _apply_notification_preferences_to_scene() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var hud = scene.get_node_or_null("HUD")
	var alert_layer = hud.get_node_or_null("BuildingNotificationLayer") if hud != null else null
	var citizen_feedback = scene.get_node_or_null("CitizenFeedback")
	if is_instance_valid(alert_layer) and alert_layer.has_method("set_building_alerts_enabled"):
		alert_layer.set_building_alerts_enabled(bool(_notification_preferences.get("building_alerts", true)))
	if is_instance_valid(citizen_feedback) and citizen_feedback.has_method("set_city_updates_enabled"):
		citizen_feedback.set_city_updates_enabled(bool(_notification_preferences.get("city_updates", true)))


func _process(delta: float) -> void:
	if is_loading:
		return
	if _save_pending and persistence_ready and is_instance_valid(_save_debounce_timer) and _save_debounce_timer.is_stopped():
		_save_debounce_timer.start(0.75)
	if not persistence_ready:
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
		if building.status == "constructing":
			building.update_construction_access_state()
		if building.upgrade_in_progress:
			building.update_upgrade_access_state()
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
				"construction_paused_remaining_seconds": building.construction_paused_remaining_seconds,
				"current_product": building.current_product,
				"is_producing": building.is_producing,
				"has_ready_product": building.has_ready_product,
				"production_finish_unix": building.production_finish_unix,
				"upgrade_in_progress": building.upgrade_in_progress,
				"upgrade_finish_unix": building.upgrade_finish_unix,
				"upgrade_paused_remaining_seconds": building.upgrade_paused_remaining_seconds,
				"store_star_level": building.production_component.store_star_level if is_instance_valid(building.production_component) else 0,
				"slots": building.production_component.to_save_array() if is_instance_valid(building.production_component) else []
			}
		})
	return {
		"storage": StorageManager.to_save_dict(),
		"roads": road_data,
		"buildings": building_data,
		"epic_projects": EpicProjectManager.to_save_dict(),
		"land_expansion": LandExpansionManager.to_save_dict(),
		"happiness": GameManager.happiness,
		"city_name": GameManager.city_name
	}

func _capture_tutorial_state() -> Dictionary:
	var scene = get_tree().current_scene
	if scene == null:
		return {}
	var tutorial = scene.get_node_or_null("TutorialGuide")
	if tutorial != null and tutorial.has_method("to_save_dict"):
		return tutorial.to_save_dict()
	return {}

func save_game() -> bool:
	var region_snapshot := capture_region_snapshot()
	if region_snapshot.is_empty():
		save_failed.emit("The active city scene is not ready for a JSON snapshot.")
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
			"happiness": GameManager.happiness,
			"city_name": GameManager.city_name
		},
		"economy": {
			"simoleons": EconomyManager.simoleons,
			"golden_keys": EconomyManager.golden_keys,
			"sim_cash": EconomyManager.sim_cash
		},
		"economy_ledger": EconomyManager.to_save_dict(),
		"payments": PaymentManager.to_save_dict(),
		"storage": StorageManager.to_save_dict(),
		"trade": TradeManager.to_save_dict(),
		"achievements": AchievementManager.to_save_dict(),
		"regions": RegionManager.to_save_dict(),
		"roads": road_data,
		"buildings": building_data,
		"tutorial": _capture_tutorial_state(),
		"preferences": {
			"notifications": get_notification_preferences(),
			"audio": AudioManager.to_save_dict(),
			"haptics": HapticsManager.to_save_dict(),
			"graphics": GraphicsSettingsManager.to_save_dict()
		}
	}
	var active_save_path := get_active_save_path()
	var absolute_save_directory := ProjectSettings.globalize_path(active_save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_save_directory) != OK and not DirAccess.dir_exists_absolute(absolute_save_directory):
		var directory_error := "Could not create player save directory: " + active_save_path.get_base_dir()
		push_error(directory_error)
		save_failed.emit(directory_error)
		return false
	var file := FileAccess.open(active_save_path, FileAccess.WRITE)
	if file == null:
		var file_error := "Could not write city save file: %s" % FileAccess.get_open_error()
		push_error(file_error)
		save_failed.emit(file_error)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	_save_pending = false
	autosave_elapsed = 0.0
	if is_instance_valid(_save_debounce_timer):
		_save_debounce_timer.stop()
	if has_node("/root/PlayerAccountManager") and PlayerAccountManager.is_authenticated():
		PlayerAccountManager.queue_profile_save(payload)
	save_completed.emit(active_save_path)
	return true

func _apply_saved_region_storage(region_snapshot: Dictionary, legacy_storage: Dictionary) -> void:
	if region_snapshot.has("storage") and region_snapshot.get("storage") is Dictionary:
		StorageManager.from_save_dict(region_snapshot.get("storage", {}))
	else:
		StorageManager.from_save_dict(legacy_storage)


func load_game() -> bool:
	var active_save_path := get_active_save_path()
	if not FileAccess.file_exists(active_save_path):
		_load_legacy_notification_preferences()
		_apply_notification_preferences_to_scene()
		load_completed.emit(false)
		return false

	var file := FileAccess.open(active_save_path, FileAccess.READ)
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
	GameManager.city_name = str(game_data.get("city_name", "")).strip_edges()
	var economy_data: Dictionary = parsed.get("economy", {})
	var storage_data: Dictionary = parsed.get("storage", {})

	GameManager.level = maxi(1, int(game_data.get("level", 1)))
	LevelProgression._apply_level(GameManager.level)
	RegionManager.from_save_dict(parsed.get("regions", {}))
	var region_snapshot: Dictionary = RegionManager.get_active_snapshot()
	# Version 5 stores inventory per region. Older saves migrate their single
	# global inventory into the currently active region without losing items.
	var region_roads: Array = region_snapshot.get("roads", parsed.get("roads", []))
	var region_buildings: Array = region_snapshot.get("buildings", parsed.get("buildings", []))
	var region_epic_projects: Dictionary = region_snapshot.get("epic_projects", parsed.get("epic_projects", {}))
	EconomyManager.simoleons = 100000000
	EconomyManager.golden_keys = int(economy_data.get("golden_keys", 5))
	EconomyManager.sim_cash = int(economy_data.get("sim_cash", 0))
	PaymentManager.from_save_dict(parsed.get("payments", {}))
	EconomyManager.from_save_dict(parsed.get("economy_ledger", {}))

	# Prefer the active region's warehouse when present. The top-level storage
	# field is retained only as a migration source for legacy saves; applying it
	# unconditionally here would overwrite a valid regional inventory.
	_apply_saved_region_storage(region_snapshot, storage_data)
	TradeManager.from_save_dict(parsed.get("trade", {}))

	if not _restore_region_world(region_roads, region_buildings, region_epic_projects, false, region_snapshot.get("land_expansion", {})):
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
	HappinessManager.reset_transient_city_state()
	AchievementManager.from_save_dict(parsed.get("achievements", {}))
	var tutorial = scene.get_node_or_null("TutorialGuide")
	if tutorial != null and tutorial.has_method("from_save_dict") and parsed.get("tutorial", {}) is Dictionary:
		tutorial.from_save_dict(parsed.get("tutorial", {}))
	var preferences: Dictionary = parsed.get("preferences", {})
	var saved_notifications: Variant = preferences.get("notifications", {})
	if saved_notifications is Dictionary and not saved_notifications.is_empty():
		_notification_preferences = DEFAULT_NOTIFICATION_PREFERENCES.duplicate(true)
		for key in DEFAULT_NOTIFICATION_PREFERENCES.keys():
			if saved_notifications.has(key):
				_notification_preferences[key] = bool(saved_notifications[key])
	else:
		_load_legacy_notification_preferences()
	_apply_notification_preferences_to_scene()
	AudioManager.from_save_dict(preferences.get("audio", {}))
	HapticsManager.from_save_dict(preferences.get("haptics", {}))
	GraphicsSettingsManager.from_save_dict(preferences.get("graphics", {}))
	GameManager.level_changed.emit(GameManager.level)
	# Loading a save changes XP without calling add_experience(); notify the HUD
	# explicitly so its numeric label, progress bar and level ring cannot stay stale.
	GameManager.xp_changed.emit(GameManager.experience, GameManager.get_xp_needed())
	GameManager.population_changed.emit(GameManager.population)
	GameManager.happiness_changed.emit(GameManager.happiness)
	EconomyManager.simoleons_changed.emit(EconomyManager.simoleons)
	EconomyManager.sim_cash_changed.emit(EconomyManager.sim_cash)
	EconomyManager.keys_changed.emit(EconomyManager.golden_keys)
	is_loading = false
	# Recalculate from restored buildings and current service/traffic coverage;
	# the serialized happiness value is only a fallback, never the live authority.
	HappinessManager.recalculate_city()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.reset_for_city_load()
	load_completed.emit(true)
	return true


func _restore_region_world(road_data: Array, building_data: Array, epic_data: Dictionary, _allow_empty_region: bool, land_expansion_data: Dictionary = {}) -> bool:
	var scene = get_tree().current_scene
	if scene == null:
		return false
	var road_system = scene.get_node_or_null("World/RoadSystem")
	if road_system == null:
		return false
	LandExpansionManager.from_save_dict(land_expansion_data)
	if land_expansion_data.is_empty():
		LandExpansionManager.migrate_legacy_land(road_data, building_data)
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
		if not road_system.restore_road(gateway_position):
			return false
	else:
		if not road_system.restore_road(gateway_position):
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
			if connected and road_system.restore_road(road_position):
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
			int(saved_building.get("rotation_quarters", 0)),
			true
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
		true,
		snapshot.get("land_expansion", {})
	)
	EconomyManager.simoleons = previous_simoleons
	if not success:
		is_loading = false
		return false
	# Every region owns an independent warehouse. A never-visited region starts
	# with an empty default-capacity warehouse; older snapshots migrate empty.
	var regional_storage: Dictionary = snapshot.get("storage", {
		"capacity": StorageManager.DEFAULT_CAPACITY,
		"items": {}
	})
	StorageManager.from_save_dict(regional_storage)
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
	HappinessManager.reset_transient_city_state()
	GameManager.population_changed.emit(GameManager.population)
	GameManager.happiness_changed.emit(GameManager.happiness)
	is_loading = false
	# Re-score this region now; do not show stale cached happiness from another region.
	HappinessManager.recalculate_city()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
