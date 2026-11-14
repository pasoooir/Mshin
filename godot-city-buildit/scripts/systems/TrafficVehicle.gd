class_name TrafficVehicle
extends Node3D

signal route_completed

var route: Array[Vector2i] = []
var speed: float = 2.0833333333
var vehicle_kind: String = "civilian"
var station_building_id: String = ""
var route_key: String = ""
var lane_index: int = 0
var lane_offset: float = 0.32
var ground_height: float = 0.05
var lane_direction: Vector2i = Vector2i.ZERO
var route_distance: float = 0.0
var initial_position: Vector3 = Vector3.ZERO
var use_initial_position: bool = false

var _segment_index: int = 0
var _segment_progress: float = 0.0
var _started: bool = false
var _initial_leg_complete: bool = false
var _last_segment_direction: Vector2i = Vector2i.ZERO
var _route_recovery_pending: bool = false
var _traffic_stop_elapsed: float = 0.0
var congestion_release_active: bool = false

func _ready() -> void:
	_build_vehicle_mesh()
	if route.size() < 2:
		return
	if use_initial_position:
		global_position = initial_position
	else:
		global_position = _lane_position(route[0], route[1] - route[0])
	_initial_leg_complete = not use_initial_position
	_started = true

func _process(delta: float) -> void:
	if not _started:
		return
	if _segment_index >= route.size() - 1:
		_started = false
		TrafficManager.release_all_junction_entries(self)
		route_completed.emit()
		queue_free()
		return

	var from_cell: Vector2i = route[_segment_index]
	var to_cell: Vector2i = route[_segment_index + 1]
	var travel_direction: Vector2i = to_cell - from_cell
	lane_direction = travel_direction
	var from_position: Vector3
	var to_position: Vector3
	if not _initial_leg_complete:
		from_position = initial_position
		to_position = _lane_position(from_cell, travel_direction)
	else:
		from_position = global_position if _route_recovery_pending or (_last_segment_direction != Vector2i.ZERO and _last_segment_direction != travel_direction) else _lane_position(from_cell, travel_direction)
		to_position = _lane_position(to_cell, travel_direction)

	var segment_length := from_position.distance_to(to_position)
	if segment_length <= 0.001:
		if not _initial_leg_complete:
			_initial_leg_complete = true
		else:
			_last_segment_direction = travel_direction
			_segment_index += 1
		_segment_progress = 0.0
		return

	var desired_speed: float = TrafficManager.get_speed_for_segment(from_cell, to_cell, vehicle_kind)
	var safe_speed: float = TrafficManager.get_safe_vehicle_speed(self, desired_speed)
	var junction_entry_denied := false
	# Junction admission is phase-controlled and remains a hard stop. The
	# four-second congestion recovery must never override a red/yellow phase.
	if safe_speed > 0.001:
		if not TrafficManager.request_junction_entry(self, to_cell, from_cell):
			junction_entry_denied = true
			safe_speed = 0.0
	else:
		TrafficManager.release_junction_entry(self, to_cell)
	if safe_speed <= 0.001:
		if TrafficManager.is_frontmost_vehicle_in_lane(self):
			_traffic_stop_elapsed += delta
			if _traffic_stop_elapsed >= TrafficManager.MAX_TRAFFIC_STOP_SECONDS:
				congestion_release_active = true
				safe_speed = TrafficManager.get_safe_vehicle_speed(self, desired_speed)
				if junction_entry_denied:
					safe_speed = 0.0
		else:
			# A follower is not allowed to start its own release timer or push
			# into the vehicle ahead; it waits for the leader to move.
			_traffic_stop_elapsed = 0.0
			congestion_release_active = false
		if safe_speed <= 0.001:
			return
	else:
		_traffic_stop_elapsed = 0.0
		congestion_release_active = false
	var movement: float = safe_speed * delta
	var remaining: float = segment_length * (1.0 - _segment_progress)
	var step: float = minf(movement, remaining)
	_segment_progress = minf(1.0, _segment_progress + step / segment_length)
	route_distance += step
	global_position = from_position.lerp(to_position, _segment_progress)
	if global_position.distance_squared_to(to_position) > 0.0001:
		look_at(to_position, Vector3.UP)
	if _segment_progress >= 1.0:
		if not _initial_leg_complete:
			_initial_leg_complete = true
		else:
			_last_segment_direction = travel_direction
			_route_recovery_pending = false
			TrafficManager.release_junction_entry(self, from_cell)
			_segment_index += 1
		_segment_progress = 0.0

