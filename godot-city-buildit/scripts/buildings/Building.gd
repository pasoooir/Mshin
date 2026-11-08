extends Node3D
class_name Building

signal collected(item_id: String, amount: int)
signal production_ready(item_id: String)
signal upgraded(new_stage: int)
signal construction_finished_signal

@export var building_id: String = ""
@export var building_type: String = ""
@export var grid_pos: Vector2i = Vector2i.ZERO

var definition: Dictionary = {}
var status: String = "constructing"
var build_time: float = 10.0
var production_timer: float = 0.0
var production_time: float = 20.0
var current_product: String = ""
var is_producing: bool = false
var has_ready_product: bool = false
var upgrade_stage: int = 1
var max_stage: int = 6
var current_population: int = 0
var upgrade_ready: bool = false

@onready var mesh_root: Node3D = $MeshRoot
@onready var scaffold_root: Node3D = $ScaffoldRoot
@onready var hard_hat: Node3D = $HardHat
@onready var production_icon: Label3D = $ProductionIcon
@onready var name_label: Label3D = $NameLabel
@onready var stage_label: Label3D = $StageLabel

func _ready() -> void:
	if hard_hat: hard_hat.visible = false
	if production_icon: production_icon.visible = false
	if name_label: name_label.visible = false
	if stage_label: stage_label.visible = false

func setup(data: Dictionary) -> void:
	building_id = data.get("id", "")
	building_type = data.get("type", "")
	grid_pos = data.get("grid_pos", Vector2i.ZERO)
	definition = data.get("definition", {})
	status = data.get("status", "constructing")
	build_time = definition.get("build_time", 10.0)
	upgrade_stage = data.get("upgrade_stage", 1)
	_create_visual()
	_create_scaffold()
	_update_stage_label()
	if name_label:
		name_label.text = definition.get("name", "")
	if status == "constructing":
		if hard_hat: hard_hat.visible = true
		_start_construction()
	else:
		_on_construction_finished()

func _create_visual() -> void:
	for child in mesh_root.get_children():
		child.queue_free()
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	var color: Color = definition.get("color", Color(0.8, 0.8, 0.8))
	var category: String = definition.get("category", "residential")
	var w: float = float(size.x) * 1.7
	var d: float = float(size.y) * 1.7
	_add_box(Vector3(w + 0.15, 0.25, d + 0.15), Vector3(0, 0.12, 0), color.darkened(0.35))
	var height_mult: float = 1.0
	if category == "residential":
		height_mult = 0.7 + upgrade_stage * 0.15
	var height: float = 1.6 * height_mult
	match category:
		"residential":
			height = 1.8 + upgrade_stage * 0.35
			_build_residential(w, d, height, color)
		"commercial":
			height = 2.0
			_build_commercial(w, d, height, color)
		"industrial":
			height = 2.6
			_build_industrial(w, d, height, color)
		"service":
			height = 2.2
			_build_service(w, d, height, color)
		"park":
			_build_park(w, d, color)
		_:
			_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)

