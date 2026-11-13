class_name TrafficVehicle
extends Node3D

signal route_completed

var route: Array[Vector2i] = []
var speed: float = 10.0

var _segment_index: int = 0
var _segment_progress: float = 0.0
var _started: bool = false

func _ready() -> void:
	_build_vehicle_mesh()
	if route.size() < 2:
		return
	global_position = _cell_center(route[0])
	_started = true

func _process(delta: float) -> void:
	if not _started:
		return
	if _segment_index >= route.size() - 1:
		_started = false
		route_completed.emit()
		queue_free()
		return
	var from_cell: Vector2i = route[_segment_index]
	var to_cell: Vector2i = route[_segment_index + 1]
	var travel_direction: Vector2i = to_cell - from_cell
	var from_position := _lane_position(from_cell, travel_direction)
	var to_position := _lane_position(to_cell, travel_direction)
	var segment_length := from_position.distance_to(to_position)
	if segment_length <= 0.001:
		_segment_index += 1
		_segment_progress = 0.0
		return
	_segment_progress += speed * delta / segment_length
	var progress := clampf(_segment_progress, 0.0, 1.0)
	global_position = from_position.lerp(to_position, progress)
	if global_position.distance_squared_to(to_position) > 0.0001:
		look_at(to_position, Vector3.UP)
	if _segment_progress >= 1.0:
		_segment_index += 1
		_segment_progress = 0.0

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * 2.0 + 1.0, 0.05, float(cell.y) * 2.0 + 1.0)

func _lane_position(cell: Vector2i, travel_direction: Vector2i) -> Vector3:
	var direction := Vector2(float(travel_direction.x), float(travel_direction.y)).normalized()
	var right := Vector2(-direction.y, direction.x)
	var center := _cell_center(cell)
	return center + Vector3(right.x * 0.14, 0.0, right.y * 0.14)

func _build_vehicle_mesh() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.82, 0.18, 0.12)
	body_material.roughness = 0.48
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.12, 0.24, 0.30)
	glass_material.metallic = 0.12
	glass_material.roughness = 0.22
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = Color(0.035, 0.04, 0.045)
	var light_material := StandardMaterial3D.new()
	light_material.albedo_color = Color(1.0, 0.88, 0.58)
	light_material.emission_enabled = true
	light_material.emission = Color(0.5, 0.32, 0.12)

	_add_box("Body", Vector3(0.94, 0.34, 1.62), Vector3(0.0, 0.30, 0.0), body_material)
	_add_box("Cabin", Vector3(0.76, 0.36, 0.82), Vector3(0.0, 0.63, 0.04), glass_material)
	_add_box("FrontBumper", Vector3(0.88, 0.10, 0.10), Vector3(0.0, 0.20, -0.84), tire_material)
	_add_box("RearBumper", Vector3(0.88, 0.10, 0.10), Vector3(0.0, 0.20, 0.84), tire_material)
	_add_box("LeftHeadlight", Vector3(0.16, 0.09, 0.04), Vector3(-0.30, 0.34, -0.83), light_material)
	_add_box("RightHeadlight", Vector3(0.16, 0.09, 0.04), Vector3(0.30, 0.34, -0.83), light_material)

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
			wheel.position = Vector3(x_sign * 0.48, 0.17, z_sign * 0.52)
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
