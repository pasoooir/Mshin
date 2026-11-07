extends CanvasLayer

const IconGlyph = preload("res://scripts/ui/IconGlyph.gd")
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
		"TopLeft/HappinessBox/HappyIcon":"happy",
		"TopLeft/StorageBox/StorageIcon":"storage",
		"TopLeft/MoneyBox/MoneyIcon":"money",
		"TopRight/KeysBox/KeysIcon":"keys",
		"TopRight/PowerBox/PowerIcon":"power",
		"TopRight/WaterBox/WaterIcon":"water"
	}
	for path in icon_map:
		var old_node := get_node_or_null(path)
		if old_node == null:
			continue
		var parent := old_node.get_parent()
		var icon := Control.new()
		icon.set_script(IconGlyph)
		icon.set("kind", icon_map[path])
		icon.custom_minimum_size = Vector2(28, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(icon)
		parent.move_child(icon, old_node.get_index())
		# Keep the original Label alive: onready references and signal callbacks
		# still target these nodes (notably HappinessBox/HappyIcon).
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
	var toolbar := VBoxContainer.new()
	toolbar.name = "RightToolbar"
	toolbar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	toolbar.position = Vector2(-76, -190)
	toolbar.custom_minimum_size = Vector2(64, 380)
	toolbar.add_theme_constant_override("separation", 7)
	add_child(toolbar)
	var tools := [
		["road","Road"],["residential","Residential"],["commercial","Commercial"],
		["industrial","Industrial"],["services","Services"],["specializations","Specializations"],["bulldoze","Bulldoze"]
	]
	for item in tools:
		var button := _make_icon_button(item[0], item[1])
		toolbar.add_child(button)
		button.pressed.connect(_on_category_pressed.bind(item[0]))
	var actions := HBoxContainer.new()
	actions.name = "BottomActions"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = 12
	actions.offset_top = -62
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
	submenu.offset_top = -132
	submenu.offset_right = -12
	submenu.offset_bottom = -72
	submenu.alignment = BoxContainer.ALIGNMENT_CENTER
	submenu.add_theme_constant_override("separation", 8)
	add_child(submenu)
	submenu.hide()

func _make_icon_button(kind: String, hint: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(54, 54)
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	var icon := Control.new()
	icon.set_script(IconGlyph)
	icon.set("kind", kind)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 9
	icon.offset_top = 9
	icon.offset_right = -9
	icon.offset_bottom = -9
	button.add_child(icon)
	return button

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
			options = [["power","Wind Power"],["water","Water Tower"]]
		"specializations":
			options = [["park","Parks"],["education","Education"],["transport","Transportation"]]
		"bulldoze":
			options = [["bulldoze","Bulldoze mode"],["cancel","Cancel"]]
	for option in options:
		var button := _make_icon_button(option[0], option[1])
		button.custom_minimum_size = Vector2(50, 50)
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
			BuildManager.select_building("power_wind" if option == "Wind Power" else "water_tower")
		"specializations":
			if option == "Parks": BuildManager.select_building("park_small")
			else: status_label.text = option + " specialization is coming soon."
		"bulldoze":
			status_label.text = "Bulldoze mode selected. Tap Cancel to leave this tool."
			BuildManager.cancel_placement()
			var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
			if road_system: road_system.set_road_mode(false)

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
		status_label.text = "Road mode — tap the ground (50 §)"

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
