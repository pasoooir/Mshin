extends CanvasLayer

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")
@onready var level_label: Label = $TopLeft/LevelBox/LevelLabel
@onready var population_label: Label = $TopLeft/PopBox/PopLabel
@onready var happiness_icon: Label = $TopLeft/HappinessBox/HappyIcon
@onready var storage_label: Label = $TopLeft/StorageBox/StorageLabel
@onready var simoleons_label: Label = $TopLeft/MoneyBox/MoneyLabel
@onready var keys_label: Label = $TopRight/KeysBox/KeysLabel
@onready var status_label: Label = $StatusLabel
@onready var power_label: Label = $TopRight/PowerBox/PowerLabel
@onready var water_label: Label = $TopRight/WaterBox/WaterLabel

var submenu: HBoxContainer
var active_category := ""

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.keys_changed.connect(_on_keys_changed)
	StorageManager.storage_changed.connect(_on_storage_changed)
	BuildManager.placement_mode_changed.connect(_on_placement_mode)
	ServiceManager.power_changed.connect(_on_power_changed)
	ServiceManager.water_changed.connect(_on_water_changed)
	_install_vector_icons()
	_build_toolbars()
	_update_all()
	status_label.text = "Build a road, then place a house and factory beside it."

func _install_vector_icons() -> void:
	var icon_map := {
		"TopLeft/LevelBox/LevelIcon":"level",
		"TopLeft/PopBox/PopIcon":"population",
		"TopLeft/HappinessBox/HappyIcon":"happiness",
		"TopLeft/StorageBox/StorageIcon":"storage",
		"TopLeft/MoneyBox/MoneyIcon":"simoleons",
		"TopRight/KeysBox/KeysIcon":"golden_key",
		"TopRight/PowerBox/PowerIcon":"power",
		"TopRight/WaterBox/WaterIcon":"water"
	}
	for path in icon_map:
		var old_node := get_node_or_null(path)
		if old_node == null:
			continue
		var parent := old_node.get_parent()
		var insert_index := old_node.get_index()
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(88, 88)
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon := IconAtlas.make_icon(icon_map[path], Vector2(88, 88))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shadow := TextureRect.new()
		shadow.texture = icon.texture
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.offset_left = 1.5
		shadow.offset_top = 2.0
		shadow.offset_right = 1.5
		shadow.offset_bottom = 2.0
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.modulate = Color(0.015, 0.035, 0.055, 0.48)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(shadow)
		holder.add_child(icon)
		parent.add_child(holder)
		parent.move_child(holder, insert_index)
		old_node.visible = false
		old_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in ["TopLeft/LevelBox/LevelLabel","TopLeft/PopBox/PopLabel","TopLeft/StorageBox/StorageLabel","TopLeft/MoneyBox/MoneyLabel","TopRight/KeysBox/KeysLabel","TopRight/PowerBox/PowerLabel","TopRight/WaterBox/WaterLabel"]:
		var label := get_node_or_null(path) as Label
		if label:
			label.add_theme_color_override("font_color", Color("#ffffff"))
			label.add_theme_font_size_override("font_size", 17)

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
	_on_power_changed(ServiceManager.total_power, ServiceManager.used_power)
	_on_water_changed(ServiceManager.total_water, ServiceManager.used_water)

func _on_level_changed(level: int) -> void: level_label.text = str(level)
func _on_population_changed(population: int) -> void: population_label.text = str(population)
func _on_happiness_changed(_value: float) -> void: happiness_icon.text = ""
func _on_simoleons_changed(_amount: int) -> void: simoleons_label.text = EconomyManager.get_formatted_simoleons()
func _on_keys_changed(amount: int) -> void: keys_label.text = str(amount)
func _on_storage_changed() -> void: storage_label.text = StorageManager.get_storage_ratio()
func _on_power_changed(total: int, used: int) -> void:
	if power_label: power_label.text = "%d/%d" % [used, total]
func _on_water_changed(total: int, used: int) -> void:
	if water_label: water_label.text = "%d/%d" % [used, total]

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
