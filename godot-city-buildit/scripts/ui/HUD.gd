extends CanvasLayer

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")
const LevelUpEffectScript = preload("res://scripts/ui/LevelUpEffect.gd")

# The atlas does not currently contain a banknote glyph, so SimCash uses this
# small locally drawn vector icon. All other status icons come from IconAtlas.
class BanknoteGlyph extends Control:
	func _draw() -> void:
		var note := Rect2(Vector2(5.0, 12.0), Vector2(size.x - 10.0, size.y - 24.0))
		draw_rect(note, Color("#4CD964"), true)
		draw_rect(note, Color("#D9FFE1"), false, 1.4)
		draw_circle(size * 0.5, 10.0, Color("#D9FFE1"))
		draw_line(Vector2(12, 18), Vector2(20, 18), Color("#D9FFE1"), 2.4)
		draw_line(Vector2(size.x - 20, size.y - 18), Vector2(size.x - 12, size.y - 18), Color("#D9FFE1"), 2.4)

@onready var status_label: Label = $StatusLabel

var submenu: GridContainer
var active_category := ""
var level_label: Label
var population_label: Label
var happiness_label: Label
var xp_progress: ProgressBar
var xp_text: Label
var storage_label: Label
var simoleons_label: Label
var simcash_label: Label
var keys_label: Label
var _last_simcash_value := -1
var _ui_scale := 1.0
var _level_up_queue: Array[Dictionary] = []
var _level_up_effect = null
var _level_up_camera: Camera3D
var _level_up_camera_origin: Vector3 = Vector3.ZERO
var _level_up_shake_elapsed := 0.0

func _ready() -> void:
	# Keep the existing gameplay signal wiring intact.
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	HappinessManager.immigrants_arrived.connect(_on_immigrants_arrived)
	HappinessManager.immigration_advice.connect(_on_immigration_advice)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up_rewarded.connect(_on_level_up_rewarded)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.keys_changed.connect(_on_keys_changed)
	StorageManager.storage_changed.connect(_on_storage_changed)
	BuildManager.placement_mode_changed.connect(_on_placement_mode)
	ServiceManager.power_changed.connect(_on_power_changed)
	ServiceManager.water_changed.connect(_on_water_changed)

	var viewport_size := get_viewport().get_visible_rect().size
	_ui_scale = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.62, 1.0)
	_build_top_hud()
	_build_toolbars()
	_update_all()
	status_label.text = "Tap Build, choose Residential, then place your first house beside a road."

