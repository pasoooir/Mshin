extends CanvasLayer

const Icons = preload("res://scripts/ui/Icons.gd")
const LevelUpEffectScript = preload("res://scripts/ui/LevelUpEffect.gd")

const SERVICE_GROUPS := [
	{"id":"power", "label":"Power", "buildings":["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear"]},
	{"id":"water", "label":"Water", "buildings":["water_tower", "water_pump"]},
	{"id":"sewage", "label":"Sewage", "buildings":["sewage_small", "sewage_basic", "sewage_deluxe"]},
	{"id":"waste", "label":"Waste", "buildings":["waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling"]},
	{"id":"fire", "label":"Fire", "buildings":["fire_station_small", "fire_station", "fire_station_deluxe"]},
	{"id":"police", "label":"Police", "buildings":["police_small", "police_basic", "police_precinct"]},
	{"id":"health", "label":"Health", "buildings":["clinic_small", "clinic", "hospital"]},
	{"id":"government", "label":"Government", "buildings":["town_hall"]}
]
const SPECIALIZATION_GROUPS := [
	{"id":"parks", "label":"Parks", "buildings":["park_small"]},
	{"id":"education", "label":"Education", "buildings":[]},
	{"id":"transportation", "label":"Transportation", "buildings":[]},
	{"id":"entertainment", "label":"Entertainment", "buildings":[]},
	{"id":"gambling", "label":"Gambling", "buildings":[]},
	{"id":"landmarks", "label":"Landmarks", "buildings":[]},
	{"id":"worship", "label":"Worship", "buildings":[]}
]

# The atlas does not currently contain a banknote glyph, so SimCash uses this
# SimCash and all other HUD glyphs use local transparent PNG assets.
class BanknoteGlyph extends Control:
	func _draw() -> void:
		var note := Rect2(Vector2(5.0, 12.0), Vector2(size.x - 10.0, size.y - 24.0))
		draw_rect(note, Color("#4CD964"), true)
		draw_rect(note, Color("#D9FFE1"), false, 1.4)
		draw_circle(size * 0.5, 10.0, Color("#D9FFE1"))
		draw_line(Vector2(12, 18), Vector2(20, 18), Color("#D9FFE1"), 2.4)
		draw_line(Vector2(size.x - 20, size.y - 18), Vector2(size.x - 12, size.y - 18), Color("#D9FFE1"), 2.4)

class LockGlyph extends Control:
	func _ready() -> void:
		name = "LockGlyph"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var lock_color := Color("#FFD98A")
		var body := Rect2(Vector2(size.x * 0.18, size.y * 0.48), Vector2(size.x * 0.64, size.y * 0.42))
		draw_rect(body, lock_color, true)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.49), size.x * 0.22, PI, TAU, 16, lock_color, maxf(1.5, size.x * 0.09))

@onready var status_label: Label = $StatusLabel

var submenu: HBoxContainer
var submenu_scroll: ScrollContainer
var bottom_actions: HBoxContainer
var active_service_group := ""
var active_specialization_group := ""
var submenu_level := 0
var active_category := ""
var level_label: Label
var population_label: Label
var happiness_label: Label
var xp_progress: ProgressBar
var xp_text: Label
var storage_label: Label
var storage_panel: PanelContainer
var production_panel: PanelContainer
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
var _production_timer_labels: Array[Label] = []
var _production_building: Building = null
var _production_tick_accum := 0.0
var catalog_info_panel: PanelContainer
var catalog_base_bar: PanelContainer
var catalog_advisor: Control
var context_header: PanelContainer
var context_header_title: Label
var context_header_subtitle: Label
var context_header_icons: HBoxContainer
var _catalog_selected_type := ""

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
	_ui_scale = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.90, 1.20)
	_build_top_hud()
	_build_toolbars()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout()
	_update_all()
	status_label.text = "Tap Build, choose Residential, then place your first house beside a road."

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < 900.0
	var tablet := viewport_size.x >= 900.0 and viewport_size.x < 1440.0
	var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.90, 1.20)
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		var width := (156.0 if compact else (168.0 if tablet else 184.0)) * scale_factor
		var height := minf(viewport_size.y - 176.0 * scale_factor, 640.0 * scale_factor)
		if not compact and not tablet:
			# Desktop gets a persistent left navigation rail; mobile/tablet keep it on the right.
			toolbar.anchor_left = 0.0
			toolbar.anchor_right = 0.0
			toolbar.offset_left = 12.0 * scale_factor
			toolbar.offset_right = 12.0 * scale_factor + width
		else:
			toolbar.anchor_left = 1.0
			toolbar.anchor_right = 1.0
			toolbar.offset_left = -width - 156.0 * scale_factor
			toolbar.offset_right = -156.0 * scale_factor
		toolbar.offset_top = -height * 0.5
		toolbar.offset_bottom = height * 0.5
	var left_stats := get_node_or_null("TopHUD/TopLeftStats") as Control
	if left_stats:
		left_stats.position.x = (174.0 if not compact and not tablet else 14.0) * scale_factor
	var submenu_control := get_node_or_null("ToolSubmenuScroll") as Control
	if submenu_control:
		submenu_control.anchor_left = 0.15
		submenu_control.anchor_right = 0.95
		submenu_control.anchor_top = 1.0
		submenu_control.anchor_bottom = 1.0
		submenu_control.offset_left = 0.0
		submenu_control.offset_right = 0.0
		submenu_control.offset_top = -202.0 * scale_factor
		submenu_control.offset_bottom = -8.0 * scale_factor
	if catalog_base_bar:
		catalog_base_bar.anchor_left = 0.15
		catalog_base_bar.anchor_right = 0.95
		catalog_base_bar.anchor_top = 1.0
		catalog_base_bar.anchor_bottom = 1.0
		catalog_base_bar.offset_left = 0.0
		catalog_base_bar.offset_right = 0.0
		catalog_base_bar.offset_top = -94.0 * scale_factor
		catalog_base_bar.offset_bottom = -8.0 * scale_factor
	if catalog_advisor:
		catalog_advisor.anchor_left = 0.0
		catalog_advisor.anchor_right = 0.15
		catalog_advisor.anchor_top = 1.0
		catalog_advisor.anchor_bottom = 1.0
		catalog_advisor.offset_left = 0.0
		catalog_advisor.offset_right = 0.0
		catalog_advisor.offset_top = -282.0 * scale_factor
		catalog_advisor.offset_bottom = -2.0 * scale_factor
	var catalog_close := get_node_or_null("CatalogCloseButton") as Control
	if catalog_close:
		catalog_close.anchor_left = 0.95
		catalog_close.anchor_right = 1.0
		catalog_close.anchor_top = 1.0
		catalog_close.anchor_bottom = 1.0
		catalog_close.offset_left = 0.0
		catalog_close.offset_right = -8.0 * scale_factor
		catalog_close.offset_top = -94.0 * scale_factor
		catalog_close.offset_bottom = -8.0 * scale_factor
	if context_header:
		var header_width := minf(viewport_size.x * 0.46, 600.0 * scale_factor)
		context_header.anchor_left = 0.5
		context_header.anchor_right = 0.5
		context_header.anchor_top = 0.0
		context_header.anchor_bottom = 0.0
		context_header.offset_left = -header_width * 0.5
		context_header.offset_right = header_width * 0.5
		context_header.offset_top = 76.0 * scale_factor
		context_header.offset_bottom = 230.0 * scale_factor
	var actions := get_node_or_null("BottomActions") as Control
	if actions:
		var half_actions := minf(viewport_size.x * 0.34, 300.0 * scale_factor)
		actions.offset_left = -half_actions
		actions.offset_right = half_actions
		actions.offset_top = -112.0 * scale_factor
		actions.offset_bottom = -12.0 * scale_factor

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
	var level_icon := Icons.make_icon("level", Vector2(144, 144) * _ui_scale)
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

	_build_context_header(top_hud)

