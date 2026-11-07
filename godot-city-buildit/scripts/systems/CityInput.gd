extends Node3D

@onready var camera: Camera3D = null
var touch_start: Dictionary = {}
var touch_moved: Dictionary = {}
var multi_touch_gesture := false
const TAP_SLOP := 14.0

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if BuildManager.is_placing:
			_update_ghost(event.position)
		if touch_start.has(-1) and Vector2(touch_start[-1]).distance_to(event.position) > TAP_SLOP:
			touch_moved[-1] = true
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start[-1] = event.position
			touch_moved[-1] = false
		else:
			var start: Vector2 = touch_start.get(-1, event.position)
			if start.distance_to(event.position) <= TAP_SLOP and not bool(touch_moved.get(-1, false)):
				_handle_click(event.position)
			touch_start.erase(-1)
			touch_moved.erase(-1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if touch_start.size() >= 1:
				multi_touch_gesture = true
				for touch_id in touch_moved.keys():
					touch_moved[touch_id] = true
			touch_start[event.index] = event.position
			touch_moved[event.index] = false
		else:
			if touch_start.has(event.index):
				var start: Vector2 = touch_start[event.index]
				if not multi_touch_gesture and start.distance_to(event.position) <= TAP_SLOP and not bool(touch_moved.get(event.index, false)):
					_handle_click(event.position)
			touch_start.erase(event.index)
			touch_moved.erase(event.index)
			if touch_start.is_empty():
				multi_touch_gesture = false
	elif event is InputEventScreenDrag:
		if touch_start.size() > 1:
			multi_touch_gesture = true
			for touch_id in touch_moved.keys():
				touch_moved[touch_id] = true
		if touch_start.has(event.index) and Vector2(touch_start[event.index]).distance_to(event.position) > TAP_SLOP:
			touch_moved[event.index] = true
		if BuildManager.is_placing and event.index == 0:
			_update_ghost(event.position)

func _handle_click(screen_pos: Vector2) -> void:
	var hit = _raycast_ground(screen_pos)
	if hit == null:
		return
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system and road_system.is_road_mode:
		if road_system.place_road_at_world(hit):
			_set_status("Road placed — adjacent plots can now be developed.")
		return
	if BuildManager.is_placing:
		if BuildManager.place_building_at_world(hit):
			_set_status("Construction started.")
		else:
			_set_status("Invalid plot: clear space and road access required.")
		return
	_try_interact(hit)

func _set_status(message: String) -> void:
	var label = get_tree().current_scene.get_node_or_null("HUD/StatusLabel")
	if label:
		label.text = message

func _update_ghost(screen_pos: Vector2) -> void:
	var hit = _raycast_ground(screen_pos)
	var ghost = get_tree().current_scene.get_node_or_null("GhostPreview")
	if ghost == null or hit == null or not BuildManager.is_placing:
		return
	var grid = BuildManager.world_to_grid(hit)
	ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid))

func _raycast_ground(screen_pos: Vector2) -> Variant:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return null
	var distance := -from.y / direction.y
	if distance < 0.0:
		return null
	return from + direction * distance

func _try_interact(world_pos: Vector3) -> void:
	var grid := BuildManager.world_to_grid(world_pos)
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		var size: Vector2i = building.definition.get("size", Vector2i(2,2))
		if grid not in BuildManager.get_footprint_cells(building.grid_pos, size):
			continue
		if building.definition.get("category") == "residential":
			if building.upgrade_ready:
				building.try_upgrade()
			else:
				_set_status(building.get_info())
		elif building.definition.get("category") == "commercial":
			if building.building_type == "building_supplies":
				if ProductionManager.can_craft("nails") and ProductionManager.craft_item("nails"):
					_set_status("Crafted 1 Nails.")
				else:
					_set_status("Building Supplies: collect Metal from a factory, then tap here to craft Nails.")
			else:
				_set_status(building.get_info())
		elif building.has_ready_product:
			if building.collect_production():
				_set_status("Collected %s." % building.current_product.capitalize())
		else:
			_set_status(building.get_info())
		return
