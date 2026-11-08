extends Node3D

const TAP_SLOP: float = 14.0

@onready var camera: Camera3D = null

var pointer_start: Dictionary = {}
var pointer_moved: Dictionary = {}
var multi_touch_gesture: bool = false
var road_stroke_active: Dictionary = {}
var road_stroke_last_cell: Dictionary = {}
var bulldoze_mode: bool = false
var bulldoze_road_mode: bool = false
var pending_bulldoze_building_id: String = ""

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		if bulldoze_mode or bulldoze_road_mode or BuildManager.is_placing or _is_road_mode():
			var hud = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
			if hud and hud.has_method("_on_cancel_pressed"):
				hud._on_cancel_pressed()
			else:
				set_bulldoze_mode(false)
				set_bulldoze_road_mode(false)
				BuildManager.cancel_placement()
				var roads = _road_system()
				if roads: roads.set_road_mode(false)
				_set_status("Tool cancelled.")
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_start[-1] = event.position
			pointer_moved[-1] = false
			if _is_road_mode():
				_start_road_stroke(-1, event.position)
		else:
			if road_stroke_active.has(-1):
				_end_road_stroke(-1)
			else:
				var start: Vector2 = pointer_start.get(-1, event.position)
				var moved := bool(pointer_moved.get(-1, false))
				# In building mode, dragging the placement ghost commits the final
				# green preview on release. Other interactions remain tap-only.
				if BuildManager.is_placing and moved:
					_handle_tap(event.position)
				elif start.distance_to(event.position) <= TAP_SLOP and not moved:
					_handle_tap(event.position)
			pointer_start.erase(-1)
			pointer_moved.erase(-1)
	elif event is InputEventMouseMotion:
		if pointer_start.has(-1) and Vector2(pointer_start[-1]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[-1] = true
		if road_stroke_active.has(-1):
			_continue_road_stroke(-1, event.position)
		elif BuildManager.is_placing:
			_update_ghost(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if pointer_start.size() > 0:
				multi_touch_gesture = true
				_cancel_all_road_strokes()
				for pointer_id in pointer_moved.keys():
					pointer_moved[pointer_id] = true
			pointer_start[event.index] = event.position
			pointer_moved[event.index] = false
			if pointer_start.size() == 1 and _is_road_mode():
				_start_road_stroke(event.index, event.position)
		else:
			if road_stroke_active.has(event.index):
				_end_road_stroke(event.index)
			elif pointer_start.has(event.index):
				var start: Vector2 = pointer_start[event.index]
				var moved := bool(pointer_moved.get(event.index, false))
				if not multi_touch_gesture:
					if BuildManager.is_placing and moved:
						_handle_tap(event.position)
					elif start.distance_to(event.position) <= TAP_SLOP and not moved:
						_handle_tap(event.position)
			pointer_start.erase(event.index)
			pointer_moved.erase(event.index)
			if pointer_start.is_empty():
				multi_touch_gesture = false
	elif event is InputEventScreenDrag:
		if pointer_start.size() > 1:
			multi_touch_gesture = true
			_cancel_all_road_strokes()
			for pointer_id in pointer_moved.keys():
				pointer_moved[pointer_id] = true
		if pointer_start.has(event.index) and Vector2(pointer_start[event.index]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[event.index] = true
		if road_stroke_active.has(event.index) and pointer_start.size() == 1:
			_continue_road_stroke(event.index, event.position)
		elif BuildManager.is_placing and event.index == 0:
			_update_ghost(event.position)

func _is_road_mode() -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	return road_system != null and road_system.is_road_mode

func set_bulldoze_mode(active: bool) -> void:
	_clear_bulldoze_highlight()
	bulldoze_mode = active
	if active:
		bulldoze_road_mode = false
		BuildManager.cancel_placement()
		var road_system = _road_system()
		if road_system:
			road_system.set_road_mode(false)

func set_bulldoze_road_mode(active: bool) -> void:
	_clear_bulldoze_highlight()
	bulldoze_road_mode = active
	if active:
		bulldoze_mode = false
		BuildManager.cancel_placement()
		var road_system = _road_system()
		if road_system:
			road_system.set_road_mode(false)

func _clear_bulldoze_highlight() -> void:
	if pending_bulldoze_building_id == "":
		return
	var previous = BuildManager.buildings.get(pending_bulldoze_building_id)
	if is_instance_valid(previous) and previous.has_method("set_demolition_highlight"):
		previous.set_demolition_highlight(false)
	pending_bulldoze_building_id = ""

func _handle_bulldoze_cell(grid: Vector2i, road_system = null) -> void:
	var roads = road_system if road_system != null else _road_system()
	if roads != null and roads.has_road(grid):
		_clear_bulldoze_highlight()
		if roads.remove_road(grid):
			_set_status("Road tile removed. Buildings and the rest of the road network were left untouched.")
		else:
			_set_status("Could not remove this road tile.")
		return
	if bulldoze_road_mode:
		_clear_bulldoze_highlight()
		_set_status("No road on this tile. Road bulldozer only removes asphalt.")
		return
	if not bulldoze_mode:
		return
	var building = BuildManager.building_at_cell(grid)
	if building == null or not is_instance_valid(building):
		_clear_bulldoze_highlight()
		_set_status("Nothing to demolish on this tile.")
		return
	if pending_bulldoze_building_id != building.building_id:
		_clear_bulldoze_highlight()
		pending_bulldoze_building_id = building.building_id
		if building.has_method("set_demolition_highlight"):
			building.set_demolition_highlight(true)
		_set_status("Building highlighted. Tap the highlighted building again to confirm demolition.")
		return
	var removed_name := str(building.definition.get("name", building.building_type))
	if building.has_method("set_demolition_highlight"):
		building.set_demolition_highlight(false)
	BuildManager.unregister_building(building.building_id)
	building.queue_free()
	pending_bulldoze_building_id = ""
	_set_status("%s demolished. City cells, population, factory slots and services were updated." % removed_name)

func _road_system():
	var scene = get_tree().current_scene
	return scene.get_node_or_null("World/RoadSystem") if scene else null

func _start_road_stroke(pointer_id: int, screen_position: Vector2) -> void:
	road_stroke_active[pointer_id] = true
	var world_position: Variant = _raycast_ground(screen_position)
	if world_position == null:
		_set_status("Tap or drag directly on the ground to lay asphalt.")
		return
	var cell: Vector2i = BuildManager.world_to_grid(world_position)
	road_stroke_last_cell[pointer_id] = cell
	var road_system = _road_system()
	if road_system == null:
		_set_status("Road system is unavailable.")
		return
	if road_system.has_road(cell):
		_set_status("Drag from this road to extend the asphalt network.")
	elif road_system.place_road(cell):
		_set_status("Road placed. Keep dragging to pave a connected route (50 per tile).")
	else:
		_set_status(road_system.get_road_placement_error(cell))

func _continue_road_stroke(pointer_id: int, screen_position: Vector2) -> void:
	var world_position: Variant = _raycast_ground(screen_position)
	if world_position == null or not road_stroke_last_cell.has(pointer_id):
		return
	var target_cell: Vector2i = BuildManager.world_to_grid(world_position)
	var previous: Vector2i = road_stroke_last_cell[pointer_id]
	if target_cell == previous:
		return
	var road_system = _road_system()
	if road_system == null:
		return
	for cell in _grid_line(previous, target_cell):
		if road_system.has_road(cell):
			road_stroke_last_cell[pointer_id] = cell
			continue
		if road_system.place_road(cell):
			road_stroke_last_cell[pointer_id] = cell
			_set_status("Paving connected road… 50 Simoleons per tile.")
		else:
			_set_status(road_system.get_road_placement_error(cell))
			break

func _grid_line(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x: int = start.x
	var y: int = start.y
	var dx: int = absi(finish.x - start.x)
	var dy: int = absi(finish.y - start.y)
	var sx: int = 1 if start.x < finish.x else -1
	var sy: int = 1 if start.y < finish.y else -1
	var error: int = dx - dy
	while x != finish.x or y != finish.y:
		var doubled_error: int = error * 2
		if doubled_error > -dy:
			error -= dy
			x += sx
		if doubled_error < dx:
			error += dx
			y += sy
		cells.append(Vector2i(x, y))
	return cells

func _end_road_stroke(pointer_id: int) -> void:
	road_stroke_active.erase(pointer_id)
	road_stroke_last_cell.erase(pointer_id)

func _cancel_all_road_strokes() -> void:
	road_stroke_active.clear()
	road_stroke_last_cell.clear()

func _handle_tap(screen_position: Vector2) -> void:
	var world_position: Variant = _raycast_ground(screen_position)
	if world_position == null:
		return
	var road_system = _road_system()
	var cell: Vector2i = BuildManager.world_to_grid(world_position)
	if bulldoze_mode or bulldoze_road_mode:
		_handle_bulldoze_cell(cell, road_system)
		return
	if road_system and road_system.is_road_mode:
		if road_system.place_road(cell):
			_set_status("Road placed. Tap an adjacent tile to continue (50 Simoleons).")
		else:
			_set_status(road_system.get_road_placement_error(cell))
		return
	if BuildManager.is_placing:
		var grid := BuildManager.world_to_grid(world_position)
		var ghost = get_tree().current_scene.get_node_or_null("GhostPreview")
		if ghost:
			ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid))
		if BuildManager.place_building_at_world(world_position):
			_set_status("Construction started. Tap another green plot to build again.")
			if ghost:
				ghost.hide_ghost()
		else:
			_set_status("Cannot build here: use an empty plot beside a road. Red preview means blocked or not connected.")
		return
	_try_interact(world_position)

func _set_status(message: String) -> void:
	var label = get_tree().current_scene.get_node_or_null("HUD/StatusLabel")
	if label:
		label.text = message

func _update_ghost(screen_position: Vector2) -> void:
	var world_position: Variant = _raycast_ground(screen_position)
	var ghost = get_tree().current_scene.get_node_or_null("GhostPreview")
	if ghost == null or world_position == null or not BuildManager.is_placing:
		return
	var grid: Vector2i = BuildManager.world_to_grid(world_position)
	ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid))