func _build_context_header(parent: Control) -> void:
	context_header = PanelContainer.new()
	context_header.name = "TopCenterContext"
	context_header.anchor_left = 0.5
	context_header.anchor_right = 0.5
	context_header.offset_left = -280
	context_header.offset_right = 280
	context_header.offset_top = 76
	context_header.offset_bottom = 230
	context_header.z_index = 25
	context_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.08, 0.13, 0.19, 0.82)
	glass.border_color = Color(0.78, 0.89, 0.96, 0.24)
	glass.set_border_width_all(1)
	glass.set_corner_radius_all(16)
	glass.shadow_color = Color(0, 0, 0, 0.20)
	glass.shadow_size = 8
	glass.content_margin_left = 16
	glass.content_margin_right = 16
	glass.content_margin_top = 8
	glass.content_margin_bottom = 8
	context_header.add_theme_stylebox_override("panel", glass)
	parent.add_child(context_header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	context_header.add_child(stack)
	context_header_title = Label.new()
	context_header_title.name = "ContextTitle"
	context_header_title.text = "CITY BUILDING"
	context_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_header_title.add_theme_color_override("font_color", Color.WHITE)
	context_header_title.add_theme_font_size_override("font_size", int(25 * _ui_scale))
	stack.add_child(context_header_title)
	context_header_subtitle = Label.new()
	context_header_subtitle.name = "ContextSubtitle"
	context_header_subtitle.text = "Choose a category to explore your city"
	context_header_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_header_subtitle.add_theme_color_override("font_color", Color("#DCEAF3"))
	context_header_subtitle.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	stack.add_child(context_header_subtitle)
	context_header_icons = HBoxContainer.new()
	context_header_icons.name = "ContextIconRow"
	context_header_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	context_header_icons.add_theme_constant_override("separation", 10)
	stack.add_child(context_header_icons)
	for icon_id in ["road", "residential", "commercial", "industrial", "services", "parks"]:
		context_header_icons.add_child(Icons.make_icon(icon_id, Vector2(30, 30) * _ui_scale))
	context_header.hide()

func _update_context_header(category: String, detail: String = "") -> void:
	if not is_instance_valid(context_header):
		return
	var labels := {
		"road": "ROADS & CONNECTIONS",
		"residential": "RESIDENTIAL",
		"commercial": "COMMERCIAL",
		"industrial": "INDUSTRIAL",
		"services": "CITY SERVICES",
		"specializations": "CITY SPECIALIZATIONS",
		"parks": "PARKS",
		"bulldoze": "CITY REDEVELOPMENT"
	}
	context_header_title.text = labels.get(category, category.replace("_", " ").to_upper())
	context_header_subtitle.text = detail if not detail.is_empty() else "Select a building to view its details and requirements"
	context_header.show()

func _add_stat_bar(parent: Container, icon_name: String, initial_text: String, tint: Color, hint: String, width: float) -> Label:
	var bar := PanelContainer.new()
	bar.name = icon_name.capitalize() + "StatBar"
	bar.custom_minimum_size = Vector2(width * _ui_scale, 96 * _ui_scale)
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
	var icon := Icons.make_icon(icon_name, Vector2(88, 88) * _ui_scale)
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
	var icon := Icons.make_icon(icon_name, Vector2(88, 88) * _ui_scale)
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
	button.custom_minimum_size = Vector2(88, 88) * _ui_scale
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
	bar.custom_minimum_size = Vector2(280, 96) * _ui_scale
	bar.tooltip_text = "SimCash"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _capsule_style())
	parent.add_child(bar)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(content)
	content.add_child(Icons.make_icon("money", Vector2(88, 88) * _ui_scale))
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
	var toolbar_width := 168.0 * _ui_scale
	var toolbar_height := minf(viewport_size.y - 176.0 * _ui_scale, 640.0 * _ui_scale)
	var toolbar := PanelContainer.new()
	toolbar.name = "RightToolbar"
	toolbar.anchor_left = 1.0
	toolbar.anchor_right = 1.0
	toolbar.anchor_top = 0.5
	toolbar.anchor_bottom = 0.5
	toolbar.offset_left = -toolbar_width - 112.0 * _ui_scale
	toolbar.offset_right = -112.0 * _ui_scale
	toolbar.offset_top = -toolbar_height * 0.5
	toolbar.offset_bottom = toolbar_height * 0.5
	toolbar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	toolbar.z_index = 60
	add_child(toolbar)
	toolbar.show()
	var category_scroll := ScrollContainer.new()
	category_scroll.name = "CategoryScroll"
	category_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	toolbar.add_child(category_scroll)
	var toolbar_items := VBoxContainer.new()
	toolbar_items.name = "RightToolbarItems"
	toolbar_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_items.add_theme_constant_override("separation", 5)
	category_scroll.add_child(toolbar_items)
	var tools := [
		["road", "Roads", "road"],
		["residential", "Residential", "residential"],
		["commercial", "Commercial", "commercial"],
		["industrial", "Industrial", "industrial"],
		["services", "Services", "services"],
		["specializations", "Specializations", "parks"],
		["bulldoze", "Bulldoze", "bulldoze"]
	]
	var category_height := clampf((toolbar_height - 24.0) / 7.0, 112.0 * _ui_scale, 132.0 * _ui_scale)
	for item in tools:
		var button := _make_category_button(str(item[2]), str(item[1]), Vector2(toolbar_width - 12.0, category_height))
		button.name = "Tool_" + str(item[0]).capitalize()
		button.toggle_mode = true
		toolbar_items.add_child(button)
		button.pressed.connect(_on_category_pressed.bind(str(item[0])))
	var build_toggle := Button.new()
	build_toggle.name = "BuildMenuButton"
	build_toggle.anchor_left = 1.0
	build_toggle.anchor_right = 1.0
	build_toggle.anchor_top = 0.5
	build_toggle.anchor_bottom = 0.5
	build_toggle.offset_left = -104.0 * _ui_scale
	build_toggle.offset_right = -8.0 * _ui_scale
	build_toggle.offset_top = -48.0 * _ui_scale
	build_toggle.offset_bottom = 48.0 * _ui_scale
	build_toggle.custom_minimum_size = Vector2(96, 96) * _ui_scale
	build_toggle.tooltip_text = "Close Build Menu"
	build_toggle.focus_mode = Control.FOCUS_NONE
	build_toggle.z_index = 61
	build_toggle.add_theme_stylebox_override("normal", _toolbar_style(Color("#EAF7FD"), Color("#B9D7E6")))
	build_toggle.add_theme_stylebox_override("hover", _toolbar_style(Color("#DDF3FC"), Color("#78C4E8")))
	build_toggle.add_theme_stylebox_override("pressed", _toolbar_style(Color("#C8EAF8"), Color("#4FAED8")))
	var build_content := VBoxContainer.new()
	build_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_content.alignment = BoxContainer.ALIGNMENT_CENTER
	build_content.add_theme_constant_override("separation", 1)
	build_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_toggle.add_child(build_content)
	var build_icon := Icons.make_icon("hard_hat", Vector2(108, 108) * _ui_scale)
	build_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_content.add_child(build_icon)
	var build_label := Label.new()
	build_label.name = "BuildButtonLabel"
	build_label.text = "BUILD"
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.add_theme_color_override("font_color", Color("#31566B"))
	build_label.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	build_content.add_child(build_label)
	add_child(build_toggle)
	build_toggle.pressed.connect(_toggle_category_menu)
	bottom_actions = HBoxContainer.new()
	bottom_actions.name = "BottomActions"
	bottom_actions.anchor_left = 0.5
	bottom_actions.anchor_right = 0.5
	bottom_actions.anchor_top = 1.0
	bottom_actions.anchor_bottom = 1.0
	bottom_actions.offset_left = -260.0 * _ui_scale
	bottom_actions.offset_right = 260.0 * _ui_scale
	bottom_actions.offset_top = -104.0 * _ui_scale
	bottom_actions.offset_bottom = -14.0 * _ui_scale
	bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_actions.add_theme_constant_override("separation", 10)
	bottom_actions.z_index = 62
	add_child(bottom_actions)
	for item in [["storage","Storage"],["trade","Trade"],["save","Save"]]:
		var button := _make_icon_button(item[0], item[1], Vector2(92, 82) * _ui_scale)
		bottom_actions.add_child(button)
		match item[0]:
			"storage": button.pressed.connect(_on_storage_pressed)
			"trade": button.pressed.connect(_on_trade_pressed)
			"save": button.pressed.connect(_on_save_pressed)
	catalog_base_bar = PanelContainer.new()
	catalog_base_bar.name = "CatalogBaseBar"
	catalog_base_bar.anchor_left = 0.15
	catalog_base_bar.anchor_right = 0.95
	catalog_base_bar.anchor_top = 1.0
	catalog_base_bar.anchor_bottom = 1.0
	catalog_base_bar.offset_top = -94.0 * _ui_scale
	catalog_base_bar.offset_bottom = -8.0 * _ui_scale
	catalog_base_bar.z_index = 61
	catalog_base_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalog_base_bar.add_theme_stylebox_override("panel", _catalog_bar_style())
	add_child(catalog_base_bar)
	catalog_base_bar.hide()
	submenu_scroll = ScrollContainer.new()
	submenu_scroll.name = "ToolSubmenuScroll"
	submenu_scroll.anchor_left = 0.15
	submenu_scroll.anchor_right = 0.95
	submenu_scroll.anchor_top = 1.0
	submenu_scroll.anchor_bottom = 1.0
	submenu_scroll.offset_left = 0.0
	submenu_scroll.offset_right = 0.0
	submenu_scroll.offset_top = -202.0 * _ui_scale
	submenu_scroll.offset_bottom = -8.0 * _ui_scale
	submenu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	submenu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	submenu_scroll.scroll_deadzone = 8
	submenu_scroll.follow_focus = false
	submenu_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	submenu_scroll.z_index = 63
	submenu_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(submenu_scroll)
	submenu = HBoxContainer.new()
	submenu.name = "ToolSubmenu"
	submenu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu.add_theme_constant_override("separation", 8)
	submenu.alignment = BoxContainer.ALIGNMENT_BEGIN
	submenu_scroll.add_child(submenu)
	_build_catalog_info_panel()
	_add_catalog_advisor()
	var catalog_close := Button.new()
	catalog_close.name = "CatalogCloseButton"
	catalog_close.text = "×"
	catalog_close.anchor_left = 0.95
	catalog_close.anchor_right = 1.0
	catalog_close.anchor_top = 1.0
	catalog_close.anchor_bottom = 1.0
	catalog_close.offset_left = 0.0
	catalog_close.offset_right = -8 * _ui_scale
	catalog_close.offset_top = -94 * _ui_scale
	catalog_close.offset_bottom = -8 * _ui_scale
	catalog_close.custom_minimum_size = Vector2(54, 86) * _ui_scale
	catalog_close.z_index = 66
	catalog_close.text = "×"
	catalog_close.add_theme_font_size_override("font_size", int(28 * _ui_scale))
	catalog_close.add_theme_color_override("font_color", Color("#526B7A"))
	catalog_close.add_theme_stylebox_override("normal", _catalog_close_style(false))
	catalog_close.add_theme_stylebox_override("hover", _catalog_close_style(true))
	catalog_close.add_theme_stylebox_override("pressed", _catalog_close_style(true))
	catalog_close.pressed.connect(_close_build_menu)
	add_child(catalog_close)
	catalog_close.hide()
	submenu.hide()
	submenu_scroll.hide()

