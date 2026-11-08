extends CanvasLayer

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")

# The atlas does not currently contain a banknote glyph, so SimCash uses this
# small locally drawn vector icon. All other status icons come from IconAtlas.
class BanknoteGlyph extends Control:
	func _draw() -> void:
		var note := Rect2(Vector2(2.5, 6.0), Vector2(size.x - 5.0, size.y - 12.0))
		draw_rect(note, Color("#4CD964"), true)
		draw_rect(note, Color("#D9FFE1"), false, 1.4)
		draw_circle(size * 0.5, 5.0, Color("#D9FFE1"))
		draw_line(Vector2(6, 9), Vector2(10, 9), Color("#D9FFE1"), 1.2)
		draw_line(Vector2(size.x - 10, size.y - 9), Vector2(size.x - 6, size.y - 9), Color("#D9FFE1"), 1.2)

@onready var status_label: Label = $StatusLabel

var submenu: HBoxContainer
var active_category := ""
var level_label: Label
var population_label: Label
var happiness_label: Label
var storage_label: Label
var simoleons_label: Label
var simcash_label: Label
var keys_label: Label
var _last_simcash_value := -1

func _ready() -> void:
	# Keep the existing gameplay signal wiring intact.
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.keys_changed.connect(_on_keys_changed)
	StorageManager.storage_changed.connect(_on_storage_changed)
	BuildManager.placement_mode_changed.connect(_on_placement_mode)
	ServiceManager.power_changed.connect(_on_power_changed)
	ServiceManager.water_changed.connect(_on_water_changed)

	_build_top_hud()
	_build_toolbars()
	_update_all()
	status_label.text = "Build a road, then place a house and factory beside it."

func _build_top_hud() -> void:
	# Hide the old scene-authored counters; the new responsive bar replaces them.
	for old_path in ["TopLeft", "TopRight"]:
		var old_node := get_node_or_null(old_path)
		if old_node:
			old_node.hide()
			old_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_hud := Control.new()
	top_hud.name = "TopHUD"
	top_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud.z_index = 20
	add_child(top_hud)

	var margins := MarginContainer.new()
	margins.name = "TopHUDMargins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 14)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_right", 14)
	margins.add_theme_constant_override("margin_bottom", 0)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud.add_child(margins)

	var row := HBoxContainer.new()
	row.name = "TopHUDRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(row)

	var left_group := HBoxContainer.new()
	left_group.name = "CityStats"
	left_group.add_theme_constant_override("separation", 8)
	left_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left_group)

	var spacer := Control.new()
	spacer.name = "FlexibleSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right_group := HBoxContainer.new()
	right_group.name = "Currencies"
	right_group.add_theme_constant_override("separation", 8)
	right_group.alignment = BoxContainer.ALIGNMENT_END
	right_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right_group)

	level_label = _add_icon_capsule(left_group, "level", "1", Color("#E85D9A"), "City level")
	population_label = _add_icon_capsule(left_group, "population", "0", Color("#4BA3FF"), "City population")
	happiness_label = _add_icon_capsule(left_group, "happiness", "100%", Color("#3DDB6A"), "Citizen happiness")
	storage_label = _add_icon_capsule(left_group, "storage", "0/30", Color("#5BB8F5"), "City storage")

	simoleons_label = _add_icon_capsule(right_group, "simoleons", "5000", Color("#FFD24A"), "Simoleons")
	_build_simcash_capsule(right_group)
	keys_label = _add_icon_capsule(right_group, "golden_key", "5", Color("#FFC107"), "Golden Keys")

func _add_icon_capsule(parent: HBoxContainer, icon_name: String, initial_text: String, tint: Color, hint: String) -> Label:
	var capsule := PanelContainer.new()
	capsule.name = icon_name.capitalize() + "Capsule"
	capsule.custom_minimum_size = Vector2(0, 52)
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.tooltip_text = hint
	capsule.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(capsule)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.add_child(content)

	var icon := IconAtlas.make_icon(icon_name, Vector2(30, 30))
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var value := Label.new()
	value.text = initial_text
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	value.add_theme_constant_override("shadow_offset_x", 1)
	value.add_theme_constant_override("shadow_offset_y", 1)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(value)
	return value

