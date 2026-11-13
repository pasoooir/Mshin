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
var construction_finish_unix: int = 0
var _construction_initialized := false
var _construction_tween: Tween
var production_timer: float = 0.0
var production_time: float = 20.0
var production_finish_unix: int = 0
var production_component: Node = null
var current_product: String = ""
var is_producing: bool = false
var has_ready_product: bool = false
var upgrade_stage: int = 1
var max_stage: int = 6
var current_population: int = 0
var upgrade_ready: bool = false
var upgrade_in_progress: bool = false
var upgrade_finish_unix: int = 0
var residential_plan_selected: bool = false
var _upgrade_tween: Tween
var demolition_highlight_active: bool = false
var _demolition_highlight_root: Node3D
var _move_highlight_root: Node3D
var _move_ghost_material: StandardMaterial3D
var _move_original_overlays: Dictionary = {}
static var _shared_surface_texture: Texture2D
const WIND_TURBINE_SPIN_RADIANS_PER_SECOND: float = 0.92
const RESIDENTIAL_UPGRADE_DURATION_SECONDS: int = 4
const ProductionComponentScript = preload("res://scripts/production/ProductionComponent.gd")
const BuildingModelLoader = preload("res://scripts/buildings/BuildingModelLoader.gd")
var _wind_turbine_rotor: Node3D
var _fire_smoke: CPUParticles3D = null

@onready var mesh_root: Node3D = $MeshRoot
@onready var scaffold_root: Node3D = $ScaffoldRoot
@onready var hard_hat: Node3D = $HardHat
@onready var production_icon: Label3D = get_node_or_null("ProductionIcon") as Label3D
@onready var name_label: Label3D = get_node_or_null("NameLabel") as Label3D
@onready var stage_label: Label3D = get_node_or_null("StageLabel") as Label3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		if is_instance_valid(hard_hat):
			hard_hat.visible = false
		return
	_create_visual_labels()
	if hard_hat:
		hard_hat.visible = false

func _create_visual_labels() -> void:
	if production_icon == null:
		production_icon = Label3D.new()
		production_icon.name = "ProductionIcon"
		production_icon.position = Vector3(0.0, 4.5, 0.0)
		production_icon.visible = false
		production_icon.pixel_size = 0.045
		production_icon.text = "⚙️"
		production_icon.font_size = 52
		production_icon.outline_size = 10
		add_child(production_icon)
	if name_label == null:
		name_label = Label3D.new()
		name_label.name = "NameLabel"
		name_label.position = Vector3(0.0, -0.3, 0.0)
		name_label.visible = false
		name_label.pixel_size = 0.03
		name_label.text = ""
		name_label.font_size = 28
		name_label.outline_size = 6
		add_child(name_label)
	if stage_label == null:
		stage_label = Label3D.new()
		stage_label.name = "StageLabel"
		stage_label.position = Vector3(0.0, 5.2, 0.0)
		stage_label.visible = false
		stage_label.pixel_size = 0.035
		stage_label.text = "Lv1"
		stage_label.font_size = 36
		stage_label.outline_size = 8
		stage_label.modulate = Color(1.0, 0.95, 0.5, 1.0)
		add_child(stage_label)

func setup(data: Dictionary) -> void:
	building_id = data.get("id", "")
	building_type = data.get("type", "")
	grid_pos = data.get("grid_pos", Vector2i.ZERO)
	definition = data.get("definition", {})
	status = data.get("status", "constructing")
	build_time = definition.get("build_time", 10.0)
	upgrade_stage = data.get("upgrade_stage", 1)
	# Procedural building meshes are visual-only. Headless integration tests exercise
	# the building state machine without instantiating renderer resources.
	if DisplayServer.get_name() != "headless":
		_create_visual()
		_create_scaffold()
	_update_stage_label()
	if stage_label:
		stage_label.visible = false
		stage_label.text = ""
	if name_label:
		name_label.text = definition.get("name", "")
	if status == "constructing":
		if hard_hat: hard_hat.visible = true
		_start_construction()
	else:
		_on_construction_finished()

func _apply_move_transparency(node: Node, active: bool) -> void:
	if node is GeometryInstance3D:
		if active:
			if not _move_original_overlays.has(node):
				_move_original_overlays[node] = node.material_overlay
			node.material_overlay = _move_ghost_material
		elif _move_original_overlays.has(node):
			node.material_overlay = _move_original_overlays[node]
			_move_original_overlays.erase(node)
	for child in node.get_children():
		_apply_move_transparency(child, active)

func set_move_preview(active: bool, valid: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if active:
		if _move_ghost_material == null:
			_move_ghost_material = StandardMaterial3D.new()
			_move_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_move_ghost_material.albedo_color = Color(0.58, 0.88, 1.0, 0.42)
			_move_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		for visual_root in [mesh_root, scaffold_root]:
			if is_instance_valid(visual_root):
				_apply_move_transparency(visual_root, true)
		if _move_highlight_root == null:
			_move_highlight_root = Node3D.new()
			_move_highlight_root.name = "MoveHighlight"
			add_child(_move_highlight_root)
			var footprint: Vector2i = definition.get("size", Vector2i(2, 2))
			var width := float(footprint.x) * 1.7 + 0.28
			var depth := float(footprint.y) * 1.7 + 0.28
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tint := Color(0.20, 1.0, 0.36, 0.95) if valid else Color(1.0, 0.16, 0.12, 0.95)
			material.albedo_color = tint
			material.emission_enabled = true
			material.emission = tint
			material.emission_energy_multiplier = 1.4
			for edge in 4:
				var beam := MeshInstance3D.new()
				var box := BoxMesh.new()
				if edge < 2:
					box.size = Vector3(width, 0.08, 0.10)
					beam.position = Vector3(0.0, 0.12, (-depth * 0.5) if edge == 0 else (depth * 0.5))
				else:
					box.size = Vector3(0.10, 0.08, depth)
					beam.position = Vector3((-width * 0.5) if edge == 2 else (width * 0.5), 0.12, 0.0)
				beam.mesh = box
				beam.material_override = material
				_move_highlight_root.add_child(beam)
		else:
			var tint := Color(0.20, 1.0, 0.36, 0.95) if valid else Color(1.0, 0.16, 0.12, 0.95)
			for beam in _move_highlight_root.get_children():
				if beam is MeshInstance3D and beam.material_override is StandardMaterial3D:
					beam.material_override.albedo_color = tint
					beam.material_override.emission = tint
		_move_highlight_root.visible = true
		position.y = 0.55
	else:
		for visual_root in [mesh_root, scaffold_root]:
			if is_instance_valid(visual_root):
				_apply_move_transparency(visual_root, false)
		if _move_highlight_root:
			_move_highlight_root.visible = false
		position.y = 0.0

func set_demolition_highlight(active: bool) -> void:
	# A thin emissive footprint frame makes the first bulldozer tap unmistakable.
	demolition_highlight_active = active
	if DisplayServer.get_name() == "headless":
		return
	if active and _demolition_highlight_root == null:
		_demolition_highlight_root = Node3D.new()
		_demolition_highlight_root.name = "DemolitionHighlight"
		add_child(_demolition_highlight_root)
		var footprint: Vector2i = definition.get("size", Vector2i(2, 2))
		var width := float(footprint.x) * 1.7 + 0.42
		var depth := float(footprint.y) * 1.7 + 0.42
		var beam_width := 0.12
		var beam_height := 0.10
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.72, 0.12, 0.98)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.55, 0.04)
		material.emission_energy_multiplier = 1.8
		for edge in 4:
			var beam := MeshInstance3D.new()
			var box := BoxMesh.new()
			if edge < 2:
				box.size = Vector3(width, beam_height, beam_width)
				beam.position = Vector3(0.0, 0.34, (-depth * 0.5) if edge == 0 else (depth * 0.5))
			else:
				box.size = Vector3(beam_width, beam_height, depth)
				beam.position = Vector3((-width * 0.5) if edge == 2 else (width * 0.5), 0.34, 0.0)
			beam.mesh = box
			beam.material_override = material
			_demolition_highlight_root.add_child(beam)
	if _demolition_highlight_root:
		_demolition_highlight_root.visible = active

func _create_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for child in mesh_root.get_children():
		child.queue_free()
	var model_path := str(definition.get("model_path", ""))

	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	var color: Color = definition.get("color", Color(0.8, 0.8, 0.8))
	var category: String = definition.get("category", "residential")
	var w: float = float(size.x) * 1.7
	var d: float = float(size.y) * 1.7
	_add_box(Vector3(w + 0.15, 0.25, d + 0.15), Vector3(0, 0.12, 0), color.darkened(0.35))
	var height_mult: float = 1.0
	var subtype := str(definition.get("subtype", ""))
	if category == "residential":
		height_mult = 0.7 + upgrade_stage * 0.15
	var height: float = 1.6 * height_mult

	# Keep the verified local GLTF base models in use. Residential upgrades
	# receive their level-specific architectural additions on top of that base,
	# so the imported model is retained without freezing the house silhouette.
	if _should_use_external_model(model_path):
		var model_scale: Vector3 = definition.get("model_scale", Vector3.ONE)
		if BuildingModelLoader.attach_model(mesh_root, model_path, model_scale) != null:
			if category == "residential" and upgrade_stage > 1:
				var is_apartment := subtype == "apartment"
				var is_farm := subtype == "farm"
				var residential_body_h := height
				if is_apartment:
					var residential_floors := 3 if upgrade_stage < 5 else 4
					residential_body_h = maxf(height, float(residential_floors) * 1.35)
				elif is_farm:
					residential_body_h = minf(height, 1.85)
				_build_residential_level_architecture(
					w, d, residential_body_h, color, color.lightened(0.14),
					Color(0.66, 0.59, 0.48), Color(0.48, 0.22, 0.16),
					Color(0.88, 0.82, 0.69), Color(0.24, 0.43, 0.54),
					is_apartment, is_farm
				)
			elif category == "commercial":
				var commercial_floors := 1 if upgrade_stage < 3 else (2 if upgrade_stage < 5 else 3)
				var commercial_body_h := height if commercial_floors == 1 else maxf(height, 2.0 + float(commercial_floors - 1) * 1.25)
				_build_commercial_identity(w, d, commercial_body_h, d * 0.5, upgrade_stage)
			elif category == "industrial":
				_build_industrial_identity(w, d, height, upgrade_stage)
			elif category == "service":
				_build_service_identity(w, d, height)
			elif category == "park":
				_build_park(w, d, color)
			return

	match category:
		"residential":
			# Visible architectural milestones: starter villa, expanded two-storey home,
			# then a taller upgraded residence. Each tier changes the silhouette.
			height = 2.05 + float(upgrade_stage - 1) * 0.32
			if upgrade_stage >= 3:
				height += 0.48
			if upgrade_stage >= 5:
				height += 0.62
			if subtype == "apartment":
				height += 1.25
			elif subtype == "farm":
				height = maxf(1.65, height - 0.45)
			_build_residential(w, d, height, color)
		"commercial":
			height = 2.25 + float(clampi(upgrade_stage - 1, 0, 4)) * 0.34
			_build_commercial(w, d, height, color)
		"industrial":
			height = 2.35 + float(clampi(upgrade_stage - 1, 0, 4)) * 0.42
			_build_industrial(w, d, height, color)
		"service":
			height = 2.2
			_build_service(w, d, height, color)
		"park":
			_build_park(w, d, color)
		_:
			_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)

func _should_use_external_model(model_path: String) -> bool:
	if model_path.is_empty():
		return false
	# Preserve the hand-authored level-one villa hero. Higher residential
	# stages may use their local GLTF base, with unique stage geometry layered on top.
	var is_starter_villa := str(definition.get("category", "")) == "residential" and building_type != "residential_2" and str(definition.get("subtype", "villa")) == "villa" and upgrade_stage == 1
	return not is_starter_villa