func _make_category_button(icon_name: String, label_text: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.tooltip_text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _toolbar_style(Color("#F6FBFE"), Color("#D3E5EE")))
	button.add_theme_stylebox_override("hover", _toolbar_style(Color("#E5F5FC"), Color("#83C8E7")))
	button.add_theme_stylebox_override("pressed", _toolbar_style(Color("#D0EFFB"), Color("#5AAED2")))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var icon_size := maxf(96.0 * _ui_scale, minf(112.0 * _ui_scale, button_size.y * 0.82))
	var icon := Icons.make_icon(icon_name, Vector2(icon_size, icon_size))
	content.add_child(icon)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#31566B"))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.30))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", int(14 * _ui_scale))
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

	var icon := Icons.make_icon(kind, button_size - Vector2(12, 12))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	if icon.texture == null:
		# Never substitute a font glyph: web fonts may not contain the symbol.
		icon.texture = Icons.get_tex("ui", "placeholder")
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
		push_error("[HUD] RightToolbar is missing.")
		return
	if toolbar.visible:
		_close_build_menu()
		return
	toolbar.show()
	if bottom_actions:
		bottom_actions.show()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "BUILD"
	if build_button_node:
		build_button_node.tooltip_text = "Build menu"

func _close_build_menu() -> void:
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	_set_bulldozer_indicator(false)
	if submenu_scroll and submenu_scroll.visible:
		var catalog_exit := create_tween()
		catalog_exit.tween_property(submenu_scroll, "modulate:a", 0.0, 0.14)
		catalog_exit.tween_callback(submenu_scroll.hide)
	elif submenu_scroll:
		submenu_scroll.hide()
	if submenu:
		submenu.hide()
	var catalog_close := get_node_or_null("CatalogCloseButton") as Control
	if catalog_close:
		catalog_close.hide()
	if catalog_base_bar:
		catalog_base_bar.hide()
	if catalog_advisor:
		catalog_advisor.hide()
	if context_header:
		context_header.hide()
	var build_button := get_node_or_null("BuildMenuButton") as Control
	if build_button:
		build_button.show()
	_hide_building_info()
	active_category = ""
	active_service_group = ""
	active_specialization_group = ""
	submenu_level = 0
	_set_active_category_visuals("")
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		toolbar.hide()
	if bottom_actions:
		bottom_actions.show()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "BUILD"
	if build_button:
		build_button.tooltip_text = "Open Build Menu"