func _build_top_hud() -> void:
	# Hide scene-authored legacy counters; build the reference's two-corner layout.
	for old_path in ["TopLeft", "TopRight"]:
		var old_node := get_node_or_null(old_path)
		if old_node:
			old_node.hide()
			old_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_hud := Control.new()
	top_hud.name = "TopHUD"
	top_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hud.z_index = 20
	add_child(top_hud)

	var left_stack := VBoxContainer.new()
	left_stack.name = "TopLeftStats"
	left_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_stack.position = Vector2(14, 10)
	left_stack.custom_minimum_size = Vector2(620, 210) * _ui_scale
	left_stack.add_theme_constant_override("separation", 5)
	left_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hud.add_child(left_stack)

	var top_stats := HBoxContainer.new()
	top_stats.name = "PrimaryCityStats"
	top_stats.add_theme_constant_override("separation", 8)
	top_stats.mouse_filter = Control.MOUSE_FILTER_PASS
	left_stack.add_child(top_stats)

	var level_badge := PanelContainer.new()
	level_badge.name = "LevelBadge"
	level_badge.custom_minimum_size = Vector2(112, 112) * _ui_scale
	level_badge.add_theme_stylebox_override("panel", _level_badge_style())
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_stats.add_child(level_badge)
	var level_overlay := Control.new()
	level_overlay.custom_minimum_size = Vector2(108, 108) * _ui_scale
	level_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_child(level_overlay)
	var level_icon := IconAtlas.make_icon("level", Vector2(96, 96) * _ui_scale)
	level_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_overlay.add_child(level_icon)
	level_label = Label.new()
	level_label.name = "LevelValue"
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", int(38 * _ui_scale))
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	level_label.add_theme_constant_override("shadow_offset_x", 2)
	level_label.add_theme_constant_override("shadow_offset_y", 2)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_overlay.add_child(level_label)

	population_label = _add_stat_bar(top_stats, "population", "0", Color("#4BA3FF"), "City population", 180)
	storage_label = _add_stat_bar(top_stats, "storage", "0/30", Color("#5BB8F5"), "City storage", 170)

	var happiness_row := HBoxContainer.new()
	happiness_row.name = "HappinessStatRow"
	happiness_row.add_theme_constant_override("separation", 8)
	happiness_row.mouse_filter = Control.MOUSE_FILTER_PASS
	left_stack.add_child(happiness_row)
	happiness_label = _add_stat_bar(happiness_row, "happiness", "100%", Color("#A8E62E"), "Citizen happiness", 220)

	var xp_row := HBoxContainer.new()
	xp_row.name = "ExperienceRow"
	xp_row.add_theme_constant_override("separation", 8)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_stack.add_child(xp_row)
	xp_text = _make_hud_value("0 / %d XP" % GameManager.get_xp_needed(), int(16 * _ui_scale))
	xp_text.custom_minimum_size = Vector2(105, 24) * _ui_scale
	xp_row.add_child(xp_text)
	xp_progress = ProgressBar.new()
	xp_progress.name = "ExperienceProgress"
	xp_progress.custom_minimum_size = Vector2(210, 18) * _ui_scale
	xp_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_progress.min_value = 0
	xp_progress.max_value = GameManager.get_xp_needed()
	xp_progress.value = GameManager.experience
	xp_progress.show_percentage = false
	xp_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_progress)

	var right_stack := VBoxContainer.new()
	right_stack.name = "TopRightCurrencies"
	right_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_stack.anchor_left = 1.0
	right_stack.anchor_right = 1.0
	right_stack.offset_left = -340
	right_stack.offset_right = -12
	right_stack.offset_top = 10
	right_stack.offset_bottom = 238
	right_stack.add_theme_constant_override("separation", 7)
	right_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hud.add_child(right_stack)

	simoleons_label = _add_currency_bar(right_stack, "simoleons", "5000", Color("#FFD24A"), "Simoleons", true)
	_build_simcash_capsule(right_stack)
	var keys_row := HBoxContainer.new()
	keys_row.name = "PremiumCurrencyRow"
	keys_row.add_theme_constant_override("separation", 8)
	keys_row.mouse_filter = Control.MOUSE_FILTER_PASS
	right_stack.add_child(keys_row)
	keys_label = _add_currency_bar(keys_row, "golden_key", "5", Color("#FFC107"), "Golden Keys", false, 100)

func _add_stat_bar(parent: Container, icon_name: String, initial_text: String, tint: Color, hint: String, width: float) -> Label:
	var bar := PanelContainer.new()
	bar.name = icon_name.capitalize() + "StatBar"
	bar.custom_minimum_size = Vector2(width * _ui_scale, 64 * _ui_scale)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = hint
	bar.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(bar)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(content)
	var icon := IconAtlas.make_icon(icon_name, Vector2(44, 44) * _ui_scale)
	icon.modulate = tint
	content.add_child(icon)
	var value := _make_hud_value(initial_text, int(25 * _ui_scale))
	content.add_child(value)
	return value

