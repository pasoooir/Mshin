extends CanvasLayer

const Icons = preload("res://scripts/ui/Icons.gd")
const MAX_VISIBLE_BUBBLES := 3
const BUBBLE_SHOW_SECONDS := 5.5
const BUBBLE_HIDE_SECONDS := 2.5
const BUBBLE_POP_DURATION := 0.24
const BUBBLE_FADE_DURATION := 0.18
const BUBBLE_BOB_AMPLITUDE := 3.0
const CITIZEN_DIALOGUE := {
	"road": ["We need a road!", "Road access, please!"],
	"power": ["Our lights are out!", "Please connect power!"],
	"water": ["We need clean water!", "No water at home!"],
	"sewage": ["Please fix our drains!", "Sewage service needed!"],
	"waste": ["Our bins are full!", "Please collect waste!"],
	"fire": ["We need fire cover!", "A fire station nearby?"],
	"police": ["We need police nearby!", "Safety needs a boost!"],
	"health": ["A clinic would help!", "We need healthcare!"],
	"happiness": ["Make our city happier!", "We need more city services!"],
	"happy": ["We love this neighborhood!", "Life is good here!"]
}

var _overlay: Control
var _active_bubbles: Array[Dictionary] = []
var _showing := false
var _elapsed := 0.0
var _priority_offsets: Dictionary = {}
var _dialogue_cycle := 0

func _ready() -> void:
	layer = 90
	if DisplayServer.get_name() == "headless":
		return
	_overlay = Control.new()
	_overlay.name = "CitizenFeedbackOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _process(delta: float) -> void:
	if not is_instance_valid(_overlay):
		return
	_elapsed += delta
	if _showing:
		_update_bubble_positions()
		if _elapsed >= BUBBLE_SHOW_SECONDS:
			_clear_bubbles()
			_showing = false
			_elapsed = 0.0
	elif _elapsed >= BUBBLE_HIDE_SECONDS:
		_spawn_feedback_bubbles()
		_showing = not _active_bubbles.is_empty()
		_elapsed = 0.0

func get_feedback_for_home(home: Node3D) -> Dictionary:
	if not is_instance_valid(home) or str(home.get("status")) != "completed":
		return {}
	var definition: Dictionary = home.get("definition")
	if str(definition.get("category", "")) != "residential":
		return {}
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	var grid_pos: Vector2i = home.get("grid_pos")
	var home_id := str(home.get("building_id"))
	if not BuildManager.has_road_access(grid_pos, size):
		return _feedback("road", "Road access needed", "road", 0)
	if HappinessManager._service_group_is_unlocked("power") and not ServiceManager.power_served_ids.has(home_id):
		return _feedback("power", "We need power", "power", 1)
	if HappinessManager._service_group_is_unlocked("water") and not ServiceManager.water_served_ids.has(home_id):
		return _feedback("water", "We need water", "water", 2)
	if HappinessManager._service_group_is_unlocked("sewage") and not ServiceManager.sewage_served_ids.has(home_id):
		return _feedback("sewage", "Sewage service needed", "sewage", 3)
	if HappinessManager._service_group_is_unlocked("waste") and not ServiceManager.waste_served_ids.has(home_id):
		return _feedback("waste", "Please collect waste", "waste", 4)
	if HappinessManager._service_group_is_unlocked("fire") and not HappinessManager._nearby_service_group(home, "fire", 38.0):
		return _feedback("fire", "We need fire cover", "fire", 5)
	if HappinessManager._service_group_is_unlocked("police") and not HappinessManager._nearby_service_group(home, "police", 38.0):
		return _feedback("police", "We need police cover", "police", 6)
	if HappinessManager._service_group_is_unlocked("health") and not HappinessManager._nearby_service_group(home, "health", 42.0):
		return _feedback("health", "We need healthcare", "health", 7)
	var happiness := HappinessManager.get_home_happiness(home_id)
	if happiness < 75.0:
		return _feedback("happiness", "Please improve our city", "happiness", 8)
	return _feedback("happy", "We're happy here!", "happiness", 20)

func _feedback(kind: String, message: String, icon_id: String, priority: int) -> Dictionary:
	return {"kind": kind, "message": message, "icon": icon_id, "priority": priority}


func _select_feedback_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	# Keep urgent issue categories first, but rotate homes within each priority
	# tier so the same first three dictionary entries do not monopolize bubbles.
	var grouped: Dictionary = {}
	for candidate in candidates:
		var feedback: Dictionary = candidate.get("feedback", {})
		var priority := int(feedback.get("priority", 99))
		if not grouped.has(priority):
			grouped[priority] = []
		var group: Array = grouped[priority]
		group.append(candidate)
		grouped[priority] = group
	var priorities: Array = grouped.keys()
	priorities.sort()
	var selected: Array[Dictionary] = []
	for priority_value in priorities:
		var priority := int(priority_value)
		var group: Array = grouped[priority]
		if group.is_empty():
			continue
		var offset := posmod(int(_priority_offsets.get(priority, 0)), group.size())
		var count := mini(MAX_VISIBLE_BUBBLES - selected.size(), group.size())
		for index in range(count):
			selected.append(group[(offset + index) % group.size()])
		_priority_offsets[priority] = (offset + count) % group.size()
		if selected.size() >= MAX_VISIBLE_BUBBLES:
			break
	return selected

