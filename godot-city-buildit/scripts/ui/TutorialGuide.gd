extends CanvasLayer
## Clear, mobile-first onboarding for the first city-building loop.
## Milestones are completed only by real gameplay events; this guide never
## grants items or mutates city state.

var save_path := "user://tutorial_progress.cfg"
var _profile_progress_loaded := false
const STEP_DATA: Array[Dictionary] = [
	{
		"id": "city_name",
		"title": "Name your city",
		"description": "Type your city name in the field below, then tap SAVE CITY. The moving finger points directly to the field.",
		"hint": "👆 TAP THE FIELD  →  Enter a name  →  SAVE CITY",
		"result": "YOU SHOULD SEE  Your city name is saved with your city."
	},
	{
		"id": "home",
		"target": "Tool_Residential",
		"title": "Build your first home",
		"description": "Open Residential, choose Villa House, then tap BUILD in its information card. The finger will then point to a valid empty plot beside a road.",
		"hint": "TAP PATH  Residential  →  Small House  →  Empty plot",
		"result": "YOU SHOULD SEE  A house construction site appear on the selected plot."
	},
	{
		"id": "factory",
		"target": "Tool_Industrial",
		"title": "Build a factory",
		"description": "Tap Industrial, choose Small Factory, then tap BUILD in its information card. Follow the finger to a valid empty plot beside a connected road.",
		"hint": "👆 TAP  Industrial  →  Small Factory  →  BUILD  →  Highlighted plot",
		"result": "YOU SHOULD SEE  Your factory appear and begin its construction timer."
	},
	{
		"id": "raw",
		"target": "ProductionProductCards",
		"title": "Make and collect Metal",
		"description": "Tap the completed factory. Tap the Metal product card once to place an order in the first empty production slot. Wait for the countdown, then collect the ready Metal.",
		"hint": "TAP IN ORDER  Factory  →  Metal card  →  Wait  →  Collect",
		"result": "YOU SHOULD SEE  Metal in a queue slot, a seconds countdown, then Metal added to City Storage after Collect."
	},
	{
		"id": "store",
		"target": "Tool_Commercial",
		"title": "Build a supply store",
		"description": "Tap Commercial, choose Building Supplies, then tap BUILD in its information card. Follow the finger to a valid empty plot beside a connected road.",
		"hint": "👆 TAP  Commercial  →  Building Supplies  →  BUILD  →  Highlighted plot",
		"result": "YOU SHOULD SEE  The store finish construction and become selectable."
	},
	{
		"id": "crafted",
		"target": "ProductionProductCards",
		"title": "Craft and collect a product",
		"description": "Tap the Building Supplies store. Choose a product whose ingredients are available in City Storage. Wait for its timer, then collect it.",
		"hint": "TAP IN ORDER  Building Supplies  →  Available product  →  Wait  →  Collect",
		"result": "YOU SHOULD SEE  The product added to City Storage. Products with missing ingredients stay unavailable."
	},
	{
		"id": "upgrade",
		"target": "ResidentialUpgradeButton",
		"title": "Upgrade your home",
		"description": "Select your completed home. Review the required materials, then deliver them to start the next construction stage.",
		"hint": "TAP IN ORDER  Select home  →  Review materials  →  Deliver",
		"result": "YOU SHOULD SEE  The home enter construction and its upgrade stage advance when complete."
	}
]

var milestones: Dictionary = {
	"city_name": false,
	"home": false,
	"factory": false,
	"raw": false,
	"store": false,
	"crafted": false,
	"upgrade": false
}
var current_step := 0
var completed := false
var tutorial_enabled := true
var _panel: PanelContainer
var _title: Label
var _description: Label
var _hint: Label
var _result: Label
var _progress: ProgressBar
var _counter: Label
var _icon_legend: Label
var _skip_button: Button
var _later_button: Button
var _dismissed := false
var _city_name_input: LineEdit
var _city_name_row: HBoxContainer
var _city_name_button: Button
var _finger_pointer: Label
var _finger_elapsed := 0.0
var _state_poll_elapsed := 0.0