func _build_residential(w: float, d: float, height: float, color: Color) -> void:
	var residential_subtype := str(definition.get("subtype", "villa"))
	if upgrade_stage == 1 and residential_subtype == "villa":
		_build_level_one_villa(w, d, height, color)
		return
	# Warm masonry palette: a stone plinth, sun-baked plaster, timber trim and clay tiles.
	var plaster := Color(0.78, 0.65, 0.49).lerp(color, 0.24)
	var plaster_light := plaster.lightened(0.14)
	var plaster_shadow := plaster.darkened(0.22)
	var stone := Color(0.43, 0.40, 0.35)
	var stone_cap := Color(0.66, 0.59, 0.48)
	var roof_tile := Color(0.48, 0.22, 0.16)
	var roof_edge := Color(0.30, 0.15, 0.12)
	var wood := Color(0.30, 0.18, 0.12)
	var frame := Color(0.88, 0.82, 0.69)
	var glass := Color(0.24, 0.43, 0.54)
	var subtype := str(definition.get("subtype", "villa"))
	var is_apartment := subtype == "apartment"
	var is_farm := subtype == "farm"
	var floors := 1
	if is_apartment:
		floors = 3 if upgrade_stage < 5 else 4
	elif upgrade_stage >= 5:
		floors = 3
	elif upgrade_stage >= 3:
		floors = 2

	var body_h := height
	if is_apartment:
		body_h = maxf(height, float(floors) * 1.35)
	elif is_farm:
		body_h = minf(height, 1.85)

	# Raised stone foundation and a projecting water-table course.
	_add_box(Vector3(w * 0.98, 0.30, d * 0.98), Vector3(0, 0.15, 0), stone)
	_add_box(Vector3(w * 1.01, 0.075, d * 1.01), Vector3(0, 0.31, 0), stone_cap)
	_add_box(Vector3(w * 0.90, body_h, d * 0.86), Vector3(0, body_h * 0.5 + 0.34, 0), plaster)

	# Corner pilasters, floor string-courses and a deep cornice break up large blank walls.
	for x_sign in [-1.0, 1.0]:
		_add_box(Vector3(0.10, body_h * 0.94, 0.10),
			Vector3(x_sign * w * 0.405, body_h * 0.5 + 0.35, d * 0.435), plaster_light)
	_add_box(Vector3(w * 0.94, 0.10, d * 0.90), Vector3(0, 0.48, 0), plaster_shadow)
	for floor_index in range(1, floors):
		var belt_y := 0.34 + body_h * float(floor_index) / float(floors)
		_add_box(Vector3(w * 0.94, 0.075, d * 0.90), Vector3(0, belt_y, 0), plaster_light)
		_add_box(Vector3(w * 0.92, 0.035, d * 0.91), Vector3(0, belt_y - 0.07, 0), plaster_shadow)

	# Keep balcony dimensions aligned with _add_natural_window()'s 0.44 m front window.
	var window_w := 0.44
	var columns := 2 if w < 4.0 else 3
	if is_apartment:
		columns = 3 if w < 5.0 else 4
	if is_farm:
		columns = 2
	for floor_index in range(floors):
		var window_y := 0.34 + (float(floor_index) + 0.55) * body_h / float(floors)
		for column in range(columns):
			var x_pos := -w * 0.29 + float(column) * (w * 0.58 / float(maxi(columns - 1, 1)))
			_add_natural_window(Vector3(x_pos, window_y, d * 0.435), frame, glass)
			if is_apartment and floor_index > 0:
				# Small projecting sill/balcony rails make apartment floors read as occupied.
				_add_box(Vector3(window_w * 1.45, 0.055, 0.18),
					Vector3(x_pos, window_y - 0.29, d * 0.49), stone_cap)
				_add_box(Vector3(window_w * 1.35, 0.045, 0.045),
					Vector3(x_pos, window_y - 0.08, d * 0.545), frame)
				for rail_x in [-0.5, 0.5]:
					_add_box(Vector3(0.035, 0.17, 0.035),
						Vector3(x_pos + rail_x * window_w, window_y - 0.18, d * 0.545), frame)

	# A real entrance composition: recessed dark door, surround, lintel, handle and two steps.
	var door_w := 0.48
	var door_h := minf(1.08, body_h * 0.58)
	var door_y := 0.34 + door_h * 0.5
	_add_box(Vector3(door_w + 0.16, door_h + 0.13, 0.075),
		Vector3(0, door_y, d * 0.438), frame)
	_add_box(Vector3(door_w, door_h, 0.045),
		Vector3(0, door_y, d * 0.485), wood)
	_add_box(Vector3(0.045, door_h * 0.78, 0.025),
		Vector3(door_w * 0.25, door_y + 0.02, d * 0.512), Color(0.56, 0.35, 0.22))
	_add_box(Vector3(0.045, 0.045, 0.035),
		Vector3(door_w * 0.30, door_y - 0.03, d * 0.535), Color(0.82, 0.66, 0.30))
	_add_box(Vector3(0.86, 0.12, 0.46), Vector3(0, 0.39, d * 0.56), stone_cap)
	_add_box(Vector3(0.70, 0.10, 0.30), Vector3(0, 0.28, d * 0.68), stone)
	_add_box(Vector3(1.02, 0.10, 0.48), Vector3(0, 0.88, d * 0.50), roof_edge)
	_add_box(Vector3(0.07, 0.54, 0.07), Vector3(-0.43, 0.61, d * 0.48), wood)
	_add_box(Vector3(0.07, 0.54, 0.07), Vector3(0.43, 0.61, d * 0.48), wood)

	# Roof form differs by building type: pitched villa roof versus dense flat-roof apartment.
	if is_apartment:
		_add_box(Vector3(w * 0.98, 0.18, d * 0.94), Vector3(0, body_h + 0.43, 0), roof_edge)
		_add_box(Vector3(w * 0.91, 0.12, d * 0.87), Vector3(0, body_h + 0.56, 0), plaster_light)
		_add_box(Vector3(w * 0.88, 0.18, 0.12), Vector3(0, body_h + 0.70, d * 0.40), stone_cap)
		_add_box(Vector3(w * 0.88, 0.18, 0.12), Vector3(0, body_h + 0.70, -d * 0.40), stone_cap)
	elif is_farm:
		# Low rural lean-to roof and timber fascia; intentionally unlike a villa roof.
		_add_box(Vector3(w * 1.04, 0.16, d * 1.00), Vector3(0, body_h + 0.43, 0), roof_edge)
		_add_box(Vector3(w * 0.96, 0.12, d * 0.88), Vector3(0, body_h + 0.56, 0), Color(0.49, 0.40, 0.27))
	else:
		# Eaves project beyond the walls; layered fascia gives the roof a finished edge.
		_add_gabled_roof(w * 1.04, d * 1.02, body_h + 0.34, 0.62, roof_tile, roof_edge)
		_add_box(Vector3(w * 1.08, 0.10, 0.12),
			Vector3(0, body_h + 0.37, d * 0.33), stone_cap)
		_add_box(Vector3(w * 1.08, 0.10, 0.12),
			Vector3(0, body_h + 0.37, -d * 0.33), stone_cap)

	# Chimney and roof details become visible on more developed homes.
	if upgrade_stage >= 3 and not is_apartment and not is_farm:
		var chimney_x := w * 0.27
		_add_box(Vector3(0.30, 0.78, 0.30),
			Vector3(chimney_x, body_h + 0.78, -d * 0.20), Color(0.55, 0.25, 0.18))
		_add_box(Vector3(0.38, 0.09, 0.38),
			Vector3(chimney_x, body_h + 1.19, -d * 0.20), roof_edge)
	if upgrade_stage >= 5 and not is_apartment:
		# Dormer-like front projection and a small roof vent distinguish the mature home.
		_add_box(Vector3(0.88, 0.62, 0.18),
			Vector3(0, body_h + 0.66, d * 0.34), plaster)
		_add_natural_window(Vector3(0, body_h + 0.69, d * 0.445), frame, glass)
		_add_box(Vector3(1.02, 0.10, 0.22),
			Vector3(0, body_h + 1.00, d * 0.34), roof_tile)

	if is_farm:
		# Cultivated beds and fence remain part of the farm identity.
		for row in range(2):
			for column in range(2):
				var crop_pos := Vector3(-w * 0.28 + float(column) * 0.62, 0.34, -d * 0.34 + float(row) * 0.58)
				_add_box(Vector3(0.48, 0.10, 0.42), crop_pos, Color(0.38, 0.30, 0.18))
				_add_box(Vector3(0.36, 0.18, 0.08), crop_pos + Vector3(0, 0.12, 0), Color(0.34, 0.55, 0.25))
		for x_pos in [-w * 0.42, w * 0.42]:
			_add_box(Vector3(0.07, 0.42, 0.07), Vector3(x_pos, 0.40, -d * 0.48), wood)

	# Each residential upgrade is a new architectural generation, not a tint or
	# a small height adjustment. The additions below change the silhouette,
	# usable massing and facade language at every stage after the starter home.
	if not is_farm or upgrade_stage > 1:
		_build_residential_level_architecture(
			w, d, body_h, plaster, plaster_light, stone_cap, roof_tile,
			frame, glass, is_apartment, is_farm
		)


func _build_residential_level_architecture(
	w: float, d: float, body_h: float, wall: Color, trim: Color,
	stone: Color, roof: Color, frame: Color, glass: Color,
	is_apartment: bool, is_farm: bool
) -> void:
	var stage := clampi(upgrade_stage, 1, 6)
	var front := d * 0.46
	var side := w * 0.46
	var modern_white := Color(0.91, 0.93, 0.90)
	var graphite := Color(0.16, 0.21, 0.25)
	var warm_wood := Color(0.48, 0.29, 0.17)
	var accent := Color(0.12, 0.62, 0.66)
	var glass_blue := Color(0.16, 0.42, 0.58)

	if is_farm:
		# Rural homes evolve into working farmsteads: barn, silo, greenhouse and
		# expanded cultivated plots, rather than becoming urban apartment blocks.
		if stage >= 2:
			_add_box(Vector3(w * 0.48, body_h * 0.78, d * 0.42),
				Vector3(side * 0.48, body_h * 0.39 + 0.34, -d * 0.20), Color(0.67, 0.28, 0.18))
			_add_gabled_roof(w * 0.54, d * 0.48, body_h * 0.78 + 0.34, 0.42,
				Color(0.34, 0.19, 0.13), Color(0.77, 0.67, 0.48))
			_add_box(Vector3(0.12, 1.10, 0.12), Vector3(-side * 0.55, 0.89, -d * 0.38), warm_wood)
		if stage >= 3:
			var silo := CylinderMesh.new()
			silo.top_radius = 0.28
			silo.bottom_radius = 0.34
			silo.height = 1.55
			var silo_node := MeshInstance3D.new()
			silo_node.mesh = silo
			silo_node.position = Vector3(side * 0.48, 1.12, -d * 0.40)
			var silo_mat := StandardMaterial3D.new()
			silo_mat.albedo_color = Color(0.70, 0.72, 0.67)
			silo_mat.metallic = 0.28
			silo_node.material_override = silo_mat
			mesh_root.add_child(silo_node)
		if stage >= 4:
			_add_box(Vector3(w * 0.42, 1.05, d * 0.34), Vector3(-side * 0.48, 0.88, -d * 0.24), Color(0.42, 0.66, 0.54))
			for row in range(3):
				_add_box(Vector3(w * 0.38, 0.035, 0.035), Vector3(-side * 0.48, 0.42 + float(row) * 0.30, -d * 0.05), glass_blue)
		if stage >= 5:
			_add_box(Vector3(w * 0.54, 0.18, d * 0.48), Vector3(0, body_h + 0.82, -d * 0.12), Color(0.78, 0.58, 0.24))
			for row in range(2):
				for col in range(3):
					_add_box(Vector3(0.22, 0.12, 0.18), Vector3(-w * 0.20 + float(col) * 0.42, 0.96, -d * 0.42 + float(row) * 0.34), Color(0.26, 0.55, 0.22))
		if stage >= 6:
			_add_box(Vector3(w * 0.78, 0.26, d * 0.58), Vector3(0, body_h + 1.02, 0), Color(0.34, 0.47, 0.30))
			_add_box(Vector3(0.16, 1.85, 0.16), Vector3(side * 0.62, 1.28, -d * 0.42), Color(0.72, 0.74, 0.68))
		return

	if is_apartment:
		# Apartment tiers add visibly different massing: podium, offset wings,
		# glass corner core, then a stepped contemporary tower crown.
		if stage >= 2:
			_add_box(Vector3(w * 1.02, 0.34, d * 0.98), Vector3(0, 0.52, 0), accent)
			for floor in range(3):
				var y := 0.90 + float(floor) * 1.18
				_add_box(Vector3(0.11, 0.78, 0.13), Vector3(-side * 0.86, y, front), frame)
				_add_box(Vector3(0.11, 0.78, 0.13), Vector3(side * 0.86, y, front), frame)
		if stage >= 3:
			_add_box(Vector3(w * 0.34, 1.35, d * 0.70), Vector3(-w * 0.31, body_h + 0.68, 0), modern_white)
			_add_box(Vector3(w * 0.38, 0.12, d * 0.74), Vector3(-w * 0.31, body_h + 1.38, 0), accent)
		if stage >= 4:
			_add_box(Vector3(0.34, body_h * 0.72, 0.30), Vector3(side * 0.66, body_h * 0.52 + 0.34, front + 0.06), glass_blue)
			_add_box(Vector3(w * 1.08, 0.16, d * 0.20), Vector3(0, body_h + 0.84, -d * 0.34), warm_wood)
		if stage >= 5:
			_add_box(Vector3(w * 0.52, 1.45, d * 0.70), Vector3(w * 0.22, body_h + 1.08, -d * 0.06), modern_white)
			_add_box(Vector3(w * 0.56, 0.18, d * 0.76), Vector3(w * 0.22, body_h + 1.82, -d * 0.06), graphite)
		if stage >= 6:
			_add_box(Vector3(w * 0.34, 2.10, d * 0.48), Vector3(-w * 0.22, body_h + 2.10, 0), glass_blue)
			_add_box(Vector3(w * 0.40, 0.20, d * 0.56), Vector3(-w * 0.22, body_h + 3.18, 0), accent)
		return

	match stage:
		2:
			# Stage 2: expanded suburban home with attached garage and new roof wing.
			_add_box(Vector3(w * 0.42, 1.30, d * 0.62), Vector3(side * 0.53, 0.99, -d * 0.10), modern_white)
			_add_box(Vector3(w * 0.46, 0.12, d * 0.68), Vector3(side * 0.53, 1.68, -d * 0.10), graphite)
			_add_box(Vector3(w * 0.34, 0.86, 0.055), Vector3(side * 0.53, 0.88, front + 0.04), graphite)
			for rib in range(5):
				_add_box(Vector3(0.025, 0.72, 0.025), Vector3(side * 0.53 - w * 0.15 + float(rib) * 0.075, 0.88, front + 0.08), trim)
			_add_box(Vector3(w * 0.48, 0.13, d * 0.18), Vector3(-side * 0.40, body_h + 0.60, -d * 0.22), roof)
		3:
			# Stage 3: true two-storey redesign with offset upper floor and balcony.
			_add_box(Vector3(w * 0.72, 1.18, d * 0.66), Vector3(-w * 0.10, body_h + 0.60, -d * 0.04), modern_white)
			_add_box(Vector3(w * 0.78, 0.16, d * 0.72), Vector3(-w * 0.10, body_h + 1.22, -d * 0.04), graphite)
			_add_box(Vector3(w * 0.74, 0.10, 0.52), Vector3(0, body_h + 0.30, front + 0.16), warm_wood)
			_add_box(Vector3(w * 0.68, 0.08, 0.055), Vector3(0, body_h + 0.88, front + 0.42), frame)
			for post in [-1.0, 1.0]:
				_add_box(Vector3(0.055, 0.58, 0.055), Vector3(post * w * 0.32, body_h + 0.58, front + 0.42), frame)
		4:
			# Stage 4: contemporary glass sunroom, cantilevered terrace and pergola.
			_add_box(Vector3(w * 0.48, 1.55, d * 0.48), Vector3(side * 0.42, body_h * 0.50 + 0.62, -d * 0.08), glass_blue)
			for mullion in range(4):
				var mx := side * 0.42 - w * 0.19 + float(mullion) * 0.125
				_add_box(Vector3(0.045, 1.48, 0.07), Vector3(mx, body_h * 0.50 + 0.62, front + 0.10), frame)
			_add_box(Vector3(w * 0.82, 0.16, d * 0.40), Vector3(-w * 0.08, body_h + 0.48, -d * 0.30), warm_wood)
			for beam in range(5):
				_add_box(Vector3(0.09, 0.12, d * 0.38), Vector3(-w * 0.42 + float(beam) * 0.22, body_h + 0.72, -d * 0.30), roof)
		5:
			# Stage 5: modernist split-level villa with roof garden and solar canopy.
			_add_box(Vector3(w * 0.76, 1.62, d * 0.66), Vector3(-w * 0.10, body_h + 0.82, -d * 0.06), modern_white)
			_add_box(Vector3(w * 0.82, 0.18, d * 0.72), Vector3(-w * 0.10, body_h + 1.68, -d * 0.06), graphite)
			_add_box(Vector3(w * 0.44, 0.14, d * 0.56), Vector3(side * 0.48, body_h + 0.30, -d * 0.05), accent)
			for panel in range(3):
				_add_box(Vector3(0.42, 0.055, 0.30), Vector3(-w * 0.27 + float(panel) * 0.48, body_h + 1.80, -d * 0.12), Color(0.08, 0.20, 0.34))
			for planter in range(3):
				_add_box(Vector3(0.34, 0.28, 0.30), Vector3(-w * 0.30 + float(planter) * 0.52, body_h + 0.54, front + 0.08), Color(0.28, 0.54, 0.30))
		6:
			# Stage 6: premium contemporary residence; a new penthouse volume,
			# full-height glazing and a distinctive rooftop pavilion replace the old roofline.
			_add_box(Vector3(w * 0.72, 1.92, d * 0.62), Vector3(0, body_h + 1.02, -d * 0.05), modern_white)
			_add_box(Vector3(w * 0.76, 0.18, d * 0.68), Vector3(0, body_h + 2.02, -d * 0.05), graphite)
			_add_box(Vector3(w * 0.56, 1.46, 0.10), Vector3(0, body_h + 1.05, front + 0.08), glass_blue)
			_add_box(Vector3(w * 0.46, 0.16, d * 0.46), Vector3(0, body_h + 2.16, -d * 0.05), accent)
			for column in [-1.0, 1.0]:
				_add_box(Vector3(0.10, 1.88, 0.10), Vector3(column * w * 0.34, body_h + 1.00, front + 0.12), frame)


