extends Node3D

enum VoyageState { APPROACHING, BERTHED, UNLOADING, DEPARTING, WAITING }

const DOCK_X := 127.0
const OFFSHORE_X := 174.0
const DEPARTURE_X := 188.0
const ROUTE_Z := -22.0
const SAIL_SPEED := 12.0
const WALK_SPEED := 2.8
const PASSENGER_COUNT := 8
const UNLOAD_INTERVAL := 0.52
const TERMINAL_X := 99.0

var _state: VoyageState = VoyageState.APPROACHING
var _state_timer := 0.0
var _unload_timer := 0.0
var _passengers_waiting: Array[Node3D] = []
var _passenger_walkers: Array[Dictionary] = []
var _unloaded_total := 0
var _voyage_count := 0

func _ready() -> void:
	position = Vector3(OFFSHORE_X, 0.12, ROUTE_Z)
	_build_ship()
	_build_passengers()
	rotation.y = 0.0

func _process(delta: float) -> void:
	match _state:
		VoyageState.APPROACHING:
			position.x = move_toward(position.x, DOCK_X, SAIL_SPEED * delta)
			if is_equal_approx(position.x, DOCK_X):
				_state = VoyageState.BERTHED
				_state_timer = 0.65
				_voyage_count += 1
				rotation.y = lerp_angle(rotation.y, 0.0, minf(1.0, delta * 1.8))
		VoyageState.BERTHED:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = VoyageState.UNLOADING
				_unload_timer = UNLOAD_INTERVAL
		VoyageState.UNLOADING:
			_unload_timer += delta
			while _unload_timer >= UNLOAD_INTERVAL and not _passengers_waiting.is_empty():
				_unload_timer -= UNLOAD_INTERVAL
				_release_next_passenger()
			_update_passenger_walkers(delta)
			if _passengers_waiting.is_empty() and _passenger_walkers.is_empty():
				_state = VoyageState.DEPARTING
		VoyageState.DEPARTING:
			position.x = move_toward(position.x, DEPARTURE_X, SAIL_SPEED * delta)
			rotation.y = lerp_angle(rotation.y, -0.035, minf(1.0, delta * 1.2))
			if is_equal_approx(position.x, DEPARTURE_X):
				_state = VoyageState.WAITING
				_state_timer = 2.2
		VoyageState.WAITING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_reset_passengers()
				position.x = OFFSHORE_X
				rotation.y = 0.0
				_state = VoyageState.APPROACHING

func _build_ship() -> void:
	_add_box("PassengerFerryHull", Vector3(0.0, 0.45, 0.0), Vector3(11.0, 1.05, 3.8), Color("#24495C"), Color("#102F42"))
	_add_box("FerryWaterline", Vector3(0.0, 0.12, 0.0), Vector3(10.8, 0.22, 3.92), Color("#D7E3E4"), Color("#8BA6AB"))
	_add_box("PassengerDeck", Vector3(-0.15, 1.05, 0.0), Vector3(9.8, 0.20, 3.5), Color("#D6D8D0"), Color("#829399"))
	_add_box("LowerCabin", Vector3(2.15, 1.88, 0.0), Vector3(4.25, 1.42, 3.0), Color("#E9E6DB"), Color("#75858A"))
	_add_box("CabinRoof", Vector3(2.15, 2.62, 0.0), Vector3(4.5, 0.16, 3.2), Color("#F4F0E3"), Color("#9AA5A4"))
	_add_box("FrontGlass", Vector3(-0.05, 1.91, 1.51), Vector3(3.7, 0.78, 0.045), Color("#5B9EB3"), Color("#2E5B6C"))
	_add_box("RearGlass", Vector3(4.29, 1.91, 0.0), Vector3(0.045, 0.78, 2.65), Color("#5B9EB3"), Color("#2E5B6C"))
	_add_box("UpperPassengerDeck", Vector3(-2.25, 1.82, 0.0), Vector3(3.5, 0.12, 3.0), Color("#BFCBC9"), Color("#73878B"))
	_add_box("BowStripe", Vector3(-5.48, 0.62, 0.0), Vector3(0.12, 0.46, 2.4), Color("#F1EEE4"), Color("#A9B9B9"))
	_add_box("FerryNamePlate", Vector3(2.3, 2.74, 1.58), Vector3(2.3, 0.26, 0.06), Color("#D9E8E8"), Color("#52717C"))
	_add_cylinder("Mast", Vector3(3.75, 3.05, -0.82), 0.055, 0.78, Color("#D8DDDA"))
	_add_cylinder("Radar", Vector3(3.75, 3.48, -0.82), 0.19, 0.06, Color("#3E6875"))