func _spawn_feedback_bubbles() -> void:
	_clear_bubbles()
	var candidates: Array[Dictionary] = []
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		var feedback := get_feedback_for_home(building)
		if feedback.is_empty():
			continue
		candidates.append({"building": building, "feedback": feedback})
	if candidates.is_empty():
		return
	var selected := _select_feedback_candidates(candidates)
	_dialogue_cycle += 1
	for entry in selected:
		var building: Node3D = entry.building
		var feedback: Dictionary = entry.feedback
		var bubble := _create_bubble(building, feedback)
		_overlay.add_child(bubble)
		_animate_bubble_in(bubble)
		_active_bubbles.append({"building": building, "control": bubble})

func _create_bubble(building: Node3D, feedback: Dictionary) -> Button:
	var bubble := Button.new()
	bubble.name = "CitizenBubble_" + str(building.get("building_id"))
	bubble.custom_minimum_size = Vector2(174.0, 52.0)
	bubble.focus_mode = Control.FOCUS_NONE
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.tooltip_text = "Tap to inspect this home"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F7FCFF")
	style.border_color = Color("#B8D7E7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.02, 0.10, 0.16, 0.28)
	style.shadow_size = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	bubble.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#FFFFFF")
	bubble.add_theme_stylebox_override("hover", hover)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(row)
	var icon_id := str(feedback.get("icon", "happiness"))
	row.add_child(Icons.make_icon(icon_id, Vector2(30, 30)))
	var label := Label.new()
	label.text = get_citizen_line(str(feedback.get("kind", "happiness")), str(building.get("building_id")), _dialogue_cycle)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#274354"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	bubble.pressed.connect(_on_bubble_pressed.bind(str(building.get("building_id"))))
	return bubble

func _update_bubble_positions() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for index in range(_active_bubbles.size()):
		var entry: Dictionary = _active_bubbles[index]
		var building = entry.get("building")
		var bubble := entry.get("control") as Control
		if not is_instance_valid(building) or not is_instance_valid(bubble):
			if is_instance_valid(bubble):
				bubble.hide()
			continue
		var world_position: Vector3 = building.global_position + Vector3(0.0, 6.5 + float(building.get("upgrade_stage")) * 0.35, 0.0)
		if camera.is_position_behind(world_position):
			bubble.hide()
			continue
		var screen_position := camera.unproject_position(world_position)
		var bubble_size := bubble.custom_minimum_size
		var x := clampf(screen_position.x - bubble_size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - bubble_size.x - 8.0))
		var bob := sin(_elapsed * 3.0 + float(index) * 0.85) * BUBBLE_BOB_AMPLITUDE
		var y := clampf(screen_position.y - bubble_size.y - float(index) * 9.0 + bob, 8.0, maxf(8.0, viewport_size.y - bubble_size.y - 8.0))
		bubble.position = Vector2(x, y)
		bubble.size = bubble_size
		bubble.show()

func _on_bubble_pressed(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building):
		return
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.has_method("open_residential_panel"):
		hud.open_residential_panel(building)
	_clear_bubbles()
	_showing = false
	_elapsed = 0.0

func get_citizen_line(kind: String, building_id: String, cycle_index: int = 0) -> String:
	var lines: Array = CITIZEN_DIALOGUE.get(kind, CITIZEN_DIALOGUE["happiness"])
	if lines.is_empty():
		return "Citizens have feedback"
	var line_index := posmod(absi(hash(building_id)) + maxi(cycle_index, 0), lines.size())
	return str(lines[line_index])

func _animate_bubble_in(bubble: Control) -> void:
	bubble.pivot_offset = bubble.custom_minimum_size * 0.5
	bubble.scale = Vector2(0.84, 0.84)
	bubble.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := bubble.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "modulate:a", 1.0, BUBBLE_POP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector2.ONE, BUBBLE_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_bubble_out(bubble: Control) -> void:
	if bubble.is_queued_for_deletion() or bubble.has_meta("fading_out"):
		return
	bubble.set_meta("fading_out", true)
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "modulate:a", 0.0, BUBBLE_FADE_DURATION)
	tween.parallel().tween_property(bubble, "scale", Vector2(0.92, 0.92), BUBBLE_FADE_DURATION)
	tween.tween_callback(Callable(bubble, "queue_free"))

func _clear_bubbles() -> void:
	for entry in _active_bubbles:
		var bubble = entry.get("control")
		if is_instance_valid(bubble):
			_animate_bubble_out(bubble)
	_active_bubbles.clear()