func _set_active_category_visuals(category: String) -> void:
	var items := get_node_or_null("RightToolbar/CategoryScroll/RightToolbarItems")
	if items == null:
		return
	for child in items.get_children():
		if child is Button:
			var button := child as Button
			button.button_pressed = button.name.to_lower() == ("tool_" + category).to_lower()

func _on_category_pressed(category: String) -> void:
	if active_category == category and submenu_scroll and submenu_scroll.visible:
		_close_build_menu()
		return
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	_set_bulldozer_indicator(false)
	active_category = category
	active_service_group = ""
	active_specialization_group = ""
	submenu_level = 1
	_set_active_category_visuals(category)
	if category == "bulldoze":
		_start_bulldoze_mode()
		return
	_show_submenu(category)

func _show_submenu(category: String) -> void:
	if submenu == null or submenu_scroll == null:
		return
	_clear_catalog_cards()
	_update_context_header(category)
	if category == "road":
		_add_submenu_button("road_build", "Build Road", "road_build", "50 / tile", false, "road")
		_add_submenu_button("road_upgrade", "Upgrade Road", "road_upgrade", "Coming later", true, "road")
		_add_submenu_button("bulldoze_road", "Bulldoze Road", "road_bulldoze", "Remove road", false, "road")
	elif category == "services":
		_show_group_options(SERVICE_GROUPS, "services")
	elif category == "specializations":
		_show_group_options(SPECIALIZATION_GROUPS, "specializations")
	else:
		var definition_category := "park" if category == "parks" else category
		for type_id in BuildManager.building_types:
			var definition: Dictionary = BuildManager.building_types[type_id]
			if str(definition.get("category", "")) != definition_category or bool(definition.get("legacy_only", false)):
				continue
			var title := str(definition.get("name", type_id))
			var detail := "%d coins · Lv %d" % [int(definition.get("cost", 0)), int(definition.get("level", 1))]
			var locked := false
			if definition_category == "industrial":
				var required_population := int(definition.get("population_required", 0))
				if required_population > GameManager.population:
					detail += " · Requires %s population" % _format_count(required_population)
					locked = true
				elif not BuildManager.can_build_another_factory():
					detail += " · Factory limit reached"
					locked = true
			_add_submenu_button(str(type_id), title, str(type_id), detail, locked, category, int(definition.get("level", 1)), locked)
	_finish_submenu_row()

func _show_group_options(groups: Array, parent_category: String) -> void:
	submenu_level = 1
	for group in groups:
		var group_id := str(group.get("id", ""))
		var group_label := str(group.get("label", group_id))
		var buildings: Array = group.get("buildings", [])
		_add_submenu_button("group_" + group_id, group_label, group_id, "Choose category" if not buildings.is_empty() else "Coming later", false, parent_category, 1, buildings.is_empty())

func _show_group_buildings(group_id: String, parent_category: String) -> void:
	active_service_group = group_id if parent_category == "services" else ""
	active_specialization_group = group_id if parent_category == "specializations" else ""
	submenu_level = 2
	for child in submenu.get_children():
		submenu.remove_child(child)
		child.queue_free()
	_update_context_header(parent_category, group_id.replace("_", " ").capitalize() + " · Choose a building")
	var groups: Array = SERVICE_GROUPS if parent_category == "services" else SPECIALIZATION_GROUPS
	var selected_group: Dictionary = {}
	for group in groups:
		if str(group.get("id", "")) == group_id:
			selected_group = group
			break
	if selected_group.is_empty():
		_add_submenu_button("group_unavailable", "Unavailable", group_id, "Not available yet", true, parent_category)
	else:
		var buildings: Array = selected_group.get("buildings", [])
		if buildings.is_empty():
			_add_submenu_button("group_locked", str(selected_group.get("label", group_id)), group_id, "Unlocks in a future update", false, parent_category, 1, true)
		else:
			for type_id_value in buildings:
				var type_id := str(type_id_value)
				if not BuildManager.building_types.has(type_id):
					continue
				var definition: Dictionary = BuildManager.building_types[type_id]
				var footprint: Vector2i = definition.get("size", Vector2i.ONE)
				var detail := "%d coins · Lv %d · %dx%d" % [int(definition.get("cost", 0)), int(definition.get("level", 1)), footprint.x, footprint.y]
				if int(definition.get("fire", 0)) > 0 or int(definition.get("police", 0)) > 0 or int(definition.get("health", 0)) > 0:
					detail += " · Coverage: %d tiles" % int(definition.get("coverage_tiles", 15))
				if int(definition.get("pollution", 0)) > 0:
					detail += " · " + str(definition.get("pollution_label", "Pollutes"))
				_add_submenu_button(type_id, str(definition.get("name", type_id)), type_id, detail, false, parent_category, int(definition.get("level", 1)))
	_finish_submenu_row(true)