func _build_passengers() -> void:
	for index in range(PASSENGER_COUNT):
		var passenger := _create_passenger(index)
		passenger.name = "Passenger_%02d" % index
		var row := index / 4
		var lane := (index % 4) - 1.5
		passenger.position = Vector3(-3.55 + float(row) * 1.05, 1.18, lane * 0.54)
		add_child(passenger)
		_passengers_waiting.append(passenger)

func _create_passenger(index: int) -> Node3D:
	var person := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.19
	body_mesh.height = 0.78
	body.mesh = body_mesh
	body.position.y = 0.48
	var body_material := StandardMaterial3D.new()
	var palette: Array[Color] = [Color("#D76E4D"), Color("#4E83A1"), Color("#D6B45F"), Color("#648D68"), Color("#9B6B91"), Color("#D1D1C4"), Color("#C47E47"), Color("#507C78")]
	body_material.albedo_color = palette[index % palette.size()]
	body_material.roughness = 0.82
	body.material_override = body_material
	person.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.145
	head_mesh.height = 0.29
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.02, 0.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#D7A27D")
	skin.roughness = 0.9
	head.material_override = skin
	person.add_child(head)
	return person

func _release_next_passenger() -> void:
	if _passengers_waiting.is_empty():
		return
	var passenger := _passengers_waiting.pop_front()
	var parent := get_parent()
	if parent == null:
		return
	passenger.reparent(parent, true)
	var lane := float(_unloaded_total % 4) - 1.5
	var target := Vector3(TERMINAL_X + float(_unloaded_total / 4) * 0.9, 0.58, ROUTE_Z + lane * 1.15)
	passenger.set_meta("walk_target", target)
	passenger.set_meta("walk_phase", float(_unloaded_total) * 0.7)
	_unloaded_total += 1
	_passenger_walkers.append({"node": passenger, "target": target})

func _update_passenger_walkers(delta: float) -> void:
	for index in range(_passenger_walkers.size() - 1, -1, -1):
		var walker: Dictionary = _passenger_walkers[index]
		var passenger := walker["node"] as Node3D
		if not is_instance_valid(passenger):
			_passenger_walkers.remove_at(index)
			continue
		var target: Vector3 = walker["target"]
		passenger.global_position = passenger.global_position.move_toward(target, WALK_SPEED * delta)
		passenger.rotation.y = PI
		if passenger.global_position.distance_to(target) <= 0.18:
			passenger.queue_free()
			_passenger_walkers.remove_at(index)

func _reset_passengers() -> void:
	for passenger in _passengers_waiting:
		if is_instance_valid(passenger):
			passenger.queue_free()
	_passengers_waiting.clear()
	_passenger_walkers.clear()
	_unloaded_total = 0
	_build_passengers()

func _add_box(node_name: String, local_position: Vector3, dimensions: Vector3, color: Color, edge_color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.08
	instance.material_override = material
	add_child(instance)
	var outline := MeshInstance3D.new()
	outline.name = node_name + "Edge"
	var outline_mesh := BoxMesh.new()
	outline_mesh.size = dimensions * Vector3(1.012, 1.012, 1.012)
	outline.mesh = outline_mesh
	outline.position = local_position
	var outline_material := StandardMaterial3D.new()
	outline_material.albedo_color = edge_color
	outline_material.roughness = 0.9
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = outline_material
	add_child(outline)

func _add_cylinder(node_name: String, local_position: Vector3, radius: float, height: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	instance.material_override = material
	add_child(instance)

func get_voyage_state() -> int:
	return _state

func get_waiting_passenger_count() -> int:
	return _passengers_waiting.size()

func get_walking_passenger_count() -> int:
	return _passenger_walkers.size()

func get_completed_voyages() -> int:
	return _voyage_count

func get_last_voyage_unloaded_count() -> int:
	return _unloaded_total
