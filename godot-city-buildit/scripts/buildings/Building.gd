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
	var w = size.x * 1.7
	var d = size.y * 1.7
	_add_box(Vector3(w + 0.15, 0.25, d + 0.15), Vector3(0, 0.12, 0), color.darkened(0.35))
	var height_mult = 1.0
	if category == "residential":
		height_mult = 0.7 + upgrade_stage * 0.15
	var height := 1.6 * height_mult
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
	_add_box(Vector3(w * 0.88, height, d * 0.88), Vector3(0, height * 0.5 + 0.25, 0), color)
	_add_box(Vector3(w * 1.0, 0.22, d * 1.0), Vector3(0, height + 0.4, 0), color.darkened(0.22))
	var window_col = Color(0.7, 0.85, 1.0)
	_add_box(Vector3(0.35, 0.4, 0.08), Vector3(-w * 0.25, height * 0.5, d * 0.44), window_col)
	_add_box(Vector3(0.35, 0.4, 0.08), Vector3(w * 0.25, height * 0.5, d * 0.44), window_col)
	if upgrade_stage >= 3:
		_add_box(Vector3(0.3, 0.35, 0.08), Vector3(-w * 0.25, height * 0.75, d * 0.44), window_col)
		_add_box(Vector3(0.3, 0.35, 0.08), Vector3(w * 0.25, height * 0.75, d * 0.44), window_col)
	_add_box(Vector3(0.4, 0.65, 0.08), Vector3(0, 0.55, d * 0.44), color.darkened(0.4))
	if upgrade_stage >= 4:
		_add_box(Vector3(w * 0.5, 0.3, 0.4), Vector3(0, height * 0.6, -d * 0.35), color.lightened(0.1))

func _build_commercial(w: float, d: float, height: float, color: Color) -> void:
	_add_box(Vector3(w * 0.9, height, d * 0.9), Vector3(0, height * 0.5 + 0.25, 0), color)
	_add_box(Vector3(w * 0.95, 0.18, d * 0.95), Vector3(0, height + 0.35, 0), color.lightened(0.1))
	_add_box(Vector3(w * 0.6, height * 0.55, 0.1), Vector3(0, height * 0.45, d * 0.45), Color(0.6, 0.8, 1.0))
	_add_box(Vector3(w * 0.5, 0.25, 0.12), Vector3(0, height * 0.85, d * 0.46), Color(0.95, 0.4, 0.3))

func _build_industrial(w: float, d: float, height: float, color: Color) -> void:
	_add_box(Vector3(w * 0.92, height, d * 0.92), Vector3(0, height * 0.5 + 0.25, 0), color)
	_add_box(Vector3(w * 1.0, 0.2, d * 1.0), Vector3(0, height + 0.35, 0), color.darkened(0.2))
	_add_cylinder(0.22, 0.18, 1.8, Vector3(w * 0.28, height + 1.2, d * 0.28), Color(0.4, 0.4, 0.45))
	_add_box(Vector3(0.15, 0.15, d * 0.6), Vector3(-w * 0.4, height * 0.7, 0), Color(0.5, 0.5, 0.55))

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
	material.roughness = 0.75
	mesh_instance.material_override = material
	mesh_instance.position = pos
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

func _start_construction() -> void:
	if hard_hat: hard_hat.visible = true
	mesh_root.scale = Vector3(1, 0.05, 1)
	var tween = create_tween()
	tween.tween_property(mesh_root, "scale:y", 1.0, build_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_on_construction_finished)

func _on_construction_finished() -> void:
	status = "completed"
	if hard_hat: hard_hat.visible = false
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
