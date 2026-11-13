extends CanvasLayer
## First-session onboarding for the core city-building loop.
## Milestones are completed by real gameplay events; the guide never grants items
## or changes city state. Progress is stored separately from the city save.

const SAVE_PATH := "user://tutorial_progress.cfg"
const STEP_DATA: Array[Dictionary] = [
	{"id":"home", "title":"Place your first home", "description":"Open Residential on the right, choose the starter home, then place it beside the connected road.", "hint":"Residential → Small House → tap a free plot"},
	{"id":"factory", "title":"Build a factory", "description":"Open Industrial and place a Small Factory on a free plot connected to your road network.", "hint":"Industrial → Small Factory"},
	{"id":"raw", "title":"Collect a raw material", "description":"Select your factory, start producing an available raw material, then collect it when the timer finishes.", "hint":"Factory → choose Metal → Collect"},
	{"id":"store", "title":"Build a commercial store", "description":"Build a Building Supplies store. It turns raw materials into useful construction products.", "hint":"Commercial → Building Supplies"},
	{"id":"crafted", "title":"Collect a crafted product", "description":"Open the store, start a product whose ingredients you have, and collect it when it is ready.", "hint":"Store → select an available product → Collect"},
	{"id":"upgrade", "title":"Upgrade your home", "description":"Select your completed home. Deliver the required materials to begin its next construction stage.", "hint":"Select home → Deliver Materials & Upgrade"}
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
var _progress: ProgressBar
var _counter: Label
var _skip_button: Button
var _dismissed := false

func _ready() -> void:
	if not tutorial_enabled:
		return
	call_deferred("_initialize_after_city_restore")

func _initialize_after_city_restore() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_load_progress()
	if completed:
		_build_reopen_button()
		return
	_connect_gameplay_events()
	_sync_existing_city_state()
	_build_guide_panel()
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
		var category := str(BuildManager.building_types.get(type_id, {}).get("category", ""))
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

func _process(_delta: float) -> void:
	if completed or _dismissed or not is_instance_valid(_panel):
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

func _build_guide_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FirstCityTutorial"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -minf(340.0, get_viewport().get_visible_rect().size.x * 0.42)
	_panel.offset_right = minf(340.0, get_viewport().get_visible_rect().size.x * 0.42)
	_panel.offset_top = -214.0
	_panel.offset_bottom = -12.0
	_panel.z_index = 110
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102B3B")
	style.border_color = Color("#8AD7F5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	_panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var eyebrow := Label.new()
	eyebrow.text = "MAYOR'S FIRST STEPS"
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_theme_color_override("font_color", Color("#8AD7F5"))
	eyebrow.add_theme_font_size_override("font_size", 12)
	header.add_child(eyebrow)
	_counter = Label.new()
	_counter.add_theme_color_override("font_color", Color("#D8EAF3"))
	_counter.add_theme_font_size_override("font_size", 12)
	header.add_child(_counter)

	_title = Label.new()
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_font_size_override("font_size", 20)
	layout.add_child(_title)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_color_override("font_color", Color("#E0EDF4"))
	_description.add_theme_font_size_override("font_size", 14)
	layout.add_child(_description)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("#9DE0A5"))
	_hint.add_theme_font_size_override("font_size", 12)
	layout.add_child(_hint)

	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = STEP_DATA.size()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	layout.add_child(_progress)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(actions)
	_skip_button = Button.new()
	_skip_button.text = "Skip tutorial"
	_skip_button.custom_minimum_size = Vector2(130, 38)
	_skip_button.pressed.connect(_skip_tutorial)
	actions.add_child(_skip_button)

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
	_counter.text = "%d / %d" % [current_step + 1, STEP_DATA.size()]
	_progress.value = current_step

func _show_completion() -> void:
	if not is_instance_valid(_panel):
		return
	_title.text = "Your city is taking shape!"
	_description.text = "You completed the core tutorial. Keep expanding, producing, trading and improving city services."
	_hint.text = "You can reopen this guide with the ? button."
	_counter.text = "Complete"
	_progress.value = STEP_DATA.size()
	_skip_button.text = "Close"
	for connection in _skip_button.pressed.get_connections():
		_skip_button.pressed.disconnect(connection.callable)
	_skip_button.pressed.connect(_close_guide)
	_build_reopen_button()

func _skip_tutorial() -> void:
	completed = true
	current_step = STEP_DATA.size()
	_save_progress()
	_show_completion()

func _close_guide() -> void:
	_dismissed = true
	if is_instance_valid(_panel):
		_panel.hide()
	_build_reopen_button()

func _build_reopen_button() -> void:
	if get_node_or_null("ReopenTutorial") != null:
		return
	var reopen := Button.new()
	reopen.name = "ReopenTutorial"
	reopen.text = "?"
	reopen.tooltip_text = "Open city tutorial"
	reopen.custom_minimum_size = Vector2(48, 48)
	reopen.anchor_left = 1.0
	reopen.anchor_right = 1.0
	reopen.anchor_top = 0.0
	reopen.anchor_bottom = 0.0
	reopen.offset_left = -62
	reopen.offset_right = -10
	reopen.offset_top = 204
	reopen.offset_bottom = 256
	reopen.z_index = 111
	reopen.pressed.connect(_reopen_guide)
	add_child(reopen)

func _reopen_guide() -> void:
	_dismissed = false
	if is_instance_valid(_panel):
		_panel.show()
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
