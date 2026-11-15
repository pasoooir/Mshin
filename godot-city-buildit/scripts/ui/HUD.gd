extends CanvasLayer

const Icons = preload("res://scripts/ui/Icons.gd")
const LevelUpEffectScript = preload("res://scripts/ui/LevelUpEffect.gd")
const LandExpansionPanelScript = preload("res://scripts/ui/LandExpansionPanel.gd")

const STORAGE_CAPACITY_UPGRADE_COST := 500
const STORAGE_CAPACITY_UPGRADE_GAIN := 10

const SERVICE_GROUPS := [
	{"id":"power", "label":"Power", "buildings":["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear"]},
	{"id":"water", "label":"Water", "buildings":["water_tower", "water_pump"]},
	{"id":"sewage", "label":"Sewage", "buildings":["sewage_small", "sewage_basic", "sewage_deluxe"]},
	{"id":"waste", "label":"Waste", "buildings":["waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling"]},
	{"id":"fire", "label":"Fire", "buildings":["fire_station_small", "fire_station", "fire_station_deluxe"]},
	{"id":"police", "label":"Police", "buildings":["police_small", "police_basic", "police_precinct"]},
	{"id":"health", "label":"Health", "buildings":["clinic_small", "clinic", "hospital"]},
	{"id":"government", "label":"Government", "buildings":["town_hall", "epic_projects_department"]},
	{"id":"trade", "label":"Trade", "buildings":["trade_depot", "global_trade_hq", "cargo_port"]}
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
var xp_info_panel: PanelContainer
var xp_info_label: Label
var storage_label: Label
var storage_panel: PanelContainer
var storage_overlay: Control
var production_panel: PanelContainer
var production_overlay: Control
var city_needs_overlay: Control
var residential_overlay: Control
var epic_project_overlay: Control
var achievements_overlay: Control
var regions_overlay: Control
var _epic_panel_building: Building = null
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
var service_warning_panel: PanelContainer
var trade_overlay: Control
var trade_panel: PanelContainer
var settings_overlay: Control
var placement_controls: PanelContainer
var _trade_active_tab := "depot"
var _regional_trade_source_id := ""
var _regional_trade_target_id := ""
var _regional_trade_item_id := ""
var _regional_trade_amount := 1
var service_warning_label: Label
var _catalog_selected_type := ""

func _ready() -> void:
	# Keep the existing gameplay signal wiring intact.
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	HappinessManager.immigrants_arrived.connect(_on_immigrants_arrived)
	HappinessManager.immigration_advice.connect(_on_immigration_advice)
	HappinessManager.happiness_recalculated.connect(_on_city_happiness_recalculated)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up_rewarded.connect(_on_level_up_rewarded)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.keys_changed.connect(_on_keys_changed)
	StorageManager.storage_changed.connect(_on_storage_changed)
	CityDemandManager.city_needs_changed.connect(_on_city_needs_changed)
	BuildManager.placement_mode_changed.connect(_on_placement_mode)
	ServiceManager.power_changed.connect(_on_power_changed)
	ServiceManager.water_changed.connect(_on_water_changed)
	ServiceManager.sewage_changed.connect(_on_sewage_changed)
	ServiceManager.waste_changed.connect(_on_waste_changed)
	ServiceManager.workforce_changed.connect(_on_workforce_changed)
	TrafficManager.traffic_changed.connect(_on_traffic_changed)
	TradeManager.trade_state_changed.connect(_on_trade_state_changed)
	EpicProjectManager.epic_state_changed.connect(_on_epic_project_state_changed)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	AchievementManager.state_changed.connect(_on_achievement_state_changed)
	RegionManager.region_changed.connect(_on_region_changed)
	RegionManager.region_state_changed.connect(_on_region_state_changed)
	PerformanceMonitor.benchmark_progress.connect(_on_performance_benchmark_progress)
	PerformanceMonitor.benchmark_finished.connect(_on_performance_benchmark_finished)

	var viewport_size := get_viewport().get_visible_rect().size
	_ui_scale = clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.90, 1.20)
	_build_top_hud()
	_build_toolbars()
	var land_expansion_panel := LandExpansionPanelScript.new()
	land_expansion_panel.name = "LandExpansionPanel"
	add_child(land_expansion_panel)
	_build_service_warning_banner()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout()
	_update_all()
	status_label.text = "Tap Build, choose Residential, then place your first house beside a road."