func _build_residential(w: float, d: float, height: float, color: Color) -> void:
	# Warm, detailed suburban home. All dimensions stay within the assigned plot.
	var stage := clampi(upgrade_stage, 1, 6)
	var wall := color
	var wall_dark := color.darkened(0.18)
	var wall_light := color.lightened(0.12)
	var roof_col := Color(0.42, 0.22, 0.18)
	var roof_ridge := Color(0.30, 0.15, 0.12)
	var trim := Color(0.92, 0.88, 0.78)
	var glass := Color(0.38, 0.67, 0.82)
	var door_col := Color(0.34, 0.19, 0.12)
	var awning := Color(0.76, 0.24, 0.19)
	var stone := Color(0.48, 0.45, 0.39)

	var wall_w := w * (0.82 + float(stage - 1) * 0.012)
	var wall_d := d * (0.80 + float(stage - 1) * 0.012)
	var wall_h := height * 0.79
	var wall_bottom := 0.25
	var wall_top := wall_bottom + wall_h
	var front_z := wall_d * 0.5
	var window_w := clampf(wall_w * 0.22, 0.38, 0.68)
	var window_h := clampf(wall_h * 0.28, 0.42, 0.62)

	# Raised stone foundation and continuous lower facade trim.
	_add_box(Vector3(w * 0.96, 0.22, d * 0.94), Vector3(0, 0.18, 0), stone)
	_add_box(Vector3(wall_w, wall_h, wall_d), Vector3(0, wall_bottom + wall_h * 0.5, 0), wall)
	_add_box(Vector3(wall_w + 0.12, 0.11, wall_d + 0.12), Vector3(0, 0.31, 0), trim)
	_add_box(Vector3(wall_w + 0.08, 0.075, wall_d + 0.08), Vector3(0, wall_top - 0.08, 0), wall_light)

	# Front entrance: timber door, handle, two shallow steps and red canopy.
	var door_w := clampf(wall_w * 0.20, 0.42, 0.58)
	var door_h := minf(wall_h * 0.56, 1.12)
	var door_y := wall_bottom + door_h * 0.5 + 0.02
	_add_box(Vector3(door_w + 0.12, door_h + 0.12, 0.075), Vector3(0, door_y, front_z + 0.025), trim)
	_add_box(Vector3(door_w, door_h, 0.055), Vector3(0, door_y, front_z + 0.075), door_col)
	_add_box(Vector3(0.035, door_h * 0.72, 0.018), Vector3(-door_w * 0.28, door_y, front_z + 0.108), Color(0.58, 0.36, 0.21))
	_add_cylinder(0.035, 0.035, 0.025, Vector3(door_w * 0.30, door_y, front_z + 0.12), Color(0.86, 0.68, 0.30))
	_add_box(Vector3(door_w + 0.42, 0.12, 0.42), Vector3(0, 0.30, front_z + 0.28), Color(0.72, 0.69, 0.62))
	_add_box(Vector3(door_w + 0.30, 0.10, 0.30), Vector3(0, 0.41, front_z + 0.23), Color(0.82, 0.79, 0.72))
	_add_box(Vector3(door_w + 0.42, 0.10, 0.38), Vector3(0, door_y + door_h * 0.5 + 0.16, front_z + 0.19), awning)
	_add_box(Vector3(0.07, 0.18, 0.07), Vector3(-door_w * 0.48, door_y + door_h * 0.5 + 0.04, front_z + 0.17), wall_dark)
	_add_box(Vector3(0.07, 0.18, 0.07), Vector3(door_w * 0.48, door_y + door_h * 0.5 + 0.04, front_z + 0.17), wall_dark)

	# Balanced framed front windows; upper rows appear as the home grows.
	var rows := 1
	if stage >= 3:
		rows = 2
	if stage >= 5:
		rows = 3
	var columns := 2 if stage < 4 else 3
	for row in range(rows):
		var y := wall_bottom + wall_h * (0.42 + float(row) * 0.27)
		for column in range(columns):
			var x := 0.0
			if columns == 2:
				x = -wall_w * 0.29 if column == 0 else wall_w * 0.29
			else:
				x = -wall_w * 0.32 + float(column) * wall_w * 0.32
			if row == 0 and absf(x) < door_w * 0.75:
				continue
			_add_window(Vector3(x, y, front_z + 0.045), trim, glass, stage >= 2, false, window_w, window_h)

	# Side windows make the home read correctly during a full camera orbit.
	for side_sign in [-1.0, 1.0]:
		_add_window(Vector3(side_sign * (wall_w * 0.5 + 0.045), wall_bottom + wall_h * 0.48, -wall_d * 0.12),
			trim, glass, false, true, window_w * 0.82, window_h * 0.88)

	# Real two-plane gabled roof, fascia and ridge cap.
	var roof_base := wall_top - 0.02
	var roof_rise := clampf(wall_h * 0.30, 0.48, 0.78)
	_add_gabled_roof(wall_w * 1.10, wall_d * 1.12, roof_base, roof_rise, roof_col, roof_ridge)

	# Brick chimney with a visible cap, positioned toward the rear roof slope.
	var chimney_x := wall_w * 0.30
	var chimney_z := -wall_d * 0.22
	_add_box(Vector3(0.28, 0.78, 0.28), Vector3(chimney_x, roof_base + roof_rise + 0.22, chimney_z), Color(0.55, 0.31, 0.24))
	_add_box(Vector3(0.36, 0.10, 0.36), Vector3(chimney_x, roof_base + roof_rise + 0.63, chimney_z), Color(0.34, 0.20, 0.17))

	# A compact balcony and railings unlock from level 3.
	if stage >= 3:
		var balcony_y := wall_bottom + wall_h * 0.62
		var balcony_w := wall_w * (0.48 + float(stage - 3) * 0.035)
		var balcony_z := front_z + 0.30
		_add_box(Vector3(balcony_w, 0.10, 0.62), Vector3(0, balcony_y - 0.18, balcony_z), wall_light)
		_add_box(Vector3(balcony_w, 0.07, 0.07), Vector3(0, balcony_y + 0.18, balcony_z + 0.28), trim)
		for rail_x in [-balcony_w * 0.5, -balcony_w * 0.25, 0.0, balcony_w * 0.25, balcony_w * 0.5]:
			_add_box(Vector3(0.055, 0.34, 0.055), Vector3(rail_x, balcony_y, balcony_z + 0.28), trim)
		_add_box(Vector3(0.07, 0.38, 0.07), Vector3(-balcony_w * 0.5, balcony_y, balcony_z), trim)
		_add_box(Vector3(0.07, 0.38, 0.07), Vector3(balcony_w * 0.5, balcony_y, balcony_z), trim)

	# Higher levels gain dormers, richer roof detailing and a larger porch.
	if stage >= 4:
		var dormer_w := wall_w * 0.27
		var dormer_y := roof_base + roof_rise * 0.57
		_add_box(Vector3(dormer_w, 0.58, 0.42), Vector3(-wall_w * 0.23, dormer_y, 0), wall_light)
		_add_box(Vector3(dormer_w * 1.22, 0.10, 0.54), Vector3(-wall_w * 0.23, dormer_y + 0.34, 0), roof_col)
		_add_window(Vector3(-wall_w * 0.23, dormer_y, 0.225), trim, glass, false, false, dormer_w * 0.62, 0.34)
	if stage >= 5:
		_add_box(Vector3(wall_w * 0.78, 0.10, 0.16), Vector3(0, wall_top + 0.02, front_z * 0.92), trim)
		_add_box(Vector3(wall_w * 0.52, 0.08, 0.12), Vector3(0, wall_bottom + wall_h * 0.84, front_z + 0.07), awning)
	if stage >= 6:
		for x_sign in [-1.0, 1.0]:
			_add_box(Vector3(0.10, 0.62, 0.10), Vector3(x_sign * wall_w * 0.43, wall_top - 0.26, front_z + 0.06), trim)
		_add_box(Vector3(wall_w * 0.72, 0.12, wall_d * 0.72),
			Vector3(0, wall_top + roof_rise * 0.08, -wall_d * 0.02), roof_ridge)

	# Garden path and low shrubs complete the small residential plot.
	_add_box(Vector3(0.48, 0.045, d * 0.25), Vector3(0, 0.16, d * 0.62), Color(0.67, 0.61, 0.48))
	for shrub_x in [-w * 0.36, w * 0.36]:
		_add_cylinder(0.20, 0.25, 0.34, Vector3(shrub_x, 0.36, d * 0.34), Color(0.20, 0.43, 0.22))


