extends CanvasLayer
## Clear, mobile-first onboarding for the first city-building loop.
## Milestones are completed only by real gameplay events; this guide never
## grants items or mutates city state.

const SAVE_PATH := "user://tutorial_progress.cfg"
const STEP_DATA: Array[Dictionary] = [
	{
		"id": "home",
		"title": "Build your first home",
		"description": "Open the Residential menu on the right. Choose Small House, then tap an empty plot beside a road.",
		"hint": "TAP PATH  Residential  →  Small House  →  Empty plot",
		"result": "YOU SHOULD SEE  A house construction site appear on the selected plot."
	},
	{
		"id": "factory",
		"title": "Build a factory",
		"description": "Open Industrial, choose Small Factory, and place it on an empty plot connected to your road network.",
		"hint": "TAP PATH  Industrial  →  Small Factory  →  Empty plot",
		"result": "YOU SHOULD SEE  Your factory appear and begin its construction timer."
	},
	{
		"id": "raw",
		"title": "Make and collect Metal",
		"description": "Tap the completed factory. Tap the Metal product card once to place an order in the first empty production slot. Wait for the countdown, then collect the ready Metal.",
		"hint": "TAP PATH  Factory  →  Metal card  →  Wait  →  Collect",
		"result": "YOU SHOULD SEE  Metal in a queue slot, a seconds countdown, then Metal added to City Storage after Collect."
	},
	{
		"id": "store",
		"title": "Build a supply store",
		"description": "Open Commercial and place a Building Supplies store on an empty plot beside a connected road.",
		"hint": "TAP PATH  Commercial  →  Building Supplies  →  Empty plot",
		"result": "YOU SHOULD SEE  The store finish construction and become selectable."
	},
	{
		"id": "crafted",
		"title": "Craft and collect a product",
		"description": "Tap the Building Supplies store. Choose a product whose ingredients are available in City Storage. Wait for its timer, then collect it.",
		"hint": "TAP PATH  Building Supplies  →  Available product  →  Wait  →  Collect",
		"result": "YOU SHOULD SEE  The product added to City Storage. Products with missing ingredients stay unavailable."
	},
	{
		"id": "upgrade",
		"title": "Upgrade your home",
		"description": "Select your completed home. Review the required materials, then deliver them to start the next construction stage.",
		"hint": "TAP PATH  Select home  →  Review materials  →  Deliver",
		"result": "YOU SHOULD SEE  The home enter construction and its upgrade stage advance when complete."
	}
]

var milestones: Dictionary = {
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
	# PASS is intentional: IGNORE on a parent can bypass its child controls in
	# GUI hit-testing on some Godot paths. The panel background must pass taps
	# through to HUD controls underneath, while its own Buttons remain clickable.
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_theme_constant_override("separation", 10)
	_panel.add_child(layout)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(header)
	var eyebrow := Label.new()
	eyebrow.text = "☁ CITY COACH  •  YOUR NEXT TASK"
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

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_progress.min_value = 0
	_progress.max_value = STEP_DATA.size()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 12
	_progress.add_theme_stylebox_override("background", _make_progress_style(Color("#24465A")))
	_progress.add_theme_stylebox_override("fill", _make_progress_style(Color("#45C5A0")))
	layout.add_child(_progress)

	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	_later_button = _make_action_button("Later", Color("#29485B"), Color.WHITE, 112)
	_later_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_later_button.pressed.connect(_hide_for_later)
	actions.add_child(_later_button)

	_skip_button = _make_action_button("Skip guide", Color("#D9F2FF"), Color("#123348"), 142)
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.pressed.connect(_skip_tutorial)
	actions.add_child(_skip_button)

	_layout_guide_panel()

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
	var panel_height := minf(205.0, maxf(150.0, viewport_size.y - 100.0))
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
	_title.text = str(step.get("title", ""))
	_description.text = str(step.get("description", ""))
	_hint.text = str(step.get("hint", ""))
	_result.text = str(step.get("result", ""))
	_counter.text = "STEP %d OF %d" % [current_step + 1, STEP_DATA.size()]
	_progress.value = current_step

func _show_completion() -> void:
	if not is_instance_valid(_panel):
		return
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
	_build_reopen_button()

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
	_build_reopen_button()

func _close_guide() -> void:
	_hide_for_later()

func _build_reopen_button() -> void:
	if get_node_or_null("ReopenTutorial") != null:
		return
	var reopen := Button.new()
	reopen.name = "ReopenTutorial"
	reopen.text = "☁  HELP"
	reopen.tooltip_text = "Open the city coach"
	reopen.custom_minimum_size = Vector2(104, 48)
	reopen.add_theme_font_size_override("font_size", 19)
	reopen.add_theme_color_override("font_color", Color("#123348"))
	reopen.add_theme_stylebox_override("normal", _make_button_style(Color("#D9F2FF")))
	reopen.add_theme_stylebox_override("hover", _make_button_style(Color("#FFFFFF")))
	reopen.anchor_left = 0.0
	reopen.anchor_right = 0.0
	reopen.anchor_top = 1.0
	reopen.anchor_bottom = 1.0
	reopen.offset_left = 14
	reopen.offset_right = 118
	reopen.offset_top = 14
	reopen.offset_bottom = 62
	reopen.z_index = 111
	reopen.mouse_filter = Control.MOUSE_FILTER_STOP
	reopen.pressed.connect(_reopen_guide)
	add_child(reopen)

func _reopen_guide() -> void:
	_dismissed = false
	if is_instance_valid(_panel):
		_panel.show()
		_layout_guide_panel()
		if completed:
			_show_completion()
		else:
			_refresh_guide()

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	current_step = clampi(int(config.get_value("tutorial", "current_step", 0)), 0, STEP_DATA.size())
	completed = bool(config.get_value("tutorial", "completed", false))
	var saved_milestones: Variant = config.get_value("tutorial", "milestones", {})
	if saved_milestones is Dictionary:
		for key in milestones:
			milestones[key] = bool(saved_milestones.get(key, false))
	if completed:
		current_step = STEP_DATA.size()

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "current_step", current_step)
	config.set_value("tutorial", "completed", completed)
	config.set_value("tutorial", "milestones", milestones)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("[TutorialGuide] Could not save tutorial progress: %s" % error_string(error))

static func get_step_count() -> int:
	return STEP_DATA.size()

static func get_step_definition(index: int) -> Dictionary:
	if index < 0 or index >= STEP_DATA.size():
		return {}
	return STEP_DATA[index].duplicate(true)