# Level 1 starter home: a compact, colourful Sims-like villa with distinct facade,
# roof, trim, garden and warm emissive windows. Emissive meshes avoid per-house lights.
func _build_level_one_villa(w: float, d: float, height: float, base_color: Color) -> void:
	var wall := Color(0.98, 0.72, 0.43).lerp(base_color, 0.18)
	var coral := Color(0.98, 0.34, 0.28)
	var turquoise := Color(0.10, 0.68, 0.67)
	var yellow := Color(1.0, 0.78, 0.22)
	var cream := Color(1.0, 0.91, 0.72)
	var roof := Color(0.72, 0.18, 0.22)
	var roof_dark := Color(0.42, 0.10, 0.16)
	var wood := Color(0.34, 0.17, 0.11)
	var glass := Color(0.12, 0.37, 0.48)
	var body_h := maxf(height, 2.05)
	var front := d * 0.43

	# Coloured foundation, lower plinth and warm plaster walls.
	_add_box(Vector3(w * 1.04, 0.18, d * 1.04), Vector3(0, 0.09, 0), turquoise)
	_add_box(Vector3(w * 0.98, 0.18, d * 0.96), Vector3(0, 0.25, 0), cream)
	_add_box(Vector3(w * 0.88, body_h, d * 0.82), Vector3(0, body_h * 0.5 + 0.34, 0), wall)
	_add_box(Vector3(w * 0.91, 0.13, d * 0.86), Vector3(0, 0.48, 0), coral)
	_add_box(Vector3(w * 0.94, 0.10, d * 0.90), Vector3(0, body_h + 0.34, 0), turquoise)

	# Bold corner bands and a contrasting front gable.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.13, body_h * 0.96, 0.13), Vector3(side * w * 0.39, body_h * 0.5 + 0.35, front), turquoise)
	_add_box(Vector3(w * 0.44, 0.62, 0.13), Vector3(0, body_h + 0.58, front * 0.94), coral)
	_add_box(Vector3(w * 0.31, 0.40, 0.07), Vector3(0, body_h + 0.59, front * 1.04), yellow)

	# Large warm windows with luminous inner panes and crisp contrasting frames.
	for x_pos in [-w * 0.27, w * 0.27]:
		_add_box(Vector3(0.78, 0.78, 0.10), Vector3(x_pos, 1.18, front * 1.02), cream)
		_add_box(Vector3(0.64, 0.64, 0.045), Vector3(x_pos, 1.18, front * 1.10), glass)
		_add_emissive_box(Vector3(0.56, 0.56, 0.025), Vector3(x_pos, 1.18, front * 1.14), Color(1.0, 0.72, 0.32), 0.42)
		_add_box(Vector3(0.055, 0.68, 0.045), Vector3(x_pos, 1.18, front * 1.17), turquoise)
		_add_box(Vector3(0.70, 0.07, 0.16), Vector3(x_pos, 0.76, front * 1.18), coral)
		_add_box(Vector3(0.12, 0.22, 0.12), Vector3(x_pos - 0.30, 0.91, front * 1.20), yellow)
		_add_box(Vector3(0.12, 0.22, 0.12), Vector3(x_pos + 0.30, 0.91, front * 1.20), turquoise)

	# Recessed front door, bright surround, handle and welcoming steps.
	_add_box(Vector3(0.66, 1.22, 0.12), Vector3(0, 0.95, front * 1.03), turquoise)
	_add_box(Vector3(0.48, 1.04, 0.07), Vector3(0, 0.94, front * 1.12), wood)
	_add_box(Vector3(0.045, 0.82, 0.025), Vector3(-0.10, 0.95, front * 1.17), coral)
	_add_box(Vector3(0.045, 0.055, 0.035), Vector3(0.15, 0.92, front * 1.19), yellow)
	_add_box(Vector3(0.92, 0.12, 0.42), Vector3(0, 0.37, front * 1.28), yellow)
	_add_box(Vector3(0.72, 0.10, 0.28), Vector3(0, 0.25, front * 1.46), cream)

	# Two-plane pitched roof with saturated red tiles and golden ridge.
	_add_gabled_roof(w * 1.10, d * 1.04, body_h + 0.34, 0.72, roof, roof_dark)
	_add_box(Vector3(w * 1.14, 0.12, 0.15), Vector3(0, body_h + 1.09, 0), yellow)
	for roof_side in [-1.0, 1.0]:
		_add_box(Vector3(w * 0.96, 0.09, 0.11), Vector3(0, body_h + 0.39, roof_side * d * 0.32), cream)

	# Small dormer, chimney and decorative roof panels give the silhouette a toy-town charm.
	_add_box(Vector3(0.72, 0.48, 0.16), Vector3(0, body_h + 0.77, front * 0.52), yellow)
	_add_box(Vector3(0.48, 0.30, 0.07), Vector3(0, body_h + 0.78, front * 0.60), glass)
	_add_box(Vector3(0.30, 0.62, 0.30), Vector3(w * 0.30, body_h + 0.76, -d * 0.20), coral)
	_add_box(Vector3(0.38, 0.09, 0.38), Vector3(w * 0.30, body_h + 1.10, -d * 0.20), yellow)

	# Emissive wall sconces and a bright coloured canopy above the entrance.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.18, 0.25, 0.09), Vector3(side * 0.52, 1.24, front * 1.12), turquoise)
		_add_emissive_box(Vector3(0.12, 0.17, 0.045), Vector3(side * 0.52, 1.23, front * 1.18), yellow, 1.65)
	_add_box(Vector3(1.42, 0.12, 0.48), Vector3(0, 1.88, front * 1.14), coral)
	for stripe in range(5):
		var stripe_x := -0.56 + float(stripe) * 0.28
		_add_box(Vector3(0.22, 0.13, 0.46), Vector3(stripe_x, 1.87, front * 1.20), cream if stripe % 2 == 0 else yellow)

	# Flower boxes, tiny shrubs and a colourful front garden edge.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.72, 0.18, 0.28), Vector3(side * w * 0.30, 0.57, front * 1.23), coral)
		for flower in range(3):
			var flower_x: float = float(side) * w * 0.30 - 0.22 + float(flower) * 0.22
			_add_box(Vector3(0.13, 0.17, 0.13), Vector3(flower_x, 0.73, front * 1.25), [coral, yellow, turquoise][flower])
	_add_box(Vector3(w * 0.72, 0.07, 0.34), Vector3(0, 0.08, d * 0.48), turquoise)

