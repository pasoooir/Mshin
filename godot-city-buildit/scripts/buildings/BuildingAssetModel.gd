extends Node3D
class_name BuildingAssetModel

const SurfaceLibrary = preload("res://scripts/buildings/BuildingSurfaceLibrary.gd")
@export var asset_type: String = ""

func _ready() -> void:
	_build_asset()

func _build_asset() -> void:
	for child in get_children():
		child.queue_free()
	_box(Vector3(3.38, 0.22, 3.38), Vector3(0, 0.11, 0), Color("#77766E"), "concrete")
	match asset_type:
		"restaurant_traditional":
			_build_traditional_restaurant()
		"fast_food":
			_build_fast_food()
		"hardware_store":
			_build_hardware_store()
		"farmers_market":
			_build_farmers_market()
		"furniture_store":
			_build_furniture_store()
		_:
			push_warning("Unknown dedicated building asset type: " + asset_type)

func _material(color: Color, surface: String) -> StandardMaterial3D:
	var maps := SurfaceLibrary.get_maps(surface)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = maps["albedo"]
	material.normal_enabled = true
	material.normal_texture = maps["normal"]
	material.normal_scale = 0.20
	material.roughness_texture = maps["roughness"]
	material.metallic_texture = maps["metallic"]
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(1.5, 1.5, 1.5)
	material.roughness = 0.78
	if surface == "glass":
		material.roughness = 0.18
		material.metallic = 0.08
	elif surface == "metal" or surface == "painted_metal":
		material.roughness = 0.38
		material.metallic = 0.55 if surface == "metal" else 0.28
	return material

func _box(size: Vector3, pos: Vector3, color: Color, surface: String = "plaster", rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, surface)
	node.position = pos
	node.rotation = rot
	add_child(node)
	return node

func _cylinder(radius: float, height: float, pos: Vector3, color: Color, surface: String = "metal") -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _material(color, surface)
	node.position = pos
	add_child(node)

func _window(pos: Vector3, width: float, height: float) -> void:
	_box(Vector3(width + 0.14, height + 0.14, 0.10), pos, Color("#D9CBB0"), "painted_metal")
	_box(Vector3(width, height, 0.055), pos + Vector3(0, 0, 0.065), Color("#244C60"), "glass")
	_box(Vector3(0.045, height, 0.075), pos + Vector3(0, 0, 0.095), Color("#D9CBB0"), "painted_metal")
	_box(Vector3(width, 0.045, 0.075), pos + Vector3(0, 0, 0.095), Color("#D9CBB0"), "painted_metal")

func _build_traditional_restaurant() -> void:
	_box(Vector3(3.18, 2.45, 2.95), Vector3(0, 1.34, -0.12), Color("#D8B98A"), "plaster")
	_box(Vector3(3.32, 0.18, 3.08), Vector3(0, 2.58, -0.12), Color("#6A3829"), "wood")
	_box(Vector3(3.30, 0.16, 1.12), Vector3(0, 2.95, 0.84), Color("#9A3F2F"), "roof", Vector3(deg_to_rad(25), 0, 0))
	_box(Vector3(3.30, 0.16, 1.12), Vector3(0, 2.95, -1.08), Color("#9A3F2F"), "roof", Vector3(deg_to_rad(-25), 0, 0))
	_box(Vector3(3.34, 0.13, 0.16), Vector3(0, 3.40, -0.12), Color("#6A3829"), "wood")
	_window(Vector3(-0.92, 1.62, 1.40), 0.88, 0.94)
	_window(Vector3(0.90, 1.62, 1.40), 0.78, 0.94)
	_box(Vector3(0.54, 1.58, 0.10), Vector3(0.05, 0.98, 1.43), Color("#59372B"), "wood")
	_box(Vector3(3.30, 0.14, 0.42), Vector3(0, 2.46, 1.55), Color("#A34B35"), "roof")
	_cylinder(0.10, 1.15, Vector3(-1.15, 3.24, -0.82), Color("#454A4C"), "metal")
	for x in [-0.92, 0.92]:
		_cylinder(0.22, 0.10, Vector3(x, 0.48, 1.62), Color("#E7D8B8"), "wood")
		_cylinder(0.045, 0.48, Vector3(x, 0.24, 1.62), Color("#493A31"), "metal")
	_box(Vector3(0.85, 0.16, 0.12), Vector3(0, 2.05, 1.57), Color("#6E2D25"), "wood")

func _build_fast_food() -> void:
	_box(Vector3(3.28, 2.05, 3.05), Vector3(0, 1.18, -0.05), Color("#E9E4D8"), "plaster")
	_box(Vector3(3.48, 0.22, 3.22), Vector3(0, 2.27, -0.05), Color("#343B40"), "painted_metal")
	_box(Vector3(3.42, 0.36, 0.20), Vector3(0, 2.00, 1.52), Color("#C52D24"), "painted_metal")
	_box(Vector3(3.52, 0.12, 0.62), Vector3(0, 1.60, 1.62), Color("#F3C34F"), "roof")
	_box(Vector3(1.02, 1.05, 0.06), Vector3(-0.92, 1.08, 1.55), Color("#244B5B"), "glass")
	_box(Vector3(0.72, 1.05, 0.06), Vector3(0.25, 1.08, 1.55), Color("#244B5B"), "glass")
	_box(Vector3(0.48, 1.12, 0.08), Vector3(1.22, 1.08, 1.55), Color("#9C382B"), "wood")
	_box(Vector3(0.72, 0.44, 0.12), Vector3(0.86, 2.52, 1.40), Color("#F5D25B"), "painted_metal")
	_box(Vector3(0.18, 0.88, 0.18), Vector3(1.80, 0.48, -0.72), Color("#D5D7D5"), "metal")
	_box(Vector3(0.58, 0.38, 0.10), Vector3(1.80, 0.98, -0.72), Color("#C52D24"), "painted_metal")
	_box(Vector3(0.08, 0.06, 0.72), Vector3(1.78, 0.04, -1.34), Color("#E8D6A5"), "concrete")