func _raycast_ground(screen_position: Vector2) -> Variant:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return null
	var distance: float = -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return null
	var hit: Vector3 = ray_origin + ray_direction * distance
	if absf(hit.x) > 80.0 or absf(hit.z) > 80.0:
		return null
	return hit

func _try_interact(world_position: Vector3) -> void:
	var grid: Vector2i = BuildManager.world_to_grid(world_position)
	var building = BuildManager.building_at_cell(grid)
	if building == null or not is_instance_valid(building):
		return
	if building.status != "completed":
		_set_status("Still under construction…")
		return

	var category := str(building.definition.get("category", ""))

	# Residential
	if category == "residential":
		if building.upgrade_ready:
			if building.try_upgrade():
				_set_status("House upgraded to level %d." % building.upgrade_stage)
			else:
				_set_status("Upgrade failed. Check materials.")
		else:
			_set_status(building.get_info())
		return

	# Industrial factories
	if category == "industrial":
		if building.has_ready_product:
			if building.collect_production():
				_set_status("Collected %s. Factory restarted." % building.current_product.capitalize())
			else:
				_set_status("Storage full. Free space to collect.")
		elif building.is_producing:
			var left := int(ceil(building.production_timer))
			_set_status("Producing %s… %ds left" % [building.current_product.capitalize(), left])
		elif building.start_factory_production():
			_set_status("Factory started producing %s." % building.current_product.capitalize())
		else:
			_set_status(building.get_info())
		return

	# Commercial stores
	if category == "commercial":
		if building.has_ready_product:
			if building.collect_production():
				_set_status("Collected %s." % building.current_product.capitalize())
			else:
				_set_status("Storage full. Free space to collect.")
			return

		if building.is_producing:
			var left2 := int(ceil(building.production_timer))
			_set_status("Crafting %s… %ds left" % [building.current_product.capitalize(), left2])
			return

		var recipe_id := ProductionManager.get_default_recipe_for_building(building.building_type)
		if recipe_id == "":
			_set_status("No unlocked recipe for this store yet.")
			return

		if building.start_commercial_production(recipe_id):
			_set_status("Crafting %s…" % recipe_id.capitalize())
		else:
			var missing := ProductionManager.get_missing_inputs_text(recipe_id)
			if missing != "":
				_set_status("Need materials for %s: %s" % [recipe_id.capitalize(), missing])
			else:
				_set_status("Cannot start %s. Check store level and materials." % recipe_id.capitalize())
		return

	_set_status(building.get_info())