func _add_currency_bar(parent: Container, icon_name: String, initial_text: String, tint: Color, hint: String, show_plus: bool, width: float = 214.0) -> Label:
	var bar := PanelContainer.new()
	bar.name = icon_name.capitalize() + "CurrencyBar"
	bar.custom_minimum_size = Vector2(width * _ui_scale, 64 * _ui_scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = hint
	bar.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(bar)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(content)
	var icon := IconAtlas.make_icon(icon_name, Vector2(44, 44) * _ui_scale)
	icon.modulate = tint
	content.add_child(icon)
	var value := _make_hud_value(initial_text, int(25 * _ui_scale))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(value)
	if show_plus:
		var add_button := _make_currency_plus_button(hint)
		content.add_child(add_button)
	return value

func _make_hud_value(initial_text: String, font_size: int) -> Label:
	var value := Label.new()
	value.text = initial_text
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	value.add_theme_constant_override("shadow_offset_x", 2)
	value.add_theme_constant_override("shadow_offset_y", 2)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value

func _level_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.17, 0.88)
	style.border_color = Color(1, 1, 1, 0.35)
	style.set_border_width_all(4)
	style.set_corner_radius_all(40)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _make_currency_plus_button(hint: String) -> Button:
	var button := Button.new()
	button.name = "CurrencyAddButton"
	button.text = "+"
	button.custom_minimum_size = Vector2(44, 44) * _ui_scale
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = hint + " shop"
	button.add_theme_font_size_override("font_size", int(30 * _ui_scale))
	_add_theme_color(button, Color("#4CD964"))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_on_currency_plus_pressed.bind(hint))
	return button
func _add_icon_capsule(parent: HBoxContainer, icon_name: String, initial_text: String, tint: Color, hint: String) -> Label:
	return _add_stat_bar(parent, icon_name, initial_text, tint, hint, 150)