func _add_submenu_button(option_id: String, title: String, icon_name: String, detail: String, disabled: bool, category: String, required_level: int = 1, locked: bool = false) -> void:
	var level_locked := GameManager.level < required_level or locked
	var button := Button.new()
	button.name = option_id
	button.custom_minimum_size = Vector2(164, 188) * _ui_scale
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled and not level_locked
	button.tooltip_text = ("Unlocks at Level %d" % required_level) if level_locked else detail
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var art := Control.new()
	art.custom_minimum_size = Vector2(142, 126) * _ui_scale
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	var icon := Icons.make_icon(icon_name, Vector2(132, 122) * _ui_scale)
	icon.name = "SubmenuArtwork"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(icon)
	if level_locked:
		var lock := Label.new()
		lock.name = "CatalogLock"
		lock.text = "LOCKED"
		lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lock.offset_left = -66 * _ui_scale
		lock.offset_right = -3 * _ui_scale
		lock.offset_top = 2 * _ui_scale
		lock.offset_bottom = 25 * _ui_scale
		lock.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		lock.add_theme_color_override("font_color", Color("#A66A16"))
		art.add_child(lock)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 34 * _ui_scale
	label.add_theme_color_override("font_color", Color("#344B5B") if not level_locked else Color("#84929B"))
	label.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	content.add_child(label)
	var count := Label.new()
	count.name = "BuildingCount"
	count.text = "%d/1" % _count_existing_buildings(option_id)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_color_override("font_color", Color("#748795"))
	count.add_theme_font_size_override("font_size", int(11 * _ui_scale))
	content.add_child(count)
	button.mouse_entered.connect(_set_submenu_icon_scale.bind(icon, 1.06))
	button.mouse_exited.connect(_set_submenu_icon_scale.bind(icon, 1.0))
	submenu.add_child(button)
	button.pressed.connect(_on_submenu_option.bind(category, option_id))

func _count_existing_buildings(type_id: String) -> int:
	var count := 0
	var scene := get_tree().current_scene
	if scene == null:
		return count
	for node in scene.find_children("*", "Building", true, false):
		var building := node as Building
		if is_instance_valid(building) and building.building_type == type_id:
			count += 1
	return count

func _catalog_card_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F4FBFF") if state == "hover" else (Color("#E8F5FC") if state == "pressed" else Color("#FFFFFF"))
	style.border_color = Color("#75BFE7") if state == "pressed" else Color("#D8E5EC")
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _catalog_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.99, 1.0, 0.97)
	style.border_color = Color("#D8E5EC")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, -2)
	return style

func _clear_catalog_cards() -> void:
	for child in submenu.get_children():
		submenu.remove_child(child)
		child.queue_free()
	_catalog_selected_type = ""
	_hide_building_info()

func _add_catalog_advisor() -> void:
	catalog_advisor = Control.new()
	catalog_advisor.name = "CatalogAdvisor"
	catalog_advisor.anchor_left = 0.0
	catalog_advisor.anchor_right = 0.15
	catalog_advisor.anchor_top = 1.0
	catalog_advisor.anchor_bottom = 1.0
	catalog_advisor.offset_top = -282.0 * _ui_scale
	catalog_advisor.offset_bottom = -2.0 * _ui_scale
	catalog_advisor.z_index = 64
	catalog_advisor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(catalog_advisor)
	var portrait := TextureRect.new()
	portrait.name = "AdvisorPortrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.texture = Icons.get_advisor_tex()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalog_advisor.add_child(portrait)
	catalog_advisor.hide()

func _build_catalog_info_panel() -> void:
	catalog_info_panel = PanelContainer.new()
	catalog_info_panel.name = "BuildingInfoPanel"
	catalog_info_panel.anchor_left = 0.0
	catalog_info_panel.anchor_right = 0.0
	catalog_info_panel.anchor_top = 1.0
	catalog_info_panel.anchor_bottom = 1.0
	catalog_info_panel.anchor_left = 0.15
	catalog_info_panel.anchor_right = 0.39
	catalog_info_panel.offset_left = 10 * _ui_scale
	catalog_info_panel.offset_right = -8 * _ui_scale
	catalog_info_panel.offset_top = -430 * _ui_scale
	catalog_info_panel.offset_bottom = -218 * _ui_scale
	catalog_info_panel.z_index = 65
	catalog_info_panel.add_theme_stylebox_override("panel", _catalog_bar_style())
	add_child(catalog_info_panel)
	catalog_info_panel.hide()