func _add_gabled_roof(w: float, d: float, base_y: float, rise: float, roof_col: Color, ridge_col: Color) -> void:
	# Each roof plane runs from the ridge to one eave; opposite X rotations form a true gable.
	var half_depth := d * 0.29
	var slope_angle := atan2(rise, half_depth)
	var panel_length := sqrt(half_depth * half_depth + rise * rise)
	var panel_size := Vector3(w, 0.14, panel_length * 1.08)
	var panel_y := base_y + rise * 0.5
	var front_z := d * 0.145
	_add_box_rotated(panel_size, Vector3(0, panel_y, front_z), roof_col, Vector3(slope_angle, 0, 0))
	_add_box_rotated(panel_size, Vector3(0, panel_y, -front_z), roof_col, Vector3(-slope_angle, 0, 0))
	_add_box(Vector3(w * 1.04, 0.12, 0.16), Vector3(0, base_y + rise + 0.035, 0), ridge_col)
	# Contrasting fascia along both long eaves.
	_add_box(Vector3(w * 1.06, 0.12, 0.10), Vector3(0, base_y + 0.04, d * 0.30), ridge_col)
	_add_box(Vector3(w * 1.06, 0.12, 0.10), Vector3(0, base_y + 0.04, -d * 0.30), ridge_col)


