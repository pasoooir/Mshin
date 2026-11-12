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

# Procedural Mayor Level badge: no raster icon, with a glossy purple face and live XP ring.
class LevelBadgeVisual extends Control:
	var progress_fraction: float = 0.0

	func set_progress(value: float) -> void:
		progress_fraction = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 4.0
		# Soft drop shadow and metallic outer rim.
		draw_circle(center + Vector2(0.0, 2.5), radius + 2.0, Color(0.035, 0.018, 0.075, 0.42))
		draw_circle(center, radius + 2.0, Color("#F5A7FF"))
		draw_circle(center, radius - 1.0, Color("#63218C"))
		# Deep violet face with a subtle offset highlight for a polished 3D finish.
		draw_circle(center + Vector2(0.0, 1.0), radius - 4.0, Color("#8F25C7"))
		draw_circle(center + Vector2(-7.0, -10.0), radius * 0.58, Color(1.0, 0.78, 1.0, 0.13))
		draw_arc(center, radius - 7.0, PI * 1.08, PI * 1.92, 36, Color(1.0, 0.86, 1.0, 0.30), 2.2, true)
		# Dark track and bright magenta XP arc remain visible around the entire badge.
		draw_arc(center, radius + 0.5, -PI * 0.5, PI * 1.5, 72, Color("#42134F"), 5.5, true)
		if progress_fraction > 0.0:
			draw_arc(center, radius + 0.5, -PI * 0.5, -PI * 0.5 + TAU * progress_fraction, 72, Color("#F45AF0"), 5.5, true)
		draw_arc(center, radius - 4.0, PI * 1.08, PI * 1.90, 48, Color(1.0, 0.86, 1.0, 0.18), 1.2, true)

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
var level_badge_visual: LevelBadgeVisual
var population_label: Label
var happiness_label: Label
var xp_progress: ProgressBar
var xp_text: Label
var storage_label: Label
var storage_panel: PanelContainer
var storage_overlay: Control
var production_panel: PanelContainer
var production_overlay: Control
var city_needs_overlay: Control
var residential_overlay: Control
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
var _production_progress_bars: Array[ProgressBar] = []
var _production_building: Building = null
var _production_tick_accum := 0.0
var _factory_ready_scan_accum := 0.0
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
	CityDemandManager.city_needs_changed.connect(_on_city_needs_changed)
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
	var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.90, 1.20)
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		# Keep the transparent PNG shortcuts on the right at every viewport size.
		# They sit below the three compact resource rows and never use a hard-hat toggle.
		var width := 92.0 * scale_factor
		toolbar.anchor_left = 1.0
		toolbar.anchor_right = 1.0
		toolbar.anchor_top = 0.30
		toolbar.anchor_bottom = 0.985
		toolbar.offset_left = -width - 8.0 * scale_factor
		toolbar.offset_right = -6.0 * scale_factor
		toolbar.offset_top = 0.0
		toolbar.offset_bottom = 0.0
	var left_stats := get_node_or_null("TopHUD/TopLeftStats") as Control
	if left_stats:
		# Keep the complete HUD stack aligned to a consistent inset from the left screen edge.
		left_stats.position.x = 14.0 * scale_factor
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
	left_stack.custom_minimum_size = Vector2(470, 170) * _ui_scale
	left_stack.add_theme_constant_override("separation", 5)
	left_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hud.add_child(left_stack)

	var top_stats := HBoxContainer.new()
	top_stats.name = "PrimaryCityStats"
	top_stats.add_theme_constant_override("separation", 8)
	top_stats.mouse_filter = Control.MOUSE_FILTER_PASS
	left_stack.add_child(top_stats)

	var level_badge := Control.new()
	level_badge.name = "LevelBadge"
	level_badge.custom_minimum_size = Vector2(88, 88) * _ui_scale
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_stats.add_child(level_badge)
	level_badge_visual = LevelBadgeVisual.new()
	level_badge_visual.name = "LevelBadgeVisual"
	level_badge_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_badge_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_child(level_badge_visual)
	level_label = Label.new()
	level_label.name = "LevelValue"
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", int(36 * _ui_scale))
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color("#4B145F"))
	level_label.add_theme_constant_override("outline_size", 4)
	level_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.015, 0.12, 0.85))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 2)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_child(level_label)
	level_badge_visual.set_progress(float(GameManager.experience) / float(maxi(1, GameManager.get_xp_needed())))

	population_label = _add_stat_bar(top_stats, "population", "0", Color("#4BA3FF"), "City population", 142)
	storage_label = _add_stat_bar(top_stats, "storage", "0/30", Color("#5BB8F5"), "City storage", 132)

	var happiness_row := HBoxContainer.new()
	happiness_row.name = "HappinessStatRow"
	happiness_row.add_theme_constant_override("separation", 8)
	happiness_row.mouse_filter = Control.MOUSE_FILTER_PASS
	left_stack.add_child(happiness_row)
	happiness_label = _add_stat_bar(happiness_row, "happiness", "100%", Color("#A8E62E"), "Citizen happiness", 178)

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
	right_stack.offset_left = -276.0 * _ui_scale
	right_stack.offset_right = -10.0 * _ui_scale
	right_stack.offset_top = 8.0 * _ui_scale
	right_stack.offset_bottom = 194.0 * _ui_scale
	right_stack.add_theme_constant_override("separation", 5)
	right_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	top_hud.add_child(right_stack)
	simoleons_label = _add_currency_bar(right_stack, "simoleons", str(EconomyManager.simoleons), Color("#FFD24A"), "Simoleons", true, 184)
	simcash_label = _add_currency_bar(right_stack, "money", str(EconomyManager.sim_cash), Color("#B8E89B"), "SimCash", true, 184)
	keys_label = _add_currency_bar(right_stack, "golden_key", str(EconomyManager.golden_keys), Color("#FFC247"), "Golden Keys", false, 184)

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
	bar.custom_minimum_size = Vector2(width * _ui_scale, 70 * _ui_scale)
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
	var icon := Icons.make_icon(icon_name, Vector2(54, 54) * _ui_scale)
	icon.modulate = tint
	content.add_child(icon)
	var value := _make_hud_value(initial_text, int(22 * _ui_scale))
	content.add_child(value)
	return value

func _add_currency_bar(parent: Container, icon_name: String, initial_text: String, tint: Color, hint: String, show_plus: bool, width: float = 184.0) -> Label:
	var currency_node_prefix := icon_name.replace("_", " ").capitalize().replace(" ", "")
	var row := HBoxContainer.new()
	row.name = currency_node_prefix + "CurrencyRow"
	row.custom_minimum_size = Vector2(0, 54) * _ui_scale
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	var bar := PanelContainer.new()
	bar.name = currency_node_prefix + "CurrencyBar"
	bar.custom_minimum_size = Vector2(width, 54) * _ui_scale
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = hint
	bar.add_theme_stylebox_override("panel", _capsule_style())
	row.add_child(bar)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(content)
	var icon := Icons.make_icon(icon_name, Vector2(48, 48) * _ui_scale)
	icon.modulate = tint
	content.add_child(icon)
	var value := _make_hud_value(initial_text, int(23 * _ui_scale))
	value.name = currency_node_prefix + "CurrencyValue"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(value)
	if show_plus:
		row.add_child(_make_currency_plus_button(hint))
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

func _make_currency_plus_button(hint: String) -> Button:
	var button := Button.new()
	button.name = hint.replace(" ", "") + "CurrencyPlus"
	button.custom_minimum_size = Vector2(54, 54) * _ui_scale
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = hint + " shop"
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#DDF4FF")
	normal.border_color = Color("#83C8E8")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0, 0, 0, 0.30)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#F0FBFF")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	var plus_icon := Icons.make_icon("plus", Vector2(43, 43) * _ui_scale)
	plus_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plus_icon.offset_left = 4
	plus_icon.offset_top = 4
	plus_icon.offset_right = -4
	plus_icon.offset_bottom = -4
	button.add_child(plus_icon)
	button.pressed.connect(_on_currency_plus_pressed.bind(hint))
	return button