func _show_building_info(type_id: String) -> void:
	if not BuildManager.building_types.has(type_id):
		return
	_catalog_selected_type = type_id
	var definition: Dictionary = BuildManager.building_types[type_id]
	for child in catalog_info_panel.get_children():
		catalog_info_panel.remove_child(child)
		child.queue_free()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	catalog_info_panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = str(definition.get("name", type_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#263746"))
	title.add_theme_font_size_override("font_size", int(17 * _ui_scale))
	heading.add_child(title)
	var close := Button.new()
	close.name = "BuildingInfoClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(30, 30) * _ui_scale
	close.pressed.connect(_hide_building_info)
	heading.add_child(close)
	var footprint: Vector2i = definition.get("size", Vector2i.ONE)
	_add_info_line(layout, "Area", "%d × %d tiles" % [footprint.x, footprint.y])
	var boost := int(definition.get("happiness", definition.get("population", definition.get("coverage_tiles", 0))))
	_add_info_line(layout, "Boost", str(boost) if boost > 0 else "—")
	_add_info_line(layout, "Price", "%s Simoleons" % _format_count(int(definition.get("cost", 0))))
	var required_level := int(definition.get("level", 1))
	_add_info_line(layout, "Requirements", "Level %d" % required_level)
	if GameManager.level < required_level:
		status_label.text = "Unlocked at Level %d." % required_level
	var build := Button.new()
	build.name = "CatalogBuildButton"
	build.text = "BUILD" if GameManager.level >= required_level else "LOCKED · LEVEL %d" % required_level
	build.disabled = GameManager.level < required_level
	build.custom_minimum_size.y = 34 * _ui_scale
	build.add_theme_stylebox_override("normal", _catalog_action_style())
	build.add_theme_color_override("font_color", Color.WHITE)
	build.pressed.connect(_select_building_type.bind(type_id))
	layout.add_child(build)
	catalog_info_panel.show()
	catalog_info_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(catalog_info_panel, "modulate:a", 1.0, 0.18)

func _add_info_line(parent: VBoxContainer, key_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var key := Label.new()
	key.text = key_text
	key.custom_minimum_size.x = 88 * _ui_scale
	key.add_theme_color_override("font_color", Color("#78909E"))
	row.add_child(key)
	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", Color("#263746"))
	row.add_child(value)

func _catalog_close_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F4FAFD") if hovered else Color("#FFFFFF")
	style.border_color = Color("#D6E5EC")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.shadow_size = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _catalog_action_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#42A96B")
	style.set_corner_radius_all(9)
	return style

func _hide_building_info() -> void:
	if is_instance_valid(catalog_info_panel):
		var tween := create_tween()
		tween.tween_property(catalog_info_panel, "modulate:a", 0.0, 0.12)
		tween.tween_callback(catalog_info_panel.hide)
func _set_submenu_icon_scale(icon: Control, factor: float) -> void:
	if not is_instance_valid(icon):
		return
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2.ONE * factor

func _finish_submenu_row(show_back: bool = false) -> void:
	if show_back:
		var back := Button.new()
		back.name = "Submenu_Back"
		back.text = "‹"
		back.tooltip_text = "Back to categories"
		back.custom_minimum_size = Vector2(54, 188) * _ui_scale
		back.focus_mode = Control.FOCUS_NONE
		back.add_theme_stylebox_override("normal", _catalog_card_style("normal"))
		back.add_theme_color_override("font_color", Color("#526B7A"))
		back.pressed.connect(_on_submenu_option.bind(active_category, "back"))
		submenu.add_child(back)
	submenu.show()
	submenu_scroll.show()
	if catalog_base_bar:
		catalog_base_bar.show()
	if catalog_advisor:
		catalog_advisor.show()
	var catalog_close := get_node_or_null("CatalogCloseButton") as Control
	if catalog_close:
		catalog_close.show()
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		toolbar.hide()
	var build_button := get_node_or_null("BuildMenuButton") as Control
	if build_button:
		build_button.hide()
	if context_header:
		context_header.show()
	submenu_scroll.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(submenu_scroll, "modulate:a", 1.0, 0.20)
	if bottom_actions:
		bottom_actions.hide()

func _select_building_type(type_id: String) -> void:
	if not BuildManager.building_types.has(type_id):
		status_label.text = "This building is not available yet."
		return
	var definition: Dictionary = BuildManager.building_types[type_id]
	var required_level := int(definition.get("level", 1))
	if GameManager.level < required_level:
		status_label.text = "Unlocked at Level %d." % required_level
		return
	if definition.get("category", "") == "industrial":
		if not BuildManager.can_build_another_factory():
			status_label.text = "Factory limit reached (%d). Level up to unlock another factory slot." % LevelProgression.get_factory_limit_for_level(GameManager.level)
			return
		if not BuildManager.can_build_factory_type(type_id):
			var required_population := BuildManager.get_factory_type_population_requirement(type_id)
			status_label.text = "%s requires %s city population." % [str(definition.get("name", type_id)), _format_count(required_population)]
			return
	_set_tool_modes_off()
	BuildManager.select_building(type_id)
	if BuildManager.is_placing:
		_highlight_submenu_choice(type_id)
		if submenu_scroll:
			submenu_scroll.show()
		if bottom_actions:
			bottom_actions.hide()
	else:
		status_label.text = "Could not enter placement mode for %s." % str(definition.get("name", type_id))

func _highlight_submenu_choice(type_id: String) -> void:
	for child in submenu.get_children():
		if child is Button:
			var button := child as Button
			if button.name == type_id:
				button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.13, 0.32, 0.20, 1.0), Color("#A8E62E")))
			elif not button.name.begins_with("Submenu_"):
				button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.08, 0.16, 0.21, 0.97), Color(0.52, 0.72, 0.82, 0.62)))

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
	active_category = "bulldoze"
	_set_active_category_visuals("bulldoze")
	_set_bulldozer_indicator(true)
	for child in submenu.get_children():
		submenu.remove_child(child)
		child.queue_free()
	_add_submenu_button("bulldoze_active", "Bulldoze Active", "bulldoze", "Tap a building or road", true, "bulldoze")
	_finish_submenu_row()
	status_label.text = "Bulldozer active. Tap a building or road; press Cancel to exit."

func _start_bulldoze_road_mode() -> void:
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	var scene := get_tree().current_scene
	var city_input = scene.get_node_or_null("CityInput") if scene else null
	if city_input:
		city_input.set_bulldoze_road_mode(true)
	active_category = "road"
	_set_active_category_visuals("road")
	_set_bulldozer_indicator(true)
	for child in submenu.get_children():
		submenu.remove_child(child)
		child.queue_free()
	_add_submenu_button("bulldoze_road_active", "Road Bulldozer", "bulldoze", "Tap a road to remove it", true, "road")
	_finish_submenu_row()
	status_label.text = "Road bulldozer active. Tap a road to remove it."

func _on_submenu_option(category: String, option_id: String) -> void:
	if option_id == "back":
		active_service_group = ""
		active_specialization_group = ""
		_show_submenu(active_category)
		return
	if option_id.begins_with("group_"):
		var group_id := option_id.trim_prefix("group_")
		var groups: Array = SERVICE_GROUPS if category == "services" else SPECIALIZATION_GROUPS
		for group in groups:
			if str(group.get("id", "")) == group_id:
				# Every group opens level two, including groups whose content is
				# intentionally locked for a later gameplay milestone.
				_show_group_buildings(group_id, category)
				return
	if category == "road":
		if option_id == "road_build":
			_set_tool_modes_off()
			BuildManager.cancel_placement()
			var scene := get_tree().current_scene
			var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
			if road_system:
				road_system.set_road_mode(true)
				status_label.text = "Road mode. Tap or drag from the highway (50 Simoleons per tile). Press Cancel to exit."
			else:
				status_label.text = "Road system is unavailable."
		elif option_id == "road_upgrade":
			status_label.text = "Road upgrades will be available in a later update."
		elif option_id == "bulldoze_road":
			_start_bulldoze_road_mode()
	else:
		_show_building_info(option_id)