func _build_simcash_capsule(parent: Container) -> void:
	var bar := PanelContainer.new()
	bar.name = "SimCashCurrencyBar"
	bar.custom_minimum_size = Vector2(248, 64) * _ui_scale
	bar.tooltip_text = "SimCash"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(bar)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(content)
	var glyph := BanknoteGlyph.new()
	glyph.custom_minimum_size = Vector2(44, 44) * _ui_scale
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(glyph)
	simcash_label = _make_hud_value(str(EconomyManager.sim_cash), int(25 * _ui_scale))
	simcash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	simcash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(simcash_label)
	content.add_child(_make_currency_plus_button("SimCash"))
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
	for old_path in ["LeftMenu", "LeftToolbar"]:
		var old_node := get_node_or_null(old_path)
		if old_node:
			old_node.queue_free()

	var viewport_size := get_viewport().get_visible_rect().size
	var category_width := 86.0
	var category_height := 70.0
	var panel_height := 4.0 * category_height + 3.0 * 5.0 + 62.0

	var toolbar := PanelContainer.new()
	toolbar.name = "RightToolbar"
	toolbar.anchor_left = 1.0
	toolbar.anchor_right = 1.0
	toolbar.anchor_top = 0.5
	toolbar.anchor_bottom = 0.5
	toolbar.offset_left = -290.0
	toolbar.offset_right = -92.0
	toolbar.offset_top = -panel_height * 0.5
	toolbar.offset_bottom = panel_height * 0.5
	toolbar.add_theme_stylebox_override("panel", _toolbar_style(Color(0.035, 0.075, 0.105, 0.96), Color(0.65, 0.82, 0.92, 0.48)))
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	toolbar.z_index = 60
	add_child(toolbar)
	toolbar.hide()

	var dock_content := VBoxContainer.new()
	dock_content.add_theme_constant_override("separation", 7)
	dock_content.mouse_filter = Control.MOUSE_FILTER_PASS
	toolbar.add_child(dock_content)

	var dock_header := HBoxContainer.new()
	dock_header.name = "BuildMenuHeader"
	dock_header.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_header.add_theme_constant_override("separation", 6)
	dock_content.add_child(dock_header)

	var dock_title := Label.new()
	dock_title.text = "BUILD"
	dock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dock_title.add_theme_color_override("font_color", Color("#F4F8FC"))
	dock_title.add_theme_font_size_override("font_size", 16)
	dock_header.add_child(dock_title)

	var close_dock := Button.new()
	close_dock.name = "CloseBuildMenu"
	close_dock.text = "X"
	close_dock.custom_minimum_size = Vector2(34, 32)
	close_dock.tooltip_text = "Close Build Menu"
	close_dock.focus_mode = Control.FOCUS_NONE
	close_dock.add_theme_font_size_override("font_size", 18)
	close_dock.add_theme_color_override("font_color", Color.WHITE)
	close_dock.add_theme_stylebox_override("normal", _toolbar_style(Color(0.55, 0.16, 0.16, 0.9), Color(1.0, 0.55, 0.45, 0.9)))
	close_dock.add_theme_stylebox_override("hover", _toolbar_style(Color(0.78, 0.20, 0.18, 1.0), Color.WHITE))
	close_dock.pressed.connect(_close_build_menu)
	dock_header.add_child(close_dock)

	var toolbar_items := GridContainer.new()
	toolbar_items.name = "RightToolbarItems"
	toolbar_items.columns = 2
	toolbar_items.add_theme_constant_override("h_separation", 5)
	toolbar_items.add_theme_constant_override("v_separation", 5)
	toolbar_items.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock_content.add_child(toolbar_items)

	var tools := [
		["road", "Road"],
		["residential", "Residential"],
		["commercial", "Commercial"],
		["industrial", "Industrial"],
		["services", "Services"],
		["parks", "Parks"],
		["bulldoze", "Bulldoze"]
	]
	for item in tools:
		var button := _make_category_button(str(item[0]), str(item[1]), Vector2(category_width, category_height))
		button.name = "Tool_" + str(item[0]).capitalize()
		toolbar_items.add_child(button)
		var category_id := "park" if item[0] == "parks" else str(item[0])
		button.pressed.connect(_on_category_pressed.bind(category_id))

	var build_toggle := Button.new()
	build_toggle.name = "BuildMenuButton"
	build_toggle.anchor_left = 1.0
	build_toggle.anchor_right = 1.0
	build_toggle.anchor_top = 0.5
	build_toggle.anchor_bottom = 0.5
	build_toggle.offset_left = -88.0
	build_toggle.offset_right = -8.0
	build_toggle.offset_top = -42.0
	build_toggle.offset_bottom = 42.0
	build_toggle.custom_minimum_size = Vector2(80, 84)
	build_toggle.tooltip_text = "Open Build Menu"
	build_toggle.focus_mode = Control.FOCUS_NONE
	build_toggle.z_index = 61
	build_toggle.add_theme_stylebox_override("normal", _toolbar_style(Color(0.08, 0.19, 0.26, 0.98), Color("#FFC857")))
	build_toggle.add_theme_stylebox_override("hover", _toolbar_style(Color(0.13, 0.30, 0.40, 1.0), Color("#FFE19A")))
	build_toggle.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.20, 0.34, 0.38, 1.0), Color("#FFE19A")))
	var build_content := VBoxContainer.new()
	build_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_content.alignment = BoxContainer.ALIGNMENT_CENTER
	build_content.add_theme_constant_override("separation", 1)
	build_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_toggle.add_child(build_content)
	var build_icon := IconAtlas.make_icon("hard_hat", Vector2(42, 42))
	build_content.add_child(build_icon)
	var build_label := Label.new()
	build_label.name = "BuildButtonLabel"
	build_label.text = "BUILD"
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.add_theme_color_override("font_color", Color.WHITE)
	build_label.add_theme_font_size_override("font_size", 13)
	build_content.add_child(build_label)
	add_child(build_toggle)
	build_toggle.pressed.connect(_toggle_category_menu)

	var actions := HBoxContainer.new()
	actions.name = "BottomActions"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = 12
	actions.offset_top = -104
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

	submenu = GridContainer.new()
	submenu.name = "ToolSubmenu"
	submenu.anchor_left = 1.0
	submenu.anchor_right = 1.0
	submenu.anchor_top = 0.5
	submenu.anchor_bottom = 0.5
	submenu.columns = 2
	submenu.add_theme_constant_override("h_separation", 6)
	submenu.add_theme_constant_override("v_separation", 6)
	submenu.z_index = 62
	add_child(submenu)
	submenu.hide()

