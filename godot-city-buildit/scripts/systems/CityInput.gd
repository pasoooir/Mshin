extends Node3D

const TAP_SLOP: float = 14.0

@onready var camera: Camera3D = null

var pointer_start: Dictionary = {}
var pointer_moved: Dictionary = {}
var multi_touch_gesture: bool = false

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_start[-1] = event.position
			pointer_moved[-1] = false
		else:
			var start: Vector2 = pointer_start.get(-1, event.position)
			if start.distance_to(event.position) <= TAP_SLOP and not bool(pointer_moved.get(-1, false)):
				_handle_tap(event.position)
			pointer_start.erase(-1)
			pointer_moved.erase(-1)
	elif event is InputEventMouseMotion:
		if pointer_start.has(-1) and Vector2(pointer_start[-1]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[-1] = true
		if BuildManager.is_placing:
			_update_ghost(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if pointer_start.size() > 0:
				multi_touch_gesture = true
				for pointer_id in pointer_moved.keys():
					pointer_moved[pointer_id] = true
			pointer_start[event.index] = event.position
			pointer_moved[event.index] = false
		else:
			if pointer_start.has(event.index):
				var start: Vector2 = pointer_start[event.index]
				if not multi_touch_gesture and start.distance_to(event.position) <= TAP_SLOP and not bool(pointer_moved.get(event.index, false)):
					_handle_tap(event.position)
			pointer_start.erase(event.index)
			pointer_moved.erase(event.index)
			if pointer_start.is_empty():
				multi_touch_gesture = false
	elif event is InputEventScreenDrag:
		if pointer_start.size() > 1:
			multi_touch_gesture = true
			for pointer_id in pointer_moved.keys():
				pointer_moved[pointer_id] = true
		if pointer_start.has(event.index) and Vector2(pointer_start[event.index]).distance_to(event.position) > TAP_SLOP:
			pointer_moved[event.index] = true
		if BuildManager.is_placing and event.index == 0:
			_update_ghost(event.position)

func _handle_tap(screen_position: Vector2) -> void:
	var world_position: Variant = _raycast_ground(screen_position)
	if world_position == null:
		return
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system and road_system.is_road_mode:
		if road_system.place_road_at_world(world_position):
			_set_status("Road tile connected. Place the next tile beside the road.")
		else:
			_set_status("Road must connect to the existing network and cost 50 Simoleons.")
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
	# Direct cell lookup avoids scanning every building and allocating footprint arrays on each tap.
	var building = BuildManager.building_at_cell(grid)
	if building == null or not is_instance_valid(building):
		return
	if building.definition.get("category", "") == "residential":
		if building.upgrade_ready:
			if building.try_upgrade():
				_set_status("House upgraded to level %d. Population increased." % building.upgrade_stage)
		else:
			_set_status(building.get_info())
	elif building.definition.get("category", "") == "commercial":
		if building.building_type == "building_supplies":
			if ProductionManager.craft_item("nails"):
				_set_status("Crafted Nails. Wait for another Metal and upgrade your house.")
			else:
				_set_status("Building Supplies: collect Metal from your factory, then tap here to craft Nails.")
		else:
			_set_status(building.get_info())
	elif building.has_ready_product:
		if building.collect_production():
			_set_status("Collected %s. It is now in your city storage." % building.current_product.capitalize())
	else:
		_set_status(building.get_info())