func _on_land_expansion_pressed() -> void:
	var panel := get_node_or_null("LandExpansionPanel")
	if is_instance_valid(panel) and panel.has_method("open_panel"):
		panel.open_panel()

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	if is_instance_valid(production_panel) and is_instance_valid(_production_building):
		open_production_panel(_production_building)

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
	if is_instance_valid(service_warning_panel):
		var warning_width := minf(680.0, maxf(240.0, viewport_size.x - 24.0 * scale_factor))
		service_warning_panel.offset_left = -warning_width * 0.5
		service_warning_panel.offset_right = warning_width * 0.5
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
		var half_actions := minf(viewport_size.x * 0.42, 360.0 * scale_factor)
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
	level_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	level_badge.tooltip_text = "Mayor Level. The ring shows progress toward the next level. Earn XP through building, production, achievements and sustained city happiness."
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
	xp_text = _make_hud_value("0 / %d XP" % GameManager.get_xp_needed(), int(20 * _ui_scale))
	xp_text.custom_minimum_size = Vector2(105, 24) * _ui_scale
	xp_text.tooltip_text = "XP raises your Mayor Level. Earn it by placing/completing buildings, collecting production, unlocking achievements, and keeping average city happiness at 80 percent or higher for 60 seconds."
	xp_row.add_child(xp_text)
	xp_progress = ProgressBar.new()
	xp_progress.name = "ExperienceProgress"
	xp_progress.custom_minimum_size = Vector2(210, 18) * _ui_scale
	xp_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_progress.min_value = 0
	xp_progress.max_value = GameManager.get_xp_needed()
	xp_progress.value = GameManager.experience
	xp_progress.show_percentage = false
	xp_progress.tooltip_text = "Progress toward the next Mayor Level. The number shows current XP / XP required."
	xp_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_progress)
	var xp_info_button := Button.new()
	xp_info_button.name = "MayorLevelInfoButton"
	xp_info_button.text = "?"
	xp_info_button.custom_minimum_size = Vector2(30, 28) * _ui_scale
	xp_info_button.focus_mode = Control.FOCUS_NONE
	xp_info_button.tooltip_text = "Tap to learn how Mayor Level and XP work."
	xp_info_button.pressed.connect(_toggle_xp_info_panel)
	_add_theme_color(xp_info_button, Color("#79C9F2"))
	xp_row.add_child(xp_info_button)

	xp_info_panel = PanelContainer.new()
	xp_info_panel.name = "MayorLevelInfoPanel"
	xp_info_panel.position = Vector2(14, 194) * _ui_scale
	xp_info_panel.custom_minimum_size = Vector2(390, 154) * _ui_scale
	xp_info_panel.size = xp_info_panel.custom_minimum_size
	xp_info_panel.z_index = 45
	xp_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var xp_panel_style := StyleBoxFlat.new()
	xp_panel_style.bg_color = Color(0.055, 0.09, 0.14, 0.96)
	xp_panel_style.border_color = Color("#79C9F2")
	xp_panel_style.set_border_width_all(2)
	xp_panel_style.set_corner_radius_all(12)
	xp_panel_style.content_margin_left = 12
	xp_panel_style.content_margin_right = 12
	xp_panel_style.content_margin_top = 9
	xp_panel_style.content_margin_bottom = 9
	xp_info_panel.add_theme_stylebox_override("panel", xp_panel_style)
	top_hud.add_child(xp_info_panel)
	var xp_panel_content := VBoxContainer.new()
	xp_panel_content.add_theme_constant_override("separation", 5)
	xp_info_panel.add_child(xp_panel_content)
	var xp_panel_header := HBoxContainer.new()
	xp_panel_content.add_child(xp_panel_header)
	var xp_panel_title := Label.new()
	xp_panel_title.text = "MAYOR LEVEL PROGRESS"
	xp_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_panel_title.add_theme_color_override("font_color", Color("#FFE28A"))
	xp_panel_title.add_theme_font_size_override("font_size", int(19 * _ui_scale))
	xp_panel_header.add_child(xp_panel_title)
	var xp_panel_close := Button.new()
	xp_panel_close.name = "MayorLevelInfoClose"
	xp_panel_close.text = "×"
	xp_panel_close.custom_minimum_size = Vector2(30, 26) * _ui_scale
	xp_panel_close.focus_mode = Control.FOCUS_NONE
	xp_panel_close.pressed.connect(func() -> void: xp_info_panel.hide())
	xp_panel_header.add_child(xp_panel_close)
	xp_info_label = Label.new()
	xp_info_label.name = "MayorLevelInfoText"
	xp_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xp_info_label.add_theme_color_override("font_color", Color.WHITE)
	xp_info_label.add_theme_font_size_override("font_size", int(17 * _ui_scale))
	xp_panel_content.add_child(xp_info_label)
	xp_info_panel.hide()
	_refresh_xp_info_panel()

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
	context_header_title.add_theme_color_override("font_color", Color("#17394D"))
	context_header_title.add_theme_font_size_override("font_size", int(25 * _ui_scale))
	stack.add_child(context_header_title)
	context_header_subtitle = Label.new()
	context_header_subtitle.name = "ContextSubtitle"
	context_header_subtitle.text = "Choose a category to explore your city"
	context_header_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_header_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_header_subtitle.add_theme_color_override("font_color", Color("#DCEAF3"))
	context_header_subtitle.add_theme_font_size_override("font_size", int(17 * _ui_scale))
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
	if detail.is_empty() and category == "services":
		detail = _service_summary_text()
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
	toolbar.anchor_bottom = 0.82
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
	var land_button := Button.new()
	land_button.name = "Tool_LandExpansion"
	land_button.anchor_left = 1.0
	land_button.anchor_right = 1.0
	land_button.anchor_top = 0.835
	land_button.anchor_bottom = 0.985
	land_button.offset_left = -toolbar_width - 8.0 * _ui_scale
	land_button.offset_right = -6.0 * _ui_scale
	land_button.offset_top = 0.0
	land_button.offset_bottom = 0.0
	land_button.custom_minimum_size = Vector2(toolbar_width, 84.0 * _ui_scale)
	land_button.tooltip_text = "Expand city land with Dozer Wheel, Dozer Blade and Dozer Exhaust."
	land_button.focus_mode = Control.FOCUS_NONE
	land_button.mouse_filter = Control.MOUSE_FILTER_PASS
	land_button.z_index = 61
	land_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	land_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	land_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var land_icon := Icons.make_icon("bulldoze", Vector2(icon_size, icon_size))
	land_icon.name = "CategoryPNG"
	land_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	land_icon.offset_left = 4.0 * _ui_scale
	land_icon.offset_top = 3.0 * _ui_scale
	land_icon.offset_right = -4.0 * _ui_scale
	land_icon.offset_bottom = -3.0 * _ui_scale
	land_button.add_child(land_icon)
	add_child(land_button)
	land_button.pressed.connect(_on_land_expansion_pressed)
	bottom_actions = HBoxContainer.new()
	bottom_actions.name = "BottomActions"
	bottom_actions.anchor_left = 0.5
	bottom_actions.anchor_right = 0.5
	bottom_actions.anchor_top = 1.0
	bottom_actions.anchor_bottom = 1.0
	bottom_actions.offset_left = -300.0 * _ui_scale
	bottom_actions.offset_right = 300.0 * _ui_scale
	bottom_actions.offset_top = -104.0 * _ui_scale
	bottom_actions.offset_bottom = -14.0 * _ui_scale
	bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_actions.add_theme_constant_override("separation", 10)
	bottom_actions.z_index = 62
	add_child(bottom_actions)
	for item in [["storage","Storage"],["city_needs","City Needs"],["trade","Trade"],["regions","Regions"],["achievements","Achievements"],["save","Save"]]:
		var button := _make_icon_button(str(item[0]), str(item[1]), Vector2(86, 76) * _ui_scale)
		button.name = "CityNeedsAction" if str(item[0]) == "city_needs" else str(item[0]).capitalize() + "Action"
		bottom_actions.add_child(button)
		match str(item[0]):
			"storage": button.pressed.connect(_on_storage_pressed)
			"city_needs": button.pressed.connect(_on_city_needs_pressed)
			"trade": button.pressed.connect(_on_trade_pressed)
			"achievements": button.pressed.connect(_on_achievements_pressed)
			"regions": button.pressed.connect(_on_regions_pressed)
			"save": button.pressed.connect(_on_save_pressed)
	var settings_button := _make_icon_button("settings", "Settings", Vector2(70, 76) * _ui_scale)
	settings_button.name = "SettingsAction"
	settings_button.pressed.connect(_on_settings_pressed)
	bottom_actions.add_child(settings_button)
	_build_placement_controls()
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
	label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
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
		_add_submenu_button("road_upgrade", "Upgrade Road", "road_upgrade", "2 → 4 → 6 lanes → Avenue", false, "road")
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
				var lock_reason := BuildManager.get_factory_build_lock_reason(str(type_id))
				if lock_reason != "":
					detail += " · " + lock_reason
					locked = true
			var region_lock_reason := BuildManager.get_region_build_lock_reason(str(type_id))
			if region_lock_reason != "":
				detail += " · " + region_lock_reason
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
				var population_lock := BuildManager.get_population_build_lock_reason(type_id)
				if population_lock != "":
					detail += " · " + population_lock
				if int(definition.get("fire", 0)) > 0 or int(definition.get("police", 0)) > 0 or int(definition.get("health", 0)) > 0:
					detail += " · Coverage: %d tiles" % int(definition.get("coverage_tiles", 15))
				if int(definition.get("pollution", 0)) > 0:
					detail += " · " + str(definition.get("pollution_label", "Pollutes"))
				if str(definition.get("service_group", "")) in ["sewage", "waste"]:
					detail += " · City-wide capacity · Gateway road required"
				_add_submenu_button(type_id, str(definition.get("name", type_id)), type_id, detail, false, parent_category, int(definition.get("level", 1)), population_lock != "")
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
		lock.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		lock.add_theme_color_override("font_color", Color("#A66A16"))
		art.add_child(lock)
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 34 * _ui_scale
	label.add_theme_color_override("font_color", Color("#344B5B") if not level_locked else Color("#84929B"))
	label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	content.add_child(label)
	var count := Label.new()
	count.name = "BuildingCount"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.text = "%d/1" % _count_existing_buildings(option_id)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_color_override("font_color", Color("#748795"))
	count.add_theme_font_size_override("font_size", int(15 * _ui_scale))
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
	var scroll := ScrollContainer.new()
	scroll.name = "BuildingInfoScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_info_panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 4)
	scroll.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = str(definition.get("name", type_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#263746"))
	title.add_theme_font_size_override("font_size", int(21 * _ui_scale))
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
	var required_population := int(definition.get("population_required", 0))
	var requirements_text := "Level %d" % required_level
	if required_population > 0:
		requirements_text += " · Population %s" % _format_count(required_population)
	var region_lock := BuildManager.get_region_build_lock_reason(type_id)
	if not region_lock.is_empty():
		requirements_text += " · " + region_lock
	_add_info_line(layout, "Requirements", requirements_text)
	var population_lock := BuildManager.get_population_build_lock_reason(type_id)
	var factory_lock := BuildManager.get_factory_build_lock_reason(type_id) if str(definition.get("category", "")) == "industrial" else ""
	_add_info_line(layout, "Construction", _format_duration(int(definition.get("build_time", 0))))
	var construction_bom := BuildManager.get_construction_bom(type_id)
	var bom_lines: Array[String] = []
	for item_id in construction_bom:
		var item_definition := ProductionManager.get_item_definition(str(item_id))
		var item_name := str(item_definition.get("name", item_id))
		bom_lines.append("%s ×%d (stock %d)" % [item_name, int(construction_bom[item_id]), StorageManager.get_count(str(item_id))])
	_add_info_line(layout, "Materials", "No material charge" if bom_lines.is_empty() else ", ".join(bom_lines))
	_add_info_line(layout, "BOM source", BuildManager.get_construction_bom_source(type_id))
	var bom_lock := BuildManager.get_construction_bom_lock_reason(type_id)
	if not bom_lock.is_empty():
		status_label.text = bom_lock
	if GameManager.level < required_level:
		status_label.text = "Unlocked at Level %d." % required_level
	elif not region_lock.is_empty():
		status_label.text = region_lock
	var can_build := GameManager.level >= required_level and population_lock.is_empty() and factory_lock.is_empty() and region_lock.is_empty() and bom_lock.is_empty()
	var build := Button.new()
	build.name = "CatalogBuildButton"
	build.text = "BUILD" if can_build else ("NEEDS MATERIALS" if not bom_lock.is_empty() else ("LOCKED · " + region_lock if not region_lock.is_empty() else ("LOCKED · " + factory_lock if not factory_lock.is_empty() else ("LOCKED · POPULATION %s" % _format_count(required_population) if population_lock != "" else "LOCKED · LEVEL %d" % required_level))))
	build.disabled = not can_build
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
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var population_lock := BuildManager.get_population_build_lock_reason(type_id)
	if population_lock != "":
		status_label.text = population_lock
		return
	if definition.get("category", "") == "industrial":
		var lock_reason := BuildManager.get_factory_build_lock_reason(type_id)
		if lock_reason != "":
			status_label.text = lock_reason
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
		road_system.set_road_upgrade_mode(false)

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

func _start_road_upgrade_mode() -> void:
	_set_tool_modes_off()
	BuildManager.cancel_placement()
	var scene := get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system:
		road_system.set_road_upgrade_mode(true)
		status_label.text = "Road upgrade mode — tap a road tile. Unlocks: 4 lanes Lv 9, 6 lanes Lv 15, Avenue Lv 20. Costs: 300 / 1200 / 1500 per tile."
	else:
		status_label.text = "Road system is unavailable."

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
			_start_road_upgrade_mode()
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

func _build_service_warning_banner() -> void:
	service_warning_panel = PanelContainer.new()
	service_warning_panel.name = "PersistentServiceWarnings"
	service_warning_panel.anchor_left = 0.5
	service_warning_panel.anchor_right = 0.5
	service_warning_panel.anchor_top = 0.0
	service_warning_panel.anchor_bottom = 0.0
	service_warning_panel.offset_left = -320.0
	service_warning_panel.offset_top = 112.0
	service_warning_panel.offset_right = 320.0
	service_warning_panel.offset_bottom = 164.0
	service_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	service_warning_panel.z_index = 20
	storage_panel.add_theme_stylebox_override("panel", _city_panel_style())
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
	upgrade.disabled = false
	upgrade.text = "INCREASE CAPACITY  (+%d) — %d" % [STORAGE_CAPACITY_UPGRADE_GAIN, STORAGE_CAPACITY_UPGRADE_COST]
	upgrade.tooltip_text = "Add %d storage slots for %d Simoleons." % [STORAGE_CAPACITY_UPGRADE_GAIN, STORAGE_CAPACITY_UPGRADE_COST]
	upgrade.pressed.connect(_on_storage_capacity_upgrade_pressed)
	layout.add_child(upgrade)
	_refresh_storage_panel()


func _on_storage_capacity_upgrade_pressed() -> void:
	if EconomyManager.simoleons < STORAGE_CAPACITY_UPGRADE_COST:
		status_label.text = "Not enough Simoleons. Need %d; you have %d." % [STORAGE_CAPACITY_UPGRADE_COST, EconomyManager.simoleons]
		return
	if not StorageManager.try_upgrade_capacity(STORAGE_CAPACITY_UPGRADE_COST, STORAGE_CAPACITY_UPGRADE_GAIN):
		status_label.text = "Storage upgrade failed. No capacity was added."
		return
	# StorageManager emits capacity_changed and storage_changed; the latter refreshes this open panel.
	status_label.text = "Storage expanded to %d slots." % StorageManager.capacity


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
		empty_label.add_theme_font_size_override("font_size", int(22 * _ui_scale))
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

func open_trade_panel(tab: String = "depot") -> void:
	BuildManager.cancel_placement()
	_show_trade_panel(tab)

func _close_trade_panel() -> void:
	if is_instance_valid(trade_overlay):
		trade_overlay.queue_free()
	trade_overlay = null
	trade_panel = null

func _show_trade_panel(tab: String = "depot") -> void:
	_close_trade_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	trade_overlay = Control.new()
	trade_overlay.name = "TradeOverlay"
	trade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trade_overlay.z_index = 110
	trade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(trade_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "TradeBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.035, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	trade_overlay.add_child(backdrop)

	var panel_width := minf(920.0 * _ui_scale, viewport_size.x * 0.96)
	var panel_height := minf(790.0 * _ui_scale, viewport_size.y * 0.94)
	trade_panel = PanelContainer.new()
	trade_panel.name = "TradePanel"
	trade_panel.anchor_left = 0.5
	trade_panel.anchor_right = 0.5
	trade_panel.anchor_top = 0.5
	trade_panel.anchor_bottom = 0.5
	trade_panel.offset_left = -panel_width * 0.5
	trade_panel.offset_right = panel_width * 0.5
	trade_panel.offset_top = -panel_height * 0.5
	trade_panel.offset_bottom = panel_height * 0.5
	trade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	trade_panel.add_theme_stylebox_override("panel", _city_panel_style())
	trade_overlay.add_child(trade_panel)

	var layout := VBoxContainer.new()
	layout.name = "TradeLayout"
	layout.add_theme_constant_override("separation", 10)
	trade_panel.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "City Trade"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(26 * _ui_scale))
	title.add_theme_color_override("font_color", Color("#172330"))
	heading.add_child(title)
	var close := Button.new()
	close.name = "TradeClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44) * _ui_scale
	close.add_theme_font_size_override("font_size", int(32 * _ui_scale))
	close.pressed.connect(_close_trade_panel)
	heading.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	var depot_tab := Button.new()
	depot_tab.name = "TradeDepotTab"
	depot_tab.text = "TRADE DEPOT"
	depot_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depot_tab.pressed.connect(_show_trade_panel.bind("depot"))
	tabs.add_child(depot_tab)
	var market_tab := Button.new()
	market_tab.name = "GlobalMarketTab"
	market_tab.text = "GLOBAL TRADE"
	market_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_tab.pressed.connect(_show_trade_panel.bind("market"))
	tabs.add_child(market_tab)
	var ship_tab := Button.new()
	ship_tab.name = "CargoShipTab"
	ship_tab.text = "CARGO SHIP"
	ship_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_tab.pressed.connect(_show_trade_panel.bind("ship"))
	tabs.add_child(ship_tab)
	var regional_tab := Button.new()
	regional_tab.name = "RegionalTradeTab"
	regional_tab.text = "REGIONAL"
	regional_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regional_tab.pressed.connect(_show_trade_panel.bind("regional"))
	tabs.add_child(regional_tab)

	var scroll := ScrollContainer.new()
	scroll.name = "TradeContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "TradeContent"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	_trade_active_tab = tab if tab in ["depot", "market", "ship", "regional"] else "depot"
	if _trade_active_tab == "market":
		market_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	elif _trade_active_tab == "ship":
		ship_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	elif _trade_active_tab == "regional":
		regional_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	else:
		depot_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	_refresh_trade_panel_content()

func _refresh_trade_panel_content() -> void:
	if not is_instance_valid(trade_panel):
		return
	var body := trade_panel.find_child("TradeContent", true, false) as VBoxContainer
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if _trade_active_tab == "market":
		_build_global_trade_content(body)
	elif _trade_active_tab == "ship":
		_build_cargo_ship_content(body)
	elif _trade_active_tab == "regional":
		_build_regional_trade_content(body)
	else:
		_build_trade_depot_content(body)

func _on_trade_state_changed() -> void:
	if is_instance_valid(trade_panel) and trade_panel.visible:
		_refresh_trade_panel_content()

func _trade_message(parent: VBoxContainer, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 70 * _ui_scale
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(21 * _ui_scale))
	label.add_theme_color_override("font_color", Color("#526C7C"))
	parent.add_child(label)

func _build_trade_depot_content(parent: VBoxContainer) -> void:
	if GameManager.population < TradeManager.DEPOT_UNLOCK_POPULATION:
		_trade_message(parent, "Trade Depot unlocks at 8,000 city population.")
		return
	if not TradeManager.has_trade_building("trade_depot"):
		_trade_message(parent, "Place and complete the Trade Depot from Services → Trade to start selling city products.")
		return

	var title_row := HBoxContainer.new()
	title_row.add_child(Icons.make_item_icon("ui", "trade_depot", Vector2(36, 36) * _ui_scale))
	parent.add_child(title_row)
	var heading := Label.new()
	heading.text = "LIST PRODUCTS · 4 MARKET SLOTS"
	heading.add_theme_font_size_override("font_size", int(21 * _ui_scale))
	heading.add_theme_color_override("font_color", Color("#24465A"))
	title_row.add_child(heading)
	var items := StorageManager.get_all_items()
	var item_ids: Array = items.keys()
	item_ids.sort()
	if item_ids.is_empty():
		_trade_message(parent, "City Storage is empty. Produce or collect items before listing them.")
	for item_value in item_ids:
		var item_id := str(item_value)
		var count := int(items[item_value])
		var row := HBoxContainer.new()
		row.name = "TradeListRow_" + item_id
		row.custom_minimum_size.y = 48 * _ui_scale
		parent.add_child(row)
		var label := Label.new()
		label.text = "%s  ×%d" % [str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize())), count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#263746"))
		row.add_child(label)
		var list_button := Button.new()
		list_button.name = "TradeList_" + item_id
		list_button.text = "LIST 1 · §%d" % ProductionManager.get_item_value(item_id)
		list_button.disabled = not TradeManager.can_list_for_sale(item_id, 1)
		list_button.pressed.connect(_on_trade_list_item.bind(item_id))
		row.add_child(list_button)

	var listings_heading := Label.new()
	listings_heading.text = "YOUR LISTINGS"
	listings_heading.add_theme_font_size_override("font_size", int(21 * _ui_scale))
	listings_heading.add_theme_color_override("font_color", Color("#24465A"))
	parent.add_child(listings_heading)
	var listings := TradeManager.get_sell_slots()
	if listings.is_empty():
		_trade_message(parent, "No active listings.")
	for index in range(listings.size()):
		var listing: Dictionary = listings[index]
		var row := HBoxContainer.new()
		row.name = "TradeListing_%d" % index
		row.custom_minimum_size.y = 48 * _ui_scale
		parent.add_child(row)
		var item_name := str(StorageManager.item_definitions.get(str(listing.get("item_id", "")), {}).get("name", str(listing.get("item_id", "Item")).capitalize()))
		var ready := bool(listing.get("ready", false))
		var status := "READY TO COLLECT" if ready else "%ds remaining" % ceili(float(listing.get("time_left", 0.0)))
		var label := Label.new()
		label.text = "%s ×%d · %s" % [item_name, int(listing.get("amount", 0)), status]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#263746"))
		row.add_child(label)
		var collect := Button.new()
		collect.name = "TradeCollect_%d" % index
		collect.text = "COLLECT §%d" % int(listing.get("price", 0))
		collect.disabled = not ready
		collect.pressed.connect(_on_trade_collect_sale.bind(index))
		row.add_child(collect)

func _build_global_trade_content(parent: VBoxContainer) -> void:
	if GameManager.population < TradeManager.GLOBAL_TRADE_UNLOCK_POPULATION:
		_trade_message(parent, "Global Trade HQ unlocks at 10,000 city population.")
		return
	if not TradeManager.has_trade_building("global_trade_hq"):
		_trade_message(parent, "Place and complete Global Trade HQ from Services → Trade to access the market.")
		return
	_trade_message(parent, "Offline local market simulation. These offers are generated by the game; live player-to-player trading is not connected.")
	var offers := TradeManager.get_market_offers()
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var item_id := str(offer.get("item_id", ""))
		var amount := int(offer.get("amount", 0))
		var price := int(offer.get("price", 0))
		var row := HBoxContainer.new()
		row.name = "GlobalOffer_%d" % index
		row.custom_minimum_size.y = 54 * _ui_scale
		parent.add_child(row)
		var label := Label.new()
		label.text = "%s ×%d · §%d" % [str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize())), amount, price]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#263746"))
		row.add_child(label)
		var buy := Button.new()
		buy.name = "GlobalBuy_%d" % index
		buy.text = "SOLD" if bool(offer.get("sold", false)) else "BUY"
		buy.disabled = bool(offer.get("sold", false)) or StorageManager.get_free() < amount or not EconomyManager.can_afford(price)
		buy.pressed.connect(_on_trade_buy_offer.bind(index))
		row.add_child(buy)