func _add_natural_window(pos: Vector3, frame_col: Color, glass_col: Color, side: bool = false) -> void:
	var fw := 0.36 if side else 0.44
	var fh := 0.40 if side else 0.48
	_add_box(Vector3(fw, fh, 0.05), pos, frame_col)
	_add_box(Vector3(fw * 0.70, fh * 0.70, 0.03), pos + Vector3(0, 0, 0.025), glass_col)
	_add_box(Vector3(0.03, fh * 0.70, 0.04), pos + Vector3(0, 0, 0.03), frame_col.darkened(0.2))
	_add_box(Vector3(fw * 0.70, 0.03, 0.04), pos + Vector3(0, 0, 0.03), frame_col.darkened(0.2))
	_add_box(Vector3(fw * 1.1, 0.05, 0.10), pos + Vector3(0, -fh * 0.52, 0.03), frame_col.lightened(0.05))

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
	# Retail architecture: glazed shopfront at street level, sign fascia, canopy,
	# and progressively richer upper facade. Restaurant subtypes get a deeper canopy.
	var stage := clampi(upgrade_stage, 1, 6)
	var subtype := str(definition.get("subtype", building_type))
	var is_food := subtype.contains("restaurant") or subtype.contains("fast_food") or building_type.contains("fast_food")
	if building_type == "building_supplies" or subtype == "building_supplies":
		_build_building_supplies_showcase(w, d, height, color)
		return
	if building_type == "art_supplies" or subtype == "art":
		_build_art_supplies_showcase(w, d, height, color)
		return
	var wall := Color(0.73, 0.59, 0.43).lerp(color, 0.20)
	var wall_shadow := wall.darkened(0.19)
	var wall_light := wall.lightened(0.16)
	var trim := Color(0.88, 0.78, 0.61)
	var trim_shadow := Color(0.57, 0.43, 0.30)
	var glass := Color(0.18, 0.37, 0.46)
	var glass_glint := Color(0.43, 0.62, 0.67)
	var sign := Color(0.67, 0.25, 0.15) if is_food else Color(0.29, 0.39, 0.43)
	var sign_edge := sign.lightened(0.22)
	var stone := Color(0.40, 0.37, 0.32)
	var roof := Color(0.31, 0.29, 0.26)
	var floors := 1 if stage < 3 else (2 if stage < 5 else 3)
	var body_h := height if floors == 1 else maxf(height, 2.0 + float(floors - 1) * 1.25)
	_add_box(Vector3(w * 1.02, 0.30, d * 1.02), Vector3(0, 0.15, 0), stone)
	_add_box(Vector3(w * 0.94, 0.10, d * 0.94), Vector3(0, 0.34, 0), trim_shadow)
	_add_box(Vector3(w * 0.90, body_h, d * 0.88), Vector3(0, body_h * 0.5 + 0.38, 0), wall)
	_add_box(Vector3(w * 0.91, body_h * 0.42, 0.045), Vector3(0, body_h * 0.22 + 0.39, d * 0.447), wall_shadow)
	_add_box(Vector3(w * 0.94, 0.10, d * 0.92), Vector3(0, body_h + 0.42, 0), trim)
	var shop_w := w * (0.70 if stage < 5 else 0.76)
	var shop_h := minf(1.18, body_h * 0.54)
	_add_box(Vector3(shop_w + 0.16, shop_h + 0.16, 0.09), Vector3(-w * 0.055, shop_h * 0.5 + 0.40, d * 0.455), trim_shadow)
	_add_box(Vector3(shop_w, shop_h, 0.055), Vector3(-w * 0.055, shop_h * 0.5 + 0.40, d * 0.49), glass)
	for mullion in range(5 if stage >= 3 else 4):
		var x := -w * 0.055 - shop_w * 0.5 + float(mullion) * shop_w / float((5 if stage >= 3 else 4) - 1)
		_add_box(Vector3(0.055, shop_h + 0.04, 0.10), Vector3(x, shop_h * 0.5 + 0.40, d * 0.515), trim)
	_add_box(Vector3(shop_w * 0.32, shop_h * 0.74, 0.06), Vector3(-w * 0.055, shop_h * 0.58 + 0.40, d * 0.53), glass_glint)
	var door_w := 0.40
	_add_box(Vector3(door_w + 0.12, 1.02, 0.09), Vector3(w * 0.35, 0.90, d * 0.455), trim_shadow)
	_add_box(Vector3(door_w, 0.92, 0.055), Vector3(w * 0.35, 0.90, d * 0.50), glass)
	_add_box(Vector3(w * 0.88, 0.19 if is_food else 0.15, 0.40), Vector3(0, body_h * 0.76, d * 0.51), sign)
	_add_box(Vector3(w * 0.92, 0.065, 0.44), Vector3(0, body_h * 0.76 + 0.13, d * 0.49), sign_edge)
	_add_box(Vector3(w * (0.98 if is_food else 0.90), 0.10, 0.68 if is_food else 0.48), Vector3(0, 1.72, d * 0.57), sign if is_food else trim_shadow)
	_add_box(Vector3(w * 0.96, 0.07, 0.10), Vector3(0, 1.65, d * 0.83), trim)
	if floors >= 2:
		for floor in range(1, floors):
			var fy := 0.38 + float(floor) * body_h / float(floors)
			_add_box(Vector3(w * 0.94, 0.10, d * 0.91), Vector3(0, fy, 0), trim_shadow)
			for column in range(3 if stage < 5 else 4):
				var x := -w * 0.30 + float(column) * w * 0.60 / float((3 if stage < 5 else 4) - 1)
				_add_natural_window(Vector3(x, fy + 0.52, d * 0.447), trim, glass)
				_add_box(Vector3(0.06, body_h / float(floors) * 0.82, 0.07), Vector3(x - 0.30, fy + 0.50, d * 0.44), wall_light)
	if stage >= 5:
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.14, body_h + 0.18, 0.14), Vector3(side * w * 0.43, body_h * 0.5 + 0.39, d * 0.44), trim)
		_add_box(Vector3(w * 0.98, 0.16, d * 0.94), Vector3(0, body_h + 0.52, 0), roof)
	else:
		_add_box(Vector3(w * 0.98, 0.12, d * 0.94), Vector3(0, body_h + 0.49, 0), roof)

	_build_commercial_identity(w, d, body_h, d * 0.5, stage)


func _build_commercial_identity(w: float, d: float, body_h: float, front: float, stage: int) -> void:
	# Trade-specific rooflines and street props make each shop readable before
	# the player opens its production panel. These are distinct meshes, not tints.
	var id := building_type
	var roof_y := body_h + 0.78
	var white := Color(0.94, 0.91, 0.82)
	var dark := Color(0.15, 0.20, 0.25)
	var green := Color(0.20, 0.52, 0.30)
	var accent := Color(0.96, 0.62, 0.16)
	match id:
		"shop_chain":
			# Franchise store: broad branded fascia, projecting corner sign and
			# a repeated modular canopy distinguish it from independent shops.
			_add_box(Vector3(w * 0.96, 0.34, 0.16), Vector3(0, 1.88, front + 0.30), Color(0.12, 0.34, 0.72))
			_add_box(Vector3(w * 0.82, 0.08, 0.20), Vector3(0, 2.08, front + 0.34), Color(0.98, 0.82, 0.18))
			_add_box(Vector3(0.18, 0.92, 0.18), Vector3(w * 0.46, 1.32, front + 0.28), Color(0.12, 0.34, 0.72))
			_add_box(Vector3(w * 0.22, 0.22, 0.20), Vector3(w * 0.46, 1.84, front + 0.28), Color(0.98, 0.82, 0.18))
			for bay in range(5):
				var x := -w * 0.40 + float(bay) * w * 0.20
				_add_box(Vector3(w * 0.16, 0.08, 0.34), Vector3(x, 1.58, front + 0.34), Color(0.96, 0.94, 0.86) if bay % 2 == 0 else Color(0.12, 0.34, 0.72))
		"restaurant_traditional":
			_add_box(Vector3(w * 0.74, 0.12, d * 0.38), Vector3(0, 1.95, front + 0.28), Color(0.56, 0.16, 0.10))
			_add_cylinder(0.13, 0.17, 1.25, Vector3(w * 0.32, roof_y, -d * 0.28), dark)
			for table in [-1.0, 1.0]:
				_add_cylinder(0.20, 0.20, 0.08, Vector3(table * w * 0.34, 0.40, front + 0.62), white)
				_add_cylinder(0.045, 0.045, 0.46, Vector3(table * w * 0.34, 0.18, front + 0.62), dark)
		"fast_food":
			_add_box(Vector3(0.20, 1.35, 0.20), Vector3(w * 0.40, 1.10, front + 0.38), accent)
			_add_box(Vector3(0.72, 0.52, 0.12), Vector3(w * 0.40, 1.82, front + 0.38), Color(0.88, 0.18, 0.10))
			_add_box(Vector3(w * 0.76, 0.12, d * 0.30), Vector3(0, 1.58, -d * 0.30), dark)
		"hardware_store":
			for stack in range(3):
				_add_box(Vector3(w * 0.22, 0.24, d * 0.20), Vector3(-w * 0.28 + float(stack) * w * 0.28, 0.48, front + 0.38), Color(0.65, 0.39, 0.16))
			_add_box(Vector3(w * 0.78, 0.14, d * 0.28), Vector3(0, roof_y, 0), accent)
		"farmers_market":
			_add_box(Vector3(w * 0.94, 0.10, d * 0.54), Vector3(0, 1.66, front + 0.22), green)
			for stall in range(4):
				var x := -w * 0.36 + float(stall) * w * 0.24
				_add_box(Vector3(0.42, 0.30, 0.34), Vector3(x, 0.48, front + 0.52), [Color(0.82,0.20,0.12), Color(0.92,0.68,0.12), green, Color(0.88,0.42,0.16)][stall])
		"furniture_store":
			_add_box(Vector3(w * 0.52, 0.48, 0.30), Vector3(-w * 0.20, 0.72, front + 0.32), Color(0.55, 0.24, 0.15))
			_add_box(Vector3(w * 0.52, 0.20, 0.26), Vector3(-w * 0.20, 1.04, front + 0.32), Color(0.80, 0.58, 0.34))
			_add_box(Vector3(0.22, 0.78, 0.22), Vector3(w * 0.28, 0.82, front + 0.34), dark)
		"gardening_supplies":
			_add_box(Vector3(w * 0.48, 1.05, d * 0.38), Vector3(0, 0.90, -d * 0.26), Color(0.30, 0.58, 0.42))
			for pot in range(4):
				var x := -w * 0.36 + float(pot) * w * 0.24
				_add_cylinder(0.12, 0.16, 0.22, Vector3(x, 0.43, front + 0.38), Color(0.62, 0.28, 0.15))
				_add_cylinder(0.025, 0.09, 0.36, Vector3(x, 0.70, front + 0.38), green)
		"donut_shop":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.22
			ring.outer_radius = 0.42
			var ring_node := MeshInstance3D.new()
			ring_node.mesh = ring
			ring_node.position = Vector3(0, roof_y + 0.24, 0)
			var ring_mat := StandardMaterial3D.new()
			ring_mat.albedo_color = Color(0.92, 0.48, 0.55)
			ring_node.material_override = ring_mat
			mesh_root.add_child(ring_node)
			_add_box(Vector3(w * 0.72, 0.12, d * 0.34), Vector3(0, 1.62, front + 0.20), Color(0.98, 0.76, 0.68))
		"home_appliances":
			for unit in range(3):
				var x := -w * 0.28 + float(unit) * w * 0.28
				_add_box(Vector3(0.34, 0.62, 0.32), Vector3(x, roof_y, -d * 0.18), [white, Color(0.65,0.72,0.76), dark][unit])
				_add_box(Vector3(0.22, 0.12, 0.035), Vector3(x, roof_y + 0.12, -d * 0.01), accent)
		"fashion_store":
			_add_box(Vector3(w * 0.72, 0.14, d * 0.30), Vector3(0, 1.72, front + 0.20), Color(0.68, 0.22, 0.46))
			for display in [-1.0, 1.0]:
				_add_cylinder(0.09, 0.12, 0.42, Vector3(display * w * 0.30, 0.74, front + 0.38), Color(0.82, 0.58, 0.42))
				_add_box(Vector3(0.26, 0.38, 0.10), Vector3(display * w * 0.30, 1.10, front + 0.38), [Color(0.18,0.42,0.72), Color(0.78,0.22,0.38)][0 if display < 0 else 1])
		"sports_shop":
			_add_cylinder(0.34, 0.34, 0.10, Vector3(-w * 0.26, roof_y, 0), Color(0.92, 0.38, 0.12))
			_add_box(Vector3(0.07, 0.88, 0.07), Vector3(w * 0.28, 0.92, front + 0.34), dark)
			_add_box(Vector3(0.62, 0.06, 0.06), Vector3(w * 0.28, 1.30, front + 0.34), accent)
		"toy_store":
			for block in range(4):
				var x := -w * 0.30 + float(block) * w * 0.20
				_add_box(Vector3(0.34, 0.34, 0.34), Vector3(x, roof_y + 0.18, 0), [Color(0.92,0.18,0.18), Color(0.15,0.55,0.88), Color(0.96,0.72,0.12), green][block])
		"restoration_office":
			for column in range(3):
				var x := -w * 0.32 + float(column) * w * 0.32
				_add_box(Vector3(0.10, 1.15, 0.10), Vector3(x, 0.94, front + 0.32), Color(0.62, 0.60, 0.53))
				_add_box(Vector3(0.32, 0.10, 0.10), Vector3(x, 1.52, front + 0.32), accent)
		"farmers_store":
			_add_gabled_roof(w * 0.62, d * 0.46, body_h + 0.48, 0.52, Color(0.52,0.24,0.15), Color(0.82,0.68,0.44))
			_add_box(Vector3(w * 0.42, 0.52, d * 0.28), Vector3(0, 0.72, front + 0.30), Color(0.58,0.34,0.16))
		"dessert_shop":
			_add_box(Vector3(w * 0.96, 0.12, d * 0.42), Vector3(0, 1.65, front + 0.22), Color(0.98,0.72,0.78))
			for accent_index in range(5):
				var x := -w * 0.40 + float(accent_index) * w * 0.20
				_add_cylinder(0.08, 0.08, 0.22, Vector3(x, 1.86, front + 0.24), [Color(0.90,0.22,0.28), Color(1.0,0.72,0.20), Color(0.36,0.65,0.42)][accent_index % 3])
		_:
			pass
	if stage >= 4:
		# Later shop levels gain a new upper-floor volume and larger roof plant.
		_add_box(Vector3(w * 0.54, 0.26, d * 0.52), Vector3(0, body_h + 0.90, -d * 0.12), dark)
		_add_box(Vector3(w * 0.48, 0.18, d * 0.44), Vector3(0, body_h + 1.08, -d * 0.12), accent)



