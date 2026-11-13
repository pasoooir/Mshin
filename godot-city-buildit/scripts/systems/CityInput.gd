extends Node3D

const TAP_SLOP: float = 14.0
const LONG_PRESS_MOVE_SLOP: float = 36.0

@onready var camera: Camera3D = null

var pointer_start: Dictionary = {}
var pointer_moved: Dictionary = {}
var pointer_hold_elapsed: Dictionary = {}
var pointer_last_position: Dictionary = {}
var placement_rotate_pointer: Dictionary = {}
var move_pointer_id: int = -999
const LONG_PRESS_SECONDS: float = 0.55
var multi_touch_gesture: bool = false
var road_stroke_active: Dictionary = {}
var road_stroke_last_cell: Dictionary = {}
var bulldoze_mode: bool = false
var bulldoze_road_mode: bool = false
var pending_bulldoze_building_id: String = ""

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

# Godot can synthesize mouse events from a physical touch. Treat the real
# ScreenTouch stream as authoritative so one finger is never counted twice.
func _has_active_screen_touch() -> bool:
	for pointer_id in pointer_start.keys():
		if int(pointer_id) >= 0:
			return true
	return false

func _clear_emulated_mouse_pointer() -> void:
	pointer_start.erase(-1)
	pointer_moved.erase(-1)
	pointer_hold_elapsed.erase(-1)
	pointer_last_position.erase(-1)
	road_stroke_active.erase(-1)
	road_stroke_last_cell.erase(-1)

func _process(delta: float) -> void:
	if BuildManager.is_moving or bulldoze_mode or bulldoze_road_mode or _is_road_mode():
		return
	if pointer_start.size() != 1:
		return
	var pointer_id = pointer_start.keys()[0]
	var last_position: Vector2 = pointer_last_position.get(pointer_id, pointer_start[pointer_id])
	# Small touch jitter is normal on phones. Only cancel long-press after a
	# deliberate movement beyond the larger long-press tolerance.
	if Vector2(pointer_start[pointer_id]).distance_to(last_position) > LONG_PRESS_MOVE_SLOP:
		pointer_hold_elapsed.erase(pointer_id)
		return
	pointer_hold_elapsed[pointer_id] = float(pointer_hold_elapsed.get(pointer_id, 0.0)) + delta
	if float(pointer_hold_elapsed[pointer_id]) >= LONG_PRESS_SECONDS:
		pointer_hold_elapsed[pointer_id] = -1.0
		if BuildManager.is_placing:
			if BuildManager.rotate_placement():
				placement_rotate_pointer[pointer_id] = true
				pointer_moved[pointer_id] = true
				pointer_hold_elapsed[pointer_id] = 0.0
				_update_ghost(last_position)
				_set_status("Building rotated 90 degrees. Keep holding to rotate again, or tap a plot to place.")
		else:
			_begin_move_from_screen(pointer_id, pointer_start[pointer_id])

func _begin_move_from_screen(pointer_id: int, screen_position: Vector2) -> void:
	# Resolve the visible building volume: in an oblique view the ground point
	# under a roof/facade touch can be behind the actual building footprint.
	var building := _building_at_screen(screen_position)
	if building == null or not is_instance_valid(building):
		_set_status("No building selected. Press and hold directly on a building to move it.")
		return
	if building.status != "completed":
		_set_status("Still under construction")
		return
	if BuildManager.begin_move(building):
		if BuildManager.is_placing:
			BuildManager.cancel_placement()
		move_pointer_id = int(pointer_id)
		pointer_moved[pointer_id] = true
		_set_status("Move mode: drag the highlighted building to a green valid plot. Release to place or press X to cancel.")
	else:
		_set_status("This building cannot be moved right now.")

func _building_at_screen(screen_position: Vector2) -> Building:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var closest_building: Building = null
	var closest_distance := INF
	for candidate in BuildManager.buildings.values():
		if not is_instance_valid(candidate) or not (candidate is Building):
			continue
		var building := candidate as Building
		var footprint: Vector2i = building.definition.get("size", Vector2i(2, 2))
		var half_width := float(footprint.x) * BuildManager.GRID_SIZE * 0.5 + 0.18
		var half_depth := float(footprint.y) * BuildManager.GRID_SIZE * 0.5 + 0.18
		# Conservative model-space envelope includes roof and upper facade.
		var bounds := AABB(
			Vector3(building.global_position.x - half_width, 0.0, building.global_position.z - half_depth),
			Vector3(half_width * 2.0, 14.0, half_depth * 2.0)
		)
		var hit_position: Variant = bounds.intersects_ray(ray_origin, ray_direction)
		if hit_position == null:
			continue
		var hit_distance := ray_origin.distance_to(hit_position)
		if hit_distance < closest_distance:
			closest_distance = hit_distance
			closest_building = building
	return closest_building