func _ensure_regional_trade_selection() -> void:
	var unlocked: Array[String] = RegionManager.unlocked_regions.duplicate()
	if unlocked.is_empty():
		return
	if _regional_trade_source_id not in unlocked:
		_regional_trade_source_id = RegionManager.active_region_id
	if _regional_trade_source_id not in unlocked:
		_regional_trade_source_id = unlocked[0]
	if _regional_trade_target_id not in unlocked or _regional_trade_target_id == _regional_trade_source_id:
		_regional_trade_target_id = ""
		for region_id in unlocked:
			if region_id != _regional_trade_source_id:
				_regional_trade_target_id = region_id
				break
	var eligible_items := TradeManager.get_trade_eligible_item_ids()
	eligible_items.sort()
	if _regional_trade_item_id not in eligible_items and not eligible_items.is_empty():
		_regional_trade_item_id = eligible_items[0]

func _on_regional_trade_source_selected(index: int, option: OptionButton) -> void:
	_regional_trade_source_id = str(option.get_item_metadata(index))
	if _regional_trade_source_id == _regional_trade_target_id:
		_regional_trade_target_id = ""
	_ensure_regional_trade_selection()
	_refresh_trade_panel_content()

func _on_regional_trade_target_selected(index: int, option: OptionButton) -> void:
	_regional_trade_target_id = str(option.get_item_metadata(index))
	if _regional_trade_target_id == _regional_trade_source_id:
		_regional_trade_target_id = ""
	_ensure_regional_trade_selection()
	_refresh_trade_panel_content()