func _add_icon_capsule(parent: HBoxContainer, icon_name: String, initial_text: String, tint: Color, hint: String) -> Label:
	return _add_stat_bar(parent, icon_name, initial_text, tint, hint, 150)
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
	var toolbar_width := 92.0 * _ui_scale
	var toolbar := PanelContainer.new()
	toolbar.name = "RightToolbar"
	toolbar.anchor_left = 1.0
	toolbar.anchor_right = 1.0
	toolbar.anchor_top = 0.30
	toolbar.anchor_bottom = 0.985
	toolbar.offset_left = -toolbar_width - 8.0 * _ui_scale
	toolbar.offset_right = -6.0 * _ui_scale
	toolbar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	toolbar.mouse_filter = Control.MOUSE_FILTER_PASS
	toolbar.z_index = 60
	add_child(toolbar)
	var category_scroll := ScrollContainer.new()
	category_scroll.name = "CategoryScroll"
	category_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	category_scroll.scroll_deadzone = 4
	category_scroll.follow_focus = false
	category_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	category_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	toolbar.add_child(category_scroll)
	var toolbar_items := VBoxContainer.new()
	toolbar_items.name = "RightToolbarItems"
	toolbar_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_items.add_theme_constant_override("separation", 10 * _ui_scale)
	toolbar_items.mouse_filter = Control.MOUSE_FILTER_PASS
	category_scroll.add_child(toolbar_items)
	var tools := [
		["residential", "Residential", "residential"],
		["commercial", "Commercial", "commercial"],
		["industrial", "Industrial", "industrial"],
		["services", "Services", "services"],
		["specializations", "Specializations", "parks"],
		["road", "Roads", "road"],
		["bulldoze", "Bulldoze", "bulldoze"]
	]
	var icon_size := 78.0 * _ui_scale
	for item in tools:
		var button := Button.new()
		button.name = "Tool_" + str(item[0]).capitalize()
		button.custom_minimum_size = Vector2(toolbar_width, 84.0 * _ui_scale)
		button.tooltip_text = str(item[1])
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var icon := Icons.make_icon(str(item[2]), Vector2(icon_size, icon_size))
		icon.name = "CategoryPNG"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4.0 * _ui_scale
		icon.offset_top = 3.0 * _ui_scale
		icon.offset_right = -4.0 * _ui_scale
		icon.offset_bottom = -3.0 * _ui_scale
		button.add_child(icon)
		toolbar_items.add_child(button)
		button.pressed.connect(_on_category_pressed.bind(str(item[0])))
	toolbar.show()
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
	for item in [["storage","Storage"],["info","City Needs"],["trade","Trade"],["save","Save"]]:
		var button := _make_icon_button(str(item[0]), str(item[1]), Vector2(92, 82) * _ui_scale)
		button.name = str(item[0]).capitalize() + "Action"
		bottom_actions.add_child(button)
		match str(item[0]):
			"storage": button.pressed.connect(_on_storage_pressed)
			"info": button.pressed.connect(_on_city_needs_pressed)
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
	submenu_scroll.scroll_deadzone = 4
	submenu_scroll.follow_focus = false
	submenu_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	submenu_scroll.z_index = 63
	submenu_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(submenu_scroll)
	submenu = HBoxContainer.new()
	submenu.name = "ToolSubmenu"
	submenu.mouse_filter = Control.MOUSE_FILTER_PASS
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
	catalog_close.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	catalog_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	button.add_theme_stylebox_override("normal", _toolbar_style(Color(0.055, 0.075, 0.09, 0.78), Color(1.0, 1.0, 1.0, 0.12)))
	button.add_theme_stylebox_override("hover", _toolbar_style(Color(0.10, 0.16, 0.19, 0.92), Color("#83C8E7")))
	button.add_theme_stylebox_override("pressed", _toolbar_style(Color(0.12, 0.25, 0.22, 0.96), Color("#A8E62E")))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var icon_size := maxf(48.0 * _ui_scale, minf(66.0 * _ui_scale, button_size.y * 0.72))
	var icon := Icons.make_icon(icon_name, Vector2(icon_size, icon_size))
	content.add_child(icon)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
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
	# Kept for compatibility with older callers; the category rail is persistent.
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		toolbar.show()


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
	_hide_building_info()
	active_category = ""
	active_service_group = ""
	active_specialization_group = ""
	submenu_level = 0
	_set_active_category_visuals("")
	var toolbar := get_node_or_null("RightToolbar") as Control
	if toolbar:
		toolbar.show()
	if bottom_actions:
		bottom_actions.show()


func _set_active_category_visuals(category: String) -> void:
	var items := get_node_or_null("RightToolbar/CategoryScroll/RightToolbarItems")
	if items == null:
		return
	for child in items.get_children():
		if child is Button:
			var button := child as Button
			var icon := button.get_node_or_null("CategoryPNG") as TextureRect
			var selected := button.name.to_lower() == ("tool_" + category).to_lower()
			if icon:
				icon.modulate = Color("#FFFFFF") if selected or category.is_empty() else Color("#C9D6DC")

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
	button.mouse_filter = Control.MOUSE_FILTER_PASS
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
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.add_child(icon)
	if level_locked:
		var lock := Label.new()
		lock.name = "CatalogLock"
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 34 * _ui_scale
	label.add_theme_color_override("font_color", Color("#344B5B") if not level_locked else Color("#84929B"))
	label.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	content.add_child(label)
	var count := Label.new()
	count.name = "BuildingCount"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for building_value in BuildManager.buildings.values():
		var building := building_value as Building
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
	_add_info_line(layout, "Construction", _format_duration(int(definition.get("build_time", 0))))
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

func _catalog_close_style(_hovered: bool) -> StyleBox:
	# The catalog close control is a plain X; it must not create a white tile.
	return StyleBoxEmpty.new()

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
		back.mouse_filter = Control.MOUSE_FILTER_PASS
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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
	# Selection feedback must never paint opaque/dark cards behind the PNG artwork.
	for child in submenu.get_children():
		if child is Button:
			var button := child as Button
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			var title := button.find_child("Label", true, false) as Label
			if title:
				title.add_theme_color_override("font_color", Color("#4B9E38") if button.name == type_id else Color("#344B5B"))

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
	if is_instance_valid(level_badge_visual):
		level_badge_visual.set_progress(float(clampi(xp, 0, maxi(1, needed))) / float(maxi(1, needed)))

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
	_factory_ready_scan_accum += delta
	if _factory_ready_scan_accum >= 0.5:
		_factory_ready_scan_accum = 0.0
		_refresh_factory_ready_icons()
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