func _build_simcash_capsule(parent: HBoxContainer) -> void:
	var capsule := PanelContainer.new()
	capsule.name = "SimCashCapsule"
	capsule.custom_minimum_size = Vector2(0, 52)
	capsule.tooltip_text = "SimCash"
	capsule.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(capsule)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	capsule.add_child(content)

	var glyph := BanknoteGlyph.new()
	glyph.custom_minimum_size = Vector2(30, 30)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(glyph)

	simcash_label = Label.new()
	simcash_label.text = str(EconomyManager.sim_cash)
	simcash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	simcash_label.add_theme_color_override("font_color", Color.WHITE)
	simcash_label.add_theme_font_size_override("font_size", 16)
	simcash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(simcash_label)

	var add_button := Button.new()
	add_button.name = "SimCashAddButton"
	add_button.text = "+"
	add_button.custom_minimum_size = Vector2(25, 25)
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.tooltip_text = "SimCash shop (not available yet)"
	add_button.add_theme_font_size_override("font_size", 18)
	add_theme_color(add_button, Color("#4CD964"))
	content.add_child(add_button)
	add_button.pressed.connect(_on_simcash_plus_pressed)

func _add_theme_color(button: Button, tint: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
	normal.border_color = Color(tint.r, tint.g, tint.b, 0.72)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r, tint.g, tint.b, 0.38)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color.WHITE)

func _capsule_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.78)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _build_toolbars() -> void:
	var old_menu := get_node_or_null("LeftMenu")
	if old_menu:
		old_menu.queue_free()
	var old_toolbar := get_node_or_null("RightToolbar")
	if old_toolbar:
		old_toolbar.queue_free()
	# Large touch targets stay inside a vertical scroller on short landscape screens.
	var toolbar_scroll := ScrollContainer.new()
	toolbar_scroll.name = "RightToolbar"
	toolbar_scroll.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	var scroll_height := get_viewport().get_visible_rect().size.y * 0.82
	toolbar_scroll.position = Vector2(-124, -scroll_height * 0.5)
	toolbar_scroll.custom_minimum_size = Vector2(116, scroll_height)
	toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(toolbar_scroll)
	var toolbar := VBoxContainer.new()
	toolbar.name = "RightToolbarItems"
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_scroll.add_child(toolbar)

	# Keep this order stable: primary construction tools first, destructive action last.
	var tools := [
		["road","Road"],
		["residential","Residential"],
		["commercial","Commercial"],
		["industrial","Industrial"],
		["services","Services"],
		["specializations","Specializations / Park"],
		["bulldoze","Bulldoze"]
	]
	for item in tools:
		var button := _make_icon_button(item[0], item[1])
		toolbar.add_child(button)
		button.pressed.connect(_on_category_pressed.bind(item[0]))

	var actions := HBoxContainer.new()
	actions.name = "BottomActions"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = 12
	actions.offset_top = -126
	actions.offset_right = -12
	actions.offset_bottom = -8
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	for item in [["storage","Storage"],["trade","Trade"],["save","Save"],["cancel","Cancel"]]:
		var button := _make_icon_button(item[0], item[1])
		actions.add_child(button)
		match item[0]:
			"storage": button.pressed.connect(_on_storage_pressed)
			"trade": button.pressed.connect(_on_trade_pressed)
			"save": button.pressed.connect(_on_save_pressed)
			"cancel": button.pressed.connect(_on_cancel_pressed)

	submenu = HBoxContainer.new()
	submenu.name = "ToolSubmenu"
	submenu.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	submenu.offset_left = 12
	submenu.offset_top = -250
	submenu.offset_right = -12
	submenu.offset_bottom = -130
	submenu.alignment = BoxContainer.ALIGNMENT_CENTER
	submenu.add_theme_constant_override("separation", 8)
	add_child(submenu)
	submenu.hide()

func _make_icon_button(kind: String, hint: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(112, 112)
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
	button.add_theme_stylebox_override("hover", _toolbar_style(Color(0.16, 0.32, 0.43, 0.18), Color(0.55, 0.78, 0.9, 0.42)))
	button.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.95, 0.72, 0.28, 0.22), Color(0.98, 0.82, 0.48, 0.68)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := IconAtlas.make_icon(kind, Vector2(104, 104))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	if icon.texture == null:
		# Never leave a silent gray slot when an atlas key is missing.
		var fallback := Label.new()
		fallback.text = hint.left(1).to_upper()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_color_override("font_color", Color.WHITE)
		fallback.add_theme_font_size_override("font_size", 28)
		button.add_child(fallback)
	else:
		button.add_child(icon)
	return button

func _toolbar_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _on_category_pressed(category: String) -> void:
	if active_category == category and submenu.visible:
		submenu.hide()
		active_category = ""
		return
	active_category = category
	_show_submenu(category)

