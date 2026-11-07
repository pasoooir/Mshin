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

func place_road(grid_pos: Vector2i) -> bool:
	if roads.has(grid_pos) or not BuildManager.is_inside_world(grid_pos):
		return false
	if not _has_adjacent_road(grid_pos):
		return false
	if not EconomyManager.can_afford(ROAD_COST):
		return false
	if not BuildManager.is_cell_free(grid_pos, Vector2i.ONE):
		return false
	if not EconomyManager.spend_simoleons(ROAD_COST):
		return false
	var mesh: MeshInstance3D = _create_road_mesh()
	add_child(mesh)
	mesh.position = Vector3(grid_pos.x * GRID_SIZE + GRID_SIZE * 0.5, 0.025, grid_pos.y * GRID_SIZE + GRID_SIZE * 0.5)
	roads[grid_pos] = mesh
	road_placed.emit(grid_pos)
	return true

func place_road_at_world(world_pos: Vector3) -> bool:
	return place_road(BuildManager.world_to_grid(world_pos))

func remove_road(grid_pos: Vector2i) -> void:
	if not roads.has(grid_pos):
		return
	roads[grid_pos].queue_free()
	roads.erase(grid_pos)
	road_removed.emit(grid_pos)

func _create_road_mesh() -> MeshInstance3D:
	var root := MeshInstance3D.new()
	var asphalt := BoxMesh.new()
	asphalt.size = Vector3(GRID_SIZE * 0.98, 0.08, GRID_SIZE * 0.98)
	root.mesh = asphalt
	var asphalt_material := StandardMaterial3D.new()
	asphalt_material.albedo_color = Color(0.16, 0.18, 0.20)
	asphalt_material.roughness = 0.96
	root.material_override = asphalt_material

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
	curb_material.albedo_color = Color(0.55, 0.57, 0.58)
	for side in [-1.0, 1.0]:
		var curb := MeshInstance3D.new()
		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(GRID_SIZE * 0.96, 0.12, 0.07)
		curb.mesh = curb_mesh
		curb.material_override = curb_material
		curb.position = Vector3(0.0, 0.025, side * GRID_SIZE * 0.46)
		root.add_child(curb)
	return root

func get_road_count() -> int:
	return roads.size()