func _make_category_button(icon_name: String, label_text: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.tooltip_text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.07, 0.14, 0.19, 0.72), Color(0.30, 0.48, 0.58, 0.50)))
	button.add_theme_stylebox_override("hover", _toolbar_style(Color(0.15, 0.30, 0.39, 0.96), Color("#FFC857")))
	button.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.22, 0.34, 0.37, 1.0), Color("#FFE19A")))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var icon := IconAtlas.make_icon(icon_name, Vector2(38, 38))
	content.add_child(icon)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#F4F8FC"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 12)
	content.add_child(label)
	return button

func _make_icon_button(kind: String, hint: String, requested_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	var button_size := requested_size if requested_size != Vector2.ZERO else Vector2(112, 112) * _ui_scale
	button.custom_minimum_size = button_size
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
	button.add_theme_stylebox_override("hover", _toolbar_style(Color(0.16, 0.32, 0.43, 0.18), Color(0.55, 0.78, 0.9, 0.42)))
	button.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.95, 0.72, 0.28, 0.22), Color(0.98, 0.82, 0.48, 0.68)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := IconAtlas.make_icon(kind, button_size - Vector2(12, 12))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	if icon.texture == null:
		# Never substitute a font glyph: web fonts may not contain the symbol.
		icon.texture = IconAtlas.texture_for("fallback")
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

func _toggle_category_menu() -> void:
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar == null:
		push_error("[HUD] RightToolbar is missing; Build menu cannot open.")
		return
	if toolbar.visible or (submenu and submenu.visible):
		_close_build_menu()
		return
	toolbar.show()
	toolbar.z_index = 60
	toolbar.move_to_front()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "CLOSE"
	var build_button := get_node_or_null("BuildMenuButton") as Control
	if build_button:
		build_button.z_index = 61
		build_button.move_to_front()

func _close_build_menu() -> void:
	if submenu:
		submenu.hide()
	active_category = ""
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		toolbar.hide()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "BUILD"
	var build_button := get_node_or_null("BuildMenuButton") as Control
	if build_button:
		build_button.tooltip_text = "Open Build Menu"


func _on_category_pressed(category: String) -> void:
	if category == "park":
		_select_building_type("park_small")
		return
	if category == "bulldoze":
		_start_bulldoze_mode()
		return
	if active_category == category and submenu.visible:
		_close_building_submenu(false)
		return
	active_category = category
	_show_submenu(category)
	var category_toolbar := get_node_or_null("RightToolbar")
	if category_toolbar:
		category_toolbar.hide()