func replace_route(new_route: Array[Vector2i]) -> void:
	if new_route.size() < 2:
		return
	route = new_route.duplicate()
	_segment_index = 0
	_segment_progress = 0.0
	_initial_leg_complete = true
	_last_segment_direction = Vector2i.ZERO
	_route_recovery_pending = true
	_traffic_stop_elapsed = 0.0
	congestion_release_active = false
	route_key = TrafficManager._route_key(route)
	lane_direction = route[1] - route[0]
	_started = true
	TrafficManager.release_all_junction_entries(self)

func _cell_center(cell: Vector2i) -> Vector3:
	var world_x := float(cell.x) * 2.0 + 1.0
	return Vector3(world_x, ground_height, float(cell.y) * 2.0 + 1.0)

func _lane_position(cell: Vector2i, travel_direction: Vector2i) -> Vector3:
	# Right-hand traffic: the vehicle occupies the lane to the driver's right.
	# In X/Z world coordinates this perpendicular points to the right for
	# every cardinal travel direction, so opposing traffic uses the other side.
	var direction := Vector2(float(travel_direction.x), float(travel_direction.y)).normalized()
	var right := Vector2(-direction.y, direction.x)
	var center := _cell_center(cell)
	return center + Vector3(right.x * lane_offset, 0.0, right.y * lane_offset)

func _build_vehicle_mesh() -> void:
	var body_color := Color("#D94A3A")
	var glass_color := Color("#183A4A")
	if vehicle_kind == "police":
		body_color = Color("#F0F2F4")
	elif vehicle_kind == "fire":
		body_color = Color("#D5221E")
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color
	body_material.roughness = 0.48
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = glass_color
	glass_material.metallic = 0.12
	glass_material.roughness = 0.22
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = Color("#090B0D")
	var light_material := StandardMaterial3D.new()
	light_material.albedo_color = Color("#FFE5A6")
	light_material.emission_enabled = true
	light_material.emission = Color("#D88A38")
	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color("#F51F24") if vehicle_kind == "fire" else Color("#245BFF")
	beacon_material.emission_enabled = true
	beacon_material.emission = beacon_material.albedo_color * 1.8

	_add_box("Body", Vector3(0.56, 0.34, 1.50), Vector3(0.0, 0.30, 0.0), body_material)
	_add_box("Cabin", Vector3(0.46, 0.36, 0.78), Vector3(0.0, 0.63, 0.04), glass_material)
	_add_box("FrontBumper", Vector3(0.54, 0.10, 0.10), Vector3(0.0, 0.20, -0.84), tire_material)
	_add_box("RearBumper", Vector3(0.88, 0.10, 0.10), Vector3(0.0, 0.20, 0.84), tire_material)
	_add_box("LeftHeadlight", Vector3(0.16, 0.09, 0.04), Vector3(-0.18, 0.34, -0.77), light_material)
	_add_box("RightHeadlight", Vector3(0.16, 0.09, 0.04), Vector3(0.18, 0.34, -0.77), light_material)
	if vehicle_kind == "police" or vehicle_kind == "fire":
		_add_box("EmergencyLightbar", Vector3(0.56, 0.09, 0.16), Vector3(0.0, 0.86, 0.02), beacon_material)
		if vehicle_kind == "fire":
			_add_box("FireEquipment", Vector3(0.54, 0.16, 0.72), Vector3(0.0, 0.86, 0.43), body_material)

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.17
	wheel_mesh.bottom_radius = 0.17
	wheel_mesh.height = 0.13
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			wheel.mesh = wheel_mesh
			wheel.material_override = tire_material
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(x_sign * 0.25, 0.17, z_sign * 0.48)
			add_child(wheel)

func _add_box(node_name: String, box_size: Vector3, local_position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	add_child(instance)