func _on_regional_trade_item_selected(index: int, option: OptionButton) -> void:
	_regional_trade_item_id = str(option.get_item_metadata(index))
	_refresh_trade_panel_content()

func _on_regional_trade_amount_changed(value: float, source_id: String, target_id: String, item_id: String, transfer_button: Button) -> void:
	_regional_trade_amount = maxi(1, int(value))
	if is_instance_valid(transfer_button):
		transfer_button.disabled = not TradeManager.can_transfer_between_regions(source_id, target_id, item_id, _regional_trade_amount)

func _on_regional_trade_transfer_pressed(source_id: String, target_id: String, item_id: String, amount_control: SpinBox) -> void:
	var amount := maxi(1, int(amount_control.value))
	if not TradeManager.transfer_between_regions(source_id, target_id, item_id, amount):
		if is_instance_valid(status_label):
			status_label.text = "Transfer failed: check unlocked regions, Global Trade HQ, source stock and target warehouse capacity."
		return
	if is_instance_valid(status_label):
		status_label.text = "Transferred %s ×%d from %s to %s." % [item_id.capitalize(), amount, source_id, target_id]
	_show_trade_panel("regional")

func _build_regional_trade_content(parent: VBoxContainer) -> void:
	if GameManager.population < TradeManager.GLOBAL_TRADE_UNLOCK_POPULATION:
		_trade_message(parent, "Regional trade unlocks with Global Trade HQ at 10,000 city population.")
		return
	if not TradeManager.is_global_trade_operational():
		_trade_message(parent, "Complete Global Trade HQ in the active region to initiate regional warehouse transfers.")
		return
	_ensure_regional_trade_selection()
	var unlocked: Array[String] = RegionManager.unlocked_regions.duplicate()
	if unlocked.size() < 2 or _regional_trade_target_id.is_empty():
		_trade_message(parent, "Unlock a second region before transferring warehouse items between regions.")
		return
	_trade_message(parent, "Move goods between independent regional warehouses. Transfers are validated atomically and saved immediately.")
	var source_row := HBoxContainer.new()
	parent.add_child(source_row)
	var source_label := Label.new()
	source_label.text = "FROM"
	source_label.custom_minimum_size.x = 74 * _ui_scale
	source_row.add_child(source_label)
	var source_option := OptionButton.new()
	source_option.name = "RegionalTradeSource"
	source_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for region_id in unlocked:
		var definition := RegionManager.get_region_definition(region_id)
		source_option.add_item(str(definition.get("name", region_id)))
		source_option.set_item_metadata(source_option.item_count - 1, region_id)
		if region_id == _regional_trade_source_id:
			source_option.select(source_option.item_count - 1)
	source_option.item_selected.connect(_on_regional_trade_source_selected.bind(source_option))
	source_row.add_child(source_option)

	var target_row := HBoxContainer.new()
	parent.add_child(target_row)
	var target_label := Label.new()
	target_label.text = "TO"
	target_label.custom_minimum_size.x = 74 * _ui_scale
	target_row.add_child(target_label)
	var target_option := OptionButton.new()
	target_option.name = "RegionalTradeTarget"
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for region_id in unlocked:
		if region_id == _regional_trade_source_id:
			continue
		var definition := RegionManager.get_region_definition(region_id)
		target_option.add_item(str(definition.get("name", region_id)))
		target_option.set_item_metadata(target_option.item_count - 1, region_id)
		if region_id == _regional_trade_target_id:
			target_option.select(target_option.item_count - 1)
	target_option.item_selected.connect(_on_regional_trade_target_selected.bind(target_option))
	target_row.add_child(target_option)

	var eligible_items := TradeManager.get_trade_eligible_item_ids()
	eligible_items.sort()
	if eligible_items.is_empty():
		_trade_message(parent, "No unlocked trade-eligible products are available yet.")
		return
	var item_row := HBoxContainer.new()
	parent.add_child(item_row)
	var item_label := Label.new()
	item_label.text = "ITEM"
	item_label.custom_minimum_size.x = 74 * _ui_scale
	item_row.add_child(item_label)
	var item_option := OptionButton.new()
	item_option.name = "RegionalTradeItem"
	item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item_id in eligible_items:
		var item_name := str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize()))
		item_option.add_item(item_name)
		item_option.set_item_metadata(item_option.item_count - 1, item_id)
		if item_id == _regional_trade_item_id:
			item_option.select(item_option.item_count - 1)
	item_option.item_selected.connect(_on_regional_trade_item_selected.bind(item_option))
	item_row.add_child(item_option)

	var source_storage := TradeManager.get_region_storage_snapshot(_regional_trade_source_id)
	var target_storage := TradeManager.get_region_storage_snapshot(_regional_trade_target_id)
	var source_items: Dictionary = source_storage.get("items", {})
	var target_items: Dictionary = target_storage.get("items", {})
	var source_count := int(source_items.get(_regional_trade_item_id, 0))
	var target_used := 0
	for count in target_items.values():
		target_used += maxi(0, int(count))
	var target_capacity := maxi(1, int(target_storage.get("capacity", StorageManager.DEFAULT_CAPACITY)))
	var amount_row := HBoxContainer.new()
	parent.add_child(amount_row)
	var amount_label := Label.new()
	amount_label.text = "AMOUNT"
	amount_label.custom_minimum_size.x = 74 * _ui_scale
	amount_row.add_child(amount_label)
	var amount_control := SpinBox.new()
	amount_control.name = "RegionalTradeAmount"
	amount_control.min_value = 1
	amount_control.max_value = maxi(1, source_count)
	amount_control.value = clampi(_regional_trade_amount, 1, maxi(1, source_count))
	amount_control.custom_minimum_size.x = 140 * _ui_scale
	amount_row.add_child(amount_control)

	var capacity_label := Label.new()
	capacity_label.name = "RegionalTradeCapacity"
	capacity_label.text = "Source stock: %d · Target free: %d/%d" % [source_count, maxi(0, target_capacity - target_used), target_capacity]
	capacity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(capacity_label)
	var transfer_button := Button.new()
	transfer_button.name = "RegionalTradeTransfer"
	transfer_button.text = "TRANSFER GOODS"
	transfer_button.custom_minimum_size.y = 48 * _ui_scale
	transfer_button.disabled = not TradeManager.can_transfer_between_regions(_regional_trade_source_id, _regional_trade_target_id, _regional_trade_item_id, int(amount_control.value))
	amount_control.value_changed.connect(_on_regional_trade_amount_changed.bind(_regional_trade_source_id, _regional_trade_target_id, _regional_trade_item_id, transfer_button))
	transfer_button.pressed.connect(_on_regional_trade_transfer_pressed.bind(_regional_trade_source_id, _regional_trade_target_id, _regional_trade_item_id, amount_control))
	parent.add_child(transfer_button)