func _show_submenu(category: String) -> void:
	for child in submenu.get_children():
		submenu.remove_child(child)
		child.queue_free()

	var options: Array = []
	if category == "road":
		options = [["road_build", "Build Road", 1], ["bulldoze_road", "Bulldoze Road", 1]]
	else:
		var definition_category := "service" if category == "services" else category
		for type_id in BuildManager.building_types:
			var definition: Dictionary = BuildManager.building_types[type_id]
			if str(definition.get("category", "")) == definition_category:
				options.append([str(type_id), str(definition.get("name", type_id)), int(definition.get("level", 1))])

	if options.is_empty():
		status_label.text = "No build items are available in this category."
		_close_building_submenu(false)
		return

	submenu.show()
	var viewport_size := get_viewport().get_visible_rect().size
	var columns := 2 if viewport_size.x < 1200.0 else 3
	var panel_width := 292.0 if columns == 2 else 390.0
	var item_height := 58.0
	var rows := ceili(float(options.size() + 2) / float(columns))
	var panel_height := float(rows) * item_height + float(rows - 1) * 6.0
	submenu.columns = columns
	submenu.offset_left = -(panel_width + 12.0)
	submenu.offset_right = -12.0
	submenu.offset_top = -panel_height * 0.5
	submenu.offset_bottom = panel_height * 0.5
	var item_width := (panel_width - 12.0 - 6.0 * float(columns - 1)) / float(columns)

	for option in options:
		var type_id: String = str(option[0])
		var title: String = str(option[1])
		var required_level: int = int(option[2])
		var locked := GameManager.level < required_level
		var choice := Button.new()
		choice.name = type_id
		choice.text = title
		if locked:
			choice.text += "\\nUnlocked at Level %d" % required_level
		choice.custom_minimum_size = Vector2(item_width, item_height)
		choice.focus_mode = Control.FOCUS_NONE
		choice.tooltip_text = ("Unlocked at Level %d" % required_level) if locked else title
		choice.add_theme_font_size_override("font_size", 13)
		choice.add_theme_color_override("font_color", Color("#F4F8FC"))
		choice.add_theme_color_override("font_disabled_color", Color("#F4F8FC"))
		choice.add_theme_stylebox_override("normal", _toolbar_style(Color(0.10, 0.18, 0.23, 0.97), Color(0.55, 0.78, 0.9, 0.7)))
		choice.add_theme_stylebox_override("hover", _toolbar_style(Color(0.18, 0.34, 0.42, 0.99), Color(0.95, 0.82, 0.48, 0.95)))
		choice.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.30, 0.42, 0.28, 0.99), Color(0.95, 0.82, 0.48, 1.0)))
		submenu.add_child(choice)
		choice.pressed.connect(_on_submenu_option.bind(category, type_id))

	var back_button := Button.new()
	back_button.name = "BackToCategories"
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(item_width, item_height)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.pressed.connect(_close_building_submenu.bind(false))
	submenu.add_child(back_button)

	var close_button := Button.new()
	close_button.name = "CloseSubmenu"
	close_button.text = "CLOSE  X"
	close_button.custom_minimum_size = Vector2(item_width, item_height)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = "Close Build Menu"
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.pressed.connect(_close_build_menu)
	submenu.add_child(close_button)


func _select_building_type(type_id: String) -> void:
	if not BuildManager.building_types.has(type_id):
		status_label.text = "This building is not available yet."
		return
	var definition: Dictionary = BuildManager.building_types[type_id]
	var required_level := int(definition.get("level", 1))
	if GameManager.level < required_level:
		status_label.text = "Unlocked at Level %d." % required_level
		return
	if definition.get("category", "") == "industrial" and BuildManager.factory_count >= LevelProgression.max_factories:
		status_label.text = "Factory limit reached (%d). Upgrade your city to unlock more factory slots." % LevelProgression.max_factories
		return
	_set_tool_modes_off()
	BuildManager.select_building(type_id)
	if BuildManager.is_placing:
		_close_building_submenu(false)
	else:
		status_label.text = "Could not enter placement mode for %s." % str(definition.get("name", type_id))

func _on_building_choice_pressed(type_id: String) -> void:
	# Keep the existing test and scene callback contract while routing through
	# the same level, factory-capacity and placement checks as every menu item.
	_select_building_type(type_id)

func _set_tool_modes_off() -> void:
	_set_bulldozer_indicator(false)
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	if city_input:
		city_input.set_bulldoze_mode(false)
		city_input.set_bulldoze_road_mode(false)
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system:
		road_system.set_road_mode(false)

