extends Node3D

var ghost_mesh: MeshInstance3D
var is_valid := false

func _ready() -> void:
	visible = false
	if DisplayServer.get_name() == "headless":
		return
	ghost_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.4, 1.8, 3.4)
	ghost_mesh.mesh = box
	add_child(ghost_mesh)
	_set_color(false)

func show_at(world_pos: Vector3, size: Vector2i = Vector2i(2,2), valid: bool = true) -> void:
	if not is_instance_valid(ghost_mesh):
		return
	visible = true
	global_position = world_pos + Vector3((size.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.95, (size.y - 1) * BuildManager.GRID_SIZE * 0.5)
	var box := ghost_mesh.mesh as BoxMesh
	box.size = Vector3(size.x * BuildManager.GRID_SIZE * 0.88, 1.8, size.y * BuildManager.GRID_SIZE * 0.88)
	is_valid = valid
	_set_color(valid)

func hide_ghost() -> void:
	visible = false

func _set_color(valid: bool) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 0.95, 0.3, 0.38) if valid else Color(0.95, 0.12, 0.12, 0.42)
	ghost_mesh.material_override = material