# Signature commercial hero asset: a vivid, readable construction-supplies shop.
# Geometry is deliberately built from the same local primitives as the rest of
# the city so it remains offline, editable and compatible with the GL renderer.
func _build_building_supplies_showcase(w: float, d: float, height: float, color: Color) -> void:
	var brick := Color(0.82, 0.22, 0.10)
	var brick_light := Color(1.0, 0.36, 0.16)
	var brick_dark := Color(0.48, 0.12, 0.08)
	var navy := Color(0.055, 0.16, 0.29)
	var navy_light := Color(0.12, 0.31, 0.49)
	var cream := Color(0.96, 0.84, 0.64)
	var glass := Color(0.10, 0.29, 0.40)
	var glass_glow := Color(0.38, 0.66, 0.75)
	var timber := Color(0.66, 0.34, 0.12)
	var timber_light := Color(0.91, 0.56, 0.22)
	var concrete := Color(0.57, 0.57, 0.53)
	var safety_yellow := Color(1.0, 0.57, 0.04)
	var body_h := maxf(height, 2.15)
	var front := d * 0.5

	# Deep stone base, warm brick piers and a strongly coloured roof fascia.
	_add_box(Vector3(w * 1.06, 0.32, d * 1.06), Vector3(0, 0.16, 0), concrete.darkened(0.28))
	_add_box(Vector3(w * 1.02, 0.10, d * 1.02), Vector3(0, 0.34, 0), cream.darkened(0.18))
	_add_box(Vector3(w * 0.94, body_h, d * 0.88), Vector3(0, body_h * 0.5 + 0.40, 0), brick)
	_add_box(Vector3(w * 0.96, 0.22, d * 0.94), Vector3(0, body_h + 0.48, 0), navy)
	_add_box(Vector3(w * 0.92, 0.08, d * 0.90), Vector3(0, body_h + 0.63, 0), navy_light)
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.16, body_h * 0.98, 0.12), Vector3(side * w * 0.43, body_h * 0.5 + 0.40, front * 0.88), brick_light)
		_add_box(Vector3(0.12, body_h * 0.98, 0.12), Vector3(side * w * 0.43, body_h * 0.5 + 0.40, -front * 0.88), brick_dark)

	# Wide shop glazing, divided into legible display bays with warm interior light.
	var glass_w := w * 0.78
	var glass_h := 1.12
	_add_box(Vector3(glass_w + 0.14, glass_h + 0.16, 0.10), Vector3(0, glass_h * 0.5 + 0.43, front * 0.91), navy)
	_add_box(Vector3(glass_w, glass_h, 0.055), Vector3(0, glass_h * 0.5 + 0.43, front * 0.95), glass)
	for i in range(5):
		var x := -glass_w * 0.5 + float(i) * glass_w / 4.0
		_add_box(Vector3(0.045, glass_h + 0.06, 0.08), Vector3(x, glass_h * 0.5 + 0.43, front * 0.985), cream)
	# Shelves and colourful product stacks are visible through the storefront.
	for shelf in range(2):
		var y := 0.72 + float(shelf) * 0.43
		_add_box(Vector3(glass_w * 0.88, 0.055, 0.22), Vector3(0, y, front * 0.80), timber)
		for product in range(7):
			var px := -glass_w * 0.39 + float(product) * glass_w * 0.13
			var product_col: Color = [brick_light, safety_yellow, Color(0.10, 0.48, 0.72), Color(0.88, 0.88, 0.78)][product % 4]
			_add_box(Vector3(0.12, 0.25 if shelf == 0 else 0.20, 0.12), Vector3(px, y + 0.15, front * 0.82), product_col)
	# Central glazed entrance with bright metal handles.
	_add_box(Vector3(0.48, 1.04, 0.10), Vector3(w * 0.37, 0.91, front * 0.91), cream)
	_add_box(Vector3(0.38, 0.94, 0.06), Vector3(w * 0.37, 0.91, front * 0.96), glass_glow.darkened(0.22))
	_add_box(Vector3(0.025, 0.28, 0.035), Vector3(w * 0.29, 0.90, front * 1.00), safety_yellow)
	_add_box(Vector3(w * 0.92, 0.18, 0.20), Vector3(0, 1.72, front * 0.97), navy)
	_add_box(Vector3(w * 0.88, 0.055, 0.22), Vector3(0, 1.83, front * 0.99), safety_yellow)
	# Red/cream striped awning, each panel has a visible angled canopy edge.
	_add_box(Vector3(w * 0.98, 0.10, 0.52), Vector3(0, 1.48, front * 1.08), navy)
	for stripe in range(9):
		var sx := -w * 0.47 + float(stripe) * w * 0.1175
		var stripe_col := Color(0.91,0.12,0.10) if stripe % 2 == 0 else Color(1.0,0.91,0.80)
		_add_box_rotated(Vector3(w * 0.115, 0.09, 0.48), Vector3(sx, 1.43, front * 1.12), stripe_col, Vector3(deg_to_rad(-8.0), 0, 0))
	# Warm wall lamps on both sides of the storefront.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.10, 0.20, 0.10), Vector3(side * w * 0.43, 1.52, front * 1.02), navy)
		_add_emissive_box(Vector3(0.13, 0.18, 0.10), Vector3(side * w * 0.43, 1.39, front * 1.04), Color(1.0,0.63,0.18), 1.6)

	# Side windows and a readable brick-and-metal architectural rhythm.
	for floor in range(2):
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.055, 0.62, d * 0.30), Vector3(side * w * 0.475, 1.25 + float(floor) * 0.78, 0), navy)
			_add_box(Vector3(0.07, 0.48, d * 0.26), Vector3(side * w * 0.49, 1.25 + float(floor) * 0.78, 0), glass_glow.darkened(0.18))
	_add_box(Vector3(w * 0.96, 0.13, d * 0.92), Vector3(0, 2.05, 0), navy_light)

	# Rooftop stock: stacked bricks, cement sacks, strapped lumber and ventilation.
	_add_box(Vector3(w * 0.34, 0.12, d * 0.25), Vector3(-w * 0.28, body_h + 0.78, -d * 0.22), timber)
	for row in range(3):
		for col in range(4):
			_add_box(Vector3(w * 0.075, 0.13, d * 0.09), Vector3(-w * 0.39 + float(col) * w * 0.075, body_h + 0.90 + float(row) * 0.13, -d * 0.25 + float(row % 2) * 0.035), brick_light if row % 2 == 0 else brick)
	_add_box(Vector3(w * 0.27, 0.12, d * 0.20), Vector3(w * 0.27, body_h + 0.78, -d * 0.20), cream)
	for sack in range(3):
		_add_box(Vector3(w * 0.24, 0.16, d * 0.13), Vector3(w * 0.27, body_h + 0.92 + float(sack) * 0.14, -d * 0.20), cream.lightened(0.04))
	for plank in range(4):
		_add_box(Vector3(w * 0.12, 0.10, d * 0.48), Vector3(w * 0.36, body_h + 0.78 + float(plank) * 0.11, d * 0.24), timber_light if plank % 2 == 0 else timber)
	# Compact rooftop jib crane: mast, angled boom, counterweight and hook.
	_add_box(Vector3(0.12, 0.78, 0.12), Vector3(-w * 0.08, body_h + 1.18, 0), safety_yellow)
	_add_box_rotated(Vector3(w * 0.70, 0.13, 0.16), Vector3(w * 0.06, body_h + 1.60, 0), safety_yellow, Vector3(0, 0, deg_to_rad(-13.0)))
	for mark in range(5):
		_add_box_rotated(Vector3(0.08, 0.14, 0.18), Vector3(-w * 0.18 + float(mark) * w * 0.12, body_h + 1.60, 0.09), navy, Vector3(0, 0, deg_to_rad(-13.0)))
	_add_box(Vector3(0.10, 0.34, 0.10), Vector3(w * 0.36, body_h + 1.40, 0), navy)
	_add_box(Vector3(0.035, 0.28, 0.035), Vector3(w * 0.37, body_h + 1.18, 0), navy)
	_add_box(Vector3(0.16, 0.12, 0.12), Vector3(w * 0.37, body_h + 1.02, 0), navy)
	# A small louvered rooftop extractor anchors the industrial-material silhouette.
	_add_box(Vector3(0.42, 0.30, 0.36), Vector3(w * 0.34, body_h + 0.82, -d * 0.38), concrete)
	for vent in range(4):
		_add_box(Vector3(0.32, 0.025, 0.035), Vector3(w * 0.34, body_h + 0.72 + float(vent) * 0.065, -d * 0.17), navy)


# Signature art retailer: bright gallery glazing, paint displays and an unmistakable rooftop easel.
# Kept procedural and local so the building is fully available offline on mobile.
func _build_art_supplies_showcase(w: float, d: float, height: float, color: Color) -> void:
	var body_h := maxf(height, 2.25)
	var front := d * 0.5
	var plum := Color(0.25, 0.16, 0.36)
	var purple := Color(0.43, 0.25, 0.62)
	var lavender := Color(0.72, 0.57, 0.86)
	var teal := Color(0.10, 0.42, 0.48)
	var teal_light := Color(0.20, 0.65, 0.67)
	var cream := Color(0.98, 0.91, 0.78)
	var glass := Color(0.12, 0.31, 0.40)
	var gold := Color(1.0, 0.68, 0.12)
	var wood := Color(0.48, 0.27, 0.15)
	var paints: Array[Color] = [
		Color(0.94, 0.20, 0.28), Color(1.0, 0.58, 0.12),
		Color(0.98, 0.84, 0.20), Color(0.20, 0.67, 0.40),
		Color(0.16, 0.55, 0.83), Color(0.52, 0.30, 0.76),
		Color(0.94, 0.42, 0.65)
	]

	# Raised plinth, saturated gallery walls and a contrasting upper cornice.
	_add_box(Vector3(w * 1.06, 0.30, d * 1.06), Vector3(0, 0.15, 0), plum)
	_add_box(Vector3(w * 1.01, 0.09, d * 1.01), Vector3(0, 0.33, 0), gold)
	_add_box(Vector3(w * 0.94, body_h, d * 0.88), Vector3(0, body_h * 0.5 + 0.38, 0), teal)
	_add_box(Vector3(w * 0.97, 0.20, d * 0.94), Vector3(0, body_h + 0.47, 0), plum)
	_add_box(Vector3(w * 0.92, 0.075, d * 0.90), Vector3(0, body_h + 0.61, 0), lavender)

	# Full-height display glazing with warm gallery lighting and deep purple mullions.
	var display_w := w * 0.76
	var display_h := 1.24
	_add_box(Vector3(display_w + 0.18, display_h + 0.18, 0.11),
		Vector3(-w * 0.045, display_h * 0.5 + 0.43, front * 0.91), plum)
	_add_box(Vector3(display_w, display_h, 0.055),
		Vector3(-w * 0.045, display_h * 0.5 + 0.43, front * 0.96), glass)
	_add_emissive_box(Vector3(display_w * 0.92, display_h * 0.88, 0.025),
		Vector3(-w * 0.045, display_h * 0.5 + 0.43, front * 0.985), Color(1.0, 0.66, 0.28), 0.28)
	for mullion in range(5):
		var mx := -w * 0.045 - display_w * 0.5 + float(mullion) * display_w * 0.25
		_add_box(Vector3(0.055, display_h + 0.06, 0.08),
			Vector3(mx, display_h * 0.5 + 0.43, front * 1.01), cream)

	# Framed miniature canvases behind the windows.
	for canvas_index in range(3):
		var cx := -w * 0.27 + float(canvas_index) * w * 0.22
		_add_box(Vector3(0.36, 0.48, 0.045), Vector3(cx, 1.08, front * 0.82), wood)
		_add_box(Vector3(0.29, 0.40, 0.025), Vector3(cx, 1.08, front * 0.85), paints[canvas_index * 2])
		_add_box(Vector3(0.12, 0.06, 0.018), Vector3(cx - 0.035, 1.12, front * 0.87), paints[canvas_index * 2 + 1])

	# Entrance and a bright gallery sign band.
	_add_box(Vector3(0.52, 1.05, 0.11), Vector3(w * 0.36, 0.91, front * 0.91), cream)
	_add_box(Vector3(0.40, 0.93, 0.06), Vector3(w * 0.36, 0.91, front * 0.96), glass)
	_add_box(Vector3(0.035, 0.26, 0.035), Vector3(w * 0.29, 0.91, front * 1.0), gold)
	_add_box(Vector3(w * 0.90, 0.22, 0.20), Vector3(0, 1.84, front * 0.97), purple)
	_add_box(Vector3(w * 0.84, 0.06, 0.22), Vector3(0, 1.97, front * 0.99), gold)
	# Individual vivid canopy panels read clearly at the mobile camera distance.
	_add_box(Vector3(w * 0.98, 0.10, 0.48), Vector3(0, 1.55, front * 1.08), plum)
	for stripe in range(8):
		var sx := -w * 0.4375 + float(stripe) * w * 0.125
		_add_box_rotated(Vector3(w * 0.12, 0.10, 0.45), Vector3(sx, 1.49, front * 1.12),
			paints[stripe % paints.size()], Vector3(deg_to_rad(-8.0), 0, 0))
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.11, 0.20, 0.10), Vector3(side * w * 0.43, 1.56, front * 1.02), plum)
		_add_emissive_box(Vector3(0.13, 0.17, 0.10), Vector3(side * w * 0.43, 1.42, front * 1.04), gold, 1.5)

	# Display racks on the side walls: paint tubes, brushes and rolled paper.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.07, 0.92, d * 0.40), Vector3(side * w * 0.47, 1.14, 0), plum)
		for item in range(5):
			var item_z := -d * 0.28 + float(item) * d * 0.14
			_add_box(Vector3(0.12, 0.42, 0.10), Vector3(side * w * 0.50, 1.10, item_z), paints[item])
			_add_box(Vector3(0.13, 0.045, 0.11), Vector3(side * w * 0.50, 1.33, item_z), cream)

	# Rooftop artist's easel and oversized colourful canvas are the store's silhouette landmark.
	_add_box(Vector3(w * 0.34, 0.12, d * 0.26), Vector3(-w * 0.25, body_h + 0.75, -d * 0.20), wood)
	_add_box_rotated(Vector3(0.11, 1.12, 0.12), Vector3(-w * 0.29, body_h + 1.20, -d * 0.20), wood, Vector3(0, 0, deg_to_rad(-8.0)))
	_add_box_rotated(Vector3(0.11, 1.12, 0.12), Vector3(-w * 0.10, body_h + 1.20, -d * 0.20), wood, Vector3(0, 0, deg_to_rad(8.0)))
	_add_box(Vector3(0.66, 0.78, 0.10), Vector3(-w * 0.20, body_h + 1.38, -d * 0.12), cream)
	_add_box(Vector3(0.54, 0.64, 0.045), Vector3(-w * 0.20, body_h + 1.39, -d * 0.055), paints[4])
	_add_box(Vector3(0.28, 0.22, 0.035), Vector3(-w * 0.25, body_h + 1.50, -d * 0.025), paints[0])
	_add_box(Vector3(0.20, 0.16, 0.035), Vector3(-w * 0.12, body_h + 1.25, -d * 0.025), paints[5])

	# Neat rooftop paint tins and stacked canvases.
	for tin in range(4):
		var tx := w * 0.12 + float(tin) * 0.20
		_add_box(Vector3(0.16, 0.24, 0.16), Vector3(tx, body_h + 0.82, -d * 0.18), paints[tin + 1])
		_add_box(Vector3(0.17, 0.035, 0.17), Vector3(tx, body_h + 0.96, -d * 0.18), cream)
	for canvas_stack in range(3):
		_add_box(Vector3(0.52, 0.07, 0.36), Vector3(w * 0.27, body_h + 0.78 + float(canvas_stack) * 0.08, d * 0.22), cream)
	# Roof vents and side glazing finish the massing.
	_add_box(Vector3(0.38, 0.26, 0.34), Vector3(w * 0.34, body_h + 0.78, -d * 0.38), purple)
	for vent in range(3):
		_add_box(Vector3(0.30, 0.025, 0.035), Vector3(w * 0.34, body_h + 0.70 + float(vent) * 0.065, -d * 0.20), plum)
	for floor in range(2):
		_add_box(Vector3(0.055, 0.52, d * 0.30), Vector3(w * 0.49, 1.25 + float(floor) * 0.72, 0), plum)
		_add_box(Vector3(0.07, 0.40, d * 0.25), Vector3(w * 0.51, 1.25 + float(floor) * 0.72, 0), teal_light)