func _set_bulldozer_indicator(active: bool) -> void:
	var indicator := get_node_or_null("BulldozerModeIndicator")
	if active:
		if indicator == null:
			var badge := PanelContainer.new()
			badge.name = "BulldozerModeIndicator"
			badge.anchor_left = 0.5
			badge.anchor_right = 0.5
			badge.offset_left = -112
			badge.offset_right = 112
			badge.offset_top = 12
			badge.offset_bottom = 52
			badge.z_index = 40
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", _toolbar_style(Color(0.30, 0.12, 0.06, 0.94), Color("#FFC247")))
			var label := Label.new()
			label.text = "BULLDOZER ACTIVE"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color("#FFD76A"))
			label.add_theme_font_size_override("font_size", 18)
			badge.add_child(label)
			add_child(badge)
			indicator = badge
		indicator.show()
	elif indicator:
		indicator.hide()

func _start_bulldoze_mode() -> void:
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	if city_input:
		city_input.set_bulldoze_mode(true)
	_close_build_menu()
	_set_bulldozer_indicator(true)
	status_label.text = "Bulldozer active — tap a building twice to demolish. Tap a road to remove it. Press X to cancel."

func _start_bulldoze_road_mode() -> void:
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	if city_input:
		city_input.set_bulldoze_road_mode(true)
	_close_build_menu()
	_set_bulldozer_indicator(true)
	status_label.text = "Bulldozer active — tap a road to remove it. Press X to cancel."

func _on_submenu_option(category: String, option_id: String) -> void:
	if category == "road":
		if option_id == "road_build":
			_set_tool_modes_off()
			BuildManager.cancel_placement()
			var scene := get_tree().current_scene
			var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
			if road_system:
				road_system.set_road_mode(true)
				status_label.text = "Road mode — tap or drag from the highway (50 Simoleons per tile). Press X to exit."
			else:
				status_label.text = "Road system is unavailable."
			_close_build_menu()
		elif option_id == "bulldoze_road":
			_start_bulldoze_road_mode()
	else:
		_select_building_type(option_id)

func _close_building_submenu(cancel_placement: bool = true) -> void:
	if submenu:
		submenu.hide()
	active_category = ""
	if cancel_placement:
		BuildManager.cancel_placement()
	var category_toolbar := get_node_or_null("RightToolbar") as Control
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if not BuildManager.is_placing:
		if category_toolbar:
			category_toolbar.show()
		if build_label:
			build_label.text = "CLOSE"
		if build_button_node:
			build_button_node.tooltip_text = "Close Build Menu"
	else:
		if category_toolbar:
			category_toolbar.hide()
		if build_label:
			build_label.text = "BUILD"
		if build_button_node:
			build_button_node.tooltip_text = "Open Build Menu"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
		return
	if not submenu or not submenu.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not submenu.get_global_rect().has_point(event.position):
			_close_building_submenu(false)
	elif event is InputEventScreenTouch and event.pressed:
		if not submenu.get_global_rect().has_point(event.position):
			_close_building_submenu(false)

func _update_all() -> void:
	_on_level_changed(GameManager.level)
	_on_population_changed(GameManager.population)
	_on_happiness_changed(GameManager.happiness)
	_on_xp_changed(GameManager.experience, GameManager.get_xp_needed())
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
	_on_xp_changed(GameManager.experience, GameManager.get_xp_needed())

func _on_population_changed(population: int) -> void:
	if population_label: population_label.text = _format_count(population)

func _on_immigrants_arrived(amount: int, city_population: int) -> void:
	if status_label:
		status_label.text = "+%d new residents moved in! City population: %s" % [amount, _format_count(city_population)]

func _on_immigration_advice(message: String) -> void:
	if status_label:
		status_label.text = message

func _on_happiness_changed(value: float) -> void:
	if happiness_label:
		happiness_label.text = "%d%%" % roundi(value)

func _on_xp_changed(xp: int, needed: int) -> void:
	if xp_text:
		xp_text.text = "%d / %d XP" % [xp, needed]
	if xp_progress:
		xp_progress.max_value = maxi(1, needed)
		xp_progress.value = clampi(xp, 0, needed)