func _add_window(pos: Vector3, frame_col: Color, glass_col: Color, has_shutters: bool = false,
		side: bool = false, window_w: float = 0.52, window_h: float = 0.52) -> void:
	var frame_depth := 0.075
	var glass_depth := 0.035
	var frame_size: Vector3
	var glass_size: Vector3
	var cross_size: Vector3
	var sill_size: Vector3
	var glass_offset: Vector3
	var cross_offset: Vector3
	var sill_offset: Vector3
	if side:
		frame_size = Vector3(frame_depth, window_h, window_w)
		glass_size = Vector3(glass_depth, window_h * 0.76, window_w * 0.76)
		cross_size = Vector3(glass_depth * 1.2, window_h * 0.76, 0.045)
		sill_size = Vector3(0.14, 0.07, window_w * 1.08)
		glass_offset = Vector3(pos.x + signf(pos.x) * 0.045, 0, 0)
		cross_offset = Vector3(pos.x + signf(pos.x) * 0.066, 0, 0)
		sill_offset = Vector3(pos.x + signf(pos.x) * 0.075, -window_h * 0.5 - 0.025, 0)
	else:
		frame_size = Vector3(window_w, window_h, frame_depth)
		glass_size = Vector3(window_w * 0.76, window_h * 0.76, glass_depth)
		cross_size = Vector3(0.045, window_h * 0.76, glass_depth * 1.2)
		sill_size = Vector3(window_w * 1.08, 0.07, 0.14)
		glass_offset = Vector3(0, 0, 0.045)
		cross_offset = Vector3(0, 0, 0.066)
		sill_offset = Vector3(0, -window_h * 0.5 - 0.025, 0.075)
	_add_box(frame_size, pos, frame_col)
	_add_box(glass_size, pos + glass_offset, glass_col)
	_add_box(cross_size, pos + cross_offset, frame_col.darkened(0.16))
	_add_box(sill_size, pos + sill_offset, frame_col.lightened(0.06))
	if has_shutters:
		var shutter_col := Color(0.48, 0.29, 0.19)
		if side:
			for z_sign in [-1.0, 1.0]:
				_add_box(Vector3(0.045, window_h * 0.88, 0.09),
					pos + Vector3(signf(pos.x) * 0.055, 0, z_sign * window_w * 0.48), shutter_col)
		else:
			for x_sign in [-1.0, 1.0]:
				_add_box(Vector3(0.09, window_h * 0.88, 0.045),
					pos + Vector3(x_sign * window_w * 0.48, 0, 0.055), shutter_col)

func _build_commercial(w: float, d: float, height: float, color: Color) -> void:
	_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)
	_add_box(Vector3(w * 0.98, 0.2, d * 0.98), Vector3(0, height + 0.34, 0), color.darkened(0.16))
	_add_box(Vector3(w * 0.68, height * 0.5, 0.09), Vector3(0, height * 0.43, d * 0.455), Color(0.30, 0.66, 0.79))
	_add_box(Vector3(w * 0.74, 0.22, 0.22), Vector3(0, height * 0.82, d * 0.49), Color(0.94, 0.43, 0.22))
	_add_box(Vector3(w * 0.8, 0.18, 0.35), Vector3(0, height * 0.82 + 0.2, d * 0.42), Color(0.96, 0.78, 0.35))
	for column in range(3):
		_add_box(Vector3(0.08, height * 0.55, 0.12), Vector3(-w * 0.3 + float(column) * w * 0.3, height * 0.43, d * 0.48), Color(0.9, 0.92, 0.88))
	_add_box(Vector3(w * 0.22, 0.32, 0.16), Vector3(w * 0.34, height + 0.55, -d * 0.2), Color(0.68, 0.72, 0.74))