func _add_emissive_box(size: Vector3, pos: Vector3, color: Color, energy: float = 1.0) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	instance.material_override = material
	instance.position = pos
	mesh_root.add_child(instance)

func _build_industrial(w: float, d: float, height: float, color: Color) -> void:
	# Industrial silhouette deliberately avoids retail glazing: ribbed cladding,
	# a large shutter, raised loading dock, clerestory, exhaust and roof machinery.
	var stage := clampi(upgrade_stage, 1, 6)
	var wall := Color(0.48, 0.53, 0.53).lerp(color, 0.18)
	var wall_shadow := wall.darkened(0.24)
	var wall_light := wall.lightened(0.16)
	var metal := Color(0.27, 0.33, 0.36)
	var metal_mid := Color(0.43, 0.49, 0.50)
	var metal_light := Color(0.69, 0.72, 0.69)
	var glass := Color(0.16, 0.31, 0.38)
	var safety := Color(0.83, 0.47, 0.16)
	var concrete := Color(0.43, 0.43, 0.40)
	var body_h := height
	var mass_scale := 0.90 + float(stage - 1) * 0.025
	_add_box(Vector3(w * 1.02, 0.34, d * 1.02), Vector3(0, 0.17, 0), concrete)
	_add_box(Vector3(w * 0.94, 0.09, d * 0.94), Vector3(0, 0.37, 0), metal_light.darkened(0.20))
	_add_box(Vector3(w * mass_scale, body_h, d * 0.90), Vector3(0, body_h * 0.5 + 0.40, 0), wall)
	_add_box(Vector3(w * mass_scale, body_h * 0.20, 0.055), Vector3(0, body_h * 0.12 + 0.41, d * 0.455), wall_shadow)
	var rib_count := maxi(5, int(w / (0.58 if stage < 3 else 0.42)))
	for rib in range(rib_count):
		var x := -w * 0.43 + float(rib) * (w * 0.86 / float(maxi(rib_count - 1, 1)))
		_add_box(Vector3(0.055, body_h * 0.94, 0.075), Vector3(x, body_h * 0.5 + 0.41, d * 0.465), metal_light.darkened(0.14))
		_add_box(Vector3(0.018, body_h * 0.90, 0.025), Vector3(x + 0.035, body_h * 0.5 + 0.41, d * 0.508), wall_light)
	var shutter_w := w * (0.38 if stage < 5 else 0.44)
	var shutter_h := body_h * 0.62
	_add_box(Vector3(shutter_w + 0.18, shutter_h + 0.18, 0.11), Vector3(-w * 0.20, shutter_h * 0.5 + 0.40, d * 0.46), safety.darkened(0.24))
	_add_box(Vector3(shutter_w, shutter_h, 0.07), Vector3(-w * 0.20, shutter_h * 0.5 + 0.40, d * 0.51), metal)
	for stripe in range(7):
		_add_box(Vector3(shutter_w * 0.92, 0.035, 0.035), Vector3(-w * 0.20, 0.40 + float(stripe) * shutter_h / 7.0, d * 0.555), metal_light.darkened(0.12))
	_add_box(Vector3(shutter_w * 1.16, 0.22, 0.62), Vector3(-w * 0.20, 0.40, d * 0.65), concrete)
	_add_box(Vector3(shutter_w * 1.12, 0.10, 0.16), Vector3(-w * 0.20, 0.54, d * 0.68), safety)
	_add_box(Vector3(0.52, 1.08, 0.10), Vector3(w * 0.32, 0.92, d * 0.46), metal)
	_add_box(Vector3(0.38, 0.90, 0.06), Vector3(w * 0.32, 0.92, d * 0.51), glass)
	var clerestory_count := 4 if stage < 3 else 6
	for bay in range(clerestory_count):
		var x := -w * 0.34 + float(bay) * w * 0.68 / float(clerestory_count - 1)
		_add_box(Vector3(w * 0.095, 0.34, 0.08), Vector3(x, body_h * 0.82, d * 0.465), metal_mid)
		_add_box(Vector3(w * 0.075, 0.24, 0.04), Vector3(x, body_h * 0.82, d * 0.49), glass)
	_add_box_rotated(Vector3(w * 0.54, 0.18, d * 0.98), Vector3(-w * 0.23, body_h + 0.42, 0), metal_mid, Vector3(0, 0, deg_to_rad(-8.0)))
	_add_box_rotated(Vector3(w * 0.54, 0.18, d * 0.98), Vector3(w * 0.23, body_h + 0.42, 0), metal_light, Vector3(0, 0, deg_to_rad(8.0)))
	_add_box(Vector3(w * 1.04, 0.12, 0.16), Vector3(0, body_h + 0.48, d * 0.48), metal)
	var stack_height := 1.35 + float(stage - 1) * 0.38
	_add_cylinder(0.16 + float(stage - 1) * 0.018, 0.23 + float(stage - 1) * 0.02, stack_height, Vector3(w * 0.31, body_h + stack_height * 0.5 + 0.48, -d * 0.28), metal)
	_add_cylinder(0.25 + float(stage - 1) * 0.02, 0.27 + float(stage - 1) * 0.02, 0.14, Vector3(w * 0.31, body_h + stack_height + 0.55, -d * 0.28), safety)
	if stage >= 3:
		_add_box(Vector3(w * 0.22, 0.42, d * 0.22), Vector3(-w * 0.28, body_h + 0.70, -d * 0.20), metal_mid)
		_add_cylinder(0.09, 0.12, 1.0, Vector3(-w * 0.28, body_h + 1.35, -d * 0.20), metal)
	if stage >= 5:
		for pipe_index in range(3):
			_add_cylinder(0.045, 0.055, d * 0.70, Vector3(w * (0.08 + float(pipe_index) * 0.12), body_h + 0.62, 0), safety if pipe_index == 0 else metal_light)
		_add_box(Vector3(w * 0.96, 0.18, d * 0.94), Vector3(0, body_h + 0.62, 0), wall_shadow)

	_build_industrial_identity(w, d, body_h, stage)


func _build_industrial_identity(w: float, d: float, body_h: float, stage: int) -> void:
	var tier := str(definition.get("factory_tier", building_type))
	var steel := Color(0.38, 0.47, 0.52)
	var cyan := Color(0.12, 0.66, 0.72)
	var yellow := Color(0.96, 0.62, 0.12)
	match tier:
		"small", "factory_small":
			_add_box(Vector3(w * 0.24, 0.74, d * 0.24), Vector3(w * 0.34, body_h + 0.48, -d * 0.24), steel)
			_add_cylinder(0.16, 0.22, 1.25, Vector3(-w * 0.30, body_h + 0.70, -d * 0.25), yellow)
		"basic", "factory_basic":
			for stack in range(2):
				_add_cylinder(0.13, 0.19, 1.8, Vector3(-w * 0.30 + float(stack) * w * 0.55, body_h + 0.96, -d * 0.30), steel)
			_add_box(Vector3(w * 0.76, 0.22, d * 0.16), Vector3(0, body_h + 0.58, d * 0.36), yellow)
		"mass", "factory_mass":
			_add_box(Vector3(w * 0.42, 1.05, d * 0.30), Vector3(-w * 0.30, body_h + 0.80, -d * 0.18), steel)
			_add_box(Vector3(0.12, 2.0, 0.12), Vector3(w * 0.34, body_h + 1.20, d * 0.20), yellow)
			_add_box(Vector3(w * 0.72, 0.14, 0.14), Vector3(w * 0.02, body_h + 2.08, d * 0.20), yellow)
			for pipe in range(3):
				_add_cylinder(0.06, 0.07, d * 0.70, Vector3(-w * 0.20 + float(pipe) * 0.20, body_h + 0.70, 0), steel)
		"hightech", "factory_hightech":
			_add_box(Vector3(w * 0.58, 1.10, d * 0.54), Vector3(0, body_h + 0.72, 0), Color(0.74,0.86,0.88))
			for bay in range(4):
				var x := -w * 0.30 + float(bay) * w * 0.20
				_add_box(Vector3(0.08, 0.92, d * 0.58), Vector3(x, body_h + 0.74, d * 0.04), cyan)
			_add_cylinder(0.24, 0.28, 0.32, Vector3(w * 0.32, body_h + 1.20, -d * 0.28), steel)
		"nano", "factory_nano":
			_add_box(Vector3(w * 0.72, 1.55, d * 0.70), Vector3(0, body_h + 0.92, 0), Color(0.78,0.88,0.91))
			_add_box(Vector3(w * 0.78, 0.16, d * 0.76), Vector3(0, body_h + 1.76, 0), cyan)
			for corner in [-1.0, 1.0]:
				_add_box(Vector3(0.10, 1.38, 0.10), Vector3(corner * w * 0.34, body_h + 0.90, d * 0.34), steel)
			_add_cylinder(0.30, 0.30, 0.24, Vector3(0, body_h + 1.94, -d * 0.20), cyan)
		_:
			_add_box(Vector3(w * 0.28, 0.72, d * 0.28), Vector3(0, body_h + 0.45, 0), steel)
	if stage >= 4:
		_add_box(Vector3(w * 0.86, 0.16, d * 0.72), Vector3(0, body_h + 0.56, -d * 0.08), Color(0.24,0.31,0.36))
		for skylight in range(3):
			_add_box(Vector3(0.42, 0.08, d * 0.28), Vector3(-w * 0.28 + float(skylight) * w * 0.28, body_h + 0.68, -d * 0.08), Color(0.25,0.58,0.68))


