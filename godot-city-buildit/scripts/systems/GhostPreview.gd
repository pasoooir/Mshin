extends Node3D

var ghost_mesh: MeshInstance3D
var coverage_preview_root: Node3D
var coverage_disc: MeshInstance3D
var coverage_ring: MeshInstance3D
var is_valid := false
var current_coverage_radius := -1.0

func _ready() -> void:
	visible = false
	if DisplayServer.get_name() == "headless":
		return
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.name = "BuildingGhost"
	var box := BoxMesh.new()
	box.size = Vector3(3.4, 1.8, 3.4)
	ghost_mesh.mesh = box
	add_child(ghost_mesh)
	_set_color(false)
	_build_coverage_preview()

func _build_coverage_preview() -> void:
	coverage_preview_root = Node3D.new()
	coverage_preview_root.name = "EmergencyCoveragePreview"
	coverage_preview_root.visible = false
	add_child(coverage_preview_root)

	coverage_disc = MeshInstance3D.new()
	coverage_disc.name = "CoverageArea"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.025
	disc.radial_segments = 64
	coverage_disc.mesh = disc
	coverage_disc.position.y = -0.91
	var disc_material := StandardMaterial3D.new()
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.albedo_color = Color(0.08, 0.82, 0.91, 0.13)
	disc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc_material.render_priority = 1
	coverage_disc.material_override = disc_material
	coverage_preview_root.add_child(coverage_disc)

	coverage_ring = MeshInstance3D.new()
	coverage_ring.name = "CoverageBoundary"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.985
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 8
	coverage_ring.mesh = ring
	coverage_ring.position.y = -0.875
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.12, 0.94, 1.0, 0.92)
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.render_priority = 2
	coverage_ring.material_override = ring_material
	coverage_preview_root.add_child(coverage_ring)

func show_at(world_pos: Vector3, size: Vector2i = Vector2i(2, 2), valid: bool = true, definition: Dictionary = {}) -> void:
	if not is_instance_valid(ghost_mesh):
		return
	visible = true
	global_position = world_pos + Vector3((size.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.95, (size.y - 1) * BuildManager.GRID_SIZE * 0.5)
	var box := ghost_mesh.mesh as BoxMesh
	box.size = Vector3(size.x * BuildManager.GRID_SIZE * 0.88, 1.8, size.y * BuildManager.GRID_SIZE * 0.88)
	is_valid = valid
	_set_color(valid)
	_update_coverage_preview(definition)

func _update_coverage_preview(definition: Dictionary) -> void:
	if not is_instance_valid(coverage_preview_root):
		return
	var is_fire_station := int(definition.get("fire", 0)) > 0
	var is_police_station := int(definition.get("police", 0)) > 0
	coverage_preview_root.visible = is_fire_station or is_police_station
	if not coverage_preview_root.visible:
		current_coverage_radius = -1.0
		return
	var radius := FireHazardManager.get_coverage_radius_world(definition) if is_fire_station else float(definition.get("coverage_tiles", 15)) * float(BuildManager.GRID_SIZE)
	var disc_material := coverage_disc.material_override as StandardMaterial3D
	var ring_material := coverage_ring.material_override as StandardMaterial3D
	if is_police_station:
		disc_material.albedo_color = Color(0.10, 0.22, 0.72, 0.15)
		ring_material.albedo_color = Color(0.18, 0.38, 0.98, 0.95)
	else:
		disc_material.albedo_color = Color(0.08, 0.82, 0.91, 0.13)
		ring_material.albedo_color = Color(0.12, 0.94, 1.0, 0.92)
	if is_equal_approx(radius, current_coverage_radius):
		return
	current_coverage_radius = radius
	coverage_disc.scale = Vector3(radius, 1.0, radius)
	coverage_ring.scale = Vector3(radius, 1.0, radius)

func hide_ghost() -> void:
	visible = false

func _set_color(valid: bool) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 0.95, 0.3, 0.38) if valid else Color(0.95, 0.12, 0.12, 0.42)
	ghost_mesh.material_override = material