func _build_industrial(w: float, d: float, height: float, color: Color) -> void:
	_add_box(Vector3(w * 0.92, height, d * 0.92), Vector3(0, height * 0.5 + 0.25, 0), color)
	_add_box(Vector3(w * 1.0, 0.2, d * 1.0), Vector3(0, height + 0.35, 0), color.darkened(0.2))
	_add_box(Vector3(w * 0.45, 0.12, d * 0.34), Vector3(-w * 0.22, height + 0.52, -d * 0.2), Color(0.42, 0.45, 0.48))
	_add_cylinder(0.22, 0.18, 1.8, Vector3(w * 0.28, height + 1.2, d * 0.28), Color(0.4, 0.4, 0.45))
	_add_box(Vector3(0.15, 0.15, d * 0.6), Vector3(-w * 0.4, height * 0.7, 0), Color(0.5, 0.5, 0.55))
	for bay in range(3):
		_add_box(Vector3(0.38, 0.36, 0.08), Vector3(-w * 0.28 + float(bay) * w * 0.28, height * 0.55, d * 0.47), Color(0.72, 0.83, 0.87))
	_add_box(Vector3(w * 0.32, 0.3, 0.1), Vector3(0, height * 0.82, d * 0.48), Color(0.94, 0.63, 0.22))

func _build_service(w: float, d: float, height: float, color: Color) -> void:
	var power = definition.get("power", 0)
	var water = definition.get("water", 0)
	if power > 0:
		_add_cylinder(0.12, 0.18, 3.8, Vector3(0, 2.2, 0), Color(0.85, 0.88, 0.92))
		_add_box(Vector3(0.6, 0.35, 0.35), Vector3(0, 4.1, 0), Color(0.9, 0.9, 0.95))
		for i in range(3):
			var blade = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(1.8, 0.12, 0.25)
			blade.mesh = box
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.95, 1.0)
			blade.material_override = mat
			blade.position = Vector3(0, 4.1, 0)
			blade.rotation_degrees = Vector3(0, 0, i * 120.0)
			mesh_root.add_child(blade)
	elif water > 0:
		_add_cylinder(0.7, 0.7, 1.2, Vector3(0, 2.8, 0), color)
		_add_cylinder(0.15, 0.2, 2.2, Vector3(0, 1.3, 0), color.darkened(0.2))
		_add_box(Vector3(1.6, 0.15, 1.6), Vector3(0, 0.2, 0), color.darkened(0.3))
	else:
		_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)
		_add_box(Vector3(w * 0.95, 0.2, d * 0.95), Vector3(0, height + 0.35, 0), color.darkened(0.15))
		_add_box(Vector3(0.5, 0.9, 0.1), Vector3(0, 0.7, d * 0.45), color.darkened(0.35))

func _build_park(w: float, d: float, color: Color) -> void:
	_add_box(Vector3(w * 0.9, 0.15, d * 0.9), Vector3(0, 0.1, 0), color)
	_add_cylinder(0.3, 0.35, 1.2, Vector3(0, 0.8, 0), Color(0.25, 0.55, 0.25))
	_add_box(Vector3(0.8, 0.5, 0.8), Vector3(0, 1.5, 0), Color(0.3, 0.7, 0.3))

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.04
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_root.add_child(mesh_instance)