func _close_building_submenu(cancel_placement: bool = true) -> void:
	if cancel_placement:
		_on_cancel_pressed()
	elif submenu_scroll:
		submenu_scroll.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		if submenu_scroll and submenu_scroll.visible:
			_close_build_menu()
		else:
			_on_cancel_pressed()
		get_viewport().set_input_as_handled()

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
	if is_instance_valid(production_panel):
		_production_tick_accum += delta
		if _production_tick_accum >= 0.25:
			_production_tick_accum = 0.0
			_update_production_timers()

	if not is_instance_valid(_level_up_effect) or not is_instance_valid(_level_up_camera):
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
	if is_instance_valid(storage_panel):
		_refresh_storage_panel()

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

func open_production_panel(building: Building) -> void:
	if not is_instance_valid(building) or building.status != "completed":
		return
	_clear_production_timer_tracking()
	_production_building = building
	if is_instance_valid(production_panel):
		production_panel.queue_free()
	production_panel = PanelContainer.new()
	production_panel.name = "BuildingProductionPanel"
	production_panel.anchor_left = 0.5
	production_panel.anchor_right = 0.5
	production_panel.anchor_top = 0.5
	production_panel.anchor_bottom = 0.5
	production_panel.offset_left = -235.0 * _ui_scale
	production_panel.offset_right = 235.0 * _ui_scale
	production_panel.offset_top = -235.0 * _ui_scale
	production_panel.offset_bottom = 235.0 * _ui_scale
	production_panel.z_index = 100
	production_panel.add_theme_stylebox_override("panel", _toolbar_style(Color(0.035,0.075,0.105,0.98), Color(0.55,0.78,0.92,0.85)))
	production_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(production_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	production_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = str(building.definition.get("name","Production"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(21 * _ui_scale))
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)
	var close := Button.new()
	close.text = ""
	close.icon = Icons.get_tex("ui", "close")
	close.custom_minimum_size = Vector2(44,44) * _ui_scale
	close.pressed.connect(_close_production_panel)
	header.add_child(close)
	var component = building.production_component
	if not is_instance_valid(component):
		var unavailable := Label.new()
		unavailable.text = "Production is unavailable for this building."
		layout.add_child(unavailable)
		return
	for slot_index in range(component.get_slot_count()):
		var slot_box := PanelContainer.new()
		slot_box.add_theme_stylebox_override("panel", _toolbar_style(Color(0.07,0.13,0.18,0.96), Color(0.35,0.58,0.70,0.48)))
		layout.add_child(slot_box)
		var slot_layout := VBoxContainer.new()
		slot_layout.add_theme_constant_override("separation", 5)
		slot_box.add_child(slot_layout)
		var slot_title := Label.new()
		slot_title.text = "Production Slot %d" % (slot_index + 1)
		slot_title.add_theme_color_override("font_color", Color("#8ED8FF"))
		slot_layout.add_child(slot_title)
		var slot: Dictionary = component.get_slot(slot_index)
		if slot.is_empty():
			var item_ids: Array = []
			if component.is_factory:
				for item_id in building.definition.get("can_produce", ["metal","wood"]):
					if ProductionManager.raw_materials.has(item_id) and int(ProductionManager.raw_materials[item_id].level) <= GameManager.level:
						item_ids.append(str(item_id))
			else:
				for item_id in building.definition.get("recipes", []):
					var recipe := ProductionManager.get_recipe(str(item_id))
					if not recipe.is_empty():
						item_ids.append(str(item_id))
			for item_id in item_ids:
				var item_button := Button.new()
				item_button.name = "Slot%d_%s" % [slot_index, item_id]
				item_button.icon = Icons.get_tex("raw" if component.is_factory else "crafted", item_id)
				item_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				var data: Dictionary = ProductionManager.raw_materials.get(item_id, ProductionManager.crafted_items.get(item_id, {}))
				var lock_reason := ProductionManager.get_recipe_lock_reason(item_id) if not component.is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
				item_button.text = "%s  ·  %s%s" % [str(data.get("name", item_id)), _format_duration(int(data.get("time_sec", 0))), ("  ·  " + lock_reason) if lock_reason != "" else ""]
				item_button.disabled = lock_reason != ""
				item_button.custom_minimum_size.y = 42 * _ui_scale
				item_button.pressed.connect(func():
					var started: bool = component.start_factory(item_id, slot_index) if component.is_factory else component.start_craft(item_id, slot_index)
					if started:
						status_label.text = "Production started: %s." % item_id.capitalize()
					else:
						var missing := ProductionManager.get_missing_inputs_text(item_id)
						status_label.text = "Not enough materials: %s" % missing if missing != "" else "Cannot start this production."
					_close_production_panel()
				)
				slot_layout.add_child(item_button)
		else:
			var item_id := str(slot.get("item_id",""))
			if bool(slot.get("ready", false)):
				var collect_button := Button.new()
				collect_button.name = "CollectSlot%d" % slot_index
				collect_button.text = "COLLECT  %s" % item_id.capitalize()
				collect_button.icon = Icons.get_tex("ui", "collect")
				collect_button.custom_minimum_size.y = 46 * _ui_scale
				collect_button.pressed.connect(func():
					if component.collect(slot_index):
						status_label.text = "Collected %s into City Storage." % item_id.capitalize()
					else:
						status_label.text = "Storage full"
					_close_production_panel()
				)
				slot_layout.add_child(collect_button)
			else:
				var remaining := maxi(0, int(slot.get("finish_unix",0)) - int(Time.get_unix_time_from_system()))
				var timer_label := Label.new()
				timer_label.name = "TimerSlot%d" % slot_index
				timer_label.set_meta("slot_index", slot_index)
				timer_label.text = "%s  ·  %s remaining" % [item_id.capitalize(), _format_duration(remaining)]
				var timer_row := HBoxContainer.new()
				timer_row.add_child(Icons.make_item_icon("raw" if component.is_factory else "crafted", item_id, Vector2(32, 32) * _ui_scale))
				timer_row.add_child(timer_label)
				slot_layout.add_child(timer_row)
				_production_timer_labels.append(timer_label)
	if not component.is_factory:
		var note := Label.new()
		note.text = "Recipe materials are deducted from City Storage when a slot starts."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", int(12 * _ui_scale))
		layout.add_child(note)

func _format_duration(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	if seconds < 3600:
		return "%dm" % int(seconds / 60)
	return "%dh %dm" % [int(seconds / 3600), int((seconds % 3600) / 60)]

func _clear_production_timer_tracking() -> void:
	_production_timer_labels.clear()
	_production_building = null
	_production_tick_accum = 0.0

func _update_production_timers() -> void:
	if not is_instance_valid(production_panel) or not is_instance_valid(_production_building):
		return
	var component = _production_building.production_component
	if not is_instance_valid(component):
		return
	component.refresh_slots()
	var now := int(Time.get_unix_time_from_system())
	var need_rebuild := false
	for label in _production_timer_labels:
		if not is_instance_valid(label):
			continue
		var slot_index := int(label.get_meta("slot_index", -1))
		if slot_index < 0:
			continue
		var slot: Dictionary = component.get_slot(slot_index)
		if slot.is_empty() or bool(slot.get("ready", false)):
			need_rebuild = true
			break
		var item_id := str(slot.get("item_id", ""))
		var remaining := maxi(0, int(slot.get("finish_unix", 0)) - now)
		label.text = "%s  ·  %s remaining" % [item_id.capitalize(), _format_duration(remaining)]
		if remaining <= 0:
			need_rebuild = true
	if need_rebuild:
		open_production_panel(_production_building)

func _close_production_panel() -> void:
	_clear_production_timer_tracking()
	if is_instance_valid(production_panel):
		production_panel.queue_free()
	production_panel = null

func _on_storage_pressed() -> void:
	BuildManager.cancel_placement()
	_show_storage_panel()

func _show_storage_panel() -> void:
	if is_instance_valid(storage_panel):
		storage_panel.queue_free()
	storage_panel = PanelContainer.new()
	storage_panel.name = "CityStoragePanel"
	storage_panel.anchor_left = 0.5
	storage_panel.anchor_right = 0.5
	storage_panel.anchor_top = 0.5
	storage_panel.anchor_bottom = 0.5
	storage_panel.offset_left = -230.0 * _ui_scale
	storage_panel.offset_right = 230.0 * _ui_scale
	storage_panel.offset_top = -230.0 * _ui_scale
	storage_panel.offset_bottom = 230.0 * _ui_scale
	storage_panel.z_index = 100
	storage_panel.add_theme_stylebox_override("panel", _toolbar_style(Color(0.035,0.075,0.105,0.98), Color(0.55,0.78,0.92,0.85)))
	storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(storage_panel)
	var layout := VBoxContainer.new()
	layout.name = "StorageLayout"
	layout.add_theme_constant_override("separation", 12)
	storage_panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "CITY STORAGE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(23 * _ui_scale))
	title.add_theme_color_override("font_color", Color.WHITE)
	heading.add_child(title)
	var close := Button.new()
	close.name = "StorageClose"
	close.text = "✕"
	close.custom_minimum_size = Vector2(48,48) * _ui_scale
	close.pressed.connect(_close_storage_panel)
	heading.add_child(close)
	var capacity_label := Label.new()
	capacity_label.name = "StorageCapacity"
	capacity_label.text = "Storage  %d / %d" % [StorageManager.get_used(), StorageManager.capacity]
	capacity_label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	capacity_label.add_theme_color_override("font_color", Color("#8ED8FF"))
	layout.add_child(capacity_label)
	var divider := HSeparator.new()
	layout.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.name = "StorageItemsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "StorageItemsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_refresh_storage_panel()

func _refresh_storage_panel() -> void:
	if not is_instance_valid(storage_panel):
		return
	var capacity_label := storage_panel.find_child("StorageCapacity", true, false) as Label
	if capacity_label:
		capacity_label.text = "Storage  %d / %d" % [StorageManager.get_used(), StorageManager.capacity]
	var grid := storage_panel.find_child("StorageItemsGrid", true, false) as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	var items := StorageManager.get_all_items()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Your city storage is empty."
		empty_label.add_theme_font_size_override("font_size", int(17 * _ui_scale))
		empty_label.add_theme_color_override("font_color", Color("#D4E4EE"))
		grid.add_child(empty_label)
		return
	var ids: Array = items.keys()
	ids.sort()
	for item_id in ids:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(185, 54) * _ui_scale
		row.add_theme_stylebox_override("panel", _toolbar_style(Color(0.08,0.15,0.20,0.95), Color(0.35,0.58,0.70,0.45)))
		grid.add_child(row)
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 8)
		row.add_child(item_row)
		var item_name := str(ProductionManager.raw_materials.get(item_id, ProductionManager.crafted_items.get(item_id, {})).get("name", str(item_id).capitalize()))
		var item_category := "raw" if ProductionManager.raw_materials.has(item_id) else "crafted"
		item_row.add_child(Icons.make_item_icon(item_category, str(item_id), Vector2(34, 34) * _ui_scale))
		var name_label := Label.new()
		name_label.text = item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", Color.WHITE)
		item_row.add_child(name_label)
		var count_label := Label.new()
		count_label.text = "× %d" % int(items[item_id])
		count_label.add_theme_font_size_override("font_size", int(19 * _ui_scale))
		count_label.add_theme_color_override("font_color", Color("#8ED8FF"))
		item_row.add_child(count_label)

func _close_storage_panel() -> void:
	if is_instance_valid(storage_panel):
		storage_panel.queue_free()
	storage_panel = null

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
	if submenu_scroll:
		submenu_scroll.hide()
	if submenu:
		submenu.hide()
	var catalog_close := get_node_or_null("CatalogCloseButton") as Control
	if catalog_close:
		catalog_close.hide()
	if catalog_base_bar:
		catalog_base_bar.hide()
	if catalog_advisor:
		catalog_advisor.hide()
	if context_header:
		context_header.hide()
	var build_toggle := get_node_or_null("BuildMenuButton") as Control
	if build_toggle:
		build_toggle.show()
	_hide_building_info()
	active_category = ""
	active_service_group = ""
	active_specialization_group = ""
	submenu_level = 0
	_set_active_category_visuals("")
	var category_toolbar := get_node_or_null("RightToolbar") as Control
	if category_toolbar:
		category_toolbar.show()
	if bottom_actions:
		bottom_actions.show()
	var build_button_node := get_node_or_null("BuildMenuButton")
	var build_label := build_button_node.find_child("BuildButtonLabel", true, false) as Label if build_button_node else null
	if build_label:
		build_label.text = "BUILD"
	if build_button_node:
		build_button_node.tooltip_text = "Build menu"
	if was_moving:
		status_label.text = "Move cancelled. Building returned to its original location."
	elif was_bulldozing:
		status_label.text = "Bulldozer cancelled."
	else:
		status_label.text = "Cancelled."

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