func _refresh_factory_ready_icons() -> void:
	# ProductionComponent slots are independent of the legacy single-item timer.
	# Mirror a ready slot into the building's existing billboard so it is visible
	# above the factory without adding a permanent HUD panel over the city.
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "Building", true, false):
		var building := node as Building
		if not is_instance_valid(building) or building.status != "completed":
			continue
		var component = building.production_component
		if not is_instance_valid(component):
			continue
		component.refresh_slots()
		var ready_item := ""
		for slot_index in range(component.get_slot_count()):
			var slot: Dictionary = component.get_slot(slot_index)
			if not slot.is_empty() and bool(slot.get("ready", false)):
				ready_item = str(slot.get("item_id", ""))
				break
		if is_instance_valid(building.production_icon):
			building.production_icon.text = "📦" if not ready_item.is_empty() else ""
			building.production_icon.visible = not ready_item.is_empty()
			building.production_icon.modulate = Color("#FFE06B")
			building.production_icon.outline_size = 12
			building.production_icon.outline_modulate = Color(0.12, 0.08, 0.02, 0.95)

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
	if is_instance_valid(production_overlay):
		production_overlay.queue_free()

	# SimCity BuildIt-inspired production studio: keep the city visible and
	# arrange floating item hexagons above a compact production queue.
	production_overlay = Control.new()
	production_overlay.name = "ProductionOverlay"
	production_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	production_overlay.z_index = 100
	production_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(production_overlay)

	var shade := ColorRect.new()
	shade.name = "ProductionBackdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	production_overlay.add_child(shade)

	production_panel = PanelContainer.new()
	production_panel.name = "BuildingProductionPanel"
	production_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	production_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	production_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	production_overlay.add_child(production_panel)

	var layout := VBoxContainer.new()
	layout.name = "ProductionLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 7)
	layout.add_theme_constant_override("margin_left", int(16 * _ui_scale))
	layout.add_theme_constant_override("margin_right", int(16 * _ui_scale))
	layout.add_theme_constant_override("margin_top", int(10 * _ui_scale))
	layout.add_theme_constant_override("margin_bottom", int(10 * _ui_scale))
	production_panel.add_child(layout)

	var component = building.production_component
	if not is_instance_valid(component):
		var unavailable := Label.new()
		unavailable.text = "Production is unavailable for this building."
		layout.add_child(unavailable)
		return

	# Narrow title ribbon mirrors the centered factory/store nameplate in SCBI.
	var header_center := CenterContainer.new()
	header_center.name = "ProductionHeaderCenter"
	header_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(header_center)
	var header := PanelContainer.new()
	header.name = "ProductionHeader"
	header.add_theme_stylebox_override("panel", _toolbar_style(Color("#17232D"), Color("#E8C64D")))
	header_center.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 9)
	header.add_child(header_row)
	var production_icon_id := building.building_type if Icons.COMMERCIAL_IDS.has(building.building_type) else "factory_basic"
	var building_icon := Icons.make_icon(production_icon_id, Vector2(34, 34) * _ui_scale)
	building_icon.name = "ProductionBuildingIcon"
	header_row.add_child(building_icon)
	var title := Label.new()
	title.text = str(building.definition.get("name", "Production")).to_upper()
	title.add_theme_font_size_override("font_size", int(17 * _ui_scale))
	title.add_theme_color_override("font_color", Color.WHITE)
	header_row.add_child(title)
	var close := Button.new()
	close.name = "ProductionClose"
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 38) * _ui_scale
	close.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_stylebox_override("normal", _toolbar_style(Color(0.12, 0.17, 0.21, 0.9), Color(1, 1, 1, 0.18)))
	close.pressed.connect(_close_production_panel)
	header_row.add_child(close)

	var hint := Label.new()
	hint.text = "SELECT AN ITEM  •  REVIEW THE RECIPE  •  START PRODUCTION"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", int(10 * _ui_scale))
	hint.add_theme_color_override("font_color", Color("#F5F7F8"))
	layout.add_child(hint)

	var available_slot := -1
	for slot_index in range(component.get_slot_count()):
		if component.get_slot(slot_index).is_empty():
			available_slot = slot_index
			break

	var products_title := Label.new()
	products_title.name = "AvailableProductsTitle"
	products_title.text = "FACTORY MATERIALS" if component.is_factory else "SHOP PRODUCTS"
	products_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	products_title.add_theme_font_size_override("font_size", int(12 * _ui_scale))
	products_title.add_theme_color_override("font_color", Color("#FFE07A"))
	layout.add_child(products_title)

	var product_scroll := ScrollContainer.new()
	product_scroll.name = "ProductionProductsScroll"
	product_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	product_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	product_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	product_scroll.custom_minimum_size.y = 142.0 * _ui_scale
	layout.add_child(product_scroll)

	var product_grid := GridContainer.new()
	product_grid.name = "ProductionProductCards"
	product_grid.columns = 6
	product_grid.add_theme_constant_override("h_separation", 8)
	product_grid.add_theme_constant_override("v_separation", 4)
	product_scroll.add_child(product_grid)

	var item_ids: Array = []
	if component.is_factory:
		for item_id in ProductionManager.get_factory_material_ids(str(component.factory_type)):
			if ProductionManager.raw_materials.has(item_id):
				item_ids.append(str(item_id))
	else:
		for item_id in ProductionManager.get_store_catalog_ids(str(component.shop_id)):
			if not ProductionManager.get_recipe(str(item_id)).is_empty():
				item_ids.append(str(item_id))

	if item_ids.is_empty():
		var empty_catalog := Label.new()
		empty_catalog.text = "No verified products are registered for this store yet. Production is intentionally disabled until item recipes are sourced."
		empty_catalog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_catalog.custom_minimum_size = Vector2(280, 72) * _ui_scale
		empty_catalog.add_theme_color_override("font_color", Color("#F5DFA0"))
		product_grid.add_child(empty_catalog)

	for item_id in item_ids:
		var data: Dictionary = ProductionManager.raw_materials.get(item_id, ProductionManager.get_store_item_definition(str(component.shop_id), item_id))
		var lock_reason := ProductionManager.get_recipe_lock_reason(item_id) if not component.is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
		var recipe: Dictionary = {} if component.is_factory else ProductionManager.get_recipe(item_id)
		var inputs: Dictionary = recipe.get("inputs", {})
		var can_start := available_slot >= 0 and lock_reason.is_empty()
		if not component.is_factory and lock_reason.is_empty() and not StorageManager.has_items(inputs):
			can_start = false

		var item_button := Button.new()
		item_button.name = "Slot%d_%s" % [available_slot, item_id]
		item_button.custom_minimum_size = Vector2(104, 116) * _ui_scale
		item_button.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			item_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())

		# Six-sided white tile with a subtle blue rim, matching the reference's
		# floating hexagonal item selectors rather than generic rectangular cards.
		var hex_size := Vector2(96, 104) * _ui_scale
		var hex := Polygon2D.new()
		hex.name = "HexagonBackground"
		hex.position = Vector2(4, 3) * _ui_scale
		hex.polygon = PackedVector2Array([
			Vector2(hex_size.x * 0.5, 0),
			Vector2(hex_size.x, hex_size.y * 0.25),
			Vector2(hex_size.x, hex_size.y * 0.75),
			Vector2(hex_size.x * 0.5, hex_size.y),
			Vector2(0, hex_size.y * 0.75),
			Vector2(0, hex_size.y * 0.25)
		])
		hex.color = Color("#EAF5FA") if lock_reason.is_empty() else Color("#9AAAB2")
		item_button.add_child(hex)
		var hex_outline := Line2D.new()
		hex_outline.name = "HexagonOutline"
		hex_outline.position = hex.position
		hex_outline.points = PackedVector2Array([
			Vector2(hex_size.x * 0.5, 0),
			Vector2(hex_size.x, hex_size.y * 0.25),
			Vector2(hex_size.x, hex_size.y * 0.75),
			Vector2(hex_size.x * 0.5, hex_size.y),
			Vector2(0, hex_size.y * 0.75),
			Vector2(0, hex_size.y * 0.25)
		])
		hex_outline.closed = true
		hex_outline.width = 2.0 * _ui_scale
		hex_outline.default_color = Color("#FFFFFF")
		item_button.add_child(hex_outline)

		var tile_content := VBoxContainer.new()
		tile_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile_content.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_content.add_theme_constant_override("separation", 0)
		tile_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(tile_content)
		var item_icon := Icons.make_item_icon("raw" if component.is_factory else "crafted", item_id, Vector2(54, 54) * _ui_scale)
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_content.add_child(item_icon)
		var item_name := Label.new()
		item_name.text = str(data.get("name", item_id.capitalize()))
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		item_name.add_theme_color_override("font_color", Color("#263F4B"))
		tile_content.add_child(item_name)
		if not lock_reason.is_empty():
			var lock_label := Label.new()
			lock_label.text = "LOCKED"
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.add_theme_font_size_override("font_size", int(8 * _ui_scale))
			lock_label.add_theme_color_override("font_color", Color("#8B2930"))
			tile_content.add_child(lock_label)
		item_button.tooltip_text = lock_reason
		item_button.pressed.connect(func():
			_show_production_item_details(building, item_id, available_slot)
		)
		product_grid.add_child(item_button)

	var details_host := Control.new()
	details_host.name = "ProductionDetailsHost"
	details_host.custom_minimum_size.y = 94.0 * _ui_scale
	layout.add_child(details_host)

	var queue_heading := HBoxContainer.new()
	queue_heading.name = "ProductionQueueHeading"
	layout.add_child(queue_heading)
	var queue_title := Label.new()
	queue_title.text = "PRODUCTION QUEUE"
	queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_title.add_theme_font_size_override("font_size", int(12 * _ui_scale))
	queue_title.add_theme_color_override("font_color", Color("#FFE07A"))
	queue_heading.add_child(queue_title)
	var queue_count := Label.new()
	queue_count.text = "%d / %d" % [component.get_slot_count() - _count_empty_production_slots(component), component.get_slot_count()]
	queue_count.add_theme_font_size_override("font_size", int(12 * _ui_scale))
	queue_count.add_theme_color_override("font_color", Color.WHITE)
	queue_heading.add_child(queue_count)

	var queue_scroll := ScrollContainer.new()
	queue_scroll.name = "ProductionQueueScroll"
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.custom_minimum_size.y = 96.0 * _ui_scale
	layout.add_child(queue_scroll)
	var queue_row := HBoxContainer.new()
	queue_row.name = "ProductionQueueSlots"
	queue_row.add_theme_constant_override("separation", 9)
	queue_scroll.add_child(queue_row)
	for slot_index in range(component.get_slot_count()):
		var slot: Dictionary = component.get_slot(slot_index)
		var slot_card := PanelContainer.new()
		slot_card.name = "QueueSlot%d" % slot_index
		slot_card.custom_minimum_size = Vector2(124, 90) * _ui_scale
		var slot_fill := Color(0.025, 0.045, 0.06, 0.72) if not slot.is_empty() else Color(0.025, 0.045, 0.06, 0.28)
		var slot_border := Color("#FFFFFF") if slot.is_empty() else Color("#78C9E8")
		slot_card.add_theme_stylebox_override("panel", _toolbar_style(slot_fill, slot_border))
		queue_row.add_child(slot_card)
		var slot_content := VBoxContainer.new()
		slot_content.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_content.add_theme_constant_override("separation", 1)
		slot_card.add_child(slot_content)
		if slot.is_empty():
			var empty_label := Label.new()
			empty_label.text = "EMPTY"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.add_theme_color_override("font_color", Color("#FFFFFF"))
			empty_label.add_theme_font_size_override("font_size", int(12 * _ui_scale))
			slot_content.add_child(empty_label)
		else:
			var queued_item_id := str(slot.get("item_id", ""))
			var item_category := "raw" if component.is_factory else "crafted"
			var queue_item_row := HBoxContainer.new()
			queue_item_row.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_content.add_child(queue_item_row)
			queue_item_row.add_child(Icons.make_item_icon(item_category, queued_item_id, Vector2(28, 28) * _ui_scale))
			var queue_item_name := Label.new()
			queue_item_name.text = str(ProductionManager.raw_materials.get(queued_item_id, ProductionManager.crafted_items.get(queued_item_id, {})).get("name", queued_item_id.capitalize()))
			queue_item_name.add_theme_font_size_override("font_size", int(10 * _ui_scale))
			queue_item_name.add_theme_color_override("font_color", Color.WHITE)
			queue_item_row.add_child(queue_item_name)
			if bool(slot.get("ready", false)):
				var collect_button := Button.new()
				collect_button.name = "CollectSlot%d" % slot_index
				collect_button.text = "COLLECT"
				collect_button.custom_minimum_size.y = 27 * _ui_scale
				collect_button.add_theme_font_size_override("font_size", int(10 * _ui_scale))
				collect_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#E6B93E"), Color("#FFE18A")))
				collect_button.add_theme_color_override("font_color", Color("#34280B"))
				collect_button.pressed.connect(func():
					if component.collect(slot_index):
						status_label.text = "Collected %s into City Storage." % queued_item_id.capitalize()
					else:
						status_label.text = "Storage full — collect space in City Storage first."
					open_production_panel(building)
				)
				slot_content.add_child(collect_button)
			else:
				var remaining := maxi(0, int(slot.get("finish_unix", 0)) - int(Time.get_unix_time_from_system()))
				var timer_label := Label.new()
				timer_label.name = "TimerSlot%d" % slot_index
				timer_label.set_meta("slot_index", slot_index)
				timer_label.text = _format_clock_duration(remaining)
				timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				timer_label.add_theme_font_size_override("font_size", int(12 * _ui_scale))
				timer_label.add_theme_color_override("font_color", Color("#FFE18A"))
				slot_content.add_child(timer_label)
				var progress := ProgressBar.new()
				progress.name = "ProgressSlot%d" % slot_index
				progress.set_meta("slot_index", slot_index)
				progress.show_percentage = false
				progress.custom_minimum_size.y = 6.0 * _ui_scale
				progress.max_value = 1.0
				var total_seconds := maxf(1.0, ProductionManager.get_production_time(queued_item_id))
				var started_unix := int(slot.get("start_unix", int(slot.get("finish_unix", 0)) - int(total_seconds)))
				progress.value = clampf(1.0 - float(remaining) / total_seconds, 0.0, 1.0)
				progress.set_meta("start_unix", started_unix)
				progress.set_meta("finish_unix", int(slot.get("finish_unix", 0)))
				slot_content.add_child(progress)
				_production_timer_labels.append(timer_label)
				_production_progress_bars.append(progress)

	var footer := Label.new()
	footer.text = "Completed goods are collected into City Storage."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", int(9 * _ui_scale))
	footer.add_theme_color_override("font_color", Color("#E5EDF1"))
	layout.add_child(footer)


