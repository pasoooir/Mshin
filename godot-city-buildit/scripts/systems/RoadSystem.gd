extends Node3D

signal road_placed(grid_pos: Vector2i)
signal road_removed(grid_pos: Vector2i)

const GRID_SIZE: float = 2.0
const ROAD_COST: int = 50

var roads: Dictionary = {}
var is_road_mode: bool = false

func _ready() -> void:
	print("[RoadSystem] Ready")

func set_road_mode(active: bool) -> void:
	is_road_mode = active
	if active:
		BuildManager.cancel_placement()

func seed_starter_access() -> void:
	# A free two-lane connector joins the coastal highway to the first buildable plots.
	# It is seeded only for a brand-new city; saved road networks remain untouched.
	for x in range(-23, 2):
		for z in [-1, 0]:
			var cell := Vector2i(x, z)
			if roads.has(cell):
				continue
			var mesh := _create_road_mesh()
			mesh.rotation_degrees.y = 90.0
			add_child(mesh)
			mesh.position = Vector3(float(x) * GRID_SIZE + GRID_SIZE * 0.5, 0.025, float(z) * GRID_SIZE + GRID_SIZE * 0.5)
			roads[cell] = mesh

func has_road(grid_pos: Vector2i) -> bool:
	return roads.has(grid_pos)

func _has_adjacent_road(grid_pos: Vector2i) -> bool:
	if roads.is_empty():
		return true
	var neighbours: Array[Vector2i] = [
		grid_pos + Vector2i.UP,
		grid_pos + Vector2i.DOWN,
		grid_pos + Vector2i.LEFT,
		grid_pos + Vector2i.RIGHT
	]
	for neighbour in neighbours:
		if roads.has(neighbour):
			return true
	return false

func get_road_placement_error(grid_pos: Vector2i) -> String:
	if roads.has(grid_pos):
		return "A road already exists on this tile."
	if not BuildManager.is_inside_world(grid_pos):
		return "This tile is outside the buildable city area."
	if not _has_adjacent_road(grid_pos):
		return "Start beside the existing highway or road; roads must connect."
	if not EconomyManager.can_afford(ROAD_COST):
		return "Not enough Simoleons. Each road tile costs 50."
	if not BuildManager.is_cell_free(grid_pos, Vector2i.ONE):
		return "This tile is occupied by a building."
	return ""

func place_road(grid_pos: Vector2i) -> bool:
	if get_road_placement_error(grid_pos) != "":
		return false
	if not EconomyManager.spend_simoleons(ROAD_COST):
		return false
	var mesh: Node3D = _create_road_mesh()
	add_child(mesh)
	mesh.position = Vector3(grid_pos.x * GRID_SIZE + GRID_SIZE * 0.5, 0.025, grid_pos.y * GRID_SIZE + GRID_SIZE * 0.5)
	roads[grid_pos] = mesh
	road_placed.emit(grid_pos)
	return true

func place_road_at_world(world_pos: Vector3) -> bool:
	return place_road(BuildManager.world_to_grid(world_pos))

func remove_road(grid_pos: Vector2i) -> bool:
	if not roads.has(grid_pos):
		return false
	var road_mesh = roads[grid_pos]
	roads.erase(grid_pos)
	if is_instance_valid(road_mesh):
		road_mesh.queue_free()
	road_removed.emit(grid_pos)
	return true

func _create_road_mesh() -> Node3D:
	# Keep road connectivity and placement fully testable without allocating
	# renderer resources under the headless dummy renderer.
	if DisplayServer.get_name() == "headless":
		return Node3D.new()
	var root := MeshInstance3D.new()
	var asphalt := BoxMesh.new()
	asphalt.size = Vector3(GRID_SIZE * 0.98, 0.08, GRID_SIZE * 0.98)
	root.mesh = asphalt
	root.material_override = _get_asphalt_material()

	var center_line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.09, 0.012, GRID_SIZE * 0.52)
	center_line.mesh = line_mesh
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 0.82, 0.22)
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_line.material_override = line_material
	center_line.position.y = 0.047
	root.add_child(center_line)

	var curb_material := StandardMaterial3D.new()
	curb_material.albedo_color = Color(0.64, 0.65, 0.61)
	curb_material.roughness = 0.92
	var sidewalk_material := StandardMaterial3D.new()
	sidewalk_material.albedo_color = Color(0.48, 0.49, 0.45)
	sidewalk_material.roughness = 1.0
	for side in [-1.0, 1.0]:
		var curb := MeshInstance3D.new()
		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(GRID_SIZE * 0.96, 0.12, 0.09)
		curb.mesh = curb_mesh
		curb.material_override = curb_material
		curb.position = Vector3(0.0, 0.055, side * GRID_SIZE * 0.455)
		root.add_child(curb)
		var sidewalk := MeshInstance3D.new()
		var sidewalk_mesh := BoxMesh.new()
		sidewalk_mesh.size = Vector3(GRID_SIZE * 0.96, 0.055, 0.25)
		sidewalk.mesh = sidewalk_mesh
		sidewalk.material_override = sidewalk_material
		sidewalk.position = Vector3(0.0, 0.018, side * GRID_SIZE * 0.54)
		root.add_child(sidewalk)
	return root

func get_road_count() -> int:
	return roads.size()


# Shared generated asphalt texture keeps road tiles visually consistent and avoids per-tile texture allocations.
static var _shared_asphalt_material: StandardMaterial3D

func _get_asphalt_material() -> StandardMaterial3D:
	if _shared_asphalt_material != null:
		return _shared_asphalt_material
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var hash_value := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			var grain := fposmod(hash_value, 1.0)
			var shade := 0.15 + grain * 0.13
			image.set_pixel(x, y, Color(shade, shade * 1.02, shade * 1.04, 1.0))
	var texture := ImageTexture.create_from_image(image)
	_shared_asphalt_material = StandardMaterial3D.new()
	_shared_asphalt_material.albedo_texture = texture
	_shared_asphalt_material.roughness = 0.98
	_shared_asphalt_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _shared_asphalt_material
