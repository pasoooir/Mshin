extends Node3D

const PASTURE_MIN_X := -88.0
const PASTURE_MAX_X := 42.0
const PASTURE_MIN_ABS_Z := 82.0
const PASTURE_MAX_ABS_Z := 88.5
const ASPHALT_MIN_X := -68.5
const ASPHALT_MAX_X := -42.0

var _animal_positions: Array[Vector3] = []
var _animal_headings: Array[float] = []
var _parts: Array[Dictionary] = []
var _elapsed := 0.0

func configure(sheep_positions: Array[Vector3], cattle_positions: Array[Vector3]) -> void:
	_animal_positions.clear()
	_animal_headings.clear()
	for position in sheep_positions:
		_animal_positions.append(position)
		_animal_headings.append(float(_animal_positions.size()) * 1.71)
	for position in cattle_positions:
		_animal_positions.append(position)
		_animal_headings.append(float(_animal_positions.size()) * 2.13)

func register_part(instance: MultiMeshInstance3D, owners: Array[int], offsets: Array[Vector3]) -> void:
	if not is_instance_valid(instance) or instance.multimesh == null:
		return
	if owners.size() != instance.multimesh.instance_count or offsets.size() != owners.size():
		push_error("Livestock MultiMesh registration has mismatched owner/offset arrays.")
		return
	var bases: Array[Basis] = []
	for index in range(instance.multimesh.instance_count):
		bases.append(instance.multimesh.get_instance_transform(index).basis)
	_parts.append({"multimesh": instance.multimesh, "owners": owners.duplicate(), "offsets": offsets.duplicate(), "bases": bases})

func is_valid_grazing_position(position: Vector3) -> bool:
	if position.x < PASTURE_MIN_X or position.x > PASTURE_MAX_X:
		return false
	var in_north_pasture := position.z >= PASTURE_MIN_ABS_Z and position.z <= PASTURE_MAX_ABS_Z
	var in_south_pasture := position.z <= -PASTURE_MIN_ABS_Z and position.z >= -PASTURE_MAX_ABS_Z
	if not in_north_pasture and not in_south_pasture:
		return false
	if position.x >= ASPHALT_MIN_X and position.x <= ASPHALT_MAX_X:
		return false
	if LandExpansionManager.is_world_position_unlocked(position):
		return false
	var scene := get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system:
		var cell := Vector2i(floori(position.x / BuildManager.GRID_SIZE), floori(position.z / BuildManager.GRID_SIZE))
		for x in range(-1, 2):
			for y in range(-1, 2):
				if road_system.has_road(cell + Vector2i(x, y)):
					return false
	return true

func _process(delta: float) -> void:
	if _animal_positions.is_empty():
		return
	var step := minf(delta, 0.1)
	_elapsed += step
	for index in range(_animal_positions.size()):
		var heading := _animal_headings[index] + sin(_elapsed * 0.31 + float(index) * 1.37) * step * 0.22
		var direction := Vector2(cos(heading), sin(heading))
		var speed := 0.24 + float((index * 7) % 5) * 0.055
		var candidate := _animal_positions[index] + Vector3(direction.x, 0.0, direction.y) * speed * step
		if is_valid_grazing_position(candidate):
			_animal_positions[index] = candidate
			_animal_headings[index] = heading
		else:
			_animal_headings[index] = heading + PI * (0.58 + float(index % 3) * 0.08)
	_update_multimesh_parts()

func _update_multimesh_parts() -> void:
	for part in _parts:
		var multimesh: MultiMesh = part["multimesh"]
		if multimesh == null:
			continue
		var owners: Array = part["owners"]
		var offsets: Array = part["offsets"]
		var bases: Array = part["bases"]
		for instance_index in range(mini(multimesh.instance_count, owners.size())):
			var owner_index := int(owners[instance_index])
			if owner_index < 0 or owner_index >= _animal_positions.size():
				continue
			var yaw := _animal_headings[owner_index]
			var rotation_basis := Basis(Vector3.UP, yaw)
			var basis: Basis = rotation_basis * bases[instance_index]
			var origin: Vector3 = _animal_positions[owner_index] + rotation_basis * offsets[instance_index]
			multimesh.set_instance_transform(instance_index, Transform3D(basis, origin))