func _show_production_item_details(building: Building, item_id: String, slot_index: int) -> void:
	if not is_instance_valid(production_panel) or not is_instance_valid(building):
		return
	var host := production_panel.find_child("ProductionDetailsHost", true, false) as Control
	if not is_instance_valid(host):
		return
	for child in host.get_children():
		child.queue_free()

	var component = building.production_component
	var is_factory: bool = bool(component.is_factory)
	var data: Dictionary = ProductionManager.raw_materials.get(item_id, ProductionManager.get_store_item_definition(str(component.shop_id), item_id))
	var recipe: Dictionary = {} if is_factory else ProductionManager.get_recipe(item_id)
	var inputs: Dictionary = recipe.get("inputs", {})
	var lock_reason := ProductionManager.get_recipe_lock_reason(item_id) if not is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
	var missing := "" if is_factory else ProductionManager.get_missing_inputs_text(item_id)
	var can_start: bool = slot_index >= 0 and lock_reason.is_empty() and (is_factory or missing.is_empty())

	var detail := PanelContainer.new()
	detail.name = "ProductionItemDetails"
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail.add_theme_stylebox_override("panel", _toolbar_style(Color("#F5FBFE"), Color("#9BD3E8")))
	host.add_child(detail)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	detail.add_child(detail_row)

	var selected_icon := Icons.make_item_icon("raw" if is_factory else "crafted", item_id, Vector2(52, 52) * _ui_scale)
	detail_row.add_child(selected_icon)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 1)
	detail_row.add_child(text_stack)
	var selected_name := Label.new()
	selected_name.text = str(data.get("name", item_id.capitalize()))
	selected_name.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	selected_name.add_theme_color_override("font_color", Color("#173746"))
	text_stack.add_child(selected_name)
	var production_time := Label.new()
	production_time.text = "PRODUCTION TIME  " + _format_duration(int(data.get("time_sec", 60)))
	production_time.add_theme_font_size_override("font_size", int(10 * _ui_scale))
	production_time.add_theme_color_override("font_color", Color("#315C70"))
	text_stack.add_child(production_time)
	var provenance := str(data.get("source", ""))
	if provenance.to_lower().contains("conflict") or provenance.to_lower().contains("verify"):
		var provenance_warning := Label.new()
		provenance_warning.name = "RecipeDataWarning"
		provenance_warning.text = "REFERENCE DATA DISAGREES · VERIFY RECIPE BEFORE FINAL BALANCE"
		provenance_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		provenance_warning.add_theme_font_size_override("font_size", int(9 * _ui_scale))
		provenance_warning.add_theme_color_override("font_color", Color("#A13F35"))
		text_stack.add_child(provenance_warning)
	if is_factory:
		var storage_label := Label.new()
		storage_label.text = "IN CITY STORAGE  %d" % StorageManager.get_count(item_id)
		storage_label.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		storage_label.add_theme_color_override("font_color", Color("#315C70"))
		text_stack.add_child(storage_label)
	else:
		var ingredients_label := Label.new()
		ingredients_label.name = "IngredientsLabel"
		var ingredient_lines: Array[String] = []
		for input_id in inputs:
			var input_data: Dictionary = ProductionManager.raw_materials.get(input_id, ProductionManager.crafted_items.get(input_id, {}))
			var required := int(inputs[input_id])
			var owned := StorageManager.get_count(str(input_id))
			ingredient_lines.append("%s  %d/%d" % [str(input_data.get("name", str(input_id).capitalize())), owned, required])
			if owned < required:
				can_start = false
		ingredients_label.text = "REQUIRED ITEMS  " + "   •   ".join(ingredient_lines)
		ingredients_label.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		ingredients_label.add_theme_color_override("font_color", Color("#315C70") if can_start else Color("#A33A36"))
		text_stack.add_child(ingredients_label)
	if not lock_reason.is_empty() or not missing.is_empty():
		var reason := Label.new()
		reason.text = lock_reason if not lock_reason.is_empty() else "NEED " + missing
		reason.add_theme_font_size_override("font_size", int(9 * _ui_scale))
		reason.add_theme_color_override("font_color", Color("#A33A36"))
		text_stack.add_child(reason)

	var start_button := Button.new()
	start_button.name = "StartProduction"
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(92, 44) * _ui_scale
	start_button.disabled = not can_start
	start_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#E7BC43"), Color("#FFE18A")))
	start_button.add_theme_stylebox_override("disabled", _toolbar_style(Color("#AAB7BE"), Color("#D1D9DE")))
	start_button.add_theme_color_override("font_color", Color("#34280B"))
	start_button.pressed.connect(func():
		var started: bool = component.start_factory(item_id, slot_index) if is_factory else component.start_craft(item_id, slot_index)
		if started:
			status_label.text = "Production started: %s." % str(data.get("name", item_id))
		else:
			var latest_missing := ProductionManager.get_missing_inputs_text(item_id)
			status_label.text = "Not enough materials: %s" % latest_missing if not latest_missing.is_empty() else "Cannot start this production."
		open_production_panel(building)
	)
	detail_row.add_child(start_button)


