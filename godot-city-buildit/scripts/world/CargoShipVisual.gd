extends Node3D

const DOCK_POSITION := Vector3(65.0, 0.12, -22.0)
const OPEN_WATER_X := 142.0
const SAIL_SPEED := 3.2

var departed := false

func _ready() -> void:
	position = DOCK_POSITION
	_build_ship()

func set_departed(value: bool) -> void:
	departed = value

func _process(delta: float) -> void:
	var target_x := OPEN_WATER_X if departed else DOCK_POSITION.x
	position.x = move_toward(position.x, target_x, SAIL_SPEED * delta)
	var target_yaw := -0.08 if departed else 0.0
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 0.7))

func _build_ship() -> void:
	_add_box("CargoHull", Vector3(0.0, 0.45, 0.0), Vector3(11.0, 1.05, 3.4), Color("#344F61"), Color("#1D3442"))
	_add_box("Deck", Vector3(-0.1, 1.05, 0.0), Vector3(9.8, 0.20, 3.15), Color("#C7D2D5"), Color("#71858B"))
	_add_box("Container_A", Vector3(-2.8, 1.95, -0.82), Vector3(2.3, 1.55, 1.45), Color("#D28A42"), Color("#86552E"))
	_add_box("Container_B", Vector3(-0.3, 1.95, -0.82), Vector3(2.3, 1.55, 1.45), Color("#477E9B"), Color("#2B5067"))
	_add_box("Container_C", Vector3(-2.8, 1.95, 0.82), Vector3(2.3, 1.55, 1.45), Color("#5C9B80"), Color("#35634F"))
	_add_box("Container_D", Vector3(-0.3, 1.95, 0.82), Vector3(2.3, 1.55, 1.45), Color("#C65D4F"), Color("#793C36"))
	_add_box("Bridge", Vector3(3.35, 1.85, 0.0), Vector3(2.0, 1.65, 2.45), Color("#E8E9E3"), Color("#697B83"))
	_add_box("BridgeWindows", Vector3(3.35, 2.05, 1.245), Vector3(1.55, 0.48, 0.035), Color("#75B7C7"), Color("#345966"))
	_add_box("BridgeRoof", Vector3(3.35, 2.72, 0.0), Vector3(2.15, 0.18, 2.6), Color("#F3F0E5"), Color("#87969A"))
	_add_cylinder("Mast", Vector3(3.9, 3.12, -0.75), 0.055, 0.9, Color("#D6D9D6"))
	_add_box("BowMarking", Vector3(-5.52, 0.55, 0.0), Vector3(0.12, 0.5, 2.2), Color("#E4E7E3"), Color("#A9B5B6"))

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
	material.metallic = 0.12
	material.emission_enabled = false
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
	instance.mesh = mesh
	instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.45
	instance.material_override = material
	add_child(instance)