func _build_cargo_ship_content(parent: VBoxContainer) -> void:
	if GameManager.population < TradeManager.CARGO_SHIP_UNLOCK_POPULATION:
		_trade_message(parent, "Cargo Ship unlocks at 20,000 city population.")
		return
	if not TradeManager.has_trade_building("cargo_port"):
		_trade_message(parent, "Place and complete the Cargo Port from Services → Trade to open the harbor.")
		return
	if TradeManager.ship_departed:
		_trade_message(parent, "Your cargo ship is sailing. It will return in %d seconds with a fresh manifest." % ceili(TradeManager.ship_return_time_left))
		return
	_trade_message(parent, "Load all three crates. Completing the manifest earns 1 Golden Key and sends the ship out; a new ship returns after 3 minutes.")
	var crates := TradeManager.get_ship_crates()
	for index in range(crates.size()):
		var crate: Dictionary = crates[index]
		var item_id := str(crate.get("item_id", ""))
		var amount := int(crate.get("amount", 0))
		var delivered := bool(crate.get("delivered", false))
		var row := HBoxContainer.new()
		row.name = "CargoCrate_%d" % index
		row.custom_minimum_size.y = 56 * _ui_scale
		parent.add_child(row)
		var item_name := str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize()))
		var label := Label.new()
		label.text = "%s ×%d · %s" % [item_name, amount, "LOADED" if delivered else "NEEDED"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#263746"))
		row.add_child(label)
		var load_button := Button.new()
		load_button.name = "CargoLoad_%d" % index
		load_button.text = "LOADED" if delivered else "LOAD"
		load_button.disabled = delivered or StorageManager.get_count(item_id) < amount
		load_button.pressed.connect(_on_trade_deliver_ship_crate.bind(index))
		row.add_child(load_button)

func _on_trade_deliver_ship_crate(crate_index: int) -> void:
	if not TradeManager.deliver_ship_crate(crate_index):
		status_label.text = "Cargo crate needs the listed items in City Storage."
	_show_trade_panel("ship")

func _on_trade_list_item(item_id: String) -> void:
	if not TradeManager.list_for_sale(item_id, 1):
		status_label.text = "Could not list this item. Check stock, slots and Trade Depot access."
	_show_trade_panel("depot")

func _on_trade_collect_sale(slot_index: int) -> void:
	if not TradeManager.collect_sale(slot_index):
		status_label.text = "This listing is not ready to collect."
	_show_trade_panel("depot")

func _on_trade_buy_offer(offer_index: int) -> void:
	if not TradeManager.buy_global_offer(offer_index):
		status_label.text = "Could not buy this offer. Check Simoleons and storage capacity."
	_show_trade_panel("market")


func _on_settings_pressed() -> void:
	_show_settings_panel()

func _close_settings_panel() -> void:
	if is_instance_valid(settings_overlay):
		settings_overlay.queue_free()
	settings_overlay = null

func _show_settings_panel() -> void:
	_close_settings_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.z_index = 130
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "SettingsBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.035, 0.76)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_child(backdrop)

	var panel_width := minf(900.0 * _ui_scale, viewport_size.x * 0.96)
	var panel_height := minf(770.0 * _ui_scale, viewport_size.y * 0.94)
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	settings_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.name = "SettingsLayout"
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(28 * _ui_scale))
	title.add_theme_color_override("font_color", Color("#172330"))
	heading.add_child(title)
	var close := Button.new()
	close.name = "SettingsClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 44) * _ui_scale
	close.add_theme_font_size_override("font_size", int(32 * _ui_scale))
	close.add_theme_color_override("font_color", Color("#123B59"))
	close.pressed.connect(_close_settings_panel)
	heading.add_child(close)

	var section := Label.new()
	section.text = "AUDIO"
	section.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	section.add_theme_color_override("font_color", Color("#28799C"))
	layout.add_child(section)

	var toggles := GridContainer.new()
	toggles.name = "AudioToggles"
	toggles.columns = 3
	toggles.add_theme_constant_override("h_separation", 10)
	toggles.add_theme_constant_override("v_separation", 4)
	layout.add_child(toggles)
	_add_audio_setting_toggle(toggles, "MusicToggle", "Music", AudioManager.music_enabled, AudioManager.set_music_enabled)
	_add_audio_setting_toggle(toggles, "AmbientToggle", "City ambience", AudioManager.ambient_enabled, AudioManager.set_ambient_enabled)
	_add_audio_setting_toggle(toggles, "SfxToggle", "Sound effects", AudioManager.sfx_enabled, AudioManager.set_sfx_enabled)
	_add_audio_setting_toggle(toggles, "HapticsToggle", "Haptic feedback", HapticsManager.enabled, HapticsManager.set_enabled)

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var sliders := VBoxContainer.new()
	sliders.add_theme_constant_override("separation", 10)
	sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sliders)
	_add_audio_setting_slider(sliders, "MasterVolumeSlider", "Master volume", AudioManager.master_volume, AudioManager.set_master_volume)
	_add_audio_setting_slider(sliders, "MusicVolumeSlider", "Music volume", AudioManager.music_volume, AudioManager.set_music_volume)
	_add_audio_setting_slider(sliders, "AmbientVolumeSlider", "City ambience volume", AudioManager.ambient_volume, AudioManager.set_ambient_volume)
	_add_audio_setting_slider(sliders, "SfxVolumeSlider", "Sound effects volume", AudioManager.sfx_volume, AudioManager.set_sfx_volume)
	var graphics_section := Label.new()
	graphics_section.text = "3D GRAPHICS"
	graphics_section.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	graphics_section.add_theme_color_override("font_color", Color("#28799C"))
	sliders.add_child(graphics_section)
	var graphics_row := HBoxContainer.new()
	graphics_row.name = "GraphicsQualityRow"
	sliders.add_child(graphics_row)
	var graphics_label := Label.new()
	graphics_label.text = "3D render quality"
	graphics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_label.add_theme_color_override("font_color", Color("#243C4B"))
	graphics_row.add_child(graphics_label)
	var graphics_select := OptionButton.new()
	graphics_select.name = "GraphicsQualitySelect"
	graphics_select.custom_minimum_size = Vector2(150, 42) * _ui_scale
	var quality_names := GraphicsSettingsManager.get_quality_names()
	for quality_name in quality_names:
		var preset: Dictionary = GraphicsSettingsManager.get_quality_preset(quality_name)
		graphics_select.add_item(str(preset.get("label", quality_name.capitalize())))
	graphics_select.select(quality_names.find(GraphicsSettingsManager.quality))
	graphics_select.item_selected.connect(_on_graphics_quality_selected)
	graphics_row.add_child(graphics_select)
	var performance_section := Label.new()
	performance_section.text = "DEVICE PERFORMANCE"
	performance_section.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	performance_section.add_theme_color_override("font_color", Color("#28799C"))
	sliders.add_child(performance_section)
	var performance_note := Label.new()
	performance_note.text = "Run a 30-second test during normal gameplay. The report is saved locally on this device."
	performance_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	performance_note.add_theme_font_size_override("font_size", int(16 * _ui_scale))
	performance_note.add_theme_color_override("font_color", Color("#526A78"))
	sliders.add_child(performance_note)
	var performance_button := Button.new()
	performance_button.name = "RunDeviceBenchmarkButton"
	performance_button.text = "Run 30-second device test"
	performance_button.custom_minimum_size = Vector2(240, 44) * _ui_scale
	performance_button.pressed.connect(_start_performance_benchmark)
	sliders.add_child(performance_button)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	var reset := Button.new()
	reset.name = "ResetAudioSettings"
	reset.text = "Restore defaults"
	reset.custom_minimum_size = Vector2(150, 42) * _ui_scale
	reset.pressed.connect(_reset_audio_settings)
	footer.add_child(reset)