func _count_empty_production_slots(component: ProductionComponent) -> int:
	var empty_count := 0
	for index in range(component.get_slot_count()):
		if component.get_slot(index).is_empty():
			empty_count += 1
	return empty_count

func _format_clock_duration(seconds: int) -> String:
	var safe_seconds := maxi(0, seconds)
	var hours := int(safe_seconds / 3600)
	var minutes := int((safe_seconds % 3600) / 60)
	var remainder := safe_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, remainder] if hours > 0 else "%02d:%02d" % [minutes, remainder]

func _format_duration(seconds: int) -> String:
	return _format_clock_duration(seconds)

func _clear_production_timer_tracking() -> void:
	_production_timer_labels.clear()
	_production_progress_bars.clear()
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
		label.text = _format_clock_duration(remaining)
		for progress in _production_progress_bars:
			if is_instance_valid(progress) and int(progress.get_meta("slot_index", -1)) == slot_index:
				var total_seconds := maxf(1.0, ProductionManager.get_production_time(item_id))
				progress.value = clampf(1.0 - float(remaining) / total_seconds, 0.0, 1.0)
		if remaining <= 0:
			need_rebuild = true
	if need_rebuild:
		open_production_panel(_production_building)

func _close_production_panel() -> void:
	_clear_production_timer_tracking()
	if is_instance_valid(production_overlay):
		production_overlay.queue_free()
	production_overlay = null
	production_panel = null


func _on_city_needs_pressed() -> void:
	BuildManager.cancel_placement()
	_close_production_panel()
	_close_storage_panel()
	_close_residential_panel()
	open_city_needs_panel()

func _on_city_needs_changed(_snapshot: Dictionary) -> void:
	if is_instance_valid(city_needs_overlay):
		open_city_needs_panel()