func _ready() -> void:
	if not tutorial_enabled:
		return
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_initialize_after_city_restore")

func _initialize_after_city_restore() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_load_progress()
	_connect_gameplay_events()
	_sync_existing_city_state()
	_build_guide_panel()
	if completed:
		_show_completion()
	else:
		_refresh_guide()

func _connect_gameplay_events() -> void:
	if not BuildManager.building_placed.is_connected(_on_building_placed):
		BuildManager.building_placed.connect(_on_building_placed)
	if not ProductionManager.item_produced.is_connected(_on_item_produced):
		ProductionManager.item_produced.connect(_on_item_produced)

func _sync_existing_city_state() -> void:
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		var type_id := str(building.get("building_type"))
		if type_id.is_empty():
			type_id = str(building.get("type"))
		var definition: Dictionary = building.get("definition") if building.get("definition") is Dictionary else {}
		var category := str(definition.get("category", BuildManager.building_types.get(type_id, {}).get("category", "")))
		if category == "residential":
			milestones["home"] = true
			if int(building.get("upgrade_stage")) >= 2:
				milestones["upgrade"] = true
		elif category == "industrial":
			milestones["factory"] = true
		elif category == "commercial":
			milestones["store"] = true
	for item_id in StorageManager.items:
		if int(StorageManager.items.get(item_id, 0)) <= 0:
			continue
		if ProductionManager.raw_materials.has(item_id):
			milestones["raw"] = true
		if ProductionManager.crafted_items.has(item_id):
			milestones["crafted"] = true
	if not GameManager.city_name.strip_edges().is_empty():
		milestones["city_name"] = true
	_advance_completed_steps()

func _on_building_placed(building_data: Dictionary) -> void:
	var type_id := str(building_data.get("type", ""))
	var category := str(BuildManager.building_types.get(type_id, {}).get("category", ""))
	if category == "residential":
		milestones["home"] = true
	elif category == "industrial":
		milestones["factory"] = true
	elif category == "commercial":
		milestones["store"] = true
	_advance_completed_steps()

func _on_item_produced(item_id: String, _amount: int) -> void:
	if ProductionManager.raw_materials.has(item_id):
		milestones["raw"] = true
	elif ProductionManager.crafted_items.has(item_id):
		milestones["crafted"] = true
	_advance_completed_steps()

func _process(delta: float) -> void:
	if completed or _dismissed:
		return
	_state_poll_elapsed += delta
	if _state_poll_elapsed >= 1.0:
		_state_poll_elapsed = 0.0
		# Recover if gameplay events fired before the guide connected.
		_sync_existing_city_state()
		_advance_completed_steps()
	if not is_instance_valid(_panel):
		return
	_finger_elapsed += delta
	if is_instance_valid(_finger_pointer) and _finger_pointer.visible:
		# A gentle compress/release makes the hand read as a tap, not a static icon.
		var tap_phase := fposmod(_finger_elapsed, 1.15)
		var tap_scale := 0.86 if tap_phase >= 0.42 and tap_phase <= 0.58 else 1.0
		_finger_pointer.scale = Vector2.ONE * tap_scale
	_update_finger_pointer()
	if bool(milestones.get("home", false)) and not bool(milestones.get("upgrade", false)):
		for building in BuildManager.buildings.values():
			if not is_instance_valid(building):
				continue
			var type_id := str(building.get("building_type"))
			if str(BuildManager.building_types.get(type_id, {}).get("category", "")) == "residential" and int(building.get("upgrade_stage")) >= 2:
				milestones["upgrade"] = true
				_advance_completed_steps()
				break