func _add_audio_setting_toggle(parent: GridContainer, node_name: String, label_text: String, initial_value: bool, setter: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = label_text
	toggle.button_pressed = initial_value
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_font_size_override("font_size", int(17 * _ui_scale))
	toggle.toggled.connect(func(enabled: bool) -> void: setter.call(enabled))
	parent.add_child(toggle)

func _add_audio_setting_slider(parent: VBoxContainer, node_name: String, label_text: String, initial_value: float, setter: Callable) -> void:
	var row := VBoxContainer.new()
	row.name = node_name + "Row"
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var header := HBoxContainer.new()
	row.add_child(header)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#243C4B"))
	label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	header.add_child(label)
	var value_label := Label.new()
	value_label.name = node_name + "Value"
	value_label.text = "%d%%" % int(round(initial_value * 100.0))
	value_label.custom_minimum_size.x = 48 * _ui_scale
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color("#28799C"))
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial_value * 100.0
	slider.custom_minimum_size.y = 28 * _ui_scale
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(next_value: float) -> void:
		setter.call(next_value / 100.0)
		value_label.text = "%d%%" % int(round(next_value))
	)
	row.add_child(slider)

func _reset_audio_settings() -> void:
	AudioManager.set_master_volume(0.8)
	AudioManager.set_music_volume(0.42)
	AudioManager.set_ambient_volume(0.24)
	AudioManager.set_sfx_volume(0.72)
	AudioManager.set_music_enabled(true)
	AudioManager.set_ambient_enabled(true)
	AudioManager.set_sfx_enabled(true)
	HapticsManager.set_enabled(true)
	GraphicsSettingsManager.set_quality("balanced")
	_show_settings_panel()