func _add_box_rotated(size: Vector3, pos: Vector3, color: Color, rotation: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.rotation = rotation
	mesh_root.add_child(mesh_instance)

func _add_cylinder(top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	mesh_instance.mesh = cylinder
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_root.add_child(mesh_instance)

# Build a lightweight scaffold from reusable BoxMesh primitives.
# Dimensions follow the same plot width/depth used by _create_visual().
func _create_scaffold() -> void:
	if not scaffold_root:
		return
	for child in scaffold_root.get_children():
		child.queue_free()

	var plot_size: Vector2i = definition.get("size", Vector2i(2, 2))
	var width := float(plot_size.x) * 1.7
	var depth := float(plot_size.y) * 1.7
	var category: String = definition.get("category", "residential")
	var structure_height := 2.4
	match category:
		"residential":
			structure_height = 1.8 + upgrade_stage * 0.35
		"commercial":
			structure_height = 2.0
		"industrial":
			structure_height = 2.6
		"service":
			structure_height = 2.2
		"park":
			structure_height = 1.4
	structure_height = maxf(structure_height, 1.4)

	var metal := Color(0.55, 0.58, 0.62)
	var wood := Color(0.72, 0.55, 0.32)
	var half_w := width * 0.48
	var half_d := depth * 0.48
	var post_height := structure_height + 0.55
	var post_size := Vector3(0.09, post_height, 0.09)

	# Four vertical steel standards at the plot corners.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_add_scaffold_box(post_size, Vector3(x_sign * half_w, post_height * 0.5, z_sign * half_d), metal)

	# Horizontal ledgers and transoms at several construction levels.
	var levels := maxi(2, int(ceil(structure_height / 0.8)))
	for level in range(levels + 1):
		var y := 0.25 + structure_height * float(level) / float(levels)
		_add_scaffold_box(Vector3(width, 0.075, 0.075), Vector3(0, y, half_d), metal)
		_add_scaffold_box(Vector3(width, 0.075, 0.075), Vector3(0, y, -half_d), metal)
		_add_scaffold_box(Vector3(0.075, 0.075, depth), Vector3(half_w, y, 0), metal)
		_add_scaffold_box(Vector3(0.075, 0.075, depth), Vector3(-half_w, y, 0), metal)

	# A few diagonal braces on the visible front and side faces.
	for side in [-1.0, 1.0]:
		var brace_front := _add_scaffold_box(Vector3(0.075, structure_height * 0.72, 0.075),
			Vector3(side * half_w * 0.52, structure_height * 0.48, half_d + 0.015), metal)
		brace_front.rotation.z = deg_to_rad(34.0 * side)
		var brace_side := _add_scaffold_box(Vector3(0.075, structure_height * 0.72, 0.075),
			Vector3(side * (half_w + 0.015), structure_height * 0.48, 0), metal)
		brace_side.rotation.z = deg_to_rad(-34.0 * side)

	# Timber working platforms near the upper scaffold level.
	var platform_y := minf(structure_height + 0.12, post_height - 0.12)
	_add_scaffold_box(Vector3(width * 0.92, 0.11, 0.42), Vector3(0, platform_y, half_d * 0.72), wood)
	_add_scaffold_box(Vector3(0.42, 0.11, depth * 0.92), Vector3(-half_w * 0.72, platform_y, 0), wood)

	# One or two material crates sit just outside the building footprint.
	_add_scaffold_box(Vector3(0.52, 0.42, 0.48),
		Vector3(half_w + 0.38, 0.21, half_d * 0.55), Color(0.95, 0.78, 0.15))
	if width + depth > 6.0:
		_add_scaffold_box(Vector3(0.58, 0.46, 0.52),
			Vector3(-half_w - 0.4, 0.23, -half_d * 0.5), Color(0.48, 0.31, 0.17))
	else:
		_add_scaffold_box(Vector3(0.48, 0.38, 0.46),
			Vector3(-half_w - 0.34, 0.19, -half_d * 0.45), Color(0.95, 0.78, 0.15))

func _add_scaffold_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.18 if color == Color(0.55, 0.58, 0.62) else 0.0
	mesh_instance.material_override = material
	mesh_instance.position = pos
	scaffold_root.add_child(mesh_instance)
	return mesh_instance

func _start_construction() -> void:
	if hard_hat:
		hard_hat.visible = true
	if mesh_root:
		mesh_root.visible = true
		mesh_root.scale = Vector3(1.0, 0.03, 1.0)
	if scaffold_root:
		scaffold_root.visible = true
		scaffold_root.scale = Vector3(1.0, 0.05, 1.0)

	# Divide the configured construction duration into three visible phases.
	var total_time := maxf(build_time, 0.3)
	var scaffold_time := total_time * 0.30
	var building_time := total_time * 0.55
	var dismantle_time := total_time * 0.15
	var tween := create_tween()
	tween.tween_property(scaffold_root, "scale:y", 1.0, scaffold_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_root, "scale:y", 1.0, building_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(scaffold_root, "scale:y", 0.01, dismantle_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_construction_finished)

func _on_construction_finished() -> void:
	status = "completed"
	if hard_hat: hard_hat.visible = false
	if scaffold_root:
		scaffold_root.visible = false
		scaffold_root.scale = Vector3.ONE
	_play_completion_effect()
	mesh_root.scale = Vector3.ONE
	construction_finished_signal.emit()
	BuildManager.notify_construction_finished(building_id)
	if definition.get("category") == "residential":
		current_population = ProductionManager.get_population_for_stage(upgrade_stage)
		GameManager.add_population(current_population)
		GameManager.add_experience(current_population)
		_check_upgrade_ready()
	elif definition.get("population", 0) > 0:
		GameManager.add_population(definition.population)
		GameManager.add_experience(definition.population * 2)
	if definition.has("produces"):
		_start_production(definition.produces)
	if definition.has("power"):
		ServiceManager.register_power(definition.power)
	if definition.has("water"):
		ServiceManager.register_water(definition.water)
	ServiceManager.recalculate_from_buildings()
	if definition.get("happiness", 0) > 0:
		GameManager.set_happiness(min(100.0, GameManager.happiness + definition.happiness))

func _play_completion_effect() -> void:
	# A short sparkle burst marks completed construction with minimal mobile GPU cost.
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.albedo_color = Color(1.0, 0.78, 0.30)
	sparkle_material.emission_enabled = true
	sparkle_material.emission = Color(1.0, 0.52, 0.12)
	for index in range(8):
		var sparkle := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.10
		mesh.height = 0.20
		sparkle.mesh = mesh
		sparkle.material_override = sparkle_material
		sparkle.position = Vector3(0, 0.7, 0)
		add_child(sparkle)
		var angle := TAU * float(index) / 8.0
		var destination := Vector3(cos(angle) * 1.25, 2.2 + float(index % 3) * 0.35, sin(angle) * 1.25)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position", destination, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.72)
		tween.chain().tween_callback(sparkle.queue_free)

func _start_production(item_id: String) -> void:
	current_product = item_id
	is_producing = true
	production_time = ProductionManager.get_production_time(item_id)
	production_timer = production_time
	has_ready_product = false
	if production_icon:
		production_icon.visible = true
		production_icon.text = "⚙️"

func _process(delta: float) -> void:
	if is_producing and status == "completed" and not has_ready_product:
		production_timer -= delta
		if production_timer <= 0:
			production_timer = 0
			has_ready_product = true
			if production_icon:
				production_icon.text = "✅"
			production_ready.emit(current_product)
	if definition.get("category") == "residential" and status == "completed" and upgrade_stage < max_stage:
		_check_upgrade_ready()

func _check_upgrade_ready() -> void:
	if upgrade_stage >= max_stage:
		upgrade_ready = false
		if hard_hat: hard_hat.visible = false
		return
	upgrade_ready = ProductionManager.can_afford_upgrade(upgrade_stage)
	if hard_hat:
		hard_hat.visible = upgrade_ready

func try_upgrade() -> bool:
	if definition.get("category") != "residential" or upgrade_stage >= max_stage:
		return false
	if not ProductionManager.can_afford_upgrade(upgrade_stage):
		print("[Building] Need materials for upgrade to stage ", upgrade_stage + 1)
		return false
	if not ProductionManager.consume_upgrade_materials(upgrade_stage):
		return false
	var old_population = current_population
	upgrade_stage += 1
	current_population = ProductionManager.get_population_for_stage(upgrade_stage)
	var gained = current_population - old_population
	GameManager.add_population(gained)
	GameManager.add_experience(gained + 10)
	EconomyManager.add_simoleons(50 * upgrade_stage)
	_create_visual()
	_update_stage_label()
	upgrade_ready = false
	if hard_hat: hard_hat.visible = false
	upgraded.emit(upgrade_stage)
	return true

func collect_production() -> bool:
	if not has_ready_product:
		return false
	if StorageManager.add_item(current_product, 1):
		has_ready_product = false
		production_timer = production_time
		if production_icon:
			production_icon.text = "⚙️"
		collected.emit(current_product, 1)
		EconomyManager.add_simoleons(3)
		GameManager.add_experience(2)
		return true
	if production_icon:
		production_icon.text = "📦!"
	return false

func _update_stage_label() -> void:
	if stage_label and definition.get("category") == "residential":
		stage_label.visible = true
		stage_label.text = "Lv%d" % upgrade_stage
	elif stage_label:
		stage_label.visible = false

func get_info() -> String:
	var info = definition.get("name", "Building")
	if definition.get("category") == "residential":
		info += " [Lv%d/6] Population:%d" % [upgrade_stage, current_population]
		var requirements: Array = ProductionManager.get_upgrade_requirements(upgrade_stage)
		if not requirements.is_empty():
			var needed_text := " — Need: "
			for index in range(requirements.size()):
				var requirement: Dictionary = requirements[index]
				if index > 0:
					needed_text += ", "
				needed_text += "%d %s" % [int(requirement.amount), str(requirement.item).capitalize()]
			info += needed_text
		if upgrade_ready:
			info += " — READY TO UPGRADE"
	if is_producing:
		if has_ready_product:
			info += " - Ready: " + current_product
		else:
			info += " - %.0fs" % production_timer
	return info