func _build_service(w: float, d: float, height: float, color: Color) -> void:
	var power = definition.get("power", 0)
	var water = definition.get("water", 0)
	if power > 0:
		_build_wind_turbine()
	elif water > 0:
		_add_cylinder(0.7, 0.7, 1.2, Vector3(0, 2.8, 0), color)
		_add_cylinder(0.15, 0.2, 2.2, Vector3(0, 1.3, 0), color.darkened(0.2))
		_add_box(Vector3(1.6, 0.15, 1.6), Vector3(0, 0.2, 0), color.darkened(0.3))
	else:
		_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)
		_add_box(Vector3(w * 0.95, 0.2, d * 0.95), Vector3(0, height + 0.35, 0), color.darkened(0.15))
		_add_box(Vector3(0.5, 0.9, 0.1), Vector3(0, 0.7, d * 0.45), color.darkened(0.35))

	_build_service_identity(w, d, height)


func _build_service_identity(w: float, d: float, height: float) -> void:
	var id := building_type
	var red := Color(0.82, 0.16, 0.12)
	var blue := Color(0.12, 0.30, 0.62)
	var white := Color(0.92, 0.94, 0.91)
	var front := d * 0.48
	match id:
		"power_wind", "power_wind_deluxe":
			if id == "power_wind_deluxe":
				_add_box(Vector3(w * 0.72, 0.22, d * 0.54), Vector3(0, 0.24, 0), Color(0.34, 0.48, 0.54))
				_add_box(Vector3(w * 0.46, 0.70, d * 0.34), Vector3(0, 0.70, -d * 0.06), Color(0.82, 0.88, 0.90))
		"fire_station_small", "fire_station", "fire_station_deluxe":
			_add_box(Vector3(w * 0.94, 0.18, d * 0.92), Vector3(0, height + 0.38, 0), red)
			for bay in range(2 if w < 4.0 else 4):
				var x := -w * 0.30 + float(bay) * w * 0.20
				_add_box(Vector3(0.54, 1.12, 0.08), Vector3(x, 0.94, front + 0.08), white)
				_add_box(Vector3(0.46, 0.92, 0.05), Vector3(x, 0.90, front + 0.13), red.darkened(0.30))
			_add_box(Vector3(0.34, 0.44, 0.34), Vector3(w * 0.36, height + 0.62, 0), white)
		"police_small", "police_station", "police_basic", "police_precinct":
			_add_box(Vector3(w * 0.96, 0.16, d * 0.94), Vector3(0, height + 0.36, 0), blue)
			_add_box(Vector3(w * 0.30, 0.72, 0.24), Vector3(0, height + 0.80, -d * 0.18), white)
			_add_box(Vector3(0.12, 1.15, 0.12), Vector3(0, height + 1.26, -d * 0.18), blue)
		"clinic_small", "clinic", "hospital":
			_add_box(Vector3(w * 0.98, 0.18, d * 0.94), Vector3(0, height + 0.38, 0), white)
			_add_box(Vector3(w * 0.36, 0.14, 0.10), Vector3(0, height + 0.72, front + 0.08), red)
			_add_box(Vector3(0.14, 0.42, 0.10), Vector3(0, height + 0.72, front + 0.09), red)
			if id == "hospital":
				_add_box(Vector3(w * 0.28, 1.15, d * 0.30), Vector3(-w * 0.32, height + 0.82, -d * 0.22), Color(0.76,0.86,0.88))
		"water_tower":
			_add_cylinder(0.42, 0.52, 0.20, Vector3(0, height + 0.30, 0), Color(0.20,0.52,0.78))
			_add_cylinder(0.34, 0.42, 0.86, Vector3(0, height - 0.16, 0), Color(0.50,0.58,0.62))
			for leg in [-1.0, 1.0]:
				_add_box(Vector3(0.08, 0.82, 0.08), Vector3(leg * 0.32, height - 0.20, 0), Color(0.50,0.58,0.62))
		"water_pump":
			_add_box(Vector3(w * 0.82, 0.22, d * 0.72), Vector3(0, height + 0.22, 0), Color(0.24,0.48,0.62))
			_add_box(Vector3(w * 0.56, 0.92, d * 0.42), Vector3(0, 0.76, -d * 0.10), Color(0.70,0.78,0.80))
			for pipe in [-1.0, 1.0]:
				_add_cylinder(0.07, 0.09, d * 0.82, Vector3(pipe * w * 0.30, 0.48, 0), Color(0.30,0.58,0.72))
		"sewage_small", "sewage_basic", "sewage_deluxe":
			for tank in range(2 if id == "sewage_small" else 3):
				_add_cylinder(0.42, 0.48, 0.72, Vector3(-w * 0.28 + float(tank) * w * 0.28, 0.72, -d * 0.16), Color(0.48,0.62,0.60))
			_add_box(Vector3(w * 0.88, 0.12, d * 0.16), Vector3(0, 1.18, front * 0.30), Color(0.30,0.44,0.42))
		"waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling":
			_add_box(Vector3(w * 0.88, 0.52, d * 0.62), Vector3(0, 0.60, -d * 0.10), Color(0.38,0.48,0.36))
			if id == "waste_incinerator":
				_add_cylinder(0.18, 0.24, 1.55, Vector3(w * 0.30, 1.30, -d * 0.28), Color(0.48,0.50,0.50))
			if id == "waste_recycling":
				_add_box(Vector3(w * 0.70, 0.18, 0.12), Vector3(0, 1.02, front), Color(0.12,0.58,0.34))
		"power_coal", "power_oil", "power_solar", "power_nuclear", "power_wind_deluxe":
			_add_box(Vector3(w * 0.88, 0.22, d * 0.84), Vector3(0, height + 0.38, 0), Color(0.36,0.48,0.52))
			if id == "power_solar":
				for row in range(2):
					for panel in range(3):
						_add_box_rotated(Vector3(0.48, 0.06, 0.34), Vector3(-w * 0.28 + float(panel) * 0.48, 0.72 + float(row) * 0.38, -d * 0.20), Color(0.08,0.22,0.40), Vector3(deg_to_rad(-18.0),0,0))
			elif id == "power_nuclear":
				for tower in [-1.0, 1.0]:
					_add_cylinder(0.34, 0.48, 1.90, Vector3(tower * w * 0.28, 1.30, -d * 0.20), white)
		"town_hall":
			_add_box(Vector3(w * 0.94, 0.22, d * 0.92), Vector3(0, height + 0.42, 0), Color(0.78,0.70,0.52))
			_add_box(Vector3(w * 0.28, 0.85, d * 0.24), Vector3(0, height + 0.92, -d * 0.12), Color(0.72,0.26,0.16))
			_add_box(Vector3(0.08, 1.15, 0.08), Vector3(0, height + 1.70, -d * 0.12), Color(0.88,0.78,0.42))
		_:
			pass


func _build_wind_turbine() -> void:
	# A tapered tubular mast and layered nacelle give the generator a readable
	# silhouette before the rotor begins its continuous, low-cost animation.
	_add_cylinder(0.105, 0.235, 5.25, Vector3(0, 2.72, 0), Color(0.82, 0.87, 0.90))
	_add_cylinder(0.31, 0.31, 0.22, Vector3(0, 0.16, 0), Color(0.34, 0.40, 0.44))
	_add_cylinder(0.17, 0.17, 0.12, Vector3(0, 5.32, 0), Color(0.66, 0.73, 0.77))
	_add_box(Vector3(0.88, 0.38, 0.42), Vector3(0, 5.48, -0.12), Color(0.90, 0.94, 0.96))
	_add_box(Vector3(0.56, 0.12, 0.48), Vector3(0, 5.72, -0.12), Color(0.67, 0.75, 0.79))

	var rotor := Node3D.new()
	rotor.name = "WindTurbineRotor"
	rotor.position = Vector3(0, 5.50, 0.24)
	mesh_root.add_child(rotor)
	_wind_turbine_rotor = rotor

	var hub := MeshInstance3D.new()
	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 0.25
	hub_mesh.height = 0.50
	hub.mesh = hub_mesh
	var hub_material := StandardMaterial3D.new()
	hub_material.albedo_color = Color(0.96, 0.98, 1.0)
	hub_material.metallic = 0.48
	hub_material.roughness = 0.26
	hub.material_override = hub_material
	rotor.add_child(hub)

	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.94, 0.97, 0.98)
	blade_material.metallic = 0.12
	blade_material.roughness = 0.38
	for blade_index in range(3):
		var blade_pivot := Node3D.new()
		blade_pivot.name = "Blade_%d" % blade_index
		blade_pivot.rotation.z = TAU * float(blade_index) / 3.0
		rotor.add_child(blade_pivot)
		# Three progressively narrower aerodynamic sections create a tapered blade.
		var sections := [
			{"size": Vector3(0.34, 0.82, 0.12), "y": 0.47},
			{"size": Vector3(0.25, 0.98, 0.095), "y": 1.30},
			{"size": Vector3(0.12, 0.92, 0.065), "y": 2.25}
		]
		for section in sections:
			var blade_section := MeshInstance3D.new()
			var blade_mesh := BoxMesh.new()
			blade_mesh.size = section["size"]
			blade_section.mesh = blade_mesh
			blade_section.material_override = blade_material
			blade_section.position.y = section["y"]
			blade_pivot.add_child(blade_section)
		# A slim leading-edge accent catches sunlight and makes rotation legible.
		var leading_edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.035, 2.58, 0.035)
		leading_edge.mesh = edge_mesh
		leading_edge.material_override = hub_material
		leading_edge.position = Vector3(-0.105, 1.48, 0.0)
		blade_pivot.add_child(leading_edge)

	# A small red aviation beacon and dark access hatch finish the mast.
	var beacon := MeshInstance3D.new()
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.075
	beacon_mesh.height = 0.15
	beacon.mesh = beacon_mesh
	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color(1.0, 0.18, 0.12)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(1.0, 0.08, 0.04)
	beacon_material.emission_energy_multiplier = 1.3
	beacon.material_override = beacon_material
	beacon.position = Vector3(0, 5.91, -0.12)
	mesh_root.add_child(beacon)
	_add_box(Vector3(0.22, 0.68, 0.035), Vector3(0, 1.05, 0.22), Color(0.25, 0.31, 0.35))


func _build_park(w: float, d: float, color: Color) -> void:
	# A pocket park has a paved entry, crossing path, planted beds, seating and
	# a small fountain; it is a miniature public space rather than a green cube.
	_add_box(Vector3(w * 0.98, 0.15, d * 0.98), Vector3(0, 0.10, 0), Color(0.26,0.48,0.30))
	_add_box(Vector3(w * 0.86, 0.06, 0.48), Vector3(0, 0.20, 0), Color(0.72,0.68,0.58))
	_add_box(Vector3(0.42, 0.065, d * 0.84), Vector3(0, 0.22, 0), Color(0.72,0.68,0.58))
	_add_cylinder(0.30, 0.36, 0.18, Vector3(0, 0.34, 0), Color(0.34,0.58,0.72))
	_add_cylinder(0.08, 0.10, 0.48, Vector3(0, 0.62, 0), Color(0.78,0.88,0.92))
	for bed in [-1.0, 1.0]:
		_add_box(Vector3(0.34, 0.16, 0.30), Vector3(bed * w * 0.34, 0.28, -d * 0.30), Color(0.36,0.25,0.16))
		_add_cylinder(0.13, 0.17, 0.48, Vector3(bed * w * 0.34, 0.58, -d * 0.30), Color(0.22,0.52,0.28))
		_add_cylinder(0.035, 0.035, 0.42, Vector3(bed * w * 0.34, 0.88, -d * 0.30), Color(0.42,0.28,0.16))
	for seat in [-1.0, 1.0]:
		_add_box(Vector3(0.62, 0.12, 0.20), Vector3(seat * w * 0.30, 0.44, d * 0.30), Color(0.48,0.27,0.14))
		_add_box(Vector3(0.62, 0.38, 0.08), Vector3(seat * w * 0.30, 0.66, d * 0.39), Color(0.48,0.27,0.14))

func _get_surface_variation_texture() -> Texture2D:
	# Shared subtle grayscale grain modulates every architectural surface, avoiding
	# perfectly flat plastic colors without allocating a texture per mesh.
	if _shared_surface_texture == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 731942
		for y in range(64):
			for x in range(64):
				var shade := rng.randf_range(0.88, 1.0)
				image.set_pixel(x, y, Color(shade, shade, shade))
		_shared_surface_texture = ImageTexture.create_from_image(image)
	return _shared_surface_texture

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = _get_surface_variation_texture()
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.roughness = 0.82
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
	material.albedo_texture = _get_surface_variation_texture()
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.roughness = 0.84
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
	if DisplayServer.get_name() == "headless" or not scaffold_root:
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