func _city_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F4F9FD")
	style.border_color = Color("#D3E7F4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _city_panel_heading(parent: VBoxContainer, title_text: String, close_callback: Callable) -> void:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	parent.add_child(heading)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(23 * _ui_scale))
	title.add_theme_color_override("font_color", Color("#17364A"))
	heading.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(42, 42) * _ui_scale
	close.add_theme_font_size_override("font_size", int(30 * _ui_scale))
	close.add_theme_color_override("font_color", Color("#17364A"))
	close.add_theme_stylebox_override("normal", _toolbar_style(Color("#DCECF5"), Color("#A8C9DA")))
	close.pressed.connect(close_callback)
	heading.add_child(close)

func open_city_needs_panel() -> void:
	_close_production_panel()
	_close_storage_panel()
	_close_residential_panel()
	if is_instance_valid(city_needs_overlay):
		city_needs_overlay.queue_free()
	city_needs_overlay = Control.new()
	city_needs_overlay.name = "CityNeedsOverlay"
	city_needs_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_needs_overlay.z_index = 120
	city_needs_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(city_needs_overlay)
	var shade := ColorRect.new()
	shade.name = "CityNeedsBackdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	city_needs_overlay.add_child(shade)
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(820.0 * _ui_scale, viewport_size.x * 0.92)
	var panel_height := minf(650.0 * _ui_scale, viewport_size.y * 0.90)
	var panel := PanelContainer.new()
	panel.name = "CityNeedsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	city_needs_overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.name = "CityNeedsLayout"
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	_city_panel_heading(layout, "CITY NEEDS  ·  PRODUCTION OVERVIEW", _close_city_needs_panel)
	var snapshot: Dictionary = CityDemandManager.get_city_snapshot()
	var summary: Dictionary = snapshot.get("summary", {})
	var storage: Dictionary = snapshot.get("storage", {})
	var city: Dictionary = snapshot.get("city", {})
	var summary_label := Label.new()
	summary_label.name = "CityNeedsSummary"
	summary_label.text = "LEVEL %d   ·   XP %d/%d   ·   POPULATION %s   ·   HAPPINESS %d%%   ·   STORAGE %d/%d   ·   HOMES READY %d/%d   ·   WAITING %d   ·   READY ORDERS %d" % [
		int(city.get("level", 1)), int(city.get("experience", 0)), int(city.get("xp_needed", 0)), _format_count(int(city.get("population", 0))), roundi(float(city.get("happiness", 0.0))),
		int(storage.get("used", 0)), int(storage.get("capacity", 0)),
		int(summary.get("ready_homes", 0)), int(summary.get("homes", 0)),
		int(summary.get("waiting_homes", 0)), int(summary.get("ready_orders", 0))
	]
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size.y = 28 * _ui_scale
	summary_label.add_theme_font_size_override("font_size", int(11 * _ui_scale))
	summary_label.add_theme_color_override("font_color", Color("#31566B"))
	layout.add_child(summary_label)
	var tabs := HBoxContainer.new()
	tabs.name = "CityNeedsResourceSummary"
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	for metric in [
		["SIMOLEONS", str(int(snapshot.get("economy", {}).get("simoleons", 0)))],
		["SIMCASH", str(int(snapshot.get("economy", {}).get("sim_cash", 0)))],
		["GOLDEN KEYS", str(int(snapshot.get("economy", {}).get("keys", 0)))],
		["FREE STORAGE", str(int(storage.get("free", 0)))]
	]:
		var badge := PanelContainer.new()
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.add_theme_stylebox_override("panel", _toolbar_style(Color("#E4F1F8"), Color("#C4DFED")))
		tabs.add_child(badge)
		var metric_label := Label.new()
		metric_label.text = str(metric[0]) + "\n" + str(metric[1])
		metric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		metric_label.add_theme_font_size_override("font_size", int(11 * _ui_scale))
		metric_label.add_theme_color_override("font_color", Color("#1C4358"))
		badge.add_child(metric_label)
	var scroll := ScrollContainer.new()
	scroll.name = "CityNeedsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var items_title := Label.new()
	items_title.text = "CITY-WIDE MATERIAL SHORTAGES"
	items_title.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	items_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(items_title)
	if snapshot.get("items", []).is_empty():
		var empty_needs := Label.new()
		empty_needs.text = "No active residential upgrade requirements. Build and complete a home to create the first city demand plan."
		empty_needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_needs.add_theme_color_override("font_color", Color("#617A88"))
		content.add_child(empty_needs)
	for item in snapshot.get("items", []):
		var row := PanelContainer.new()
		row.name = "CityNeed_" + str(item.get("item_id", "unknown"))
		row.add_theme_stylebox_override("panel", _toolbar_style(Color("#FFFFFF"), Color("#D6E7F0")))
		content.add_child(row)
		var row_layout := HBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 8)
		row.add_child(row_layout)
		var item_id := str(item.get("item_id", ""))
		var category := "raw" if ProductionManager.raw_materials.has(item_id) else "crafted"
		row_layout.add_child(Icons.make_item_icon(category, item_id, Vector2(44, 44) * _ui_scale))
		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 1)
		row_layout.add_child(text_stack)
		var item_title := Label.new()
		item_title.text = str(item.get("name", item_id))
		item_title.add_theme_font_size_override("font_size", int(13 * _ui_scale))
		item_title.add_theme_color_override("font_color", Color("#18394D"))
		text_stack.add_child(item_title)
		var counts := Label.new()
		counts.text = "Stored %d   ·   Required %d   ·   Producing %d   ·   Ready %d   ·   Deficit %d   ·   Next ready %s" % [
			int(item.get("stored", 0)), int(item.get("required", 0)), int(item.get("producing", 0)),
			int(item.get("ready", 0)), int(item.get("deficit", 0)), (_city_needs_duration(int(item.get("eta_seconds", -1))) if int(item.get("eta_seconds", -1)) >= 0 else "—")
		]
		counts.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		counts.add_theme_color_override("font_color", Color("#A13F35") if int(item.get("deficit", 0)) > 0 else Color("#34734D"))
		text_stack.add_child(counts)
		var supplier_list: Array = item.get("suppliers", [])
		var supplier_status := str(supplier_list[0].get("status", "")) if not supplier_list.is_empty() else "missing"
		var supplier_name := str(supplier_list[0].get("name", "Available")) if not supplier_list.is_empty() else "No registered supplier"
		if supplier_status == "constructing":
			supplier_name += " · UNDER CONSTRUCTION"
		var supplier_text := Label.new()
		supplier_text.text = "SUPPLIER  " + supplier_name
		supplier_text.add_theme_font_size_override("font_size", int(9 * _ui_scale))
		supplier_text.add_theme_color_override("font_color", Color("#607989"))
		text_stack.add_child(supplier_text)
		var action := Button.new()
		action.custom_minimum_size = Vector2(112, 38) * _ui_scale
		if int(item.get("deficit", 0)) > 0:
			action.text = "BUILD" if supplier_status == "not_built" else ("BUILDING" if supplier_status == "constructing" else "PRODUCE")
		else:
			action.text = "COLLECT" if int(item.get("ready", 0)) > 0 else "COVERED"
		action.disabled = supplier_list.is_empty() or (int(item.get("deficit", 0)) <= 0 and int(item.get("ready", 0)) <= 0)
		action.add_theme_stylebox_override("normal", _toolbar_style(Color("#E9BF45"), Color("#F8D978")))
		if not supplier_list.is_empty():
			action.pressed.connect(_open_city_need_supplier.bind(supplier_list[0]))
		row_layout.add_child(action)
	var homes_title := Label.new()
	homes_title.text = "RESIDENTIAL UPGRADE PLANS"
	homes_title.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	homes_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(homes_title)
	var note := Label.new()
	note.text = "Inventory is shared city-wide. The totals above are aggregated; item stock is not reserved for multiple homes."
	note.add_theme_font_size_override("font_size", int(9 * _ui_scale))
	note.add_theme_color_override("font_color", Color("#617A88"))
	content.add_child(note)
	for home in snapshot.get("homes", []):
		var home_card := PanelContainer.new()
		home_card.add_theme_stylebox_override("panel", _toolbar_style(Color("#FDFEFF"), Color("#D9E8EF")))
		content.add_child(home_card)
		var home_layout := VBoxContainer.new()
		home_layout.add_theme_constant_override("separation", 3)
		home_card.add_child(home_layout)
		var home_header := HBoxContainer.new()
		home_layout.add_child(home_header)
		var home_title := Label.new()
		home_title.text = "%s  ·  LEVEL %d → %d" % [str(home.get("name", "Home")), int(home.get("stage", 1)), int(home.get("next_stage", 6))]
		home_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home_title.add_theme_font_size_override("font_size", int(11 * _ui_scale))
		home_title.add_theme_color_override("font_color", Color("#24485B"))
		home_header.add_child(home_title)
		var home_button := Button.new()
		home_button.text = "UPGRADE" if bool(home.get("ready", false)) and int(home.get("stage", 1)) < 6 else "WAITING"
		home_button.disabled = not bool(home.get("ready", false)) or int(home.get("stage", 1)) >= 6
		home_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#55B96A"), Color("#A6E4A9")))
		home_button.pressed.connect(_upgrade_home_from_dashboard.bind(str(home.get("building_id", ""))))
		home_header.add_child(home_button)
		for need in home.get("needs", []):
			var need_line := Label.new()
			var need_status := "READY"
			var need_color := Color("#34734D")
			if int(need.get("stored", 0)) < int(need.get("required", 0)):
				if int(need.get("ready_to_collect", 0)) > 0:
					need_status = "READY TO COLLECT %d" % int(need.get("ready_to_collect", 0))
					need_color = Color("#9A6B1D")
				elif int(need.get("in_production", 0)) > 0:
					need_status = "IN PRODUCTION %d" % int(need.get("in_production", 0))
					need_color = Color("#315C8A")
				else:
					need_status = "SHORT %d" % int(need.get("shortage", 0))
					need_color = Color("#A13F35")
			need_line.text = "%s   %d / %d   ·   %s" % [
				str(need.get("name", need.get("item_id", ""))), int(need.get("stored", 0)), int(need.get("required", 0)), need_status
			]
			need_line.add_theme_font_size_override("font_size", int(9 * _ui_scale))
			need_line.add_theme_color_override("font_color", need_color)
			home_layout.add_child(need_line)
	var orders_title := Label.new()
	orders_title.text = "ACTIVE PRODUCTION QUEUE"
	orders_title.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	orders_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(orders_title)
	for order in snapshot.get("orders", []):
		var order_label := Label.new()
		order_label.text = "%s  ·  %s  ·  %s" % [
			str(order.get("building_name", "Production")), str(order.get("item_name", "")),
			"READY TO COLLECT" if bool(order.get("ready", false)) else _city_needs_duration(int(order.get("remaining", 0)))
		]
		order_label.add_theme_font_size_override("font_size", int(10 * _ui_scale))
		order_label.add_theme_color_override("font_color", Color("#34734D") if bool(order.get("ready", false)) else Color("#31566B"))
		content.add_child(order_label)