func _show_submenu(category: String) -> void:
	for child in submenu.get_children():
		child.queue_free()
	submenu.show()
	var options: Array = []
	match category:
		"road":
			options = [["road","Road"],["cancel","Cancel"]]
		"residential":
			options = [["residential","Small House"]]
		"commercial":
			options = [["commercial","Building Supplies"],["commercial","Hardware Store"]]
		"industrial":
			options = [["industrial","Small Factory"]]
		"services":
			options = [["power","Power"],["water","Water"],["fire","Fire"],["police","Police"],["health","Health"],["sewage","Sewage"],["waste","Waste"],["government","Government"]]
		"specializations":
			options = [["education","Education"],["transportation","Transportation"],["entertainment","Entertainment"],["gambling","Gambling"],["beach","Beach"],["mountain","Mountain"],["landmark","Landmark"],["parks","Parks"],["trade_depot","Trade Depot"],["global_trade","Global Trade"],["epic","Epic"],["regions","Regions"]]
		"bulldoze":
			options = [["bulldoze","Bulldoze mode"],["cancel","Cancel"]]
	for option in options:
		var button := _make_icon_button(option[0], option[1])
		button.custom_minimum_size = Vector2(112, 112)
		submenu.add_child(button)
		button.pressed.connect(_on_submenu_option.bind(category, option[1]))

func _on_submenu_option(category: String, option: String) -> void:
	match category:
		"road":
			if option == "Road": _on_roads_pressed()
			else: _on_cancel_pressed()
		"residential": BuildManager.select_building("residential_1")
		"commercial":
			BuildManager.select_building("building_supplies" if option == "Building Supplies" else "hardware_store")
		"industrial": BuildManager.select_building("industrial_1")
		"services":
			if option == "Power": BuildManager.select_building("power_wind")
			elif option == "Water": BuildManager.select_building("water_tower")
			else: status_label.text = option + " service selected."
		"specializations":
			if option == "Parks": BuildManager.select_building("park_small")
			else: status_label.text = option + " specialization selected."
		"bulldoze":
			status_label.text = "Bulldoze mode selected. Tap Cancel to leave this tool."
			BuildManager.cancel_placement()
			var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
			if road_system: road_system.set_road_mode(false)
	if BuildManager.is_placing or category == "road":
		submenu.hide()
		active_category = ""

func _update_all() -> void:
	_on_level_changed(GameManager.level)
	_on_population_changed(GameManager.population)
	_on_happiness_changed(GameManager.happiness)
	_on_simoleons_changed(EconomyManager.simoleons)
	_on_keys_changed(EconomyManager.golden_keys)
	_on_storage_changed()
	_update_simcash()
	_on_power_changed(ServiceManager.total_power, ServiceManager.used_power)
	_on_water_changed(ServiceManager.total_water, ServiceManager.used_water)

func _update_simcash() -> void:
	if simcash_label == null:
		return
	var amount := int(EconomyManager.sim_cash)
	if amount != _last_simcash_value:
		simcash_label.text = str(amount)
		_last_simcash_value = amount

func _on_level_changed(level: int) -> void:
	if level_label: level_label.text = str(level)

func _on_population_changed(population: int) -> void:
	if population_label: population_label.text = _format_count(population)

func _on_happiness_changed(value: float) -> void:
	if happiness_label: happiness_label.text = "%d%%" % roundi(value)

func _on_simoleons_changed(_amount: int) -> void:
	if simoleons_label: simoleons_label.text = EconomyManager.get_formatted_simoleons()

func _on_keys_changed(amount: int) -> void:
	if keys_label: keys_label.text = _format_count(amount)

func _on_storage_changed() -> void:
	if storage_label: storage_label.text = StorageManager.get_storage_ratio()

func _on_power_changed(total: int, used: int) -> void:
	if status_label:
		status_label.tooltip_text = "Power usage: %d / %d" % [used, total]

func _on_water_changed(total: int, used: int) -> void:
	if status_label:
		var existing := status_label.tooltip_text
		status_label.tooltip_text = existing + "  |  Water usage: %d / %d" % [used, total]

func _format_count(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)

func _on_simcash_plus_pressed() -> void:
	status_label.text = "SimCash purchases are not available yet."

func _on_placement_mode(active: bool) -> void:
	if active: status_label.text = "Placement mode — tap a clear plot beside a road. Cancel with X."
	else: status_label.text = ""

func _on_roads_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.set_road_mode(true)
		status_label.text = "Road mode — tap or drag from the highway (50 § per tile)"

func _on_storage_pressed() -> void:
	BuildManager.cancel_placement()
	var items = StorageManager.get_all_items()
	if items.is_empty(): status_label.text = "Storage is empty."
	else:
		var inventory_text := ""
		for item_id in items: inventory_text += str(item_id) + "×" + str(items[item_id]) + "  "
		status_label.text = inventory_text

func _on_trade_pressed() -> void:
	BuildManager.cancel_placement()
	status_label.text = "Trade — %d active orders." % TradeManager.get_orders().size()

func _on_cancel_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system: road_system.set_road_mode(false)
	status_label.text = "Cancelled."

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
