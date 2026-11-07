extends Node3D

signal road_placed(grid_pos: Vector2i)
signal road_removed(grid_pos: Vector2i)
const GRID_SIZE := 2.0
var roads: Dictionary = {}
var is_road_mode := false

func _ready() -> void:
	print("[RoadSystem] Ready")

func set_road_mode(active: bool) -> void:
	is_road_mode = active
	if active:
		BuildManager.cancel_placement()

func has_road(grid_pos: Vector2i) -> bool:
	return roads.has(grid_pos)

func place_road(grid_pos: Vector2i) -> bool:
	if roads.has(grid_pos) or not EconomyManager.can_afford(50):
		return false
	if not BuildManager.is_cell_free(grid_pos, Vector2i.ONE):
		return false
	if not EconomyManager.spend_simoleons(50):
		return false
	var mesh := _create_road_mesh()
	add_child(mesh)
	mesh.position = Vector3(grid_pos.x * GRID_SIZE + GRID_SIZE * 0.5, 0.025, grid_pos.y * GRID_SIZE + GRID_SIZE * 0.5)
	roads[grid_pos] = mesh
	road_placed.emit(grid_pos)
	return true

func place_road_at_world(world_pos: Vector3) -> bool:
	return place_road(Vector2i(floori(world_pos.x / GRID_SIZE), floori(world_pos.z / GRID_SIZE)))

func remove_road(grid_pos: Vector2i) -> void:
	if not roads.has(grid_pos):
		return
	roads[grid_pos].queue_free()
	roads.erase(grid_pos)
	road_removed.emit(grid_pos)

func _create_road_mesh() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(GRID_SIZE * 0.98, 0.08, GRID_SIZE * 0.98)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.20, 0.22)
	material.roughness = 0.95
	mesh_instance.material_override = material
	var line := MeshInstance3D.new()
	var line_box := BoxMesh.new()
	line_box.size = Vector3(0.10, 0.012, GRID_SIZE * 0.58)
	line.mesh = line_box
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(0.95, 0.82, 0.25)
	line.material_override = line_material
	line.position.y = 0.047
	mesh_instance.add_child(line)
	return mesh_instance

func get_road_count() -> int:
	return roads.size()