func _on_graphics_quality_selected(index: int) -> void:
	var quality_names := GraphicsSettingsManager.get_quality_names()
	if index < 0 or index >= quality_names.size():
		return
	GraphicsSettingsManager.set_quality(quality_names[index])
	status_label.text = "3D graphics quality set to %s." % str(GraphicsSettingsManager.get_quality_preset(quality_names[index]).get("label", quality_names[index]))

func _start_performance_benchmark() -> void:
	_close_settings_panel()
	if PerformanceMonitor.start_benchmark(30.0):
		status_label.text = "Device benchmark running — keep playing normally for 30 seconds."
	else:
		status_label.text = "A device benchmark is already running."

func _on_performance_benchmark_progress(elapsed_seconds: float, duration_seconds: float) -> void:
	if not PerformanceMonitor.benchmark_running:
		return
	status_label.text = "Device benchmark: %d / %d seconds — keep playing normally." % [int(elapsed_seconds), int(duration_seconds)]

func _on_performance_benchmark_finished(report: Dictionary) -> void:
	var summary: Dictionary = report.get("summary", {})
	var target_result := "PASS" if bool(summary.get("target_60fps_pass", false)) else "NOT MET"
	var average_fps := float(summary.get("average_fps", 0.0))
	var p95_frame_ms := float(summary.get("p95_frame_ms", 0.0))
	var report_path := str(report.get("report_path", "save failed"))
	status_label.text = "Device benchmark: %.1f avg FPS · p95 %.1f ms · 60 FPS: %s · %s" % [average_fps, p95_frame_ms, target_result, report_path]