func _build_hardware_store() -> void:
	_box(Vector3(3.22, 2.55, 3.28), Vector3(0, 1.40, -0.12), Color("#C5B89C"), "concrete")
	_box(Vector3(3.42, 0.16, 3.48), Vector3(0, 2.72, -0.12), Color("#48535A"), "metal")
	for x in [-1.05, -0.35, 0.35, 1.05]:
		_box(Vector3(0.05, 2.40, 0.08), Vector3(x, 1.38, 1.56), Color("#4A555A"), "painted_metal")
	_box(Vector3(1.52, 1.50, 0.08), Vector3(-0.72, 1.14, 1.60), Color("#31596A"), "glass")
	_box(Vector3(1.10, 1.62, 0.10), Vector3(0.90, 1.08, 1.60), Color("#777E80"), "metal")
	for stack in range(3):
		_box(Vector3(0.62, 0.16, 0.54), Vector3(-1.05 + float(stack) * 0.74, 0.42, 2.02), Color("#A66F3F"), "wood")
		_box(Vector3(0.62, 0.16, 0.54), Vector3(-1.05 + float(stack) * 0.74, 0.60, 2.02), Color("#BD8B58"), "wood")
	_box(Vector3(2.65, 0.20, 0.42), Vector3(0, 2.20, 1.72), Color("#E5B53D"), "painted_metal")
	_box(Vector3(0.90, 0.22, 0.18), Vector3(0, 2.86, -0.15), Color("#39474D"), "metal")
	for x in [-1.15, 1.15]:
		_cylinder(0.12, 0.34, Vector3(x, 0.45, -1.62), Color("#6B777D"), "metal")

func _build_farmers_market() -> void:
	for x in [-1.42, -0.48, 0.48, 1.42]:
		for z in [-1.30, 1.30]:
			_box(Vector3(0.10, 2.48, 0.10), Vector3(x, 1.25, z), Color("#76583C"), "wood")
	_box(Vector3(3.48, 0.16, 3.28), Vector3(0, 2.58, 0), Color("#E7D6B4"), "roof")
	for stall in range(4):
		var x := -1.20 + float(stall) * 0.80
		var awning := Color("#C94B3E") if stall % 2 == 0 else Color("#E7C45E")
		_box(Vector3(0.76, 0.12, 1.18), Vector3(x, 2.18, 0.66), awning, "roof")
		_box(Vector3(0.74, 0.66, 0.64), Vector3(x, 0.60, 0.72), Color("#8B6544"), "wood")
		for crate in range(3):
			var produce: Color = [Color("#D94B35"), Color("#E7B93F"), Color("#65954C")][crate]
			_box(Vector3(0.16, 0.16, 0.16), Vector3(x - 0.20 + float(crate) * 0.20, 1.05, 1.12), produce, "plaster")
	_box(Vector3(3.52, 0.10, 0.18), Vector3(0, 2.74, 0), Color("#77583B"), "wood")
	_box(Vector3(3.18, 0.08, 0.22), Vector3(0, 0.16, -1.70), Color("#C6BBA3"), "concrete")

func _build_furniture_store() -> void:
	_box(Vector3(3.30, 2.92, 3.10), Vector3(0, 1.58, -0.10), Color("#D5D7D1"), "concrete")
	_box(Vector3(3.34, 0.20, 3.26), Vector3(0, 3.08, -0.10), Color("#313B43"), "metal")
	_box(Vector3(3.18, 2.02, 0.06), Vector3(0, 1.40, 1.51), Color("#244A5D"), "glass")
	for x in [-1.10, -0.36, 0.36, 1.10]:
		_box(Vector3(0.055, 1.92, 0.08), Vector3(x, 1.42, 1.58), Color("#D8D8CF"), "painted_metal")
	_box(Vector3(0.92, 0.44, 0.44), Vector3(-0.78, 0.66, 0.10), Color("#A45C42"), "wood")
	_box(Vector3(0.92, 0.14, 0.44), Vector3(-0.78, 0.95, 0.10), Color("#D6A47A"), "wood")
	for x in [-1.08, -0.48]:
		_box(Vector3(0.08, 0.38, 0.08), Vector3(x, 0.30, 0.10), Color("#4C3C33"), "wood")
	_box(Vector3(0.72, 0.64, 0.46), Vector3(0.76, 0.58, 0.10), Color("#5B7182"), "wood")
	_box(Vector3(0.84, 0.10, 0.52), Vector3(0.76, 0.94, 0.10), Color("#C7B79A"), "wood")
	_box(Vector3(2.68, 0.22, 0.26), Vector3(0, 2.82, 1.62), Color("#D7B66C"), "painted_metal")
	_box(Vector3(0.74, 0.18, 0.66), Vector3(1.18, 0.36, -1.52), Color("#555D62"), "metal")