func _start_construction(saved_finish_unix: int = 0) -> void:
	if is_instance_valid(_construction_tween) and _construction_tween.is_running():
		_construction_tween.kill()
	var now := int(Time.get_unix_time_from_system())
	construction_finish_unix = saved_finish_unix if saved_finish_unix > 0 else now + maxi(1, int(ceil(build_time)))
	var remaining := maxi(0, construction_finish_unix - now)
	if remaining <= 0:
		_on_construction_finished()
		return
	if hard_hat:
		hard_hat.visible = true
	if mesh_root:
		mesh_root.visible = true
		mesh_root.scale = Vector3(1.0, 0.03, 1.0)
	if scaffold_root:
		scaffold_root.visible = true
		scaffold_root.scale = Vector3(1.0, 0.05, 1.0)

	# Timestamp is authoritative; the tween only animates the visible construction phases.
	var total_time := float(remaining)
	var scaffold_time := total_time * 0.30
	var building_time := total_time * 0.55
	var dismantle_time := total_time * 0.15
	_construction_tween = create_tween()
	_construction_tween.tween_property(scaffold_root, "scale:y", 1.0, scaffold_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_construction_tween.tween_property(mesh_root, "scale:y", 1.0, building_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_construction_tween.tween_property(scaffold_root, "scale:y", 0.01, dismantle_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _on_construction_finished() -> void:
	if _construction_initialized:
		return
	_construction_initialized = true
	status = "completed"
	construction_finish_unix = 0
	setup_production_from_definition()
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
	if definition.has("power"):
		ServiceManager.register_power(definition.power)
	if definition.has("water"):
		ServiceManager.register_water(definition.water)
	ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	if definition.get("happiness", 0) > 0:
		GameManager.set_happiness(min(100.0, GameManager.happiness + definition.happiness))

func setup_production_from_definition() -> void:
	if is_instance_valid(production_component) or not definition.has("production_slots"):
		return
	var component = ProductionComponentScript.new()
	component.slot_count = int(definition.get("production_slots", 1))
	component.owner_building = self
	component.is_factory = str(definition.get("category", "")) == "industrial"
	component.factory_type = building_type
	component.shop_id = str(definition.get("shop_id", "building_supplies" if building_type == "shop_chain" else building_type))
	production_component = component
	add_child(production_component)

func _play_completion_effect() -> void:
	if DisplayServer.get_name() == "headless":
		return
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
	production_finish_unix = int(Time.get_unix_time_from_system()) + int(ceil(production_time))
	has_ready_product = false
	if production_icon:
		production_icon.visible = true
		production_icon.text = "⚙️"

func start_factory_production(item_id: String = "") -> bool:
	if not BuildManager.is_building_operational(self):
		return false
	if status != "completed":
		return false
	if is_producing or has_ready_product:
		return false
	var product := item_id
	if product == "":
		product = str(definition.get("produces", ProductionManager.get_default_factory_product()))
	if product == "" or definition.get("category", "") != "industrial":
		return false
	if not ProductionManager.get_factory_material_ids(building_type).has(product) or not ProductionManager.raw_materials.has(product):
		return false
	if int(ProductionManager.raw_materials[product].get("level", 1)) > GameManager.level:
		return false
	_start_production(product)
	return true

func start_commercial_production(item_id: String) -> bool:
	if not BuildManager.is_building_operational(self):
		return false
	if status != "completed" or definition.get("category", "") != "commercial":
		return false
	if is_producing or has_ready_product or item_id == "":
		return false
	var shop_id := str(definition.get("shop_id", "building_supplies" if building_type == "shop_chain" else building_type))
	if not ProductionManager.get_store_recipe_ids(shop_id).has(item_id) or not ProductionManager.can_craft(item_id):
		return false
	if not ProductionManager.consume_inputs(item_id):
		return false
	_start_production(item_id)
	return true

func set_fire_smoke(active: bool) -> void:
	if active:
		if DisplayServer.get_name() == "headless":
			return
		if status != "completed" or str(definition.get("category", "")) != "residential":
			return
		if _fire_smoke == null:
			_fire_smoke = _create_fire_smoke_particles()
			add_child(_fire_smoke)
			_fire_smoke.position = Vector3(0.0, _get_fire_smoke_anchor_height(), 0.0)
		_fire_smoke.emitting = true
	elif is_instance_valid(_fire_smoke):
		_fire_smoke.emitting = false

func _get_fire_smoke_anchor_height() -> float:
	var subtype := str(definition.get("subtype", ""))
	var height := 3.55 + float(maxi(upgrade_stage - 1, 0)) * 0.30
	if subtype == "apartment":
		height = 5.05 + float(maxi(upgrade_stage - 1, 0)) * 0.25
	elif subtype == "farm":
		height = 2.75
	return height

func _create_fire_smoke_particles() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "FireHazardBlackSmoke"
	particles.amount = 52
	particles.lifetime = 3.6
	particles.preprocess = 0.8
	particles.explosiveness = 0.0
	particles.randomness = 0.35
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.22
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 20.0
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 0.85
	particles.gravity = Vector3(0.0, -0.42, 0.0)
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.15
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-3.5, -1.0, -3.5), Vector3(7.0, 10.0, 7.0))

	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.95, 0.95)
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_color = Color(0.075, 0.075, 0.085, 0.72)
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke_mesh.material = smoke_material
	particles.mesh = smoke_mesh

	var color_gradient := Gradient.new()
	color_gradient.add_point(0.0, Color(0.055, 0.055, 0.065, 0.48))
	color_gradient.add_point(0.22, Color(0.075, 0.075, 0.085, 0.76))
	color_gradient.add_point(0.72, Color(0.105, 0.105, 0.115, 0.58))
	color_gradient.add_point(1.0, Color(0.12, 0.12, 0.13, 0.0))
	particles.color_ramp = color_gradient

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.42))
	scale_curve.add_point(Vector2(0.35, 0.82))
	scale_curve.add_point(Vector2(1.0, 1.55))
	particles.scale_amount_curve = scale_curve
	return particles

func _process(delta: float) -> void:
	if status == "constructing" and construction_finish_unix > 0 and int(Time.get_unix_time_from_system()) >= construction_finish_unix:
		_on_construction_finished()
	if status == "completed" and is_instance_valid(_wind_turbine_rotor):
		_wind_turbine_rotor.rotation.z = wrapf(
			_wind_turbine_rotor.rotation.z + WIND_TURBINE_SPIN_RADIANS_PER_SECOND * delta,
			0.0, TAU
		)
	if is_producing and status == "completed" and not has_ready_product:
		# Unix time makes production progress survive app/browser closure and reload.
		production_timer = maxf(0.0, float(production_finish_unix - int(Time.get_unix_time_from_system())))
		if int(Time.get_unix_time_from_system()) >= production_finish_unix:
			production_timer = 0.0
			has_ready_product = true
			if production_icon:
				production_icon.text = "✅"
			production_ready.emit(current_product)
	if upgrade_in_progress and upgrade_finish_unix > 0 and int(Time.get_unix_time_from_system()) >= upgrade_finish_unix:
		_finish_residential_upgrade()
	if definition.get("category") == "residential" and status == "completed" and upgrade_stage < max_stage:
		_check_upgrade_ready()

func _check_upgrade_ready() -> void:
	if not BuildManager.is_building_operational(self):
		upgrade_ready = false
		if hard_hat: hard_hat.visible = false
		return
	if upgrade_stage >= max_stage or upgrade_in_progress:
		upgrade_ready = false
		if hard_hat: hard_hat.visible = false
		return
	upgrade_ready = ProductionManager.can_afford_upgrade(upgrade_stage)
	# Show the blue plan marker only while this home's upgrade plan is selected.
	if hard_hat:
		hard_hat.visible = residential_plan_selected and status == "completed" and upgrade_stage < max_stage and not upgrade_in_progress

func set_residential_plan_selected(selected: bool) -> void:
	residential_plan_selected = selected
	if hard_hat:
		hard_hat.visible = selected and status == "completed" and upgrade_stage < max_stage and not upgrade_in_progress

func try_upgrade() -> bool:
	if not BuildManager.is_building_operational(self):
		return false
	if definition.get("category") != "residential" or status != "completed" or upgrade_stage >= max_stage or upgrade_in_progress:
		return false
	if not ProductionManager.can_afford_upgrade(upgrade_stage):
		print("[Building] Need materials for upgrade to stage ", upgrade_stage + 1)
		return false
	if not ProductionManager.consume_upgrade_materials(upgrade_stage):
		return false
	upgrade_in_progress = true
	upgrade_finish_unix = int(Time.get_unix_time_from_system()) + RESIDENTIAL_UPGRADE_DURATION_SECONDS
	upgrade_ready = false
	if hard_hat: hard_hat.visible = false
	_start_residential_upgrade_animation()
	return true

func _start_residential_upgrade_animation() -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(scaffold_root):
		return
	if is_instance_valid(_upgrade_tween) and _upgrade_tween.is_running():
		_upgrade_tween.kill()
	scaffold_root.visible = true
	scaffold_root.scale = Vector3(1.0, 0.01, 1.0)
	_upgrade_tween = create_tween()
	_upgrade_tween.tween_property(scaffold_root, "scale", Vector3.ONE, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _finish_residential_upgrade() -> void:
	if not upgrade_in_progress:
		return
	var old_population := current_population
	upgrade_stage = mini(upgrade_stage + 1, max_stage)
	# Population never drops during an upgrade; new residents are added only
	# when the short scaffold phase has completed.
	current_population = maxi(old_population, ProductionManager.get_population_for_stage(upgrade_stage))
	var gained := current_population - old_population
	upgrade_in_progress = false
	upgrade_finish_unix = 0
	if is_instance_valid(scaffold_root):
		scaffold_root.visible = false
		scaffold_root.scale = Vector3.ONE
	_create_visual()
	_update_stage_label()
	_play_completion_effect()
	GameManager.add_population(gained)
	GameManager.add_experience(gained + 10)
	EconomyManager.add_simoleons(50 * upgrade_stage)
	_check_upgrade_ready()
	upgraded.emit(upgrade_stage)
	ServiceManager.recalculate_from_buildings()

func get_upgrade_remaining_seconds() -> int:
	if not upgrade_in_progress:
		return 0
	return maxi(0, upgrade_finish_unix - int(Time.get_unix_time_from_system()))

func collect_production() -> bool:
	if not has_ready_product:
		return false
	if not StorageManager.add_item(current_product, 1):
		if production_icon:
			production_icon.text = "📦!"
		return false

	var collected_item := current_product
	has_ready_product = false
	production_timer = 0.0
	production_finish_unix = 0
	collected.emit(collected_item, 1)
	ProductionManager.item_produced.emit(collected_item, 1)
	GameManager.add_experience(2)

	# Both factories and commercial shops become idle after collection.
	# The player explicitly chooses the next raw material or craft order.
	is_producing = false
	if production_icon:
		production_icon.visible = false
	return true

func _update_stage_label() -> void:
	# Floating level text clashes with the city view. Keep the level in the
	# building information panel, not as a permanent label above every roof.
	if stage_label:
		stage_label.visible = false
		stage_label.text = ""

func get_info() -> String:
	var info = definition.get("name", "Building")
	if definition.get("category") == "residential":
		info += " [Lv%d/6] Population:%d" % [upgrade_stage, current_population]
		if upgrade_in_progress:
			info += " — UPGRADING %ds" % get_upgrade_remaining_seconds()
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
			info += " - Ready: " + str(ProductionManager.raw_materials.get(current_product, ProductionManager.crafted_items.get(current_product, {})).get("name", current_product))
		else:
			production_timer = maxf(0.0, float(production_finish_unix - int(Time.get_unix_time_from_system())))
			info += " - %.0fs" % production_timer
	return info

func restore_production_state(saved: Dictionary) -> void:
	if status == "constructing":
		var saved_construction_finish := int(saved.get("construction_finish_unix", 0))
		if saved_construction_finish > 0:
			_start_construction(saved_construction_finish)
	if is_instance_valid(production_component):
		production_component.store_star_level = clampi(int(saved.get("store_star_level", 0)), 0, 3)
		if saved.get("slots", []) is Array:
			production_component.from_save_array(saved.get("slots", []))
	upgrade_in_progress = bool(saved.get("upgrade_in_progress", false))
	upgrade_finish_unix = int(saved.get("upgrade_finish_unix", 0))
	if upgrade_in_progress:
		# Let SaveManager restore the saved resident count before _process()
		# completes an expired upgrade on the next frame.
		if upgrade_finish_unix <= int(Time.get_unix_time_from_system()):
			upgrade_finish_unix = int(Time.get_unix_time_from_system())
		if is_instance_valid(scaffold_root):
			scaffold_root.visible = true
			scaffold_root.scale = Vector3.ONE
	current_product = str(saved.get("current_product", ""))
	is_producing = bool(saved.get("is_producing", false)) and not current_product.is_empty()
	has_ready_product = bool(saved.get("has_ready_product", false))
	production_finish_unix = int(saved.get("production_finish_unix", 0))
	production_time = production_component.get_item_production_time(current_product) if not current_product.is_empty() and is_instance_valid(production_component) else (ProductionManager.get_production_time(current_product) if not current_product.is_empty() else 0.0)
	if is_producing and not has_ready_product:
		production_timer = maxf(0.0, float(production_finish_unix - int(Time.get_unix_time_from_system())))
		if production_finish_unix <= int(Time.get_unix_time_from_system()):
			has_ready_product = true
			production_timer = 0.0
	if production_icon:
		production_icon.visible = is_producing
		production_icon.text = "✅" if has_ready_product else "⚙️"