func _city_needs_duration(seconds: int) -> String:
	var safe := maxi(0, seconds)
	if safe >= 3600:
		return "%dh %02dm" % [safe / 3600, (safe % 3600) / 60]
	if safe >= 60:
		return "%dm %02ds" % [safe / 60, safe % 60]
	return "%ds" % safe

func _open_city_need_supplier(supplier: Dictionary) -> void:
	var building_id := str(supplier.get("building_id", ""))
	var building = BuildManager.buildings.get(building_id) if not building_id.is_empty() else null
	if is_instance_valid(building):
		if building.status != "completed":
			status_label.text = "%s is still under construction." % str(building.definition.get("name", "Supplier"))
			return
		_close_city_needs_panel()
		open_production_panel(building)
		return
	var type_id := str(supplier.get("building_type", ""))
	var definition: Dictionary = BuildManager.building_types.get(type_id, {})
	if definition.is_empty():
		status_label.text = "No verified supplier building is registered for this item."
		return
	_close_city_needs_panel()
	var category := str(definition.get("category", "commercial"))
	_on_category_pressed(category)
	_on_submenu_option(category, type_id)
	status_label.text = "Build %s to supply this city need." % str(definition.get("name", type_id))

func _upgrade_home_from_dashboard(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if is_instance_valid(building) and building.try_upgrade():
		_close_city_needs_panel()
		open_city_needs_panel()

func _close_city_needs_panel() -> void:
	if is_instance_valid(city_needs_overlay):
		city_needs_overlay.queue_free()
	city_needs_overlay = null

func open_residential_panel(building: Building) -> void:
	if not is_instance_valid(building) or building.status != "completed":
		return
	_close_city_needs_panel()
	_close_production_panel()
	_close_storage_panel()
	if is_instance_valid(residential_overlay):
		residential_overlay.queue_free()
	residential_overlay = Control.new()
	residential_overlay.name = "ResidentialUpgradeOverlay"
	residential_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	residential_overlay.z_index = 125
	residential_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(residential_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.62)
	residential_overlay.add_child(shade)
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(600.0 * _ui_scale, viewport_size.x * 0.90)
	var height := minf(520.0 * _ui_scale, viewport_size.y * 0.88)
	var panel := PanelContainer.new()
	panel.name = "ResidentialUpgradePanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	residential_overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	_city_panel_heading(layout, "RESIDENTIAL UPGRADE PLAN", _close_residential_panel)
	var stage := int(building.upgrade_stage)
	var requirements: Array = ProductionManager.get_upgrade_requirements(stage)
	var title := Label.new()
	title.text = "%s  ·  LEVEL %d → %d" % [str(building.definition.get("name", "Home")), stage, mini(stage + 1, 6)]
	title.add_theme_font_size_override("font_size", int(15 * _ui_scale))
	title.add_theme_color_override("font_color", Color("#24485B"))
	layout.add_child(title)
	var population_gain := ProductionManager.get_population_for_stage(mini(stage + 1, 6)) - int(building.current_population)
	var reward := Label.new()
	reward.text = "POPULATION +%d   ·   XP +%d   ·   SIMOLEONS +%d" % [maxi(0, population_gain), maxi(0, population_gain) + 10, 50 * (stage + 1)]
	reward.add_theme_font_size_override("font_size", int(11 * _ui_scale))
	reward.add_theme_color_override("font_color", Color("#34734D"))
	layout.add_child(reward)
	var all_available := not requirements.is_empty()
	for requirement in requirements:
		var item_id := str(requirement.get("item", ""))
		var amount := int(requirement.get("amount", 0))
		var owned := StorageManager.get_count(item_id)
		if owned < amount:
			all_available = false
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		layout.add_child(row)
		var icon_type := "raw" if ProductionManager.raw_materials.has(item_id) else "crafted"
		row.add_child(Icons.make_item_icon(icon_type, item_id, Vector2(46, 46) * _ui_scale))
		var item_label := Label.new()
		item_label.text = "%s   ·   %d / %d   ·   SHORT %d" % [CityDemandManager.get_item_name(item_id), owned, amount, maxi(0, amount - owned)]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.add_theme_font_size_override("font_size", int(12 * _ui_scale))
		item_label.add_theme_color_override("font_color", Color("#34734D") if owned >= amount else Color("#A13F35"))
		row.add_child(item_label)
		var supplier_rows: Array = CityDemandManager.get_suppliers_for_item(item_id)
		var supplier_line := Label.new()
		supplier_line.text = "SUPPLIER  " + (str(supplier_rows[0].get("name", "Unknown")) if not supplier_rows.is_empty() else "No registered supplier")
		supplier_line.add_theme_font_size_override("font_size", int(9 * _ui_scale))
		supplier_line.add_theme_color_override("font_color", Color("#607989"))
		layout.add_child(supplier_line)
	var upgrade := Button.new()
	upgrade.name = "ResidentialUpgradeButton"
	upgrade.text = "UPGRADE HOME" if stage < 6 else "MAXIMUM LEVEL"
	upgrade.disabled = stage >= 6 or not all_available
	upgrade.custom_minimum_size.y = 44 * _ui_scale
	upgrade.add_theme_stylebox_override("normal", _toolbar_style(Color("#55B96A"), Color("#A6E4A9")))
	upgrade.pressed.connect(_upgrade_residential_from_panel.bind(building))
	layout.add_child(upgrade)

func _upgrade_residential_from_panel(building: Building) -> void:
	if is_instance_valid(building) and building.try_upgrade():
		_close_residential_panel()

func _close_residential_panel() -> void:
	if is_instance_valid(residential_overlay):
		residential_overlay.queue_free()
	residential_overlay = null

func _on_storage_pressed() -> void:
	BuildManager.cancel_placement()
	_show_storage_panel()

func _show_storage_panel() -> void:
	_close_storage_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	storage_overlay = Control.new()
	storage_overlay.name = "StorageOverlay"
	storage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_overlay.z_index = 100
	storage_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(storage_overlay)

	var shade := ColorRect.new()
	shade.name = "StorageBackdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.70)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	storage_overlay.add_child(shade)

	var panel_width := minf(440.0 * _ui_scale, viewport_size.x * 0.82)
	var panel_height := minf(570.0 * _ui_scale, viewport_size.y * 0.88)
	storage_panel = PanelContainer.new()
	storage_panel.name = "CityStoragePanel"
	storage_panel.anchor_left = 0.5
	storage_panel.anchor_right = 0.5
	storage_panel.anchor_top = 0.5
	storage_panel.anchor_bottom = 0.5
	storage_panel.offset_left = -panel_width * 0.5
	storage_panel.offset_right = panel_width * 0.5
	storage_panel.offset_top = -panel_height * 0.5
	storage_panel.offset_bottom = panel_height * 0.5
	storage_panel.z_index = 1
	storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#F1F8FE")
	panel_style.border_color = Color("#D7EAF7")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	panel_style.shadow_size = 14
	panel_style.shadow_offset = Vector2(0, 7)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	storage_panel.add_theme_stylebox_override("panel", panel_style)
	storage_overlay.add_child(storage_panel)

	var layout := VBoxContainer.new()
	layout.name = "StorageLayout"
	layout.add_theme_constant_override("separation", 12)
	storage_panel.add_child(layout)

	var heading := HBoxContainer.new()
	heading.name = "StorageHeading"
	heading.add_theme_constant_override("separation", 8)
	layout.add_child(heading)
	var storage_icon := Icons.make_icon("storage", Vector2(62, 62) * _ui_scale)
	storage_icon.name = "StorageHeaderIcon"
	heading.add_child(storage_icon)
	var title := Label.new()
	title.name = "StorageTitle"
	title.text = "City Storage"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(27 * _ui_scale))
	title.add_theme_color_override("font_color", Color("#172330"))
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 5)
	heading.add_child(title)
	var close := Button.new()
	close.name = "StorageClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 46) * _ui_scale
	close.add_theme_font_size_override("font_size", int(34 * _ui_scale))
	close.add_theme_color_override("font_color", Color("#123B59"))
	close.add_theme_stylebox_override("normal", _toolbar_style(Color("#39A8E8"), Color("#8BD5FF")))
	close.add_theme_stylebox_override("hover", _toolbar_style(Color("#65C3F3"), Color.WHITE))
	close.add_theme_stylebox_override("pressed", _toolbar_style(Color("#2386C5"), Color("#D9F2FF")))
	close.pressed.connect(_close_storage_panel)
	heading.add_child(close)

	var capacity_wrap := Control.new()
	capacity_wrap.name = "StorageCapacityWrap"
	capacity_wrap.custom_minimum_size = Vector2(0, 48) * _ui_scale
	layout.add_child(capacity_wrap)
	var capacity_bar := ProgressBar.new()
	capacity_bar.name = "StorageCapacityBar"
	capacity_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capacity_bar.min_value = 0
	capacity_bar.max_value = maxi(1, StorageManager.capacity)
	capacity_bar.value = StorageManager.get_used()
	capacity_bar.show_percentage = false
	capacity_bar.add_theme_stylebox_override("background", _toolbar_style(Color("#BCE5F8"), Color("#D5F0FC")))
	capacity_bar.add_theme_stylebox_override("fill", _toolbar_style(Color("#FFB52E"), Color("#FFD36A")))
	capacity_wrap.add_child(capacity_bar)
	var capacity_label := Label.new()
	capacity_label.name = "StorageCapacity"
	capacity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capacity_label.text = "%d/%d" % [StorageManager.get_used(), StorageManager.capacity]
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_label.add_theme_font_size_override("font_size", int(23 * _ui_scale))
	capacity_label.add_theme_color_override("font_color", Color("#172330"))
	capacity_label.add_theme_color_override("font_outline_color", Color.WHITE)
	capacity_label.add_theme_constant_override("outline_size", 4)
	capacity_wrap.add_child(capacity_label)

	var divider := HSeparator.new()
	divider.name = "StorageDivider"
	divider.add_theme_color_override("separator", Color("#C8DFEC"))
	layout.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "StorageItemsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "StorageItemsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var upgrade := Button.new()
	upgrade.name = "StorageIncreaseCapacity"
	upgrade.text = "INCREASE CAPACITY"
	upgrade.custom_minimum_size = Vector2(0, 64) * _ui_scale
	upgrade.add_theme_font_size_override("font_size", int(22 * _ui_scale))
	upgrade.add_theme_color_override("font_color", Color.WHITE)
	upgrade.add_theme_color_override("font_shadow_color", Color("#36520B"))
	upgrade.add_theme_constant_override("shadow_offset_x", 1)
	upgrade.add_theme_constant_override("shadow_offset_y", 2)
	upgrade.add_theme_stylebox_override("normal", _toolbar_style(Color("#83D900"), Color("#B7F44C")))
	upgrade.add_theme_stylebox_override("hover", _toolbar_style(Color("#9BEA16"), Color("#D8FF83")))
	upgrade.add_theme_stylebox_override("pressed", _toolbar_style(Color("#65B900"), Color("#A6E94C")))
	upgrade.disabled = true
	upgrade.tooltip_text = "Capacity expansion purchase is not configured yet."
	layout.add_child(upgrade)
	_refresh_storage_panel()