func _on_level_up_rewarded(new_level: int, reward: int, keys: int) -> void:
	# level_changed updates the badge; reward signal is the single celebration trigger.
	# Queue multiple level-ups from one XP grant so every reward is celebrated exactly once.
	_level_up_queue.append({
		"level": new_level,
		"simoleons": reward,
		"keys": keys
	})
	_start_next_level_up_effect()

func _start_next_level_up_effect() -> void:
	if is_instance_valid(_level_up_effect) or _level_up_queue.is_empty():
		return

	var reward: Dictionary = _level_up_queue.pop_front()
	_level_up_effect = LevelUpEffectScript.new()
	_level_up_effect.name = "LevelUpCelebration"
	add_child(_level_up_effect)
	_level_up_effect.finished.connect(_on_level_up_effect_finished)
	_level_up_effect.play(
		int(reward["level"]),
		int(reward["simoleons"]),
		int(reward["keys"])
	)

	_level_up_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_level_up_camera):
		_level_up_camera_origin = _level_up_camera.position
		_level_up_shake_elapsed = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(_level_up_effect):
		return
	if not is_instance_valid(_level_up_camera):
		return

	# Tiny damped local offset; restore the exact camera position when the overlay ends.
	_level_up_shake_elapsed += delta
	var envelope := exp(-_level_up_shake_elapsed * 2.0)
	var shake := Vector3(
		sin(_level_up_shake_elapsed * 61.0) * 0.12,
		cos(_level_up_shake_elapsed * 47.0) * 0.08,
		0.0
	) * envelope
	_level_up_camera.position = _level_up_camera_origin + shake

func _on_level_up_effect_finished() -> void:
	if is_instance_valid(_level_up_camera):
		_level_up_camera.position = _level_up_camera_origin
	_level_up_camera = null
	if is_instance_valid(_level_up_effect):
		_level_up_effect.queue_free()
	_level_up_effect = null
	_start_next_level_up_effect()

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
		status_label.tooltip_text = "Power usage: %d / %d  |  Water usage: %d / %d" % [
			ServiceManager.used_power, ServiceManager.total_power, used, total
		]

func _format_count(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)

func _on_currency_plus_pressed(currency: String) -> void:
	status_label.text = currency + " purchases are not available yet."

func _on_placement_mode(active: bool) -> void:
	if active: status_label.text = "Placement mode — tap a clear plot beside a road. Cancel with X."
	else: status_label.text = ""

func _on_roads_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.set_road_mode(true)
		status_label.text = "Road mode — tap or drag from the highway (50 Simoleons per tile)"

func _on_storage_pressed() -> void:
	BuildManager.cancel_placement()
	var items = StorageManager.get_all_items()
	if items.is_empty(): status_label.text = "Storage is empty."
	else:
		var inventory_text := ""
		for item_id in items: inventory_text += str(item_id) + " x " + str(items[item_id]) + "  "
		status_label.text = inventory_text

func _on_trade_pressed() -> void:
	BuildManager.cancel_placement()
	status_label.text = "Trade — %d active orders." % TradeManager.get_orders().size()

func _on_cancel_pressed() -> void:
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	var was_bulldozing: bool = city_input != null and (city_input.bulldoze_mode or city_input.bulldoze_road_mode)
	var was_moving: bool = BuildManager.is_moving
	if was_moving:
		BuildManager.cancel_move()
		if city_input:
			city_input.move_pointer_id = -999
			city_input.pointer_start.clear()
			city_input.pointer_moved.clear()
			city_input.pointer_hold_elapsed.clear()
	_set_bulldozer_indicator(false)
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	if submenu:
		submenu.hide()
	active_category = ""
	var category_toolbar := get_node_or_null("RightToolbar") as Control
	if category_toolbar:
		category_toolbar.show()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "CLOSE"
	if build_button_node:
		build_button_node.tooltip_text = "Close Build Menu"
	if was_moving:
		status_label.text = "Move cancelled. Building returned to its original location."
	else:
		status_label.text = "Bulldozer cancelled." if was_bulldozing else "Cancelled."

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