func _on_trade_pressed() -> void:
	BuildManager.cancel_placement()
	_show_trade_panel("depot")

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

func _on_regions_pressed() -> void:
	BuildManager.cancel_placement()
	_close_production_panel()
	_close_storage_panel()
	_close_residential_panel()
	_close_trade_panel()
	_close_city_needs_panel()
	_close_achievements_panel()
	open_regions_panel()

func _on_region_changed(region_id: String) -> void:
	var region := RegionManager.get_region_definition(region_id)
	status_label.text = "Entered region: %s" % str(region.get("name", region_id))

func _on_region_state_changed() -> void:
	if is_instance_valid(regions_overlay):
		open_regions_panel()

func open_regions_panel() -> void:
	_close_regions_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	regions_overlay = Control.new()
	regions_overlay.name = "RegionsOverlay"
	regions_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	regions_overlay.z_index = 138
	regions_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(regions_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.70)
	regions_overlay.add_child(shade)
	var width := minf(920.0 * _ui_scale, viewport_size.x * 0.96)
	var height := minf(790.0 * _ui_scale, viewport_size.y * 0.94)
	var panel := PanelContainer.new()
	panel.name = "RegionsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	regions_overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	_city_panel_heading(layout, "REGIONS", _close_regions_panel)
	var summary := Label.new()
	summary.text = "Choose a region. Each region keeps its own roads, buildings and Epic Project state."
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("#526D7D"))
	layout.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.name = "RegionListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	for region in RegionManager.get_region_list():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _toolbar_style(Color("#EAF2F7"), Color("#C7D9E5")))
		entries.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 2)
		row.add_child(details)
		var title := Label.new()
		title.text = str(region.get("name", "Region"))
		title.add_theme_font_size_override("font_size", int(18 * _ui_scale))
		title.add_theme_color_override("font_color", Color("#A87522") if bool(region.get("active", false)) else Color("#24485B"))
		details.add_child(title)
		var climate := Label.new()
		climate.text = "%s climate  ·  Mayor Level %d+" % [str(region.get("climate", "temperate")).capitalize(), int(region.get("unlock_level", 1))]
		climate.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		details.add_child(climate)
		var population := Label.new()
		population.text = "Saved regional population: %s" % str(int(region.get("population", 0)))
		population.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		population.add_theme_color_override("font_color", Color("#526D7D"))
		details.add_child(population)
		if str(region.get("id", "")) != "capital":
			var regional_content := Label.new()
			regional_content.text = "Regional resource: %s  ·  Building: %s" % [str(region.get("signature_material", "—")), str(region.get("signature_building", "—"))]
			regional_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			regional_content.add_theme_font_size_override("font_size", int(13 * _ui_scale))
			regional_content.add_theme_color_override("font_color", Color("#8A672B"))
			details.add_child(regional_content)
		var action := Button.new()
		action.custom_minimum_size = Vector2(116, 44) * _ui_scale
		if bool(region.get("active", false)):
			action.text = "CURRENT"
			action.disabled = true
		elif bool(region.get("unlocked", false)):
			action.text = "TRAVEL"
			action.pressed.connect(_travel_to_region.bind(str(region.get("id", ""))))
		else:
			action.text = "LOCKED"
			action.disabled = true
			action.tooltip_text = "Reach Mayor Level %d" % int(region.get("unlock_level", 1))
		row.add_child(action)

func _travel_to_region(region_id: String) -> void:
	if RegionManager.switch_region(region_id):
		_close_regions_panel()

func _close_regions_panel() -> void:
	if is_instance_valid(regions_overlay):
		regions_overlay.queue_free()
	regions_overlay = null

func _on_achievements_pressed() -> void:
	BuildManager.cancel_placement()
	_close_production_panel()
	_close_storage_panel()
	_close_residential_panel()
	_close_trade_panel()
	_close_city_needs_panel()
	open_achievements_panel()

func _on_achievement_unlocked(_id: String, title: String, simoleons_reward: int, xp_reward: int) -> void:
	status_label.text = "Achievement unlocked: %s  ·  +%d Simoleons  ·  +%d XP" % [title, simoleons_reward, xp_reward]

func _on_achievement_state_changed() -> void:
	if is_instance_valid(achievements_overlay):
		open_achievements_panel()

func open_achievements_panel() -> void:
	_close_achievements_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	achievements_overlay = Control.new()
	achievements_overlay.name = "AchievementsOverlay"
	achievements_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	achievements_overlay.z_index = 135
	achievements_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(achievements_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.68)
	achievements_overlay.add_child(shade)
	var width := minf(910.0 * _ui_scale, viewport_size.x * 0.96)
	var height := minf(800.0 * _ui_scale, viewport_size.y * 0.94)
	var panel := PanelContainer.new()
	panel.name = "AchievementsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	achievements_overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	_city_panel_heading(layout, "CITY ACHIEVEMENTS", _close_achievements_panel)
	var summary := Label.new()
	summary.name = "AchievementSummary"
	summary.text = "UNLOCKED  ·  %d / %d" % [AchievementManager.get_unlocked_count(), AchievementManager.get_total_count()]
	summary.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	summary.add_theme_color_override("font_color", Color("#9A6A20"))
	layout.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.name = "AchievementScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	for entry in AchievementManager.get_entries():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _toolbar_style(Color("#EAF2F7"), Color("#C7D9E5")))
		entries.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		content.add_child(header)
		var title := Label.new()
		title.text = str(entry.get("title", "Achievement"))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", int(17 * _ui_scale))
		title.add_theme_color_override("font_color", Color("#A87522") if bool(entry.get("unlocked", false)) else Color("#24485B"))
		header.add_child(title)
		var state := Label.new()
		state.text = "UNLOCKED" if bool(entry.get("unlocked", false)) else "%d / %d" % [int(entry.get("progress", 0)), int(entry.get("target", 1))]
		state.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		state.add_theme_color_override("font_color", Color("#34734D") if bool(entry.get("unlocked", false)) else Color("#607989"))
		header.add_child(state)
		var description := Label.new()
		description.text = str(entry.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		description.add_theme_color_override("font_color", Color("#526D7D"))
		content.add_child(description)
		var progress_bar := ProgressBar.new()
		progress_bar.min_value = 0
		progress_bar.max_value = maxi(1, int(entry.get("target", 1)))
		progress_bar.value = int(entry.get("progress", 0))
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size.y = 7 * _ui_scale
		content.add_child(progress_bar)
		var reward := Label.new()
		reward.text = "REWARD  ·  +%d SIMOLEONS  ·  +%d XP" % [int(entry.get("simoleons", 0)), int(entry.get("xp", 0))]
		reward.add_theme_font_size_override("font_size", int(13 * _ui_scale))
		reward.add_theme_color_override("font_color", Color("#8A672B"))
		content.add_child(reward)

func _close_achievements_panel() -> void:
	if is_instance_valid(achievements_overlay):
		achievements_overlay.queue_free()
	achievements_overlay = null

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