func _refresh_storage_panel() -> void:
	if not is_instance_valid(storage_panel):
		return
	var used := StorageManager.get_used()
	var capacity_label := storage_panel.find_child("StorageCapacity", true, false) as Label
	if capacity_label:
		capacity_label.text = "%d/%d" % [used, StorageManager.capacity]
	var capacity_bar := storage_panel.find_child("StorageCapacityBar", true, false) as ProgressBar
	if capacity_bar:
		capacity_bar.max_value = maxi(1, StorageManager.capacity)
		capacity_bar.value = used
	var grid := storage_panel.find_child("StorageItemsGrid", true, false) as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var items := StorageManager.get_all_items()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.name = "StorageEmptyState"
		empty_label.text = "Your City Storage is empty."
		empty_label.custom_minimum_size = Vector2(0, 120) * _ui_scale
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
		empty_label.add_theme_color_override("font_color", Color("#526C7C"))
		grid.add_child(empty_label)
		return
	var ids: Array = items.keys()
	ids.sort()
	for item_id in ids:
		var item_key := str(item_id)
		var definition: Dictionary = StorageManager.item_definitions.get(item_key, {})
		var item_name := str(definition.get("name", item_key.capitalize()))
		var item_category := str(definition.get("type", "crafted"))
		var item_cell := Control.new()
		item_cell.name = "StorageItem_" + item_key
		item_cell.custom_minimum_size = Vector2(180, 100) * _ui_scale
		item_cell.tooltip_text = item_name
		grid.add_child(item_cell)
		var item_row := HBoxContainer.new()
		item_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_row.alignment = BoxContainer.ALIGNMENT_CENTER
		item_row.add_theme_constant_override("separation", 3)
		item_cell.add_child(item_row)
		var item_icon := Icons.make_item_icon(item_category, item_key, Vector2(78, 78) * _ui_scale)
		item_icon.name = "StorageItemIcon"
		item_row.add_child(item_icon)
		var count_label := Label.new()
		count_label.name = "StorageItemCount"
		count_label.text = str(int(items[item_id]))
		count_label.custom_minimum_size.x = 30 * _ui_scale
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", int(25 * _ui_scale))
		count_label.add_theme_color_override("font_color", Color("#101820"))
		count_label.add_theme_color_override("font_outline_color", Color.WHITE)
		count_label.add_theme_constant_override("outline_size", 2)
		item_row.add_child(count_label)


func _close_storage_panel() -> void:
	if is_instance_valid(storage_overlay):
		storage_overlay.queue_free()
	storage_overlay = null
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
	if was_moving:
		status_label.text = "Move cancelled. Building returned to its original location."
	elif was_bulldozing:
		status_label.text = "Bulldozer cancelled."
	else:
		status_label.text = "Cancelled."

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