# CameraController uses this to suppress one-finger pan during a building hold.
func is_building_press_pending(pointer_id: int) -> bool:
	if not pointer_start.has(pointer_id):
		return false
	var building := _building_at_screen(pointer_start[pointer_id])
	return building != null and is_instance_valid(building)

func _update_move_from_screen(screen_position: Vector2) -> void:
	if not BuildManager.is_moving:
		return
	var world_position: Variant = _raycast_ground(screen_position)
	if world_position == null:
		BuildManager.invalidate_move_preview()
		_set_status("Invalid location — move back onto the map or press X to cancel.")
		return
	# The finger tracks the building centre; convert it to the footprint anchor.
	var target_anchor := _move_anchor_from_world(world_position)
	var valid := BuildManager.preview_move_at(target_anchor)
	_set_status("Valid location — release to move." if valid else "Invalid location — move to a green plot or press X to cancel.")

func _move_anchor_from_world(world_position: Vector3) -> Vector2i:
	if not BuildManager.is_moving or not is_instance_valid(BuildManager.moving_building):
		return BuildManager.world_to_grid(world_position)
	var footprint: Vector2i = BuildManager.moving_building.definition.get("size", Vector2i(2, 2))
	var anchor_offset := Vector3((footprint.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.0, (footprint.y - 1) * BuildManager.GRID_SIZE * 0.5)
	return BuildManager.world_to_grid(world_position - anchor_offset)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and BuildManager.is_placing:
		if BuildManager.rotate_placement():
			var ghost = get_tree().current_scene.get_node_or_null("GhostPreview") if get_tree().current_scene else null
			if ghost and ghost.visible:
				var previous_size: Vector2i = BuildManager.get_building_size(BuildManager.selected_building_type, posmod(BuildManager.placement_rotation_quarters - 1, 4))
				var anchor_world: Vector3 = ghost.global_position - Vector3((previous_size.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.95, (previous_size.y - 1) * BuildManager.GRID_SIZE * 0.5)
				var grid: Vector2i = BuildManager.world_to_grid(anchor_world)
				ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid, BuildManager.selected_building_type, BuildManager.placement_rotation_quarters), BuildManager.building_types.get(BuildManager.selected_building_type, {}), float(BuildManager.placement_rotation_quarters) * PI * 0.5)
			_set_status("Building rotated 90 degrees.")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		if BuildManager.is_moving:
			BuildManager.cancel_move()
			move_pointer_id = -999
			pointer_start.clear()
			pointer_moved.clear()
			pointer_hold_elapsed.clear()
			pointer_last_position.clear()
			_set_status("Move cancelled. Building returned to its original location.")
			get_viewport().set_input_as_handled()
			return
		if bulldoze_mode or bulldoze_road_mode or BuildManager.is_placing or _is_road_mode() or _is_road_upgrade_mode():
			var hud = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
			if hud and hud.has_method("_on_cancel_pressed"):
				hud._on_cancel_pressed()
			else:
				set_bulldoze_mode(false)
				set_bulldoze_road_mode(false)
				BuildManager.cancel_placement()
				var roads = _road_system()
				if roads:
					roads.set_road_mode(false)
					roads.set_road_upgrade_mode(false)
				_set_status("Tool cancelled.")
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Ignore synthetic mouse input while a real touch owns the gesture.
		if _has_active_screen_touch():
			return
		if event.pressed:
			pointer_start[-1] = event.position
			pointer_moved[-1] = false
			pointer_hold_elapsed[-1] = 0.0
			pointer_last_position[-1] = event.position
			if _is_road_mode():
				_start_road_stroke(-1, event.position)
		else:
			if BuildManager.is_moving and move_pointer_id == -1:
				var moved_ok := BuildManager.finish_move()
				_set_status("Building moved successfully." if moved_ok else "Invalid location. Building returned to its original location.")
				move_pointer_id = -999
			elif road_stroke_active.has(-1):
				_end_road_stroke(-1)
			else:
				var start: Vector2 = pointer_start.get(-1, event.position)
				var moved := bool(pointer_moved.get(-1, false))
				# In building mode, dragging the placement ghost commits the final
				# green preview on release. Other interactions remain tap-only.
				if BuildManager.is_placing and moved and not placement_rotate_pointer.has(-1):
					_handle_tap(event.position)
				elif start.distance_to(event.position) <= TAP_SLOP and not moved:
					_handle_tap(event.position)
			pointer_start.erase(-1)
			pointer_moved.erase(-1)
			pointer_hold_elapsed.erase(-1)
			pointer_last_position.erase(-1)
			placement_rotate_pointer.erase(-1)
	elif event is InputEventMouseMotion:
		if _has_active_screen_touch():
			return
		if pointer_start.has(-1):
			pointer_last_position[-1] = event.position
		if pointer_start.has(-1) and Vector2(pointer_start[-1]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[-1] = true
		if road_stroke_active.has(-1):
			_continue_road_stroke(-1, event.position)
		elif BuildManager.is_moving and move_pointer_id == -1:
			_update_move_from_screen(event.position)
		elif BuildManager.is_placing:
			_update_ghost(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			# If emulation produced a mouse-down first, discard that duplicate
			# pointer before starting the authoritative touch pointer.
			_clear_emulated_mouse_pointer()
			if pointer_start.size() > 0:
				multi_touch_gesture = true
				_cancel_all_road_strokes()
				for pointer_id in pointer_moved.keys():
					pointer_moved[pointer_id] = true
			pointer_start[event.index] = event.position
			pointer_moved[event.index] = false
			pointer_hold_elapsed[event.index] = 0.0
			pointer_last_position[event.index] = event.position
			if pointer_start.size() == 1 and _is_road_mode():
				_start_road_stroke(event.index, event.position)
		else:
			if road_stroke_active.has(event.index):
				_end_road_stroke(event.index)
			elif pointer_start.has(event.index):
				if BuildManager.is_moving and move_pointer_id == event.index:
					var moved_ok := BuildManager.finish_move()
					_set_status("Building moved successfully." if moved_ok else "Invalid location. Building returned to its original location.")
					move_pointer_id = -999
				else:
					var start: Vector2 = pointer_start[event.index]
					var moved := bool(pointer_moved.get(event.index, false))
					if not multi_touch_gesture and not BuildManager.is_moving:
						if BuildManager.is_placing and moved and not placement_rotate_pointer.has(event.index):
							_handle_tap(event.position)
						elif start.distance_to(event.position) <= TAP_SLOP and not moved:
							_handle_tap(event.position)
			pointer_start.erase(event.index)
			pointer_moved.erase(event.index)
			pointer_hold_elapsed.erase(event.index)
			pointer_last_position.erase(event.index)
			placement_rotate_pointer.erase(event.index)
			if pointer_start.is_empty():
				multi_touch_gesture = false
	elif event is InputEventScreenDrag:
		if pointer_start.has(event.index):
			pointer_last_position[event.index] = event.position
		if pointer_start.size() > 1:
			multi_touch_gesture = true
			_cancel_all_road_strokes()
			for pointer_id in pointer_moved.keys():
				pointer_moved[pointer_id] = true
		if pointer_start.has(event.index) and Vector2(pointer_start[event.index]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[event.index] = true
		if road_stroke_active.has(event.index) and pointer_start.size() == 1:
			_continue_road_stroke(event.index, event.position)
		elif BuildManager.is_moving and move_pointer_id == event.index:
			_update_move_from_screen(event.position)
		elif BuildManager.is_placing and event.index == 0:
			_update_ghost(event.position)

func _is_road_mode() -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	return road_system != null and road_system.is_road_mode

func _is_road_upgrade_mode() -> bool:
	var road_system = _road_system()
	return road_system != null and road_system.is_road_upgrade_mode

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
			_set_status("Paving connected road... 50 Simoleons per tile.")
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
	if road_system and road_system.is_road_upgrade_mode:
		if road_system.upgrade_road(cell):
			_set_status("Road upgraded to %s." % road_system.get_road_level_name(road_system.get_road_level(cell)))
		else:
			_set_status(road_system.get_road_upgrade_error(cell))
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
			ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid), BuildManager.building_types.get(BuildManager.selected_building_type, {}), float(BuildManager.placement_rotation_quarters) * PI * 0.5)
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
	ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid), BuildManager.building_types.get(BuildManager.selected_building_type, {}), float(BuildManager.placement_rotation_quarters) * PI * 0.5)

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
	var scene := get_tree().current_scene
	var camera_rig = scene.get_node_or_null("CameraRig") if scene else null
	if camera_rig != null and camera_rig.has_method("focus_on"):
		camera_rig.focus_on(building.global_position)
	if building.status != "completed":
		_set_status("Still under construction…")
		return

	var category := str(building.definition.get("category", ""))

	# Residential buildings open a full upgrade-plan panel. The city-wide
	# dashboard remains available so the player never needs to inspect homes one by one.
	if category == "residential":
		var hud := get_tree().current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("open_residential_panel"):
			hud.open_residential_panel(building)
		else:
			_set_status(building.get_info())
		return

	# Production buildings open an explicit item/collect panel rather than
	# silently auto-ordering a product on every tap.
	if category in ["industrial", "commercial"]:
		var hud := get_tree().current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("open_production_panel"):
			hud.open_production_panel(building)
		else:
			_set_status(building.get_info())
		return

	_set_status(building.get_info())