func _build_guide_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FirstCityTutorial"
	_panel.z_index = 110
	# This full-screen shell is visual only. IGNORE removes it from GUI hit-testing
	# without disabling child controls; its LineEdit and Buttons keep their own filters.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 10)
	_panel.add_child(layout)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)
	var eyebrow := Label.new()
	eyebrow.text = "☁ CITY COACH  •  YOUR NEXT TASK"
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_theme_color_override("font_color", Color("#8AD7F5"))
	eyebrow.add_theme_font_size_override("font_size", 15)
	header.add_child(eyebrow)

	_counter = Label.new()
	_counter.add_theme_color_override("font_color", Color("#F5FAFF"))
	_counter.add_theme_font_size_override("font_size", 17)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_counter)

	_icon_legend = Label.new()
	_icon_legend.text = "🛣 Roads    🏠 Homes    🏭 Factory    🛒 Shops    📦 Storage"
	_icon_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_icon_legend.add_theme_color_override("font_color", Color("#D7F0FA"))
	_icon_legend.add_theme_font_size_override("font_size", 16)
	_icon_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_icon_legend)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_font_size_override("font_size", 21)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_title)

	_city_name_row = HBoxContainer.new()
	_city_name_row.name = "CityNameEntryRow"
	_city_name_row.add_theme_constant_override("separation", 8)
	_city_name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_city_name_row)

	_city_name_input = LineEdit.new()
	_city_name_input.name = "CityNameInput"
	_city_name_input.placeholder_text = "Enter your city name"
	_city_name_input.max_length = 28
	_city_name_input.virtual_keyboard_enabled = true
	_city_name_input.text_submitted.connect(func(_submitted: String) -> void: _submit_city_name())
	_city_name_input.custom_minimum_size = Vector2(0, 48)
	_city_name_input.add_theme_font_size_override("font_size", 19)
	_city_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_city_name_input.text = GameManager.city_name
	_city_name_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_city_name_row.add_child(_city_name_input)

	_city_name_button = _make_action_button("SAVE CITY", Color("#55D6A0"), Color("#123348"), 136)
	_city_name_button.name = "SaveCityNameButton"
	_city_name_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_city_name_button.pressed.connect(_submit_city_name)
	_city_name_row.add_child(_city_name_button)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", Color("#F0F6FA"))
	_description.add_theme_font_size_override("font_size", 17)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_description)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("#A8E7B0"))
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_hint)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_color_override("font_color", Color("#D5E8FF"))
	_result.add_theme_font_size_override("font_size", 15)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_result)

	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.min_value = 0
	_progress.max_value = STEP_DATA.size()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 12
	_progress.add_theme_stylebox_override("background", _make_progress_style(Color("#24465A")))
	_progress.add_theme_stylebox_override("fill", _make_progress_style(Color("#45C5A0")))
	layout.add_child(_progress)

	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	_later_button = _make_action_button("Later", Color("#29485B"), Color.WHITE, 112)
	_later_button.name = "TutorialLaterButton"
	_later_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_later_button.pressed.connect(_hide_for_later)
	actions.add_child(_later_button)

	_skip_button = _make_action_button("Skip guide", Color("#D9F2FF"), Color("#123348"), 142)
	_skip_button.name = "TutorialSkipButton"
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.pressed.connect(_skip_tutorial)
	actions.add_child(_skip_button)

	_finger_pointer = Label.new()
	_finger_pointer.name = "ActionFingerPointer"
	_finger_pointer.text = "👆"
	_finger_pointer.size = Vector2(64, 64)
	_finger_pointer.custom_minimum_size = Vector2(64, 64)
	_finger_pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finger_pointer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finger_pointer.add_theme_font_size_override("font_size", 42)
	_finger_pointer.pivot_offset = Vector2(32.0, 32.0)
	_finger_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger_pointer.z_index = 220
	add_child(_finger_pointer)

	_layout_guide_panel()
	_update_city_name_controls()

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.13, 0.19, 0.88)
	style.border_color = Color(0.45, 0.80, 0.94, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 8
	return style

func _make_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style

func _make_action_button(label: String, background: Color, foreground: Color, width: float) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(width, 50)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_stylebox_override("normal", _make_button_style(background))
	button.add_theme_stylebox_override("hover", _make_button_style(background.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", _make_button_style(background.darkened(0.10)))
	return button

func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _layout_guide_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(430.0, maxf(280.0, viewport_size.x - 24.0))
	var desired_height := 300.0 if current_step == 0 and not completed else 205.0
	var panel_height := minf(desired_height, maxf(220.0, viewport_size.y - 100.0))
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 12.0
	_panel.offset_right = _panel.offset_left + panel_width
	_panel.offset_top = 78.0
	_panel.offset_bottom = _panel.offset_top + panel_height

func _on_viewport_size_changed() -> void:
	_layout_guide_panel()

func _refresh_guide() -> void:
	if not is_instance_valid(_panel):
		return
	if current_step >= STEP_DATA.size():
		_show_completion()
		return
	var step: Dictionary = STEP_DATA[current_step]
	_update_city_name_controls()
	_title.text = str(step.get("title", ""))
	_description.text = str(step.get("description", ""))
	_hint.text = str(step.get("hint", ""))
	_result.text = str(step.get("result", ""))
	_counter.text = "STEP %d OF %d" % [current_step + 1, STEP_DATA.size()]
	_progress.value = current_step
	_update_finger_pointer()

func _update_city_name_controls() -> void:
	var is_name_step := current_step == 0 and not completed
	if is_instance_valid(_city_name_row):
		_city_name_row.visible = is_name_step
	if is_instance_valid(_icon_legend):
		_icon_legend.visible = not is_name_step
	if is_instance_valid(_result):
		_result.visible = not is_name_step
	if is_instance_valid(_icon_legend) and not GameManager.city_name.is_empty():
		_icon_legend.text = "🏙 " + GameManager.city_name + "    🛣 Roads    🏠 Homes    🏭 Factory    🛒 Shops    📦 Storage"

func _submit_city_name() -> void:
	if not is_instance_valid(_city_name_input):
		return
	var chosen_name := _city_name_input.text.strip_edges()
	if chosen_name.is_empty():
		_city_name_input.placeholder_text = "Please enter a city name first"
		_city_name_input.grab_focus()
		return
	if not GameManager.set_city_name(chosen_name):
		return
	milestones["city_name"] = true
	_save_progress()
	SaveManager.save_game()
	var hud := get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
	if is_instance_valid(hud):
		var status := hud.get("status_label") as Label
		if is_instance_valid(status):
			status.text = "Welcome to %s! Your city is ready to grow." % GameManager.city_name
	_advance_completed_steps()
	_refresh_guide()

func _update_finger_pointer() -> void:
	if not is_instance_valid(_finger_pointer) or _dismissed or completed:
		if is_instance_valid(_finger_pointer):
			_finger_pointer.hide()
		return
	var step_id := str(STEP_DATA[current_step].get("id", ""))
	if current_step == 0:
		if is_instance_valid(_city_name_input) and _city_name_input.is_visible_in_tree():
			_point_to_control(_city_name_input)
		else:
			_finger_pointer.hide()
		return

	var hud := get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
	var target: Control = null
	var world_target := Vector3.ZERO
	var has_world_target := false
	if is_instance_valid(hud):
		match step_id:
			"home", "factory", "store":
				var category := "residential" if step_id == "home" else ("industrial" if step_id == "factory" else "commercial")
				var option_id := "residential_villa" if step_id == "home" else ("factory_small" if step_id == "factory" else "building_supplies")
				var info_panel := hud.get("catalog_info_panel") as Control
				if is_instance_valid(info_panel) and info_panel.visible:
					target = info_panel.find_child("CatalogBuildButton", true, false) as Control
				elif BuildManager.is_placing:
					var placement := _get_valid_placement_world_target()
					has_world_target = bool(placement.get("valid", false))
					world_target = placement.get("position", Vector3.ZERO)
				elif str(hud.get("active_category")) == category:
					# ToolSubmenu is nested inside ToolSubmenuScroll, not a direct HUD child.
					# Search recursively so the pointer advances from the category icon to its real card.
					var submenu := hud.find_child("ToolSubmenu", true, false) as Control
					if is_instance_valid(submenu) and submenu.is_visible_in_tree():
						target = hud.find_child(option_id, true, false) as Control
				if not is_instance_valid(target) and not has_world_target:
					target = hud.find_child("Tool_" + category.capitalize(), true, false) as Control
			_:
				var target_name := str(STEP_DATA[current_step].get("target", ""))
				target = hud.find_child(target_name, true, false) as Control if not target_name.is_empty() else null

	if is_instance_valid(target) and target.is_visible_in_tree():
		_point_to_control(target)
		return
	if not has_world_target:
		var wanted_category := ""
		match step_id:
			"raw": wanted_category = "industrial"
			"crafted": wanted_category = "commercial"
			"upgrade": wanted_category = "residential"
		if not wanted_category.is_empty():
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				for building in BuildManager.buildings.values():
					if not is_instance_valid(building) or str(building.get("status")) != "completed":
						continue
					var definition: Dictionary = building.get("definition") if building.get("definition") is Dictionary else {}
					if str(definition.get("category", "")) != wanted_category:
						continue
					world_target = building.global_position + Vector3(0.0, 5.0, 0.0)
					if not camera.is_position_behind(world_target):
						has_world_target = true
						break
	if has_world_target:
		_point_to_world_position(world_target)
	else:
		_finger_pointer.hide()

func _point_to_control(target: Control) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		_finger_pointer.hide()
		return
	# HUD and coach live on separate CanvasLayers. Convert the target's
	# viewport-space anchor into this guide layer before positioning the finger;
	# mixing get_global_rect() with local Control.position drifts on scaled/mobile canvases.
	var target_anchor_in_viewport := target.get_global_transform_with_canvas() * Vector2(target.size.x * 0.72, target.size.y + 2.0 + sin(_finger_elapsed * 5.0) * 5.0)
	_finger_pointer.position = get_final_transform().affine_inverse() * target_anchor_in_viewport
	_finger_pointer.show()

func _point_to_world_position(world_position: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		_finger_pointer.hide()
		return
	var world_anchor_in_viewport := camera.unproject_position(world_position) + Vector2(20.0, 12.0 + sin(_finger_elapsed * 5.0) * 5.0)
	_finger_pointer.position = get_final_transform().affine_inverse() * world_anchor_in_viewport
	_finger_pointer.show()

func _get_valid_placement_world_target() -> Dictionary:
	var type_id := BuildManager.selected_building_type
	if type_id.is_empty() or not BuildManager.building_types.has(type_id):
		return {"valid": false}
	var definition: Dictionary = BuildManager.building_types[type_id]
	var footprint: Vector2i = definition.get("size", Vector2i(2, 2))
	var scene := get_tree().current_scene
	var road_system := scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system == null:
		return {"valid": false}
	for road_cell in road_system.roads.keys():
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var candidate: Vector2i = road_cell + direction
			if not BuildManager.can_place_at(candidate, type_id):
				continue
			var world_position: Vector3 = BuildManager.grid_to_world(candidate) + Vector3((footprint.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.0, (footprint.y - 1) * BuildManager.GRID_SIZE * 0.5)
			return {"valid": true, "position": world_position + Vector3(0.0, 4.0, 0.0)}
	return {"valid": false}

func _show_completion() -> void:
	if not is_instance_valid(_panel):
		return
	_update_city_name_controls()
	if is_instance_valid(_finger_pointer):
		_finger_pointer.hide()
	_title.text = "Your city is taking shape!"
	_description.text = "You have completed the starter guide. Keep building, producing goods, upgrading homes and improving city services."
	_hint.text = "OPEN ANY TIME  Tap the GUIDE button to review this guide."
	_result.text = "NEXT  Expand your road network and grow your city."
	_counter.text = "ALL STEPS DONE"
	_progress.value = STEP_DATA.size()
	_skip_button.text = "Close guide"
	if _skip_button.pressed.is_connected(_skip_tutorial):
		_skip_button.pressed.disconnect(_skip_tutorial)
	if not _skip_button.pressed.is_connected(_close_guide):
		_skip_button.pressed.connect(_close_guide)

func _advance_completed_steps() -> void:
	var old_step := current_step
	while current_step < STEP_DATA.size():
		var step_id := str(STEP_DATA[current_step].get("id", ""))
		if not bool(milestones.get(step_id, false)):
			break
		current_step += 1
	if current_step != old_step:
		_save_progress()
		if is_instance_valid(_panel):
			_refresh_guide()
	if current_step >= STEP_DATA.size():
		completed = true
		_save_progress()
		if is_instance_valid(_panel):
			_show_completion()

func _skip_tutorial() -> void:
	completed = true
	current_step = STEP_DATA.size()
	_save_progress()
	_show_completion()

func _hide_for_later() -> void:
	_dismissed = true
	if is_instance_valid(_panel):
		_panel.hide()
	if is_instance_valid(_finger_pointer):
		_finger_pointer.hide()
	_build_reopen_button()

func _close_guide() -> void:
	_hide_for_later()

func open_help() -> void:
	_reopen_guide()

func _reopen_guide() -> void:
	_dismissed = false
	if is_instance_valid(_panel):
		_panel.show()
		_layout_guide_panel()
		_update_city_name_controls()
		_update_finger_pointer()
		if completed:
			_show_completion()
		else:
			_refresh_guide()

func set_player_scope(path: String) -> void:
	save_path = path
	if not _profile_progress_loaded:
		_load_progress()
		if is_instance_valid(_panel):
			_refresh_guide()

func to_save_dict() -> Dictionary:
	return {
		"current_step": current_step,
		"completed": completed,
		"tutorial_enabled": tutorial_enabled,
		"milestones": milestones.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	_profile_progress_loaded = true
	current_step = clampi(int(data.get("current_step", 0)), 0, STEP_DATA.size())
	completed = bool(data.get("completed", false))
	tutorial_enabled = bool(data.get("tutorial_enabled", true))
	var saved_milestones: Variant = data.get("milestones", {})
	if saved_milestones is Dictionary:
		for key in milestones:
			milestones[key] = bool(saved_milestones.get(key, false))
	if completed:
		current_step = STEP_DATA.size()
	if is_instance_valid(_panel):
		if completed:
			_show_completion()
		else:
			_refresh_guide()

func _load_progress() -> void:
	if _profile_progress_loaded:
		return
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	current_step = clampi(int(config.get_value("tutorial", "current_step", 0)), 0, STEP_DATA.size())
	completed = bool(config.get_value("tutorial", "completed", false))
	var saved_milestones: Variant = config.get_value("tutorial", "milestones", {})
	var has_city_name_history: bool = false
	if saved_milestones is Dictionary:
		has_city_name_history = saved_milestones.has("city_name")
		for key in milestones:
			milestones[key] = bool(saved_milestones.get(key, false))
	# A pre-city-name save must not silently skip the new real input step,
	# even if an older tutorial version had already been marked complete.
	if not has_city_name_history and GameManager.city_name.is_empty():
		completed = false
		current_step = 0
		milestones["city_name"] = false
	elif completed:
		current_step = STEP_DATA.size()

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "current_step", current_step)
	config.set_value("tutorial", "completed", completed)
	config.set_value("tutorial", "milestones", milestones)
	var directory := ProjectSettings.globalize_path(save_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(directory)
	var error := config.save(save_path)
	if error != OK:
		push_warning("[TutorialGuide] Could not save tutorial progress: %s" % error_string(error))
	elif SaveManager.persistence_ready:
		SaveManager.save_game()

static func get_step_count() -> int:
	return STEP_DATA.size()

static func get_step_definition(index: int) -> Dictionary:
	if index < 0 or index >= STEP_DATA.size():
		return {}
	return STEP_DATA[index].duplicate(true)
