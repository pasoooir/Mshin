extends CanvasLayer

const Icons = preload("res://scripts/ui/Icons.gd")
const LevelUpEffectScript = preload("res://scripts/ui/LevelUpEffect.gd")
const LandExpansionPanelScript = preload("res://scripts/ui/LandExpansionPanel.gd")
const CurrencyPanelsScript = preload("res://scripts/ui/CurrencyPanels.gd")
const BuildingNotificationLayerScript = preload("res://scripts/ui/BuildingNotificationLayer.gd")

const STORAGE_CAPACITY_UPGRADE_GAIN := 5

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

# A transparent, polygon-hit-tested GUI target projected onto the selected
# building footprint. It accepts only the matching building's production item.
class ProductionBuildingDropTarget extends Control:
	var hit_polygon := PackedVector2Array()
	var highlighted := false

	func _has_point(point: Vector2) -> bool:
		return hit_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, hit_polygon)

	func _draw() -> void:
		if not highlighted or hit_polygon.size() < 3:
			return
		draw_colored_polygon(hit_polygon, Color(0.20, 0.78, 1.0, 0.12))
		var outline := hit_polygon.duplicate()
		outline.append(hit_polygon[0])
		draw_polyline(outline, Color(0.45, 0.88, 1.0, 0.95), 3.0, true)

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
var currency_panels
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
var _production_world_orbit: Node3D = null
var _production_orbit_buttons: Array[Button] = []
var _residential_world_orbit: Node3D = null
var _residential_orbit_buttons: Array[Button] = []
var _residential_building: Building = null
var _touch_selected_production_item := ""
var _touch_selected_production_building_id := 0
var _production_touch_drag_active := false
var _production_touch_dragged := false
var _production_touch_drag_index := -1
var _production_touch_drag_origin := Vector2.ZERO
var _production_touch_drag_item_id := ""
var _production_touch_drag_building: Building = null
var _production_touch_drag_source_button: Button = null
var _production_touch_drag_ghost: Control = null
var _native_ui_touch_targets: Dictionary = {}
var _native_ui_touch_origins: Dictionary = {}
var _native_ui_touch_last_positions: Dictionary = {}
var _native_ui_touch_scrolls: Dictionary = {}
var _native_ui_touch_dragged: Dictionary = {}
var _native_ui_touch_excluded: Dictionary = {}
const NATIVE_UI_TOUCH_DRAG_THRESHOLD := 12.0
var _production_tick_accum := 0.0
var _factory_ready_scan_accum := 0.0
var _building_notification_layer: Control
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
var _settings_login_indicator: Label
var _settings_login_blink_timer: Timer
var _settings_account_status: Label
var _settings_account_action: Button
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
	PlayerAccountManager.session_changed.connect(_on_settings_account_session_changed)
	PlayerAccountManager.authentication_feedback.connect(_on_settings_account_feedback)
	_settings_login_blink_timer = Timer.new()
	_settings_login_blink_timer.wait_time = 0.55
	_settings_login_blink_timer.one_shot = false
	_settings_login_blink_timer.timeout.connect(_blink_settings_login_indicator)
	add_child(_settings_login_blink_timer)
	_settings_login_blink_timer.start()
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.population_changed.connect(_on_population_changed)
	GameManager.happiness_changed.connect(_on_happiness_changed)
	HappinessManager.immigrants_arrived.connect(_on_immigrants_arrived)
	HappinessManager.immigration_advice.connect(_on_immigration_advice)
	HappinessManager.happiness_recalculated.connect(_on_city_happiness_recalculated)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up_rewarded.connect(_on_level_up_rewarded)
	EconomyManager.simoleons_changed.connect(_on_simoleons_changed)
	EconomyManager.sim_cash_changed.connect(_on_sim_cash_changed)
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
	_building_notification_layer = BuildingNotificationLayerScript.new()
	_building_notification_layer.name = "BuildingNotificationLayer"
	_building_notification_layer.configure(self)
	add_child(_building_notification_layer)
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
	xp_info_panel.custom_minimum_size = Vector2(520, 220) * _ui_scale
	xp_info_panel.size = xp_info_panel.custom_minimum_size
	xp_info_panel.z_index = 45
	xp_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var xp_panel_style := StyleBoxFlat.new()
	xp_panel_style.bg_color = Color(0.055, 0.09, 0.14, 0.96)
	xp_panel_style.border_color = Color("#79C9F2")
	xp_panel_style.set_border_width_all(3)
	xp_panel_style.set_corner_radius_all(20)
	xp_panel_style.content_margin_left = 22
	xp_panel_style.content_margin_right = 22
	xp_panel_style.content_margin_top = 18
	xp_panel_style.content_margin_bottom = 18
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
	xp_panel_close.custom_minimum_size = Vector2(48, 44) * _ui_scale
	xp_panel_close.add_theme_font_size_override("font_size", int(30 * _ui_scale))
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

	currency_panels = CurrencyPanelsScript.new()
	currency_panels.name = "CurrencyPanels"
	top_hud.add_child(currency_panels)
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
	land_button.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_settings_login_indicator = Label.new()
	_settings_login_indicator.name = "LoginRequiredIndicator"
	_settings_login_indicator.text = "●"
	_settings_login_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_login_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_login_indicator.add_theme_font_size_override("font_size", int(25 * _ui_scale))
	_settings_login_indicator.add_theme_color_override("font_color", Color("#FF4D5E"))
	_settings_login_indicator.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_settings_login_indicator.add_theme_constant_override("shadow_offset_x", 1)
	_settings_login_indicator.add_theme_constant_override("shadow_offset_y", 2)
	_settings_login_indicator.position = Vector2(settings_button.custom_minimum_size.x - 28 * _ui_scale, 0)
	_settings_login_indicator.size = Vector2(28, 28) * _ui_scale
	_settings_login_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_button.add_child(_settings_login_indicator)
	bottom_actions.add_child(settings_button)
	_update_settings_login_indicator()
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
	catalog_info_panel.anchor_right = 0.46
	catalog_info_panel.offset_left = 10 * _ui_scale
	catalog_info_panel.offset_right = -8 * _ui_scale
	catalog_info_panel.offset_top = -500 * _ui_scale
	catalog_info_panel.offset_bottom = -150 * _ui_scale
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
	close.custom_minimum_size = Vector2(48, 44) * _ui_scale
	close.add_theme_font_size_override("font_size", int(30 * _ui_scale))
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
	if is_instance_valid(production_overlay) and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
		_close_production_panel()
		get_viewport().set_input_as_handled()
		return
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
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.30, 0.13, 0.035, 0.92)
	panel_style.border_color = Color(0.95, 0.62, 0.20, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(9)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	service_warning_panel.add_theme_stylebox_override("panel", panel_style)
	service_warning_label = Label.new()
	service_warning_label.name = "WarningText"
	service_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	service_warning_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	service_warning_label.add_theme_font_size_override("font_size", 14)
	service_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	service_warning_panel.add_child(service_warning_label)
	add_child(service_warning_panel)
	_update_service_warning_banner()

func _on_city_happiness_recalculated(average: float, _scores: Dictionary) -> void:
	# Keep the visible percentage tied to the authoritative completed city
	# calculation, not only to a secondary HUD update path.
	_on_happiness_changed(average)
	_update_service_warning_banner()

func _update_service_warning_banner() -> void:
	if not is_instance_valid(service_warning_panel) or not is_instance_valid(service_warning_label):
		return
	var warning_data: Dictionary = HappinessManager.get_city_service_warnings()
	var summary := str(warning_data.get("summary", ""))
	service_warning_panel.visible = not summary.is_empty()
	service_warning_label.text = summary

func _update_all() -> void:
	_on_level_changed(GameManager.level)
	_on_population_changed(GameManager.population)
	_on_happiness_changed(GameManager.happiness)
	_on_xp_changed(GameManager.experience, GameManager.get_xp_needed())
	_on_simoleons_changed(EconomyManager.simoleons)
	_on_keys_changed(EconomyManager.golden_keys)
	_on_storage_changed()
	_update_simcash()
	_on_power_changed(ServiceManager.total_power, ServiceManager.demand_power)
	_on_water_changed(ServiceManager.total_water, ServiceManager.demand_water)
	_update_service_summary()
	_update_service_warning_banner()

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

func _toggle_xp_info_panel() -> void:
	if not is_instance_valid(xp_info_panel):
		return
	_refresh_xp_info_panel()
	xp_info_panel.visible = not xp_info_panel.visible

func _refresh_xp_info_panel() -> void:
	if not is_instance_valid(xp_info_label):
		return
	var needed := maxi(1, GameManager.get_xp_needed())
	var remaining := maxi(0, needed - GameManager.experience)
	if GameManager.level >= 60:
		xp_info_label.text = "Mayor Level %d — maximum level reached.\nXP is earned by building and completing buildings, collecting production, unlocking achievements, and maintaining average city Happiness of at least 80 percent for each 60-second period." % GameManager.level
	else:
		xp_info_label.text = "Mayor Level %d → %d\nProgress: %d / %d XP — %d XP remaining.\nEarn XP by placing/completing buildings, collecting production, unlocking achievements, or keeping average city Happiness at 80 percent or higher for 60 seconds." % [GameManager.level, GameManager.level + 1, GameManager.experience, needed, remaining]

func _on_xp_changed(xp: int, needed: int) -> void:
	var safe_needed := maxi(1, needed)
	var remaining := maxi(0, safe_needed - xp)
	var next_level := mini(60, GameManager.level + 1)
	var progress_hint := "Level %d: %d XP remaining. XP comes from building, production collection, achievements and sustained happiness (80 percent or higher for 60 seconds)." % [next_level, remaining]
	if xp_text:
		xp_text.text = "%d / %d XP" % [xp, safe_needed]
		xp_text.tooltip_text = progress_hint
	if is_instance_valid(xp_progress):
		xp_progress.tooltip_text = progress_hint
	if is_instance_valid(level_badge_visual):
		level_badge_visual.tooltip_text = progress_hint
	if xp_progress:
		xp_progress.max_value = safe_needed
		xp_progress.value = clampi(xp, 0, safe_needed)
	if is_instance_valid(level_badge_visual):
		level_badge_visual.set_progress(float(clampi(xp, 0, safe_needed)) / float(safe_needed))
	_refresh_xp_info_panel()

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
		_update_production_orbit_projection()
	_update_residential_orbit_projection()

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
	# Persistent action bubbles are rendered in screen space by a dedicated
	# layer. Keep legacy world labels hidden to avoid duplicate/overlapping icons.
	if is_instance_valid(_building_notification_layer):
		_building_notification_layer.refresh_now()
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		if is_instance_valid(building.ready_item_sprite):
			building.ready_item_sprite.visible = false
		if is_instance_valid(building.action_notification_label):
			building.action_notification_label.visible = false
		if is_instance_valid(building.production_icon):
			building.production_icon.visible = false

func _on_building_notification_collected(building_id: String, item_id: String, collected_count: int, blocked: bool) -> void:
	var item_name := str(ProductionManager.get_item_definition(item_id).get("name", item_id.capitalize()))
	if collected_count > 0:
		status_label.text = "Collected %s ×%d from %s." % [item_name, collected_count, building_id]
	elif blocked:
		status_label.text = "City Storage is full. Free space before collecting %s." % item_name
	else:
		status_label.text = "No ready %s remains at this building." % item_name
	if is_instance_valid(_building_notification_layer):
		_building_notification_layer.refresh_now()

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

func _on_power_changed(_total: int, _demand: int) -> void:
	_update_service_summary()

func _on_water_changed(_total: int, _demand: int) -> void:
	_update_service_summary()

func _on_sewage_changed(_total: int, _demand: int) -> void:
	_update_service_summary()

func _on_waste_changed(_total: int, _demand: int) -> void:
	_update_service_summary()

func _on_workforce_changed(_available: int, _demand: int, _employed: int) -> void:
	_update_service_summary()

func _on_traffic_changed(_demand: int, _capacity: int, _ratio: float) -> void:
	_update_service_summary()

func _service_summary_text() -> String:
	return "Demand / capacity — Power %d/%d · Water %d/%d · Sewage %d/%d · Waste %d/%d · Workers %d/%d employed (%d available) · Fire %d/%d homes · Police %d/%d homes · Health %d/%d homes · Traffic %d/%d (%d%%)" % [
		ServiceManager.demand_power, ServiceManager.total_power,
		ServiceManager.demand_water, ServiceManager.total_water,
		ServiceManager.demand_sewage, ServiceManager.total_sewage,
		ServiceManager.demand_waste, ServiceManager.total_waste,
		ServiceManager.employed_workers, ServiceManager.demand_workers, ServiceManager.available_workers,
		ServiceManager.served_fire_homes, ServiceManager.demand_fire_homes,
		ServiceManager.served_police_homes, ServiceManager.demand_police_homes,
		ServiceManager.served_health_homes, ServiceManager.demand_health_homes,
		TrafficManager.traffic_demand, TrafficManager.road_capacity, TrafficManager.get_congestion_percent()
	]

func _update_service_summary() -> void:
	var summary := _service_summary_text()
	if status_label:
		status_label.tooltip_text = summary
	if active_category == "services" and is_instance_valid(context_header_subtitle):
		context_header_subtitle.text = summary

func _format_count(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)

func _on_currency_plus_pressed(currency: String) -> void:
	if not is_instance_valid(currency_panels):
		push_error("[HUD] Currency popup controller is missing.")
		return
	match currency.to_lower():
		"simoleons":
			currency_panels.open_conversion()
		"simcash", "money":
			currency_panels.open_store()
		_:
			push_warning("[HUD] Unknown currency plus action: " + currency)

func _on_sim_cash_changed(amount: int) -> void:
	if simcash_label:
		simcash_label.text = str(amount)
		_last_simcash_value = amount


func _build_placement_controls() -> void:
	placement_controls = PanelContainer.new()
	placement_controls.name = "PlacementControls"
	placement_controls.anchor_left = 0.0
	placement_controls.anchor_right = 0.0
	placement_controls.anchor_top = 1.0
	placement_controls.anchor_bottom = 1.0
	placement_controls.offset_left = 12.0 * _ui_scale
	placement_controls.offset_right = 272.0 * _ui_scale
	placement_controls.offset_top = -82.0 * _ui_scale
	placement_controls.offset_bottom = -12.0 * _ui_scale
	placement_controls.z_index = 120
	placement_controls.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#102B3B")
	panel_style.border_color = Color("#8AD7F5")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 5
	panel_style.content_margin_right = 5
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	placement_controls.add_theme_stylebox_override("panel", panel_style)
	add_child(placement_controls)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	placement_controls.add_child(actions)
	var rotate_button := Button.new()
	rotate_button.name = "RotatePlacementButton"
	rotate_button.text = "↻ Rotate"
	rotate_button.tooltip_text = "Rotate building 90 degrees"
	rotate_button.custom_minimum_size = Vector2(126, 54) * _ui_scale
	rotate_button.add_theme_font_size_override("font_size", int(21 * _ui_scale))
	rotate_button.add_theme_color_override("font_color", Color("#102B3B"))
	rotate_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#8AD7F5"), Color("#D8F4FF")))
	rotate_button.add_theme_stylebox_override("hover", _toolbar_style(Color("#B2E8FA"), Color.WHITE))
	rotate_button.add_theme_stylebox_override("pressed", _toolbar_style(Color("#54B9E1"), Color("#D8F4FF")))
	rotate_button.pressed.connect(_on_rotate_placement_pressed)
	actions.add_child(rotate_button)
	var cancel_button := Button.new()
	cancel_button.name = "CancelPlacementButton"
	cancel_button.text = "✕ Cancel"
	cancel_button.tooltip_text = "Cancel building placement"
	cancel_button.custom_minimum_size = Vector2(104, 54) * _ui_scale
	cancel_button.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	cancel_button.add_theme_color_override("font_color", Color("#FFFFFF"))
	cancel_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#D94E56"), Color("#FFB7B7")))
	cancel_button.add_theme_stylebox_override("hover", _toolbar_style(Color("#EC6870"), Color.WHITE))
	cancel_button.add_theme_stylebox_override("pressed", _toolbar_style(Color("#B93440"), Color("#FFDADA")))
	cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(cancel_button)
	placement_controls.hide()

func _on_rotate_placement_pressed() -> void:
	if not BuildManager.rotate_placement():
		return
	var ghost := get_tree().current_scene.get_node_or_null("GhostPreview") if get_tree().current_scene else null
	if is_instance_valid(ghost) and ghost.visible:
		var previous_rotation := posmod(BuildManager.placement_rotation_quarters - 1, 4)
		var previous_size: Vector2i = BuildManager.get_building_size(BuildManager.selected_building_type, previous_rotation)
		var anchor_world: Vector3 = ghost.global_position - Vector3((previous_size.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.95, (previous_size.y - 1) * BuildManager.GRID_SIZE * 0.5)
		var grid := BuildManager.world_to_grid(anchor_world)
		var definition: Dictionary = BuildManager.building_types.get(BuildManager.selected_building_type, {})
		ghost.show_at(BuildManager.grid_to_world(grid), BuildManager.get_selected_size(), BuildManager.can_place_at(grid, BuildManager.selected_building_type, BuildManager.placement_rotation_quarters), definition, float(BuildManager.placement_rotation_quarters) * PI * 0.5)
	status_label.text = "Building rotated 90 degrees. Check the green/red footprint, then tap to place."

func _on_placement_mode(active: bool) -> void:
	if is_instance_valid(placement_controls):
		placement_controls.visible = active
	if active:
		status_label.text = "Placement mode — rotate with ↻, cancel with X."
	else:
		status_label.text = ""

func _on_roads_pressed() -> void:
	BuildManager.cancel_placement()
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.set_road_mode(true)
		status_label.text = "Road mode — tap or drag from the highway (50 Simoleons per tile)"

func open_building_upgrade_panel(building: Building) -> void:
	if not is_instance_valid(building) or building.status != "completed":
		return
	var stage := int(building.upgrade_stage)
	var cost := BuildManager.get_non_residential_upgrade_cost(building.building_type, stage)
	var duration := BuildManager.get_non_residential_upgrade_duration_seconds(building.building_type, stage)
	var requirements := BuildManager.get_non_residential_upgrade_bom(building.building_type, stage)
	var material_lines: Array[String] = []
	for item_id in requirements:
		material_lines.append("%s ×%d" % [str(item_id).capitalize(), int(requirements[item_id])])
	var lock_reason := BuildManager.get_non_residential_upgrade_lock_reason(building.building_type, stage)
	if not BuildManager.is_building_operational(building):
		lock_reason = "Restore Gateway road access and required operating services before upgrading."
	var dialog := ConfirmationDialog.new()
	dialog.name = "NonResidentialUpgradeDialog"
	dialog.title = "%s · UPGRADE" % str(building.definition.get("name", "Building"))
	if building.upgrade_in_progress:
		dialog.dialog_text = "Upgrade to Level %d is in progress. Remaining: %ds." % [stage + 1, building.get_upgrade_remaining_seconds()]
	else:
		dialog.dialog_text = "Level %d → %d\nCost: §%d\nConstruction time: %ds\nMaterials: %s" % [
			stage, stage + 1, cost, duration, ", ".join(material_lines)
		]
		if not lock_reason.is_empty():
			dialog.dialog_text += "\n\n" + lock_reason
	dialog.get_ok_button().text = "START UPGRADE"
	dialog.get_ok_button().disabled = building.upgrade_in_progress or not lock_reason.is_empty() or requirements.is_empty()
	dialog.confirmed.connect(_start_non_residential_upgrade.bind(building))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(480, 340))

func _start_non_residential_upgrade(building: Building) -> void:
	if not is_instance_valid(building) or not building.try_upgrade():
		if is_instance_valid(status_label):
			status_label.text = "Upgrade could not start. Check materials, funds and operating services."
		return
	if is_instance_valid(status_label):
		status_label.text = "%s upgrade to Level %d started." % [str(building.definition.get("name", "Building")), int(building.upgrade_stage) + 1]
	if is_instance_valid(_production_building) and _production_building == building:
		open_production_panel(building)

func _popup_font_size(base_size: float) -> int:
	return maxi(16, roundi(base_size * _ui_scale))


func _settings_font_size(base_size: float) -> int:
	# Settings text remains comfortably readable on phone landscape, tablets and desktop.
	return maxi(20, roundi(base_size * clampf(_ui_scale, 1.0, 1.2)))


func open_production_panel(building: Building) -> void:
	if not is_instance_valid(building) or building.status != "completed":
		return
	var category := str(building.definition.get("category", ""))
	if category not in ["industrial", "commercial"]:
		return
	var selected_component = building.production_component
	if not is_instance_valid(selected_component) or selected_component.owner_building != building:
		return
	if bool(selected_component.is_factory) != (category == "industrial"):
		return
	if selected_component.is_factory:
		# A component must keep the exact factory catalog assigned to its owner.
		if str(selected_component.factory_type) != str(building.building_type):
			return
	else:
		var expected_shop_id := str(building.definition.get("shop_id", "building_supplies" if building.building_type == "shop_chain" else building.building_type))
		if str(selected_component.shop_id) != expected_shop_id:
			return

	# Only one building-detail modal may own input at a time. The residential
	# overlay has a higher z-index than production, so leaving it alive would
	# make a newly opened factory/store appear unresponsive or show stale data.
	_close_residential_panel()
	_close_city_needs_panel()
	_close_storage_panel()
	_close_trade_panel()
	_close_epic_project_panel()
	_close_production_panel()
	_production_building = building
	_production_orbit_buttons.clear()
	if is_instance_valid(_production_world_orbit):
		_production_world_orbit.queue_free()
	_production_world_orbit = null
	var scene_root := get_tree().current_scene
	var camera_rig = scene_root.get_node_or_null("CameraRig") if scene_root else null
	if camera_rig != null and camera_rig.has_method("focus_on"):
		camera_rig.focus_on(building.global_position, 18.0)
	if is_instance_valid(production_overlay):
		production_overlay.queue_free()

	# Production is a true modal interaction state: retain the city as a
	# visible 3D backdrop, dim it by exactly 50%, and consume pointer input so
	# neither CityInput nor CameraController can interact with the world.
	production_overlay = Control.new()
	production_overlay.name = "ProductionOverlay"
	production_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	production_overlay.z_index = 100
	production_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(production_overlay)

	var shade := ColorRect.new()
	shade.name = "ProductionBackdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.50)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	production_overlay.add_child(shade)

	production_panel = PanelContainer.new()
	production_panel.name = "BuildingProductionPanel"
	var viewport_size := get_viewport().get_visible_rect().size
	var compact_layout := viewport_size.x <= 900.0 or viewport_size.y <= 520.0
	var panel_width := minf(viewport_size.x * 0.92, 1240.0 * _ui_scale)
	var panel_height := minf((238.0 if compact_layout else 258.0) * _ui_scale, viewport_size.y * 0.48)
	production_panel.anchor_left = 0.5
	production_panel.anchor_right = 0.5
	production_panel.anchor_top = 1.0
	production_panel.anchor_bottom = 1.0
	production_panel.offset_left = -panel_width * 0.5
	production_panel.offset_right = panel_width * 0.5
	production_panel.offset_top = -panel_height - 10.0 * _ui_scale
	production_panel.offset_bottom = -10.0 * _ui_scale
	var studio_style := StyleBoxFlat.new()
	studio_style.bg_color = Color(0.035, 0.20, 0.31, 0.94)
	studio_style.border_color = Color("#8ED8F5")
	studio_style.set_border_width_all(3)
	studio_style.set_corner_radius_all(28)
	studio_style.shadow_color = Color(0.0, 0.035, 0.10, 0.52)
	studio_style.shadow_size = 16
	studio_style.shadow_offset = Vector2(0, 5)
	studio_style.content_margin_left = 16
	studio_style.content_margin_right = 16
	studio_style.content_margin_top = 9
	studio_style.content_margin_bottom = 9
	production_panel.add_theme_stylebox_override("panel", studio_style)
	production_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	production_overlay.add_child(production_panel)

	var layout := VBoxContainer.new()
	layout.name = "ProductionLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 2)
	layout.add_theme_constant_override("margin_left", 4)
	layout.add_theme_constant_override("margin_right", 4)
	layout.add_theme_constant_override("margin_top", 2)
	layout.add_theme_constant_override("margin_bottom", 2)
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
	header.add_theme_stylebox_override("panel", _toolbar_style(Color("#12517A"), Color("#91DFFF")))
	header_center.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 9)
	header.add_child(header_row)
	var production_icon_id := building.building_type if Icons.COMMERCIAL_IDS.has(building.building_type) else "factory_basic"
	var building_icon := Icons.make_icon(production_icon_id, Vector2(42, 42) * _ui_scale if not compact_layout else Vector2(34, 34) * _ui_scale)
	building_icon.name = "ProductionBuildingIcon"
	header_row.add_child(building_icon)
	var title := Label.new()
	title.text = str(building.definition.get("name", "Production")).to_upper()
	title.add_theme_font_size_override("font_size", _popup_font_size((19 if not compact_layout else 16)))
	title.add_theme_color_override("font_color", Color.WHITE)
	header_row.add_child(title)
	var close := Button.new()
	close.name = "ProductionClose"
	close.text = "✕"
	close.custom_minimum_size = Vector2(42, 42) * _ui_scale if not compact_layout else Vector2(36, 36) * _ui_scale
	close.add_theme_font_size_override("font_size", _popup_font_size(20))
	close.add_theme_color_override("font_color", Color("#17394D"))
	close.add_theme_stylebox_override("normal", _toolbar_style(Color("#DCECF5"), Color("#B7D4E3")))
	close.pressed.connect(_close_production_panel)
	if not component.is_factory and ProductionManager.is_store_star_upgrade_supported(str(component.shop_id)):
		var star_status := Label.new()
		star_status.name = "StoreStarStatus"
		star_status.text = "★".repeat(component.store_star_level) + "☆".repeat(3 - component.store_star_level)
		var star_note := ProductionManager.get_store_star_status_note(str(component.shop_id), component.store_star_level)
		if not star_note.is_empty():
			star_status.text += " · " + star_note
		star_status.add_theme_font_size_override("font_size", _popup_font_size(13))
		star_status.add_theme_color_override("font_color", Color("#E4A82F"))
		header_row.add_child(star_status)
		var star_offer := ProductionManager.get_store_star_offer(str(component.shop_id), component.store_star_level)
		if not star_offer.is_empty():
			var star_button := Button.new()
			star_button.name = "UpgradeStoreStar"
			var required_level := int(star_offer.get("level", 999))
			var star_cost := int(star_offer.get("cost", 0))
			star_button.text = "UPGRADE · %d¢" % star_cost
			star_button.disabled = GameManager.level < required_level or EconomyManager.simoleons < star_cost
			star_button.tooltip_text = "Unlocks at Level %d · reduces production time by %d%%" % [required_level, int(star_offer.get("reduction", 0))]
			star_button.add_theme_font_size_override("font_size", _popup_font_size(13))
			star_button.pressed.connect(_upgrade_store_star.bind(building))
			header_row.add_child(star_button)
	header_row.add_child(close)

	# Keep the title inside the new queue panel instead of floating separately.
	var hint := Label.new()
	hint.text = "TAP A PRODUCT TO START PRODUCTION  ·  NO DRAGGING REQUIRED"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.visible = false
	hint.add_theme_font_size_override("font_size", _popup_font_size(10))
	hint.add_theme_color_override("font_color", Color("#B8D4DE"))
	layout.add_child(hint)

	var building_upgrade_button := Button.new()
	building_upgrade_button.name = "UpgradeNonResidentialBuilding"
	var upgrade_stage := int(building.upgrade_stage)
	var upgrade_cost := BuildManager.get_non_residential_upgrade_cost(building.building_type, upgrade_stage)
	var upgrade_bom := BuildManager.get_non_residential_upgrade_bom(building.building_type, upgrade_stage)
	var upgrade_lock := BuildManager.get_non_residential_upgrade_lock_reason(building.building_type, upgrade_stage)
	if not BuildManager.is_building_operational(building):
		upgrade_lock = "Restore road access and required services before upgrading."
	building_upgrade_button.text = "BUILDING UPGRADE · Lv%d → %d · §%d" % [upgrade_stage, upgrade_stage + 1, upgrade_cost]
	building_upgrade_button.tooltip_text = "Materials: " + str(upgrade_bom)
	building_upgrade_button.disabled = building.upgrade_in_progress or not upgrade_lock.is_empty() or upgrade_bom.is_empty()
	building_upgrade_button.add_theme_font_size_override("font_size", _popup_font_size(14))
	building_upgrade_button.pressed.connect(_start_non_residential_upgrade.bind(building))
	building_upgrade_button.text = "⬆"
	building_upgrade_button.custom_minimum_size = Vector2(34, 34) * _ui_scale
	building_upgrade_button.add_theme_font_size_override("font_size", _popup_font_size(18))
	header_row.add_child(building_upgrade_button)

	var available_slot := -1
	for slot_index in range(component.get_slot_count()):
		if component.get_slot(slot_index).is_empty():
			available_slot = slot_index
			break

	var products_title := Label.new()
	products_title.name = "AvailableProductsTitle"
	products_title.text = "TAP A MATERIAL TO START PRODUCTION" if component.is_factory else "TAP A PRODUCT TO START PRODUCTION"
	products_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	products_title.add_theme_font_size_override("font_size", _popup_font_size(10))
	products_title.add_theme_color_override("font_color", Color("#E8F4F9"))
	products_title.visible = false
	layout.add_child(products_title)

	# Floating product orbit stays over the live city; no opaque full-screen sheet.
	var product_orbit := Control.new()
	product_orbit.name = "ProductionProductOrbit"
	product_orbit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	product_orbit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep projected product cards above the 3D building, dimmer and bottom queue.
	product_orbit.z_index = 20
	production_overlay.add_child(product_orbit)
	var product_grid := Control.new()
	product_grid.name = "ProductionProductCards"
	product_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	product_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_grid.z_index = 20
	product_orbit.add_child(product_grid)
	# Actual 3D hexagonal platforms live in the city world; transparent buttons
	# are projected over them so touch input stays reliable on mobile.
	_production_world_orbit = Node3D.new()
	_production_world_orbit.name = "ProductionWorldOrbit"
	if scene_root:
		scene_root.add_child(_production_world_orbit)

	var item_ids: Array = []
	if component.is_factory:
		for item_id in ProductionManager.get_factory_material_ids(str(component.factory_type)):
			if ProductionManager.raw_materials.has(item_id):
				item_ids.append(str(item_id))
	else:
		for item_id in ProductionManager.get_store_catalog_ids(str(component.shop_id)):
			item_ids.append(str(item_id))

	if item_ids.is_empty():
		var empty_catalog := Label.new()
		empty_catalog.text = "No verified products are registered for this store yet. Production is intentionally disabled until item recipes are sourced."
		empty_catalog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_catalog.custom_minimum_size = Vector2(280, 72) * _ui_scale
		empty_catalog.add_theme_color_override("font_color", Color("#F5DFA0"))
		product_grid.add_child(empty_catalog)

	# Hex tiles use one responsive size per viewport, so the same honeycomb
	# geometry is used by both the left and right material clusters.
	# Touch-first product cards remain comfortably readable on narrow landscape phones.
	var selector_edge := 150.0 if viewport_size.x > 1100.0 else 140.0
	# Reflow verified products into two symmetric honeycomb clusters.
	for item_index in range(item_ids.size()):
		var item_id: String = str(item_ids[item_index])
		var data: Dictionary = ProductionManager.raw_materials.get(item_id, ProductionManager.get_store_item_definition(str(component.shop_id), item_id))
		var lock_reason := ProductionManager.get_recipe_lock_reason(item_id, component.store_star_level) if not component.is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
		var recipe: Dictionary = {} if component.is_factory else ProductionManager.get_recipe(item_id)
		var inputs: Dictionary = recipe.get("inputs", {})
		var can_start := available_slot >= 0 and lock_reason.is_empty()
		if not component.is_factory and lock_reason.is_empty() and not StorageManager.has_items(inputs):
			can_start = false

		var item_button := Button.new()
		item_button.name = "Slot%d_%s" % [available_slot, item_id]
		item_button.custom_minimum_size = Vector2(selector_edge, selector_edge + 12.0) * _ui_scale
		# product_grid is a plain Control, not a Container: minimum size alone
		# does not allocate a hit rectangle for dynamically positioned children.
		item_button.size = item_button.custom_minimum_size
		item_button.mouse_filter = Control.MOUSE_FILTER_STOP
		item_button.focus_mode = Control.FOCUS_NONE
		item_button.z_index = 30
		var tile_normal := _production_product_tile_style(Color("#FFFFFF"), Color("#C7D8E2"))
		var tile_hover := _production_product_tile_style(Color("#F0FAFF"), Color("#4A9BC4"))
		var tile_pressed := _production_product_tile_style(Color("#E1F2FA"), Color("#D8AD4A"))
		var tile_disabled := _production_product_tile_style(Color("#EEF1F3"), Color("#C6CDD1"))
		item_button.add_theme_stylebox_override("normal", tile_normal)
		item_button.add_theme_stylebox_override("hover", tile_hover)
		item_button.add_theme_stylebox_override("pressed", tile_pressed)
		item_button.add_theme_stylebox_override("disabled", tile_disabled)
		item_button.add_theme_color_override("font_color", Color("#243F4D"))
		# Put every product on the camera-facing orbit plane, not on the far side
		# of the building where its 3D hex and screen control can be occluded.
		var footprint_size: Vector2i = building.definition.get("size", Vector2i(2, 2))
		var orbit_camera := get_viewport().get_camera_3d()
		var orbit_right := orbit_camera.global_transform.basis.x.normalized() if is_instance_valid(orbit_camera) else Vector3.RIGHT
		var orbit_up := orbit_camera.global_transform.basis.y.normalized() if is_instance_valid(orbit_camera) else Vector3.UP
		# A camera-facing row keeps every selectable tile in front of the building,
		# rather than sending half the catalogue around its hidden far side.
		var orbit_spacing := maxf(2.8, float(maxi(footprint_size.x, footprint_size.y)) * 0.85)
		var orbit_horizontal_offset := (float(item_index) - float(item_ids.size() - 1) * 0.5) * orbit_spacing
		var orbit_world_position := building.global_position + orbit_right * orbit_horizontal_offset + orbit_up * 3.0
		var world_hex := _create_production_orbit_hex(item_index, orbit_world_position)
		item_button.set_meta("orbit_world_position", orbit_world_position)
		item_button.set_meta("orbit_world_hex", world_hex)

		var tile_content := VBoxContainer.new()
		tile_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile_content.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_content.add_theme_constant_override("separation", 0)
		tile_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(tile_content)
		var icon_edge := 92.0 if viewport_size.x > 1100.0 else 84.0
		var item_icon := Icons.make_item_icon("raw" if component.is_factory else "crafted", item_id, Vector2(icon_edge, icon_edge) * _ui_scale)
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_content.add_child(item_icon)
		var item_name := Label.new()
		item_name.text = str(data.get("name", item_id.capitalize()))
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.add_theme_font_size_override("font_size", _popup_font_size((12 if viewport_size.x <= 900.0 else 13)))
		item_name.add_theme_color_override("font_color", Color("#263F4B"))
		tile_content.add_child(item_name)
		if not lock_reason.is_empty():
			var lock_label := Label.new()
			lock_label.text = "LOCKED"
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.add_theme_font_size_override("font_size", _popup_font_size(8))
			lock_label.add_theme_color_override("font_color", Color("#8B2930"))
			tile_content.add_child(lock_label)
		var inventory_status := "READY" if component.is_factory or StorageManager.has_items(inputs) else "MATERIALS NEEDED"
		var stock_summary := "READY TO MAKE"
		var missing_detail := ""
		if component.is_factory:
			stock_summary = "STOCK %d" % StorageManager.get_count(item_id)
		elif not inputs.is_empty():
			missing_detail = ProductionManager.get_missing_inputs_text(item_id)
			var missing_count := 0
			for input_id in inputs:
				missing_count += maxi(0, int(inputs[input_id]) - StorageManager.get_count(str(input_id)))
			stock_summary = "MATERIALS READY" if missing_count == 0 else "%d MISSING" % missing_count
		var status_label := Label.new()
		status_label.text = lock_reason if not lock_reason.is_empty() else stock_summary
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", _popup_font_size(10))
		status_label.add_theme_color_override("font_color", Color("#A13F35") if not lock_reason.is_empty() else (Color("#34734D") if inventory_status == "READY" else Color("#D66B55")) )
		tile_content.add_child(status_label)
		item_button.disabled = not lock_reason.is_empty()
		item_button.tooltip_text = lock_reason if not lock_reason.is_empty() else (("MISSING: " + missing_detail) if not missing_detail.is_empty() else inventory_status)
		# One input path owns production orders. gui_input receives the native
		# ScreenTouch on phones and a real MouseButton on desktop; do not also
		# connect BaseButton.pressed, which can fire during the same GUI event
		# and rebuild the modal while Godot is still dispatching that pointer.
		item_button.set_meta("production_item_id", item_id)
		item_button.set_meta("production_building_id", building.get_instance_id())
		item_button.gui_input.connect(_on_production_item_gui_input.bind(building, item_id, available_slot, item_button))
		product_grid.add_child(item_button)
		item_button.set_meta("orbit_index", item_index)
		_production_orbit_buttons.append(item_button)

	_update_production_orbit_projection()

	var details_scroll := ScrollContainer.new()
	details_scroll.name = "ProductionDetailsScroll"
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.custom_minimum_size.y = (48.0 if compact_layout else 58.0) * _ui_scale
	layout.add_child(details_scroll)
	var details_host := Control.new()
	details_host.name = "ProductionDetailsHost"
	details_host.custom_minimum_size = Vector2(maxf(240.0, panel_width - 70.0 * _ui_scale), (54.0 if compact_layout else 58.0) * _ui_scale)
	details_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_host)

	var queue_heading := HBoxContainer.new()
	queue_heading.name = "ProductionQueueHeading"
	layout.add_child(queue_heading)
	var queue_title := Label.new()
	queue_title.text = "PRODUCTION QUEUE"
	queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_title.add_theme_font_size_override("font_size", _popup_font_size(16))
	queue_title.add_theme_color_override("font_color", Color("#F4FBFF"))
	queue_heading.add_child(queue_title)
	var queue_count := Label.new()
	queue_count.text = "%d / %d" % [component.get_slot_count() - _count_empty_production_slots(component), component.get_slot_count()]
	queue_count.add_theme_font_size_override("font_size", _popup_font_size(16))
	queue_count.add_theme_color_override("font_color", Color("#C0D1D8"))
	queue_heading.add_child(queue_count)
	if not component.is_factory:
		var next_slot_cost: int = component.get_next_store_queue_slot_cost()
		var add_slot := Button.new()
		add_slot.name = "PurchaseQueueSlot"
		add_slot.text = ("+ SLOT · %d SC" % next_slot_cost) if next_slot_cost > 0 else ("MAX SLOTS" if component.get_slot_count() >= ProductionComponent.MAX_STORE_QUEUE_SLOTS else "UNAVAILABLE")
		add_slot.disabled = next_slot_cost <= 0 or EconomyManager.sim_cash < next_slot_cost
		add_slot.tooltip_text = "Add one queue slot. SimCash cost is from the commercial-building reference." if next_slot_cost > 0 else ("Maximum 11 queue slots." if component.get_slot_count() >= ProductionComponent.MAX_STORE_QUEUE_SLOTS else "No verified queue-slot price is configured for this custom store.")
		add_slot.add_theme_font_size_override("font_size", _popup_font_size(13))
		add_slot.pressed.connect(_purchase_store_queue_slot.bind(building))
		queue_heading.add_child(add_slot)

	var queue_scroll := ScrollContainer.new()
	queue_scroll.name = "ProductionOrdersScroll"
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	queue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_scroll.custom_minimum_size.y = (104.0 if compact_layout else 122.0) * _ui_scale
	layout.add_child(queue_scroll)
	var orders_list := VBoxContainer.new()
	orders_list.name = "ProductionOrdersList"
	orders_list.add_theme_constant_override("separation", 7)
	orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(orders_list)
	var visible_order_count := 0
	for slot_index in range(component.get_slot_count()):
		var slot: Dictionary = component.get_slot(slot_index)
		if slot.is_empty():
			continue
		visible_order_count += 1
		var queued_item_id := str(slot.get("item_id", ""))
		var item_definition: Dictionary = ProductionManager.get_item_definition(queued_item_id)
		var item_name := str(item_definition.get("name", queued_item_id.capitalize()))
		var is_ready := bool(slot.get("ready", false))
		var is_waiting: bool = not is_ready and not component.is_factory and int(slot.get("finish_unix", 0)) <= 0
		var order_card := PanelContainer.new()
		order_card.name = "QueueSlot%d" % slot_index
		order_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_card.custom_minimum_size = Vector2(100.0, 90.0) * _ui_scale
		var order_style := StyleBoxFlat.new()
		order_style.bg_color = Color("#E8F5FA") if is_ready else Color("#F3F8FB")
		order_style.border_color = Color("#D6AE4B") if is_ready else Color("#8CC9DE")
		order_style.set_border_width_all(2)
		order_style.set_corner_radius_all(15)
		order_style.content_margin_left = 9
		order_style.content_margin_right = 9
		order_style.content_margin_top = 6
		order_style.content_margin_bottom = 6
		order_card.add_theme_stylebox_override("panel", order_style)
		orders_list.add_child(order_card)
		var order_row := HBoxContainer.new()
		order_row.name = "OrderRow%d" % slot_index
		order_row.add_theme_constant_override("separation", 10)
		order_card.add_child(order_row)
		var item_category := "raw" if component.is_factory else "crafted"
		var order_icon := Icons.make_item_icon(item_category, queued_item_id, Vector2(52, 52) * _ui_scale)
		order_icon.name = "QueueItemIcon%d" % slot_index
		order_icon.custom_minimum_size = Vector2(52, 52) * _ui_scale
		order_row.add_child(order_icon)
		var order_details := VBoxContainer.new()
		order_details.name = "OrderDetails%d" % slot_index
		order_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_details.add_theme_constant_override("separation", 2)
		order_row.add_child(order_details)
		var order_name := Label.new()
		order_name.text = item_name
		order_name.add_theme_font_size_override("font_size", _popup_font_size(15))
		order_name.add_theme_color_override("font_color", Color("#173D52"))
		order_details.add_child(order_name)
		var state_label := Label.new()
		state_label.name = "OrderState%d" % slot_index
		state_label.add_theme_font_size_override("font_size", _popup_font_size(11))
		state_label.add_theme_color_override("font_color", Color("#28734A") if is_ready else Color("#587487"))
		state_label.text = "READY TO COLLECT" if is_ready else ("WAITING IN QUEUE" if is_waiting else "IN PRODUCTION")
		order_details.add_child(state_label)
		if not is_ready and not is_waiting:
			var remaining := maxi(0, int(slot.get("finish_unix", 0)) - int(Time.get_unix_time_from_system()))
			var timer_label := Label.new()
			timer_label.name = "TimerSlot%d" % slot_index
			timer_label.set_meta("slot_index", slot_index)
			timer_label.text = _format_clock_duration(remaining)
			timer_label.add_theme_font_size_override("font_size", _popup_font_size(19))
			timer_label.add_theme_color_override("font_color", Color("#B47716"))
			order_details.add_child(timer_label)
			var progress := ProgressBar.new()
			progress.name = "ProgressSlot%d" % slot_index
			progress.set_meta("slot_index", slot_index)
			progress.show_percentage = false
			progress.custom_minimum_size.y = 7.0 * _ui_scale
			progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			progress.max_value = 1.0
			var total_seconds := maxf(1.0, component.get_item_production_time(queued_item_id))
			var started_unix := int(slot.get("start_unix", int(slot.get("finish_unix", 0)) - int(total_seconds)))
			progress.value = clampf(1.0 - float(remaining) / total_seconds, 0.0, 1.0)
			progress.set_meta("start_unix", started_unix)
			progress.set_meta("finish_unix", int(slot.get("finish_unix", 0)))
			order_details.add_child(progress)
			_production_timer_labels.append(timer_label)
			_production_progress_bars.append(progress)
		if is_ready:
			var storage_has_room := StorageManager.can_add(queued_item_id, 1)
			var collect_button := Button.new()
			collect_button.name = "CollectSlot%d" % slot_index
			collect_button.text = "COLLECT" if storage_has_room else "STORAGE FULL"
			collect_button.disabled = not storage_has_room
			collect_button.tooltip_text = "Transfer this finished item into City Storage." if storage_has_room else "Free at least one storage slot before collecting."
			collect_button.custom_minimum_size = Vector2(112, 46) * _ui_scale
			collect_button.add_theme_font_size_override("font_size", _popup_font_size(12))
			collect_button.add_theme_stylebox_override("normal", _toolbar_style(Color("#E6B93E"), Color("#FFE18A")))
			collect_button.add_theme_stylebox_override("hover", _toolbar_style(Color("#F4D36C"), Color.WHITE))
			collect_button.add_theme_color_override("font_color", Color("#34280B"))
			collect_button.pressed.connect(func():
				if component.collect(slot_index):
					status_label.text = "Collected %s into City Storage." % item_name
				else:
					status_label.text = "Storage full — free space in City Storage first."
				open_production_panel(building)
			)
			order_row.add_child(collect_button)
	if visible_order_count == 0:
		var empty_state := PanelContainer.new()
		empty_state.name = "ProductionOrdersEmptyState"
		empty_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_state.add_theme_stylebox_override("panel", _toolbar_style(Color("#EAF4F8"), Color("#9CC9DA")))
		orders_list.add_child(empty_state)
		var empty_message := VBoxContainer.new()
		empty_message.add_theme_constant_override("separation", 3)
		empty_state.add_child(empty_message)
		var empty_title := Label.new()
		empty_title.text = "NO ACTIVE ORDERS"
		empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_title.add_theme_font_size_override("font_size", _popup_font_size(14))
		empty_title.add_theme_color_override("font_color", Color("#214B60"))
		empty_message.add_child(empty_title)
		var empty_hint := Label.new()
		empty_hint.text = "Tap a product above to place an order. Your live countdowns will appear here."
		empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_hint.add_theme_font_size_override("font_size", _popup_font_size(11))
		empty_hint.add_theme_color_override("font_color", Color("#587487"))
		empty_message.add_child(empty_hint)

	var footer := Label.new()
	footer.text = "Completed goods are collected into City Storage."
	footer.visible = false
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", _popup_font_size(13))
	footer.add_theme_color_override("font_color", Color("#587487"))
	layout.add_child(footer)


func _purchase_store_queue_slot(building: Building) -> void:
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return
	var component: ProductionComponent = building.production_component
	var cost := component.get_next_store_queue_slot_cost()
	if cost <= 0:
		status_label.text = "This store already has the maximum 11 queue slots."
	elif component.purchase_store_queue_slot(cost):
		status_label.text = "Queue capacity increased to %d slots." % component.get_slot_count()
	else:
		status_label.text = "Not enough SimCash to unlock the next queue slot (%d required)." % cost
	open_production_panel(building)

func _upgrade_store_star(building: Building) -> void:
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return
	var component: ProductionComponent = building.production_component
	var offer := ProductionManager.get_store_star_offer(str(component.shop_id), component.store_star_level)
	if offer.is_empty():
		return
	if GameManager.level < int(offer.get("level", 999)):
		status_label.text = "Store upgrade unlocks at Level %d." % int(offer.level)
	elif component.upgrade_store_star():
		status_label.text = "Store upgraded to %d star. New orders use the reduced production time." % component.store_star_level
	else:
		status_label.text = "Not enough Simoleons for this store upgrade."
	open_production_panel(building)


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
	var lock_reason := ProductionManager.get_recipe_lock_reason(item_id, component.store_star_level) if not is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
	var missing := "" if is_factory else ProductionManager.get_missing_inputs_text(item_id)
	# Crafted orders can start an automatic dependency chain even when
	# ingredients are not yet in City Storage. The scheduler reserves each
	# dependency when its real store/factory job is accepted.
	var can_start: bool = slot_index >= 0 and lock_reason.is_empty() and (is_factory or (not recipe.is_empty() and StorageManager.has_items(inputs)))

	var detail := PanelContainer.new()
	detail.name = "ProductionItemDetails"
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail.add_theme_stylebox_override("panel", _toolbar_style(Color("#102D3D"), Color("#5BA8C2")))
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
	selected_name.add_theme_font_size_override("font_size", _popup_font_size(18))
	selected_name.add_theme_color_override("font_color", Color("#F2F8FA"))
	text_stack.add_child(selected_name)
	var production_time := Label.new()
	var selected_recipe: Dictionary = {} if is_factory else ProductionManager.get_recipe(item_id)
	if is_factory:
		production_time.text = "PRODUCTION TIME  " + _format_duration(int(data.get("time_sec", 60)))
	elif selected_recipe.is_empty() and int(data.get("time_sec", 0)) > 0:
		production_time.text = "REFERENCE TIME  " + _format_duration(int(data.get("time_sec", 0))) + " · INPUTS DISPUTED"
	elif selected_recipe.is_empty():
		production_time.text = "PRODUCTION TIME  NOT VERIFIED"
	else:
		production_time.text = "PRODUCTION TIME  " + _format_duration(int(ceil(component.get_item_production_time(item_id))))
	production_time.add_theme_font_size_override("font_size", _popup_font_size(14))
	production_time.add_theme_color_override("font_color", Color("#B9D4DF"))
	text_stack.add_child(production_time)
	var provenance := str(data.get("source", ""))
	if provenance.to_lower().contains("conflict") or provenance.to_lower().contains("verify") or not bool(data.get("unlock_level_verified", true)):
		var provenance_warning := Label.new()
		provenance_warning.name = "RecipeDataWarning"
		provenance_warning.text = "REFERENCE DATA DISAGREES · VERIFY RECIPE BEFORE FINAL BALANCE" if provenance.to_lower().contains("conflict") else "MAYOR LEVEL GATE NOT VERIFIED · PRODUCTION LOCKED"
		provenance_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		provenance_warning.add_theme_font_size_override("font_size", _popup_font_size(13))
		provenance_warning.add_theme_color_override("font_color", Color("#A13F35"))
		text_stack.add_child(provenance_warning)
	if is_factory:
		var storage_label := Label.new()
		storage_label.text = "IN CITY STORAGE  %d" % StorageManager.get_count(item_id)
		storage_label.add_theme_font_size_override("font_size", _popup_font_size(14))
		storage_label.add_theme_color_override("font_color", Color("#B9D4DF"))
		text_stack.add_child(storage_label)
	else:
		var ingredients_label := Label.new()
		ingredients_label.name = "IngredientsLabel"
		ingredients_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ingredients_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ingredient_lines: Array[String] = []
		for input_id in inputs:
			var input_data: Dictionary = ProductionManager.get_item_definition(str(input_id))
			var required := int(inputs[input_id])
			var owned := StorageManager.get_count(str(input_id))
			ingredient_lines.append("%s  %d/%d" % [str(input_data.get("name", str(input_id).capitalize())), owned, required])
			if owned < required:
				can_start = false
		var candidate_inputs: Array = data.get("candidate_inputs", [])
		if inputs.is_empty() and not candidate_inputs.is_empty():
			var candidate_lines: Array[String] = []
			for candidate_index in range(candidate_inputs.size()):
				var candidate: Dictionary = candidate_inputs[candidate_index]
				var candidate_parts: Array[String] = []
				for candidate_id in candidate:
					var candidate_definition := ProductionManager.get_item_definition(str(candidate_id))
					candidate_parts.append("%s ×%d" % [str(candidate_definition.get("name", str(candidate_id).capitalize())), int(candidate[candidate_id])])
				candidate_lines.append("Option %d: %s" % [candidate_index + 1, ", ".join(candidate_parts)])
			ingredients_label.text = "CONFLICTING REFERENCE INPUTS — NOT CRAFTABLE\n" + "\n".join(candidate_lines)
		else:
			ingredients_label.text = ("REQUIRED ITEMS  " + "   •   ".join(ingredient_lines)) if not inputs.is_empty() else "RECIPE INPUTS NOT VERIFIED — PRODUCTION DISABLED"
		ingredients_label.add_theme_font_size_override("font_size", _popup_font_size(14))
		ingredients_label.add_theme_color_override("font_color", Color("#B9D4DF") if can_start else Color("#FF9D91"))
		text_stack.add_child(ingredients_label)
		if int(data.get("value", 0)) > 0:
			var reference_value := Label.new()
			reference_value.name = "ReferenceTradeValue"
			reference_value.text = "REFERENCE MAX TRADE VALUE  %s SIMOLEONS" % _format_count(int(data.value))
			reference_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reference_value.add_theme_font_size_override("font_size", _popup_font_size(13))
			reference_value.add_theme_color_override("font_color", Color("#587487"))
			text_stack.add_child(reference_value)
		if not inputs.is_empty():
			var chain_label := Label.new()
			chain_label.name = "RecipeSupplyChain"
			var chain_estimate_seconds: float = ProductionManager.get_estimated_chain_seconds(item_id)
			var chain_estimate_text := "EST. REMAINING: " + _format_clock_duration(int(chain_estimate_seconds)) + " (APPROX.)" if chain_estimate_seconds >= 0.0 else "ESTIMATE UNAVAILABLE — RECIPE DATA NOT VERIFIED"
			chain_label.text = "SUPPLY CHAIN\n" + ProductionManager.get_recipe_dependency_text(item_id) + "\n" + chain_estimate_text
			chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			chain_label.add_theme_font_size_override("font_size", _popup_font_size(8))
			chain_label.add_theme_color_override("font_color", Color("#587487"))
			text_stack.add_child(chain_label)
	if not lock_reason.is_empty() or not missing.is_empty() or slot_index < 0:
		var reason := Label.new()
		reason.name = "ProductionBlockReason"
		reason.text = lock_reason if not lock_reason.is_empty() else ("NO FREE PRODUCTION SLOT" if slot_index < 0 else "MISSING CITY STORAGE: " + missing)
		reason.add_theme_font_size_override("font_size", _popup_font_size(13))
		reason.add_theme_color_override("font_color", Color("#A33A36"))
		text_stack.add_child(reason)

	# Orders are started directly by tapping a valid product tile. This
	# informational panel must never ask the player for a second START action.


func _find_first_available_production_slot(component: ProductionComponent) -> int:
	if not is_instance_valid(component):
		return -1
	# Resolve capacity at interaction time. A slot number captured when the
	# orbit was built can become stale after another order, collection or refresh.
	for index in range(component.get_slot_count()):
		if component.get_slot(index).is_empty():
			return index
	return -1


func _on_production_item_pressed(building: Building, item_id: String, _slot_hint: int, item_button: Button) -> void:
	# A card from a previous modal session must never enqueue work on a
	# different building after the player has switched factories/stores.
	if not is_instance_valid(_production_building) or _production_building != building or not is_instance_valid(production_overlay):
		return
	if is_instance_valid(item_button) and item_button.has_meta("touch_drag_consumed") and bool(item_button.get_meta("touch_drag_consumed")):
		item_button.set_meta("touch_drag_consumed", false)
		return
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return
	var component: ProductionComponent = building.production_component
	var slot_index := _find_first_available_production_slot(component)
	var payload := {"kind": "production_item", "item_id": item_id, "building_id": building.get_instance_id()}

	if not BuildManager.is_building_operational(building):
		_show_production_item_details(building, item_id, slot_index)
		status_label.text = "Production blocked: restore this building's road access, utilities and workforce."
		return
	if slot_index >= 0 and _can_accept_production_drop(Vector2.ZERO, payload, building, slot_index):
		_accept_production_drop(Vector2.ZERO, payload, building, slot_index)
		return

	# Only blocked products open the explanatory details panel. Eligible
	# products returned above directly into the queue on this same tap.
	# Keep this path so missing BOM ingredients and quantities remain visible.
	_show_production_item_details(building, item_id, slot_index)
	if slot_index < 0:
		status_label.text = "All production slots are occupied. Collect a finished item or wait for a free slot."
	elif component.is_factory:
		var raw_definition: Dictionary = ProductionManager.raw_materials.get(item_id, {})
		if not ProductionManager.get_factory_material_ids(str(component.factory_type)).has(item_id) or raw_definition.is_empty():
			status_label.text = "This material is not part of this factory's catalogue."
		elif int(raw_definition.get("level", 1)) > GameManager.level:
			status_label.text = "This material unlocks at Mayor Level %d." % int(raw_definition.get("level", 1))
		else:
			status_label.text = "Factory rejected the order. Check building operation and production capacity."
	else:
		var recipe := ProductionManager.get_recipe(item_id)
		var lock_reason := ProductionManager.get_recipe_lock_reason(item_id, component.store_star_level)
		if recipe.is_empty() or str(recipe.get("store", "")) != str(component.shop_id):
			status_label.text = "This product has no verified recipe for this store."
		elif not lock_reason.is_empty():
			status_label.text = lock_reason
		elif not ProductionManager.are_recipe_inputs_unlocked(recipe):
			status_label.text = "A required ingredient is not unlocked yet."
		else:
			var missing := ProductionManager.get_missing_inputs_text(item_id)
			status_label.text = "Missing City Storage: " + missing if not missing.is_empty() else "Store rejected the order. Check its operation and queue capacity."


func _on_production_item_gui_input(event: InputEvent, building: Building, item_id: String, _slot_index: int, item_button: Button) -> void:
	# Accept the native mobile touch event directly. A real desktop mouse click
	# uses the same single handler, without converting phone touches into mouse
	# events or depending on BaseButton.pressed signal ordering.
	# Native touch is routed centrally in _input() using viewport-space
	# hit testing. Keep this GUI callback for desktop mouse only, avoiding a
	# second activation path for the same phone touch.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not is_instance_valid(building) or building != _production_building:
		return
	if not is_instance_valid(item_button) or item_button.disabled:
		return
	if not is_instance_valid(building.production_component) or not is_instance_valid(production_overlay):
		return
	if _production_touch_drag_active:
		return
	# Resolve the first empty slot at event time, then pass through the same
	# operation/catalog gates used by ProductionComponent.start_factory().
	_on_production_item_pressed(building, item_id, -1, item_button)
	get_viewport().set_input_as_handled()


# Capture the pointer globally after a touch starts on a product tile. This is
# essential: once the finger leaves the hexagon, its GUI control no longer owns
# the pointer, but the drag must continue all the way to the bottom queue dock.
func _input(event: InputEvent) -> void:
	# Production product cards keep their dedicated native-touch route so one
	# touch can never submit twice through both the item orbit and a generic UI path.
	if event is InputEventScreenTouch and event.pressed:
		if is_instance_valid(production_overlay) and production_overlay.is_visible_in_tree() and is_instance_valid(_production_building):
			for button in _production_orbit_buttons:
				if not is_instance_valid(button):
					continue
				var rect := button.get_global_rect()
				if not button.is_visible_in_tree() or button.disabled or not rect.has_point(event.position):
					continue
				var target_building := _production_building
				var target_item_id := str(button.get_meta("production_item_id", ""))
				if not target_item_id.is_empty() and int(button.get_meta("production_building_id", 0)) == target_building.get_instance_id():
					_on_production_item_pressed(target_building, target_item_id, -1, button)
					_native_ui_touch_excluded[event.index] = true
					get_viewport().set_input_as_handled()
					return

	if _production_touch_drag_active:
		if event is InputEventScreenDrag and event.index == _production_touch_drag_index:
			if not _production_touch_dragged and _production_touch_drag_origin.distance_to(event.position) >= 12.0 * _ui_scale:
				_production_touch_dragged = true
				if is_instance_valid(_production_touch_drag_building):
					_create_production_touch_drag_ghost(_production_touch_drag_building, _production_touch_drag_item_id)
			if _production_touch_dragged:
				_update_production_touch_drag_ghost(event.position)
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventScreenTouch and not event.pressed and event.index == _production_touch_drag_index:
			var was_dragged := _production_touch_dragged
			if was_dragged:
				_finish_production_touch_drag(event.position)
				if is_instance_valid(_production_touch_drag_source_button):
					_production_touch_drag_source_button.set_meta("touch_drag_consumed", true)
				get_viewport().set_input_as_handled()
			else:
				var tapped_building := _production_touch_drag_building
				var tapped_item_id := _production_touch_drag_item_id
				var tapped_button := _production_touch_drag_source_button
				if is_instance_valid(tapped_building) and is_instance_valid(tapped_button):
					_on_production_item_pressed(tapped_building, tapped_item_id, -1, tapped_button)
					if is_instance_valid(tapped_button):
						tapped_button.set_meta("touch_drag_consumed", true)
				_clear_production_touch_drag(true)
			return

	if _route_native_ui_touch(event):
		get_viewport().set_input_as_handled()

func _route_native_ui_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch_index: int = event.index
		if event.pressed:
			if _native_ui_touch_excluded.has(touch_index):
				return true
			var target := _find_native_ui_touch_target(event.position)
			if not is_instance_valid(target):
				return false
			_native_ui_touch_targets[touch_index] = target
			_native_ui_touch_origins[touch_index] = event.position
			_native_ui_touch_last_positions[touch_index] = event.position
			_native_ui_touch_scrolls[touch_index] = target as ScrollContainer if target is ScrollContainer else _find_native_ui_scroll_ancestor(target)
			_native_ui_touch_dragged[touch_index] = false
			if target is LineEdit:
				(target as LineEdit).grab_focus()
			return true
		if _native_ui_touch_excluded.has(touch_index):
			_native_ui_touch_excluded.erase(touch_index)
			return true
		if not _native_ui_touch_targets.has(touch_index):
			return false
		var target := _native_ui_touch_targets[touch_index] as Control
		var dragged := bool(_native_ui_touch_dragged.get(touch_index, false))
		if not dragged and is_instance_valid(target) and target.is_visible_in_tree() and target.get_global_rect().has_point(event.position) and target is BaseButton:
			var button := target as BaseButton
			if not button.disabled:
				if button.toggle_mode:
					button.button_pressed = not button.button_pressed
				button.emit_signal("pressed")
		_clear_native_ui_touch(touch_index)
		return true

	if event is InputEventScreenDrag:
		var drag_index: int = event.index
		if not _native_ui_touch_targets.has(drag_index):
			return false
		var origin: Vector2 = _native_ui_touch_origins.get(drag_index, event.position)
		var last_position: Vector2 = _native_ui_touch_last_positions.get(drag_index, event.position)
		if not bool(_native_ui_touch_dragged.get(drag_index, false)) and origin.distance_to(event.position) >= NATIVE_UI_TOUCH_DRAG_THRESHOLD * _ui_scale:
			_native_ui_touch_dragged[drag_index] = true
		if bool(_native_ui_touch_dragged.get(drag_index, false)):
			var scroll := _native_ui_touch_scrolls.get(drag_index) as ScrollContainer
			if is_instance_valid(scroll):
				_scroll_native_ui_container(scroll, last_position - event.position)
		_native_ui_touch_last_positions[drag_index] = event.position
		return true
	return false

func _find_native_ui_touch_target(screen_position: Vector2) -> Control:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var controls := scene.find_children("*", "Control", true, false)
	for index in range(controls.size() - 1, -1, -1):
		var control := controls[index] as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree() or not control.get_global_rect().has_point(screen_position):
			continue
		var ancestor: Node = control
		while ancestor != null:
			if ancestor is BaseButton or ancestor is LineEdit or ancestor is ScrollContainer:
				return ancestor as Control
			ancestor = ancestor.get_parent()
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return control
	return null

func _find_native_ui_scroll_ancestor(control: Control) -> ScrollContainer:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func _scroll_native_ui_container(scroll: ScrollContainer, delta: Vector2) -> void:
	var horizontal := scroll.get_h_scroll_bar()
	if horizontal.max_value > horizontal.page:
		horizontal.value = clampf(horizontal.value + delta.x, horizontal.min_value, maxf(horizontal.min_value, horizontal.max_value - horizontal.page))
	var vertical := scroll.get_v_scroll_bar()
	if vertical.max_value > vertical.page:
		vertical.value = clampf(vertical.value + delta.y, vertical.min_value, maxf(vertical.min_value, vertical.max_value - vertical.page))

func _clear_native_ui_touch(touch_index: int) -> void:
	_native_ui_touch_targets.erase(touch_index)
	_native_ui_touch_origins.erase(touch_index)
	_native_ui_touch_last_positions.erase(touch_index)
	_native_ui_touch_scrolls.erase(touch_index)
	_native_ui_touch_dragged.erase(touch_index)

func _create_production_touch_drag_ghost(building: Building, item_id: String) -> void:
	if not is_instance_valid(production_overlay):
		return
	if is_instance_valid(_production_touch_drag_ghost):
		_production_touch_drag_ghost.queue_free()
	var ghost := PanelContainer.new()
	ghost.name = "ProductionTouchDragGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 120
	ghost.custom_minimum_size = Vector2(76, 76) * _ui_scale
	ghost.add_theme_stylebox_override("panel", _toolbar_style(Color("#EAF5FA"), Color("#E7BC43")))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	ghost.add_child(content)
	var icon := Icons.make_item_icon("raw" if building.production_component.is_factory else "crafted", item_id, Vector2(42, 42) * _ui_scale)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(ProductionManager.get_item_definition(item_id).get("name", item_id.capitalize()))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", _popup_font_size(9))
	name_label.add_theme_color_override("font_color", Color("#263F4B"))
	content.add_child(name_label)
	production_overlay.add_child(ghost)
	_production_touch_drag_ghost = ghost


func _update_production_touch_drag_ghost(screen_position: Vector2) -> void:
	if is_instance_valid(_production_touch_drag_ghost):
		_production_touch_drag_ghost.position = screen_position - _production_touch_drag_ghost.custom_minimum_size * 0.5
	if not is_instance_valid(production_panel):
		return
	var component: ProductionComponent = _production_building.production_component if is_instance_valid(_production_building) else null
	if not is_instance_valid(component):
		return
	for slot_index in range(component.get_slot_count()):
		var slot_card := production_panel.find_child("QueueSlot%d" % slot_index, true, false) as PanelContainer
		if not is_instance_valid(slot_card):
			continue
		var hovered := slot_card.get_global_rect().has_point(screen_position)
		var slot_available := component.get_slot(slot_index).is_empty()
		if hovered and slot_available:
			slot_card.add_theme_stylebox_override("panel", _toolbar_style(Color("#245D70"), Color("#F3C94E")))
		else:
			var slot_data: Dictionary = component.get_slot(slot_index)
			var refreshed_style := StyleBoxFlat.new()
			refreshed_style.bg_color = Color("#CDEEFF") if not slot_data.is_empty() else Color(0.025, 0.12, 0.19, 0.72)
			refreshed_style.border_color = Color("#7DD2F5") if not slot_data.is_empty() else Color("#E7F7FF")
			refreshed_style.set_border_width_all(3)
			refreshed_style.set_corner_radius_all(22)
			slot_card.add_theme_stylebox_override("panel", refreshed_style)


func _finish_production_touch_drag(screen_position: Vector2) -> void:
	var building := _production_touch_drag_building
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return
	var component: ProductionComponent = building.production_component
	var payload := {"kind": "production_item", "item_id": _production_touch_drag_item_id, "building_id": building.get_instance_id()}
	# Touch dragging must be able to land on the selected building itself,
	# not only on the queue cards. Test the projected building footprint using
	# the exact same polygon used by native drag-and-drop hit testing.
	# The projected target is a sibling of the compact queue panel under
	# ProductionOverlay, not a descendant of ProductionPanel.
	if is_instance_valid(production_overlay):
		var building_target := production_overlay.find_child("ProductionBuildingDropTarget", true, false) as ProductionBuildingDropTarget
		if is_instance_valid(building_target):
			# InputEventScreenTouch.position is in viewport coordinates. Convert
			# through the full canvas transform and use the actual footprint
			# polygon as the single source of truth (the axis-aligned rect is only
			# a broad-phase bound and can disagree under CanvasLayer transforms).
			var target_local_position: Vector2 = building_target.get_global_transform_with_canvas().affine_inverse() * screen_position
			if building_target._has_point(target_local_position):
				if _can_accept_building_drop(Vector2.ZERO, payload, building):
					_accept_building_drop(Vector2.ZERO, payload, building)
				else:
					status_label.text = "Cannot start this order: check missing ingredients, unlocks and free queue slots."
				return
	for slot_index in range(component.get_slot_count()):
		var slot_card: Control = null
		if is_instance_valid(production_panel):
			slot_card = production_panel.find_child("QueueSlot%d" % slot_index, true, false) as Control
		if is_instance_valid(slot_card) and slot_card.get_global_rect().has_point(screen_position):
			if _can_accept_production_drop(Vector2.ZERO, payload, building, slot_index):
				_accept_production_drop(Vector2.ZERO, payload, building, slot_index)
			elif is_instance_valid(status_label):
				status_label.text = "This queue slot cannot accept that product. Choose an empty unlocked slot."
			return
	if is_instance_valid(status_label):
		status_label.text = "Tap a product to place the order. No empty queue slot is needed."


func _clear_production_touch_drag(clear_selection: bool = true) -> void:
	_production_touch_drag_active = false
	_production_touch_dragged = false
	_production_touch_drag_index = -1
	_production_touch_drag_item_id = ""
	_production_touch_drag_building = null
	_production_touch_drag_source_button = null
	if clear_selection:
		_touch_selected_production_item = ""
		_touch_selected_production_building_id = 0
	if is_instance_valid(_production_touch_drag_ghost):
		_production_touch_drag_ghost.queue_free()
	_production_touch_drag_ghost = null


func _on_production_building_gui_input(event: InputEvent, building: Building) -> void:
	var activated := false
	if event is InputEventScreenTouch and not event.pressed:
		activated = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		activated = true
	if not activated or _touch_selected_production_item.is_empty():
		return
	if not is_instance_valid(building) or building.get_instance_id() != _touch_selected_production_building_id:
		return
	var payload := {"kind": "production_item", "item_id": _touch_selected_production_item, "building_id": building.get_instance_id()}
	if _can_accept_building_drop(Vector2.ZERO, payload, building):
		_accept_building_drop(Vector2.ZERO, payload, building)
		_touch_selected_production_item = ""
		_touch_selected_production_building_id = 0
		get_viewport().set_input_as_handled()


func _can_accept_building_drop(_at_position: Vector2, data: Variant, building: Building) -> bool:
	if not (data is Dictionary) or str(data.get("kind", "")) != "production_item":
		return false
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return false
	if int(data.get("building_id", 0)) != building.get_instance_id():
		return false
	var component: ProductionComponent = building.production_component
	for slot_index in range(component.get_slot_count()):
		if component.get_slot(slot_index).is_empty():
			return _can_accept_production_drop(Vector2.ZERO, data, building, slot_index)
	return false


func _accept_building_drop(_at_position: Vector2, data: Variant, building: Building) -> void:
	if not _can_accept_building_drop(Vector2.ZERO, data, building):
		return
	var component: ProductionComponent = building.production_component
	for slot_index in range(component.get_slot_count()):
		if component.get_slot(slot_index).is_empty():
			_accept_production_drop(Vector2.ZERO, data, building, slot_index)
			return


func _on_production_slot_gui_input(event: InputEvent, building: Building, slot_index: int) -> void:
	var activated := false
	if event is InputEventScreenTouch and not event.pressed:
		activated = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		activated = true
	if not activated or _touch_selected_production_item.is_empty():
		return
	if not is_instance_valid(building) or building.get_instance_id() != _touch_selected_production_building_id:
		return
	var payload := {"kind": "production_item", "item_id": _touch_selected_production_item, "building_id": building.get_instance_id()}
	if _can_accept_production_drop(Vector2.ZERO, payload, building, slot_index):
		_accept_production_drop(Vector2.ZERO, payload, building, slot_index)
		_touch_selected_production_item = ""
		_touch_selected_production_building_id = 0
		get_viewport().set_input_as_handled()


func _get_production_drag_data(_at_position: Vector2, building: Building, item_id: String, item_button: Button) -> Variant:
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return null
	var component: ProductionComponent = building.production_component
	var data: Dictionary = ProductionManager.raw_materials.get(item_id, ProductionManager.get_store_item_definition(str(component.shop_id), item_id))
	var lock_reason := ProductionManager.get_recipe_lock_reason(item_id, component.store_star_level) if not component.is_factory else ("Unlocks at Level %d" % int(data.get("level", 1)) if int(data.get("level", 1)) > GameManager.level else "")
	if not lock_reason.is_empty():
		return null
	if not component.is_factory:
		var recipe := ProductionManager.get_recipe(item_id)
		if recipe.is_empty() or not StorageManager.has_items(recipe.get("inputs", {})):
			return null
	# Native desktop drag can also emit Button.pressed on release; suppress the
	# click so a successful queue drop never opens the detail capsule afterward.
	if is_instance_valid(item_button):
		item_button.set_meta("touch_drag_consumed", true)
	return {"kind": "production_item", "item_id": item_id, "building_id": building.get_instance_id()}


func _can_accept_production_drop(_at_position: Vector2, data: Variant, building: Building, slot_index: int) -> bool:
	if not (data is Dictionary) or str(data.get("kind", "")) != "production_item":
		return false
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return false
	if int(data.get("building_id", 0)) != building.get_instance_id():
		return false
	# Keep the UI acceptance gate identical to the production component's
	# operational requirement; otherwise a product looks valid but is rejected
	# only after the click reaches start_factory/start_craft.
	if not BuildManager.is_building_operational(building):
		return false
	var component: ProductionComponent = building.production_component
	if slot_index < 0 or slot_index >= component.get_slot_count() or not component.get_slot(slot_index).is_empty():
		return false
	var item_id := str(data.get("item_id", ""))
	if component.is_factory:
		if not ProductionManager.get_factory_material_ids(str(component.factory_type)).has(item_id) or not ProductionManager.raw_materials.has(item_id):
			return false
		return int(ProductionManager.raw_materials[item_id].get("level", 1)) <= GameManager.level
	var recipe: Dictionary = ProductionManager.get_recipe(item_id)
	if recipe.is_empty() or str(recipe.get("store", "")) != str(component.shop_id):
		return false
	if not ProductionManager.get_recipe_lock_reason(item_id, component.store_star_level).is_empty() or not ProductionManager.are_recipe_inputs_unlocked(recipe):
		return false
	# A manual order is accepted only when every ingredient is physically in
	# City Storage. Missing ingredients are never silently auto-produced.
	return StorageManager.has_items(recipe.get("inputs", {}))


func _accept_production_drop(_at_position: Vector2, data: Variant, building: Building, slot_index: int) -> void:
	if not _can_accept_production_drop(Vector2.ZERO, data, building, slot_index):
		return
	var component: ProductionComponent = building.production_component
	var item_id := str(data.get("item_id", ""))
	var started := false
	if component.is_factory:
		started = component.start_factory(item_id, slot_index)
	else:
		# No hidden dependency-chain start: the player must first manufacture
		# or collect each required input into City Storage.
		started = component.start_craft(item_id, slot_index)
	if started:
		status_label.text = "Production order accepted: %s." % str(ProductionManager.get_item_definition(item_id).get("name", item_id))
	else:
		status_label.text = "Order not accepted. Check materials, supplier chain, building operation and slot availability."
	open_production_panel(building)


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
	# A queued commercial order may become the active job after the previous
	# order completes. Detect that transition even though waiting cards have no
	# timer label yet, then rebuild the card with its live countdown.
	for slot_index in range(component.get_slot_count()):
		var slot_state: Dictionary = component.get_slot(slot_index)
		if slot_state.is_empty():
			continue
		var should_show_timer: bool = not bool(slot_state.get("ready", false)) and (component.is_factory or int(slot_state.get("finish_unix", 0)) > 0)
		var existing_timer := production_panel.find_child("TimerSlot%d" % slot_index, true, false)
		if should_show_timer != is_instance_valid(existing_timer):
			need_rebuild = true
			break
	if need_rebuild:
		open_production_panel(_production_building)
		return
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
				var total_seconds := maxf(1.0, _production_building.production_component.get_item_production_time(item_id))
				progress.value = clampf(1.0 - float(remaining) / total_seconds, 0.0, 1.0)
		if remaining <= 0:
			need_rebuild = true
	if need_rebuild:
		open_production_panel(_production_building)

func _close_production_panel() -> void:
	_clear_production_timer_tracking()
	_touch_selected_production_item = ""
	_touch_selected_production_building_id = 0
	_production_orbit_buttons.clear()
	if is_instance_valid(_production_world_orbit):
		_production_world_orbit.queue_free()
	_production_world_orbit = null
	if is_instance_valid(production_overlay):
		production_overlay.queue_free()
	production_overlay = null
	production_panel = null


func _production_product_tile_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.02, 0.07, 0.11, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _create_production_orbit_hex(index: int, world_position: Vector3) -> Node3D:
	return _create_world_hex_platform(_production_world_orbit, "ProductionHex_%d" % index, world_position)


func _create_world_hex_platform(parent: Node3D, node_name: String, world_position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.global_position = world_position
	if not is_instance_valid(parent):
		return root
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 1.55
	rim_mesh.bottom_radius = 1.55
	rim_mesh.height = 0.42
	rim_mesh.radial_segments = 6
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color("#AFC6D4")
	rim_material.metallic = 0.32
	rim_material.roughness = 0.28
	var rim := MeshInstance3D.new()
	rim.name = "HexDepthAndRim"
	rim.mesh = rim_mesh
	rim.material_override = rim_material
	root.add_child(rim)
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 1.40
	face_mesh.bottom_radius = 1.40
	face_mesh.height = 0.30
	face_mesh.radial_segments = 6
	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = Color("#F7FBFF")
	face_material.roughness = 0.24
	face_material.metallic = 0.08
	face_material.emission_enabled = true
	face_material.emission = Color(0.72, 0.84, 0.92, 1.0)
	face_material.emission_energy_multiplier = 0.10
	var face := MeshInstance3D.new()
	face.name = "WhiteHexFace"
	face.mesh = face_mesh
	face.material_override = face_material
	face.position.y = 0.21
	root.add_child(face)
	parent.add_child(root)
	return root

func _update_production_orbit_projection() -> void:
	if _production_orbit_buttons.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var dock_top := viewport_size.y * 0.58
	if is_instance_valid(production_panel) and production_panel.size.y > 0.0:
		dock_top = minf(dock_top, production_panel.get_global_rect().position.y - 8.0)
	var first_button := _production_orbit_buttons[0] as Control
	var button_size := first_button.size if is_instance_valid(first_button) else Vector2(100.0, 112.0)
	var gap := 8.0
	var columns := mini(_production_orbit_buttons.size(), maxi(1, int(floor((viewport_size.x - 16.0 + gap) / (button_size.x + gap)))))
	var rows := int(ceil(float(_production_orbit_buttons.size()) / float(columns)))
	var row_y := clampf(viewport_size.y * 0.18, 70.0, maxf(70.0, dock_top - button_size.y - float(rows - 1) * (button_size.y + gap)))
	var total_row_width := float(columns) * button_size.x + float(columns - 1) * gap
	var start_x := maxf(8.0, (viewport_size.x - total_row_width) * 0.5)
	for index in range(_production_orbit_buttons.size()):
		var button := _production_orbit_buttons[index]
		if not is_instance_valid(button):
			continue
		var world_position: Vector3 = button.get_meta("orbit_world_position", Vector3.ZERO)
		var projected := camera.unproject_position(world_position + Vector3(0.0, 0.24, 0.0))
		var behind := camera.is_position_behind(world_position)
		var col := index % columns
		var row_index := int(index / columns)
		var fallback_position := Vector2(start_x + float(col) * (button_size.x + gap), row_y + float(row_index) * (button_size.y + gap))
		var projected_rect := Rect2(projected - button_size * 0.5, button_size)
		var safe_rect := Rect2(Vector2(4.0, 66.0), Vector2(viewport_size.x - 8.0, maxf(0.0, dock_top - 70.0)))
		button.position = fallback_position if behind or not safe_rect.encloses(projected_rect) else projected - button_size * 0.5
		button.visible = true


func _update_residential_orbit_projection() -> void:
	if _residential_orbit_buttons.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var first_button := _residential_orbit_buttons[0] as Control
	var button_size := first_button.size if is_instance_valid(first_button) else Vector2(108.0, 116.0)
	var gap := 8.0
	var columns := mini(_residential_orbit_buttons.size(), maxi(1, int(floor((viewport_size.x - 16.0 + gap) / (button_size.x + gap)))))
	var total_row_width := float(columns) * button_size.x + float(columns - 1) * gap
	var start_x := maxf(8.0, (viewport_size.x - total_row_width) * 0.5)
	var row_y := clampf(viewport_size.y * 0.16, 66.0, maxf(66.0, viewport_size.y * 0.34 - button_size.y))
	for index in range(_residential_orbit_buttons.size()):
		var button := _residential_orbit_buttons[index]
		if not is_instance_valid(button):
			continue
		var world_position: Vector3 = button.get_meta("orbit_world_position", Vector3.ZERO)
		var projected := camera.unproject_position(world_position + Vector3(0.0, 0.24, 0.0))
		var behind := camera.is_position_behind(world_position)
		var col := index % columns
		var row_index := int(index / columns)
		var fallback_position := Vector2(start_x + float(col) * (button_size.x + gap), row_y + float(row_index) * (button_size.y + gap))
		var projected_rect := Rect2(projected - button_size * 0.5, button_size)
		var safe_rect := Rect2(Vector2(4.0, 62.0), Vector2(viewport_size.x - 8.0, viewport_size.y * 0.34))
		button.position = fallback_position if behind or not safe_rect.encloses(projected_rect) else projected - button_size * 0.5
		button.visible = true


func _on_residential_material_pressed(home: Building, item_id: String) -> void:
	if not is_instance_valid(home):
		return
	var suppliers: Array = CityDemandManager.get_suppliers_for_item(item_id)
	var supplier_name := ""
	for supplier in suppliers:
		if str(supplier.get("status", "")) != "available":
			supplier_name = str(supplier.get("name", "Supplier"))
			continue
		var supplier_id := str(supplier.get("building_id", ""))
		if supplier_id.is_empty():
			continue
		for candidate in BuildManager.buildings.values():
			if not is_instance_valid(candidate) or str(candidate.building_id) != supplier_id:
				continue
			if not is_instance_valid(candidate.production_component):
				continue
			_close_residential_panel()
			open_production_panel(candidate)
			var component: ProductionComponent = candidate.production_component
			var slot_index := -1
			for index in range(component.get_slot_count()):
				if component.get_slot(index).is_empty():
					slot_index = index
					break
			var payload := {"kind":"production_item", "item_id":item_id, "building_id":candidate.get_instance_id()}
			if slot_index >= 0 and _can_accept_production_drop(Vector2.ZERO, payload, candidate, slot_index):
				_accept_production_drop(Vector2.ZERO, payload, candidate, slot_index)
			else:
				_show_production_item_details(candidate, item_id, slot_index)
				var missing := ProductionManager.get_missing_inputs_text(item_id)
				if not missing.is_empty():
					status_label.text = "Missing City Storage: " + missing
			return
	var item_name := str(ProductionManager.get_item_definition(item_id).get("name", item_id.capitalize()))
	if supplier_name.is_empty():
		supplier_name = str(suppliers[0].get("name", "the required supplier")) if not suppliers.is_empty() else "a verified supplier"
	status_label.text = "Build or complete %s to produce %s." % [supplier_name, item_name]

func _on_city_needs_pressed() -> void:
	BuildManager.cancel_placement()
	_close_production_panel()
	_close_storage_panel()
	_close_residential_panel()
	open_city_needs_panel()

func _on_city_needs_changed(_snapshot: Dictionary) -> void:
	if is_instance_valid(city_needs_overlay):
		var previous_scroll := 0
		var previous_scroll_node = city_needs_overlay.find_child("CityNeedsScroll", true, false)
		if is_instance_valid(previous_scroll_node):
			previous_scroll = previous_scroll_node.scroll_vertical
		open_city_needs_panel()
		var refreshed_scroll_node = city_needs_overlay.find_child("CityNeedsScroll", true, false)
		if is_instance_valid(refreshed_scroll_node):
			refreshed_scroll_node.scroll_vertical = previous_scroll

func _city_panel_style() -> StyleBoxFlat:
	# Shared premium strategy-game window frame: warm ivory surface, deep blue
	# outer rim, gold accent and generous content inset for touch-first play.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F7FAFC")
	style.border_color = Color("#D7B45A")
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0.005, 0.025, 0.055, 0.58)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

func _city_panel_heading(parent: VBoxContainer, title_text: String, close_callback: Callable) -> void:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	parent.add_child(heading)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _popup_font_size(30))
	title.add_theme_color_override("font_color", Color("#17364A"))
	heading.add_child(title)
	var close := Button.new()
	close.name = "WindowCloseButton"
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 46) * _ui_scale
	close.add_theme_font_size_override("font_size", _popup_font_size(38))
	close.add_theme_color_override("font_color", Color("#17364A"))
	close.add_theme_stylebox_override("normal", _toolbar_style(Color("#E8F0F5"), Color("#B6C9D6")))
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
	var panel_width := minf(1080.0 * _ui_scale, viewport_size.x * 0.96)
	var panel_height := minf(830.0 * _ui_scale, viewport_size.y * 0.94)
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
	summary_label.text = "LEVEL %d   ·   XP %d/%d   ·   POPULATION %s   ·   HAPPINESS %d%%   ·   STORAGE %d/%d   ·   HOMES READY %d/%d   ·   UPGRADING %d   ·   WAITING %d   ·   ACTIVE ORDERS %d   ·   READY ORDERS %d" % [
		int(city.get("level", 1)), int(city.get("experience", 0)), int(city.get("xp_needed", 0)), _format_count(int(city.get("population", 0))), roundi(float(city.get("happiness", 0.0))),
		int(storage.get("used", 0)), int(storage.get("capacity", 0)),
		int(summary.get("ready_homes", 0)), int(summary.get("homes", 0)), int(summary.get("upgrading_homes", 0)),
		int(summary.get("waiting_homes", 0)), int(summary.get("active_orders", 0)), int(summary.get("ready_orders", 0))
	]
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size.y = 28 * _ui_scale
	summary_label.add_theme_font_size_override("font_size", _popup_font_size(15))
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
		metric_label.add_theme_font_size_override("font_size", _popup_font_size(15))
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
	var inventory_title := Label.new()
	inventory_title.text = "CITY STORAGE INVENTORY  ·  %d ITEM TYPES" % snapshot.get("inventory", []).size()
	inventory_title.add_theme_font_size_override("font_size", _popup_font_size(17))
	inventory_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(inventory_title)
	var inventory_grid := GridContainer.new()
	inventory_grid.name = "CityStorageInventory"
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 6)
	inventory_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(inventory_grid)
	if snapshot.get("inventory", []).is_empty():
		var empty_inventory := Label.new()
		empty_inventory.text = "City Storage is currently empty."
		empty_inventory.add_theme_font_size_override("font_size", _popup_font_size(14))
		empty_inventory.add_theme_color_override("font_color", Color("#617A88"))
		inventory_grid.add_child(empty_inventory)
	for inventory_item in snapshot.get("inventory", []):
		var inventory_card := PanelContainer.new()
		inventory_card.add_theme_stylebox_override("panel", _toolbar_style(Color("#F5FAFC"), Color("#D9E8EF")))
		inventory_grid.add_child(inventory_card)
		var inventory_layout := VBoxContainer.new()
		inventory_layout.add_theme_constant_override("separation", 1)
		inventory_card.add_child(inventory_layout)
		var inventory_id := str(inventory_item.get("item_id", ""))
		var inventory_category := "raw" if ProductionManager.raw_materials.has(inventory_id) else "crafted"
		var inventory_icon := Icons.make_item_icon(inventory_category, inventory_id, Vector2(34, 34) * _ui_scale)
		inventory_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inventory_layout.add_child(inventory_icon)
		var inventory_name := Label.new()
		inventory_name.text = str(inventory_item.get("name", inventory_id))
		inventory_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inventory_name.add_theme_font_size_override("font_size", _popup_font_size(8))
		inventory_name.add_theme_color_override("font_color", Color("#24485B"))
		inventory_layout.add_child(inventory_name)
		var inventory_count := Label.new()
		inventory_count.text = "× %d" % int(inventory_item.get("count", 0))
		inventory_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_count.add_theme_font_size_override("font_size", _popup_font_size(14))
		inventory_count.add_theme_color_override("font_color", Color("#34734D"))
		inventory_layout.add_child(inventory_count)
	var items_title := Label.new()
	items_title.text = "CITY-WIDE MATERIAL SHORTAGES"
	items_title.add_theme_font_size_override("font_size", _popup_font_size(17))
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
		item_title.add_theme_font_size_override("font_size", _popup_font_size(17))
		item_title.add_theme_color_override("font_color", Color("#18394D"))
		text_stack.add_child(item_title)
		var counts := Label.new()
		counts.text = "Stored %d   ·   Required %d   ·   Producing %d   ·   Ready %d   ·   Deficit %d   ·   Next ready %s" % [
			int(item.get("stored", 0)), int(item.get("required", 0)), int(item.get("producing", 0)),
			int(item.get("ready", 0)), int(item.get("deficit", 0)), (_city_needs_duration(int(item.get("eta_seconds", -1))) if int(item.get("eta_seconds", -1)) >= 0 else "—")
		]
		counts.add_theme_font_size_override("font_size", _popup_font_size(14))
		counts.add_theme_color_override("font_color", Color("#A13F35") if int(item.get("deficit", 0)) > 0 else Color("#34734D"))
		text_stack.add_child(counts)
		var supplier_list: Array = item.get("suppliers", [])
		var supplier_status := str(supplier_list[0].get("status", "")) if not supplier_list.is_empty() else "missing"
		var supplier_name := str(supplier_list[0].get("name", "Available")) if not supplier_list.is_empty() else "No registered supplier"
		if supplier_status == "constructing":
			supplier_name += " · UNDER CONSTRUCTION"
		elif supplier_status == "catalog_only":
			supplier_name += " · RECIPE PENDING"
		var supplier_text := Label.new()
		supplier_text.text = "SUPPLIER  " + supplier_name
		supplier_text.add_theme_font_size_override("font_size", _popup_font_size(13))
		supplier_text.add_theme_color_override("font_color", Color("#607989"))
		text_stack.add_child(supplier_text)
		var action := Button.new()
		action.custom_minimum_size = Vector2(112, 38) * _ui_scale
		if int(item.get("deficit", 0)) > 0:
			action.text = "BUILD" if supplier_status == "not_built" else ("BUILDING" if supplier_status == "constructing" else ("VIEW" if supplier_status == "catalog_only" else "PRODUCE"))
		else:
			action.text = "COLLECT" if int(item.get("ready", 0)) > 0 else "COVERED"
		action.disabled = supplier_list.is_empty() or (int(item.get("deficit", 0)) <= 0 and int(item.get("ready", 0)) <= 0)
		action.add_theme_stylebox_override("normal", _toolbar_style(Color("#E9BF45"), Color("#F8D978")))
		if not supplier_list.is_empty():
			action.pressed.connect(_open_city_need_supplier.bind(supplier_list[0]))
		row_layout.add_child(action)
	var orders_title := Label.new()
	orders_title.text = "ACTIVE PRODUCTION QUEUE"
	orders_title.add_theme_font_size_override("font_size", _popup_font_size(17))
	orders_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(orders_title)
	if snapshot.get("orders", []).is_empty():
		var no_orders := Label.new()
		no_orders.text = "No active factory or store orders."
		no_orders.add_theme_font_size_override("font_size", _popup_font_size(14))
		no_orders.add_theme_color_override("font_color", Color("#617A88"))
		content.add_child(no_orders)
	for order in snapshot.get("orders", []):
		var order_row := PanelContainer.new()
		order_row.name = "CityProductionOrder_%s_%d" % [str(order.get("building_id", "")), int(order.get("slot_index", 0))]
		order_row.add_theme_stylebox_override("panel", _toolbar_style(Color("#F5FAFC"), Color("#D9E8EF")))
		content.add_child(order_row)
		var order_layout := HBoxContainer.new()
		order_layout.add_theme_constant_override("separation", 8)
		order_row.add_child(order_layout)
		var order_item_id := str(order.get("item_id", ""))
		var order_category := "raw" if ProductionManager.raw_materials.has(order_item_id) else "crafted"
		order_layout.add_child(Icons.make_item_icon(order_category, order_item_id, Vector2(34, 34) * _ui_scale))
		var order_info := Label.new()
		var order_ready := bool(order.get("ready", false))
		var order_timer := "READY TO COLLECT" if order_ready else _city_needs_duration(int(order.get("remaining", 0)))
		order_info.text = "%s  ·  %s  ·  SLOT %d  ·  %s" % [CityDemandManager.get_item_name(order_item_id), str(order.get("building_name", "Factory / Store")), int(order.get("slot", 0)) + 1, order_timer]
		order_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_info.add_theme_font_size_override("font_size", _popup_font_size(14))
		order_info.add_theme_color_override("font_color", Color("#9A6B1D") if order_ready else Color("#315C8A"))
		order_layout.add_child(order_info)
		var order_action := Button.new()
		order_action.text = "COLLECT" if order_ready else "OPEN"
		order_action.custom_minimum_size = Vector2(86, 34) * _ui_scale
		order_action.pressed.connect(_open_city_production_order.bind(str(order.get("building_id", ""))))
		order_layout.add_child(order_action)
	var homes_title := Label.new()
	homes_title.text = "RESIDENTIAL UPGRADE PLANS"
	homes_title.add_theme_font_size_override("font_size", _popup_font_size(17))
	homes_title.add_theme_color_override("font_color", Color("#17364A"))
	content.add_child(homes_title)
	var note := Label.new()
	note.text = "Shared stock is allocated once across home plans in this view. Producing and ready-to-collect batches stay separate until collected into City Storage."
	note.add_theme_font_size_override("font_size", _popup_font_size(13))
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
		home_title.add_theme_font_size_override("font_size", _popup_font_size(15))
		home_title.add_theme_color_override("font_color", Color("#24485B"))
		home_header.add_child(home_title)
		var home_button := Button.new()
		var home_upgrading := bool(home.get("upgrading", false))
		home_button.text = "UPGRADING" if home_upgrading else ("UPGRADE" if bool(home.get("ready", false)) and int(home.get("stage", 1)) < 6 else "WAITING")
		home_button.disabled = home_upgrading or not bool(home.get("ready", false)) or int(home.get("stage", 1)) >= 6
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
			need_line.add_theme_font_size_override("font_size", _popup_font_size(13))
			need_line.add_theme_color_override("font_color", need_color)
			home_layout.add_child(need_line)

func _city_needs_duration(seconds: int) -> String:
	var safe := maxi(0, seconds)
	if safe >= 3600:
		return "%dh %02dm" % [safe / 3600, (safe % 3600) / 60]
	if safe >= 60:
		return "%dm %02ds" % [safe / 60, safe % 60]
	return "%ds" % safe

func _open_city_production_order(building_id: String) -> void:
	var building: Variant = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or building.status != "completed":
		return
	_close_city_needs_panel()
	open_production_panel(building)

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
	if str(building.definition.get("category", "")) != "residential":
		return
	# Tear down the previous home panel before assigning the new owner. queue_free
	# alone leaves the old high-z Control alive until the end of the frame.
	_close_residential_panel()
	# Switching to a home always tears down every competing building modal.
	_close_city_needs_panel()
	_close_production_panel()
	_close_storage_panel()
	_close_trade_panel()
	_close_epic_project_panel()
	building.set_residential_plan_selected(true)
	_residential_orbit_buttons.clear()
	_residential_building = building
	if is_instance_valid(_residential_world_orbit):
		_residential_world_orbit.queue_free()
	_residential_world_orbit = null
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
	var plan_icon := Icons.make_icon("hard_hat", Vector2(38, 38) * _ui_scale)
	plan_icon.name = "ResidentialPlanHardHat"
	plan_icon.modulate = Color("#3D9DE5")
	layout.add_child(plan_icon)
	var stage := int(building.upgrade_stage)
	var is_upgrading := bool(building.upgrade_in_progress)
	var requirements: Array = [] if is_upgrading else ProductionManager.get_upgrade_requirements(stage)
	var city_snapshot := CityDemandManager.get_city_snapshot()
	var home_data: Dictionary = {}
	for candidate in city_snapshot.get("homes", []):
		if str(candidate.get("building_id", "")) == building.building_id:
			home_data = candidate
			break
	# Home upgrade materials are shown as the same raised 3D hex tokens around
	# the selected house. Tapping a shortage token opens its actual supplier and
	# submits the corresponding production order when that supplier can accept it.
	_residential_world_orbit = Node3D.new()
	_residential_world_orbit.name = "ResidentialWorldOrbit"
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(_residential_world_orbit)
	for requirement_index in range(requirements.size()):
		var requirement: Dictionary = requirements[requirement_index]
		var item_id := str(requirement.get("item", ""))
		if item_id.is_empty():
			continue
		var amount := int(requirement.get("amount", 0))
		var owned := StorageManager.get_count(item_id)
		for home_need in home_data.get("needs", []):
			if str(home_need.get("item_id", "")) == item_id:
				owned = int(home_need.get("stored", owned))
				break
		var footprint_size: Vector2i = building.definition.get("size", Vector2i(2, 2))
		var orbit_camera := get_viewport().get_camera_3d()
		var orbit_right := orbit_camera.global_transform.basis.x.normalized() if is_instance_valid(orbit_camera) else Vector3.RIGHT
		var orbit_up := orbit_camera.global_transform.basis.y.normalized() if is_instance_valid(orbit_camera) else Vector3.UP
		var orbit_spacing := maxf(2.8, float(maxi(footprint_size.x, footprint_size.y)) * 0.85)
		var orbit_horizontal_offset := (float(requirement_index) - float(requirements.size() - 1) * 0.5) * orbit_spacing
		var orbit_position := building.global_position + orbit_right * orbit_horizontal_offset + orbit_up * 3.2
		_create_world_hex_platform(_residential_world_orbit, "ResidentialHex_%d" % requirement_index, orbit_position)
		var material_button := Button.new()
		material_button.name = "ResidentialNeed_%s" % item_id
		material_button.custom_minimum_size = Vector2(136.0, 148.0) * _ui_scale
		# Residential buttons are projected children of a plain Control as well;
		# give them an explicit touch rectangle instead of only a minimum size.
		material_button.size = material_button.custom_minimum_size
		material_button.mouse_filter = Control.MOUSE_FILTER_STOP
		material_button.flat = false
		material_button.focus_mode = Control.FOCUS_NONE
		material_button.z_index = 30
		material_button.add_theme_stylebox_override("normal", _production_product_tile_style(Color("#FFFFFF"), Color("#C7D8E2")))
		material_button.add_theme_stylebox_override("hover", _production_product_tile_style(Color("#F0FAFF"), Color("#4A9BC4")))
		material_button.add_theme_stylebox_override("pressed", _production_product_tile_style(Color("#E1F2FA"), Color("#D8AD4A")))
		material_button.add_theme_stylebox_override("disabled", _production_product_tile_style(Color("#EEF1F3"), Color("#C6CDD1")))
		var material_content := VBoxContainer.new()
		material_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		material_content.alignment = BoxContainer.ALIGNMENT_CENTER
		material_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material_button.add_child(material_content)
		var material_icon_type := "raw" if ProductionManager.raw_materials.has(item_id) else "crafted"
		var material_icon := Icons.make_item_icon(material_icon_type, item_id, Vector2(88, 88) * _ui_scale)
		material_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material_content.add_child(material_icon)
		var material_name := Label.new()
		material_name.text = CityDemandManager.get_item_name(item_id)
		material_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_name.add_theme_font_size_override("font_size", _popup_font_size(12))
		material_name.add_theme_color_override("font_color", Color("#263F4B"))
		material_content.add_child(material_name)
		var material_stock := Label.new()
		material_stock.text = "%d / %d" % [owned, amount]
		material_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_stock.add_theme_font_size_override("font_size", _popup_font_size(10))
		material_stock.add_theme_color_override("font_color", Color("#34734D") if owned >= amount else Color("#A13F35"))
		material_content.add_child(material_stock)
		material_button.disabled = owned >= amount
		material_button.tooltip_text = "Already stored" if owned >= amount else "Tap to open supplier and start this material"
		material_button.set_meta("orbit_world_position", orbit_position)
		material_button.pressed.connect(_on_residential_material_pressed.bind(building, item_id))
		residential_overlay.add_child(material_button)
		_residential_orbit_buttons.append(material_button)
	_update_residential_orbit_projection()
	var title := Label.new()
	title.text = "%s  ·  LEVEL %d → %d" % [str(building.definition.get("name", "Home")), stage, mini(stage + 1, 6)]
	title.add_theme_font_size_override("font_size", _popup_font_size(19))
	title.add_theme_color_override("font_color", Color("#24485B"))
	layout.add_child(title)
	var population_gain := ProductionManager.get_population_for_stage(mini(stage + 1, 6)) - int(building.current_population)
	var reward := Label.new()
	reward.text = "POPULATION +%d   ·   XP +%d   ·   SIMOLEONS +%d" % [maxi(0, population_gain), maxi(0, population_gain) + 10, 50 * (stage + 1)]
	reward.add_theme_font_size_override("font_size", _popup_font_size(15))
	reward.add_theme_color_override("font_color", Color("#34734D"))
	layout.add_child(reward)
	var plan_note := Label.new()
	plan_note.name = "ResidentialPlanDataNote"
	plan_note.text = ProductionManager.get_upgrade_plan_note(stage)
	plan_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_note.add_theme_font_size_override("font_size", _popup_font_size(13))
	plan_note.add_theme_color_override("font_color", Color("#8A672B"))
	layout.add_child(plan_note)
	if is_upgrading:
		var upgrade_status := Label.new()
		upgrade_status.name = "ResidentialUpgradeInProgress"
		upgrade_status.text = "SCAFFOLDING IN PROGRESS  ·  %d SECONDS REMAINING" % building.get_upgrade_remaining_seconds()
		upgrade_status.add_theme_font_size_override("font_size", _popup_font_size(15))
		upgrade_status.add_theme_color_override("font_color", Color("#315C8A"))
		layout.add_child(upgrade_status)
	var all_available := not requirements.is_empty() and not is_upgrading
	var shortage_lines: Array[String] = []
	for requirement in requirements:
		var item_id := str(requirement.get("item", ""))
		var amount := int(requirement.get("amount", 0))
		var allocated_need: Dictionary = {}
		for home_need in home_data.get("needs", []):
			if str(home_need.get("item_id", "")) == item_id:
				allocated_need = home_need
				break
		var owned := int(allocated_need.get("stored", StorageManager.get_count(item_id)))
		var ready_count := int(allocated_need.get("ready_to_collect", 0))
		var producing_count := int(allocated_need.get("in_production", 0))
		var shortage := int(allocated_need.get("shortage", maxi(0, amount - owned)))
		if owned < amount:
			all_available = false
			shortage_lines.append("%s ×%d" % [CityDemandManager.get_item_name(item_id), maxi(0, amount - owned)])
		var need_status := "READY"
		var need_color := Color("#34734D")
		if owned < amount:
			if ready_count > 0:
				need_status = "READY TO COLLECT %d" % ready_count
				need_color = Color("#9A6B1D")
			elif producing_count > 0:
				need_status = "IN PRODUCTION %d" % producing_count
				need_color = Color("#315C8A")
			else:
				need_status = "SHORT %d" % shortage
				need_color = Color("#A13F35")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		layout.add_child(row)
		var icon_type := "raw" if ProductionManager.raw_materials.has(item_id) else "crafted"
		row.add_child(Icons.make_item_icon(icon_type, item_id, Vector2(46, 46) * _ui_scale))
		var item_label := Label.new()
		item_label.text = "%s   ·   %d / %d   ·   %s" % [CityDemandManager.get_item_name(item_id), owned, amount, need_status]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.add_theme_font_size_override("font_size", _popup_font_size(16))
		item_label.add_theme_color_override("font_color", need_color)
		row.add_child(item_label)
		var supplier_rows: Array = CityDemandManager.get_suppliers_for_item(item_id)
		var supplier_line := Label.new()
		supplier_line.text = "SUPPLIER  " + (str(supplier_rows[0].get("name", "Unknown")) if not supplier_rows.is_empty() else "No registered supplier")
		supplier_line.add_theme_font_size_override("font_size", _popup_font_size(13))
		supplier_line.add_theme_color_override("font_color", Color("#607989"))
		layout.add_child(supplier_line)
	var plan_status := Label.new()
	plan_status.name = "ResidentialPlanStatus"
	plan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_upgrading:
		plan_status.text = "MSHIN TEMPORARY CONSTRUCTION · %d SEC LEFT" % building.get_upgrade_remaining_seconds()
		plan_status.add_theme_color_override("font_color", Color("#315C8A"))
	elif stage >= 6:
		plan_status.text = "MAXIMUM RESIDENTIAL LEVEL"
		plan_status.add_theme_color_override("font_color", Color("#587487"))
	elif all_available:
		plan_status.text = "ALL REQUIRED MATERIALS READY · HOME CAN BE UPGRADED"
		plan_status.add_theme_color_override("font_color", Color("#34734D"))
	else:
		plan_status.text = "MATERIALS MISSING · " + (", ".join(shortage_lines) if not shortage_lines.is_empty() else "CHECK REQUIRED ITEMS")
		plan_status.add_theme_color_override("font_color", Color("#A13F35"))
	plan_status.add_theme_font_size_override("font_size", _popup_font_size(14))
	layout.add_child(plan_status)
	if is_upgrading:
		var upgrade_progress := ProgressBar.new()
		upgrade_progress.name = "ResidentialUpgradeProgress"
		upgrade_progress.min_value = 0.0
		upgrade_progress.max_value = 1.0
		upgrade_progress.show_percentage = false
		var remaining_seconds := building.get_upgrade_remaining_seconds()
		upgrade_progress.value = clampf(1.0 - float(remaining_seconds) / 4.0, 0.0, 1.0)
		upgrade_progress.custom_minimum_size.y = 10.0 * _ui_scale
		layout.add_child(upgrade_progress)
		if remaining_seconds > 0:
			var progress_tween := create_tween()
			progress_tween.tween_property(upgrade_progress, "value", 1.0, float(remaining_seconds))
	var upgrade := Button.new()
	upgrade.name = "ResidentialUpgradeButton"
	upgrade.text = "CONSTRUCTION IN PROGRESS" if is_upgrading else ("DELIVER MATERIALS & UPGRADE" if all_available else ("MATERIALS MISSING" if stage < 6 else "MAXIMUM LEVEL"))
	upgrade.disabled = is_upgrading or stage >= 6 or not all_available
	upgrade.custom_minimum_size.y = 44 * _ui_scale
	upgrade.add_theme_stylebox_override("normal", _toolbar_style(Color("#55B96A"), Color("#A6E4A9")))
	upgrade.pressed.connect(_upgrade_residential_from_panel.bind(building))
	layout.add_child(upgrade)
	if stage >= 6:
		var epic_action := Button.new()
		epic_action.name = "EpicProjectAction"
		epic_action.custom_minimum_size.y = 42 * _ui_scale
		if building.is_epic_building:
			epic_action.text = "EPIC BUILDING · TOKEN PARTS"
		elif str(EpicProjectManager.active_project.get("building_id", "")) == building.building_id:
			epic_action.text = "VIEW ACTIVE EPIC PROJECT"
		else:
			var epic_reason := EpicProjectManager.get_start_block_reason(building)
			epic_action.text = "START EPIC PROJECT" if epic_reason.is_empty() else "EPIC PROJECT LOCKED"
			epic_action.disabled = not epic_reason.is_empty()
			epic_action.tooltip_text = epic_reason
		epic_action.add_theme_stylebox_override("normal", _toolbar_style(Color("#B68A35"), Color("#F2D27B")))
		epic_action.add_theme_color_override("font_color", Color("#34280B"))
		epic_action.pressed.connect(_open_epic_project_panel.bind(building))
		layout.add_child(epic_action)

func _upgrade_residential_from_panel(building: Building) -> void:
	if not is_instance_valid(building) or _residential_building != building or not is_instance_valid(residential_overlay):
		return
	if building.try_upgrade():
		_close_residential_panel()


func _open_epic_project_panel(building: Building) -> void:
	if not is_instance_valid(building) or _residential_building != building or not is_instance_valid(residential_overlay):
		return
	_close_residential_panel()
	_close_epic_project_panel()
	_epic_panel_building = building
	epic_project_overlay = Control.new()
	epic_project_overlay.name = "EpicProjectOverlay"
	epic_project_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	epic_project_overlay.z_index = 130
	epic_project_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(epic_project_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.68)
	epic_project_overlay.add_child(shade)
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(900.0 * _ui_scale, viewport_size.x * 0.96)
	var height := minf(770.0 * _ui_scale, viewport_size.y * 0.94)
	var panel := PanelContainer.new()
	panel.name = "EpicProjectPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.add_theme_stylebox_override("panel", _city_panel_style())
	epic_project_overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	panel.add_child(layout)
	_city_panel_heading(layout, "EPIC PROJECTS", _close_epic_project_panel)
	var subtitle := Label.new()
	subtitle.text = str(building.definition.get("name", "Residential Building"))
	subtitle.add_theme_font_size_override("font_size", _popup_font_size(19))
	subtitle.add_theme_color_override("font_color", Color("#24485B"))
	layout.add_child(subtitle)

	if building.is_epic_building:
		var tier_names: Array[String] = ["", "BRONZE · TURTLE", "SILVER · LLAMA", "GOLD · CHEETAH"]
		var tier_name: String = tier_names[clampi(building.epic_tier, 1, 3)]
		var tier_label := Label.new()
		tier_label.text = "EPIC BUILDING  ·  " + tier_name
		tier_label.add_theme_font_size_override("font_size", _popup_font_size(18))
		tier_label.add_theme_color_override("font_color", Color("#A87522"))
		layout.add_child(tier_label)
		var parts := Label.new()
		parts.text = "TOKEN PARTS  ·  %d" % EpicProjectManager.get_token_part_count(["", "bronze", "silver", "gold"][clampi(building.epic_tier, 1, 3)])
		layout.add_child(parts)
		var entry: Dictionary = EpicProjectManager.epic_buildings.get(building.building_id, {})
		var next_collect := int(entry.get("next_token_part_unix", 0))
		var remaining := maxi(0, next_collect - int(Time.get_unix_time_from_system()))
		var collect_status := Label.new()
		collect_status.text = "NEXT TOKEN PART  ·  READY" if remaining <= 0 else "NEXT TOKEN PART  ·  %s" % _format_clock_duration(remaining)
		layout.add_child(collect_status)
		var collect := Button.new()
		collect.name = "CollectEpicTokenPart"
		collect.text = "COLLECT TOKEN PART"
		collect.disabled = remaining > 0
		collect.custom_minimum_size.y = 44 * _ui_scale
		collect.pressed.connect(_collect_epic_token_part.bind(building))
		layout.add_child(collect)
		return

	var active: Dictionary = EpicProjectManager.active_project
	if active.is_empty():
		var reason := EpicProjectManager.get_start_block_reason(building)
		var explanation := Label.new()
		explanation.text = reason if not reason.is_empty() else "A 24-hour community project converts this fully upgraded home into an Epic Building. Contribute items through specialization tasks to earn project points."
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(explanation)
		var start := Button.new()
		start.name = "StartEpicProject"
		start.text = "START 24-HOUR EPIC PROJECT"
		start.disabled = not reason.is_empty()
		start.custom_minimum_size.y = 46 * _ui_scale
		start.pressed.connect(_start_epic_project_from_panel.bind(building))
		layout.add_child(start)
		return

	if str(active.get("building_id", "")) != building.building_id:
		var busy := Label.new()
		busy.text = "Another Epic Project is already active. Only one project can run at a time."
		busy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(busy)
		return

	var points := int(active.get("points", 0))
	var tier := str(active.get("tier", "none")).to_upper()
	var project_status := Label.new()
	project_status.text = "EPIC POINTS  ·  %d / 200  ·  %s" % [points, tier]
	project_status.add_theme_font_size_override("font_size", _popup_font_size(17))
	project_status.add_theme_color_override("font_color", Color("#A87522"))
	layout.add_child(project_status)
	var progress := ProgressBar.new()
	progress.name = "EpicProjectProgress"
	progress.min_value = 0
	progress.max_value = 200
	progress.value = clampi(points, 0, 200)
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12 * _ui_scale
	layout.add_child(progress)
	var finished := bool(active.get("finished", false))
	if finished:
		var finish_label := Label.new()
		finish_label.text = "PROJECT COMPLETE · " + tier
		finish_label.add_theme_color_override("font_color", Color("#34734D") if tier != "NONE" else Color("#A13F35"))
		layout.add_child(finish_label)
		var finish_button := Button.new()
		finish_button.name = "FinishEpicProject"
		finish_button.custom_minimum_size.y = 46 * _ui_scale
		if tier == "NONE":
			finish_button.text = "CLOSE · NO EPIC TIER EARNED"
			finish_button.pressed.connect(_dismiss_epic_project_from_panel.bind(building))
		else:
			finish_button.text = "UPGRADE TO EPIC BUILDING"
			finish_button.pressed.connect(_claim_epic_project_from_panel.bind(building))
		layout.add_child(finish_button)
		return

	var remaining_label := Label.new()
	remaining_label.text = "TIME REMAINING  ·  %s" % _format_clock_duration(EpicProjectManager.get_project_remaining_seconds())
	layout.add_child(remaining_label)
	var task_scroll := ScrollContainer.new()
	task_scroll.name = "EpicTaskScroll"
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	task_scroll.custom_minimum_size.y = 220 * _ui_scale
	layout.add_child(task_scroll)
	var task_list := VBoxContainer.new()
	task_list.add_theme_constant_override("separation", 6)
	task_scroll.add_child(task_list)
	for task in active.get("tasks", []):
		var task_row := HBoxContainer.new()
		task_row.add_theme_constant_override("separation", 8)
		task_list.add_child(task_row)
		var item_id := str(task.get("item_id", ""))
		var amount := int(task.get("amount", 0))
		var points_value := int(task.get("points", 0))
		task_row.add_child(Icons.make_item_icon("raw" if ProductionManager.raw_materials.has(item_id) else "crafted", item_id, Vector2(38, 38) * _ui_scale))
		var task_label := Label.new()
		task_label.text = "%s × %d  ·  +%d EPIC POINTS" % [CityDemandManager.get_item_name(item_id), amount, points_value]
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_row.add_child(task_label)
		var contribute := Button.new()
		contribute.text = "CONTRIBUTE"
		contribute.disabled = StorageManager.get_count(item_id) < amount
		contribute.pressed.connect(_contribute_epic_task_from_panel.bind(str(task.get("id", "")), building))
		task_row.add_child(contribute)

func _start_epic_project_from_panel(building: Building) -> void:
	if is_instance_valid(building):
		EpicProjectManager.start_project(building.building_id)

func _contribute_epic_task_from_panel(task_id: String, _building: Building) -> void:
	EpicProjectManager.contribute_to_task(task_id)

func _claim_epic_project_from_panel(_building: Building) -> void:
	EpicProjectManager.claim_project()

func _dismiss_epic_project_from_panel(_building: Building) -> void:
	EpicProjectManager.dismiss_finished_project()

func _collect_epic_token_part(building: Building) -> void:
	if is_instance_valid(building):
		EpicProjectManager.collect_token_part(building.building_id)

func _on_epic_project_state_changed() -> void:
	if is_instance_valid(epic_project_overlay) and is_instance_valid(_epic_panel_building):
		_open_epic_project_panel(_epic_panel_building)

func _close_epic_project_panel() -> void:
	if is_instance_valid(epic_project_overlay):
		epic_project_overlay.queue_free()
	epic_project_overlay = null
	_epic_panel_building = null

func _close_residential_panel() -> void:
	_residential_building = null
	_residential_orbit_buttons.clear()
	if is_instance_valid(_residential_world_orbit):
		_residential_world_orbit.queue_free()
	_residential_world_orbit = null
	for city_building in BuildManager.buildings.values():
		if is_instance_valid(city_building) and str(city_building.definition.get("category", "")) == "residential":
			city_building.set_residential_plan_selected(false)
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
	title.add_theme_font_size_override("font_size", _popup_font_size(27))
	title.add_theme_color_override("font_color", Color("#172330"))
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 5)
	heading.add_child(title)
	var close := Button.new()
	close.name = "StorageClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(46, 46) * _ui_scale
	close.add_theme_font_size_override("font_size", _popup_font_size(40))
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
	capacity_label.add_theme_font_size_override("font_size", _popup_font_size(23))
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

	var special_heading := Label.new()
	special_heading.name = "StorageSpecialItemsHeading"
	special_heading.text = "STORAGE SPECIAL ITEMS · 18 SIMCASH EACH"
	special_heading.add_theme_font_size_override("font_size", _popup_font_size(17))
	special_heading.add_theme_color_override("font_color", Color("#28799C"))
	layout.add_child(special_heading)
	for item_id in StorageManager.STORAGE_ITEM_IDS:
		var item_row := HBoxContainer.new()
		item_row.name = "StorageSpecialItem_" + item_id
		layout.add_child(item_row)
		var item_label := Label.new()
		item_label.text = "%s  ×%d" % [str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id)), StorageManager.get_count(item_id)]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_row.add_child(item_label)
		var buy_item := Button.new()
		buy_item.name = "Buy_" + item_id
		buy_item.text = "BUY · 18"
		buy_item.custom_minimum_size = Vector2(112, 42) * _ui_scale
		buy_item.disabled = GameManager.level < StorageManager.STORAGE_UNLOCK_LEVEL or StorageManager.get_free() < 1 or EconomyManager.sim_cash < StorageManager.STORAGE_ITEM_SIMCASH_PRICE
		buy_item.pressed.connect(_on_buy_storage_special_item.bind(item_id))
		item_row.add_child(buy_item)
	var required_each := StorageManager.get_next_storage_upgrade_requirement()
	var requirement := Label.new()
	requirement.name = "StorageUpgradeRequirement"
	requirement.text = "Next upgrade: +5 capacity · %d of each Storage Bar, Lock and Camera" % required_each
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(requirement)
	var upgrade := Button.new()
	upgrade.name = "ConfirmStorageSpecialItemUpgrade"
	upgrade.text = "CONFIRM CAPACITY UPGRADE (+5)"
	upgrade.custom_minimum_size.y = 54 * _ui_scale
	upgrade.add_theme_font_size_override("font_size", _popup_font_size(19))
	upgrade.add_theme_stylebox_override("normal", _toolbar_style(Color("#83D900"), Color("#B7F44C")))
	upgrade.disabled = not StorageManager.can_upgrade_storage_with_items()
	upgrade.pressed.connect(_on_storage_capacity_upgrade_pressed)
	layout.add_child(upgrade)
	_refresh_storage_panel()


func _on_buy_storage_special_item(item_id: String) -> void:
	var result := EconomyManager.buy_special_item_with_simcash(item_id, StorageManager.STORAGE_ITEM_SIMCASH_PRICE, StorageManager.STORAGE_UNLOCK_LEVEL)
	if not bool(result.get("success", false)):
		status_label.text = "Storage item purchase failed: %s" % str(result.get("reason", "unknown"))
		return
	SaveManager.save_game()
	_show_storage_panel()

func _on_storage_capacity_upgrade_pressed() -> void:
	var result := StorageManager.upgrade_storage_with_items()
	if not bool(result.get("success", false)):
		status_label.text = "Storage upgrade failed: %s" % str(result.get("reason", "unknown"))
		return
	SaveManager.save_game()
	status_label.text = "Storage expanded to %d slots." % StorageManager.capacity
	_show_storage_panel()


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
		empty_label.add_theme_font_size_override("font_size", _popup_font_size(22))
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
		count_label.add_theme_font_size_override("font_size", _popup_font_size(25))
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
	backdrop.color = Color(0.015, 0.025, 0.035, 0.42)
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
	title.add_theme_font_size_override("font_size", _popup_font_size(26))
	title.add_theme_color_override("font_color", Color("#172330"))
	heading.add_child(title)
	var close := Button.new()
	close.name = "TradeClose"
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44) * _ui_scale
	close.add_theme_font_size_override("font_size", _popup_font_size(32))
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

	var players_tab := Button.new()
	players_tab.name = "PlayerMarketTab"
	players_tab.text = "PLAYER MARKET"
	players_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_tab.pressed.connect(_show_trade_panel.bind("players"))
	tabs.add_child(players_tab)

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

	_trade_active_tab = tab if tab in ["depot", "market", "ship", "regional", "players"] else "depot"
	if _trade_active_tab == "market":
		market_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	elif _trade_active_tab == "ship":
		ship_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	elif _trade_active_tab == "regional":
		regional_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	elif _trade_active_tab == "players":
		players_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	else:
		depot_tab.add_theme_stylebox_override("normal", _catalog_action_style())
	_refresh_trade_panel_content()
	if _trade_active_tab == "players":
		call_deferred("_refresh_player_market")

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
	elif _trade_active_tab == "players":
		_build_player_market_content(body)
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
	label.add_theme_font_size_override("font_size", _popup_font_size(21))
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
	heading.add_theme_font_size_override("font_size", _popup_font_size(21))
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
	listings_heading.add_theme_font_size_override("font_size", _popup_font_size(21))
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
		var cancel := Button.new()
		cancel.name = "TradeCancel_%d" % index
		cancel.text = "CANCEL"
		cancel.tooltip_text = "Return the reserved goods to City Storage and remove this listing."
		cancel.disabled = StorageManager.get_free() < int(listing.get("amount", 0))
		cancel.pressed.connect(_on_trade_cancel_sale.bind(index))
		row.add_child(cancel)

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

func _on_trade_cancel_sale(slot_index: int) -> void:
	if not TradeManager.cancel_sale_listing(slot_index):
		status_label.text = "Could not cancel listing. Ensure City Storage has enough free capacity."
	else:
		status_label.text = "Listing cancelled; reserved goods returned to City Storage."
	_show_trade_panel("depot")

func _build_player_market_content(parent: VBoxContainer) -> void:
	if not PlayerAccountManager.is_authenticated():
		_trade_message(parent, "Sign in to a player account to buy and sell with other mayors.")
		return
	var refresh_row := HBoxContainer.new()
	parent.add_child(refresh_row)
	var refresh_label := Label.new()
	refresh_label.text = "PLAYER-TO-PLAYER MARKET · Simoleons"
	refresh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_label.add_theme_font_size_override("font_size", _popup_font_size(20))
	refresh_label.add_theme_color_override("font_color", Color("#24465A"))
	refresh_row.add_child(refresh_label)
	var refresh_button := Button.new()
	refresh_button.text = "REFRESH"
	refresh_button.pressed.connect(_refresh_player_market)
	refresh_row.add_child(refresh_button)

	var market_heading := Label.new()
	market_heading.text = "AVAILABLE FROM OTHER PLAYERS"
	market_heading.add_theme_font_size_override("font_size", _popup_font_size(17))
	market_heading.add_theme_color_override("font_color", Color("#28799C"))
	parent.add_child(market_heading)
	if PlayerMarketManager.public_listings.is_empty():
		_trade_message(parent, "No player listings are available. Refresh later or list goods from your warehouse.")
	for listing in PlayerMarketManager.public_listings:
		var listing_id := str(listing.get("listing_id", ""))
		var item_id := str(listing.get("item_id", ""))
		var quantity := int(listing.get("quantity", 0))
		var total_price := int(listing.get("total_price", 0))
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 48 * _ui_scale
		parent.add_child(row)
		var info := Label.new()
		info.text = "%s ×%d · §%d · Mayor #%d" % [str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize())), quantity, total_price, int(listing.get("seller_id", 0))]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info.add_theme_color_override("font_color", Color("#263746"))
		row.add_child(info)
		var buy := Button.new()
		buy.text = "BUY"
		buy.disabled = EconomyManager.simoleons < total_price or StorageManager.get_free() < quantity
		buy.pressed.connect(_buy_player_market_listing.bind(listing_id))
		row.add_child(buy)

	var shop_heading := Label.new()
	shop_heading.text = "MY SHOP · RESERVED GOODS"
	shop_heading.add_theme_font_size_override("font_size", _popup_font_size(17))
	shop_heading.add_theme_color_override("font_color", Color("#28799C"))
	parent.add_child(shop_heading)
	for item_variant in StorageManager.get_all_items().keys():
		var item_id := str(item_variant)
		var count := StorageManager.get_count(item_id)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 44 * _ui_scale
		parent.add_child(row)
		var item_label := Label.new()
		item_label.text = "%s ×%d" % [str(StorageManager.item_definitions.get(item_id, {}).get("name", item_id.capitalize())), count]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(item_label)
		var sell := Button.new()
		sell.text = "SELL 1 · §%d" % ProductionManager.get_item_value(item_id)
		sell.disabled = not TradeManager.is_trade_eligible_item(item_id) or count < 1 or ProductionManager.get_item_value(item_id) <= 0
		sell.pressed.connect(_list_player_market_item.bind(item_id))
		row.add_child(sell)

	for listing in PlayerMarketManager.my_listings:
		var listing_status := str(listing.get("status", ""))
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 44 * _ui_scale
		parent.add_child(row)
		var info := Label.new()
		info.text = "%s ×%d · §%d each · %s" % [
			str(listing.get("item_id", "Item")).capitalize(),
			int(listing.get("quantity", 0)),
			int(listing.get("unit_price", 0)),
			listing_status.to_upper()
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(info)
		if listing_status == "active":
			var cancel := Button.new()
			cancel.text = "CANCEL"
			cancel.pressed.connect(_cancel_player_market_listing.bind(str(listing.get("listing_id", ""))))
			row.add_child(cancel)

	var orders_heading := Label.new()
	orders_heading.text = "MY RECENT MARKET ORDERS"
	orders_heading.add_theme_font_size_override("font_size", _popup_font_size(17))
	orders_heading.add_theme_color_override("font_color", Color("#28799C"))
	parent.add_child(orders_heading)
	var market_transactions: Array[Dictionary] = []
	for transaction in EconomyManager.get_recent_transactions(30):
		var transaction_type := str(transaction.get("type", ""))
		if transaction_type in ["player_market_purchase", "player_market_sale", "player_market_listing_reserved", "player_market_listing_cancelled"]:
			market_transactions.append(transaction)
	market_transactions.reverse()
	if market_transactions.is_empty():
		_trade_message(parent, "Your player-market activity will appear here.")
	for transaction in market_transactions.slice(0, 10):
		var metadata: Dictionary = transaction.get("metadata", {})
		var order_row := HBoxContainer.new()
		order_row.custom_minimum_size.y = 36 * _ui_scale
		parent.add_child(order_row)
		var order_label := Label.new()
		var action_label := str(transaction.get("type", "")).replace("player_market_", "").replace("_", " ").to_upper()
		order_label.text = "%s · %s ×%d · §%d" % [
			action_label,
			str(metadata.get("item_id", "Goods")).capitalize(),
			int(metadata.get("quantity", transaction.get("amount", 0))),
			int(transaction.get("amount", 0)) if str(transaction.get("currency", "")) == "simoleons" else 0
		]
		order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		order_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_row.add_child(order_label)

func _refresh_player_market() -> void:
	await PlayerMarketManager.refresh_market()
	await PlayerMarketManager.refresh_my_shop()
	_refresh_trade_panel_content()

func _list_player_market_item(item_id: String) -> void:
	var result := await PlayerMarketManager.create_listing(item_id, 1, ProductionManager.get_item_value(item_id))
	if not bool(result.get("success", false)):
		status_label.text = "Could not list item: %s" % str(result.get("reason", "unknown error"))
	else:
		status_label.text = "Item listed. It is reserved until sold or cancelled."
	_show_trade_panel("players")

func _buy_player_market_listing(listing_id: String) -> void:
	var result := await PlayerMarketManager.buy_listing(listing_id)
	if not bool(result.get("success", false)):
		status_label.text = "Purchase failed: %s" % str(result.get("reason", "unknown error"))
	else:
		status_label.text = "Purchase complete. Goods and Simoleons were transferred."
	_show_trade_panel("players")

func _cancel_player_market_listing(listing_id: String) -> void:
	var result := await PlayerMarketManager.cancel_listing(listing_id)
	if not bool(result.get("success", false)):
		status_label.text = "Could not cancel listing: %s" % str(result.get("reason", "unknown error"))
	else:
		status_label.text = "Listing cancelled; reserved goods returned to your warehouse."
	_show_trade_panel("players")

func _on_trade_buy_offer(offer_index: int) -> void:
	if not TradeManager.buy_global_offer(offer_index):
		status_label.text = "Could not buy this offer. Check Simoleons and storage capacity."
	_show_trade_panel("market")



func _update_settings_login_indicator() -> void:
	if not is_instance_valid(_settings_login_indicator):
		return
	_settings_login_indicator.visible = not PlayerAccountManager.is_authenticated()
	if is_instance_valid(_settings_login_blink_timer):
		if PlayerAccountManager.is_authenticated():
			_settings_login_blink_timer.stop()
			_settings_login_indicator.visible = false
		else:
			if _settings_login_blink_timer.is_stopped():
				_settings_login_blink_timer.start()
			_settings_login_indicator.visible = true

func _blink_settings_login_indicator() -> void:
	if PlayerAccountManager.is_authenticated():
		_update_settings_login_indicator()
		return
	if is_instance_valid(_settings_login_indicator):
		_settings_login_indicator.visible = not _settings_login_indicator.visible

func _refresh_settings_account_section() -> void:
	if not is_instance_valid(_settings_account_status) or not is_instance_valid(_settings_account_action):
		return
	if PlayerAccountManager.is_authenticated():
		_settings_account_status.text = "Connected securely · Mayor #%d\nWelcome and daily rewards are claimed automatically." % PlayerAccountManager.player_id
		_settings_account_action.text = "Sign out"
		if is_instance_valid(_settings_account_action.get_node_or_null("GmailButtonContent")):
			_settings_account_action.get_node("GmailButtonContent").hide()
	else:
		_settings_account_status.text = "Guest mode\nSign in to secure your city and receive login rewards."
		_settings_account_action.text = ""
		if is_instance_valid(_settings_account_action.get_node_or_null("GmailButtonContent")):
			_settings_account_action.get_node("GmailButtonContent").show()

func _on_settings_account_action_pressed() -> void:
	if PlayerAccountManager.is_authenticated():
		PlayerAccountManager.logout()
		_refresh_settings_account_section()
		return
	_settings_account_action.disabled = true
	PlayerAccountManager.begin_google_sign_in()
	if is_instance_valid(_settings_account_status):
		_settings_account_status.text = "Connecting to Google securely…"

func _on_settings_account_session_changed(_player_id: int, _authenticated: bool) -> void:
	_update_settings_login_indicator()
	_refresh_settings_account_section()

func _on_settings_account_feedback(message: String, success: bool) -> void:
	if is_instance_valid(_settings_account_status):
		_settings_account_status.text = message
	if is_instance_valid(_settings_account_action):
		_settings_account_action.disabled = false
		_settings_account_action.text = "Sign out" if success and PlayerAccountManager.is_authenticated() else ("" if not PlayerAccountManager.is_authenticated() else "Sign out")
		var gmail_content := _settings_account_action.get_node_or_null("GmailButtonContent")
		if is_instance_valid(gmail_content):
			gmail_content.visible = not PlayerAccountManager.is_authenticated()

func _on_settings_pressed() -> void:
	_show_settings_panel()

func _close_settings_panel() -> void:
	if is_instance_valid(settings_overlay):
		settings_overlay.queue_free()
	settings_overlay = null

func _show_settings_panel() -> void:
	_close_settings_panel()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(1360.0 * _ui_scale, viewport_size.x * 0.94)
	var compact_scale := minf(1.0, viewport_size.y / 520.0)
	var panel_height := viewport_size.y * 0.94
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.z_index = 130
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "SettingsBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.035, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_child(backdrop)
	var backdrop_tween := create_tween()
	backdrop_tween.tween_property(backdrop, "color:a", 0.76, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	panel.pivot_offset = Vector2(panel_width, panel_height) * 0.5
	panel.scale = Vector2(0.965, 0.965)
	panel.modulate.a = 0.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#152B45")
	panel_style.border_color = Color("#5BD7F7")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(28)
	panel_style.shadow_color = Color(0.01, 0.06, 0.14, 0.55)
	panel_style.shadow_size = 26
	panel_style.shadow_offset = Vector2(0, 9)
	panel_style.content_margin_left = 22 * compact_scale
	panel_style.content_margin_right = 22 * compact_scale
	panel_style.content_margin_top = 14 * compact_scale
	panel_style.content_margin_bottom = 14 * compact_scale
	panel.add_theme_stylebox_override("panel", panel_style)
	settings_overlay.add_child(panel)
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var layout := VBoxContainer.new()
	layout.name = "SettingsLayout"
	layout.add_theme_constant_override("separation", 7 * compact_scale)
	panel.add_child(layout)

	var heading := HBoxContainer.new()
	heading.name = "SettingsHeading"
	layout.add_child(heading)
	var title := Label.new()
	title.text = "SETTINGS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", _settings_font_size(34))
	title.add_theme_color_override("font_color", Color("#F5FBFF"))
	title.add_theme_color_override("font_shadow_color", Color("#48CFF5"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	heading.add_child(title)
	var close := Button.new()
	close.name = "SettingsClose"
	close.text = "✖"
	close.custom_minimum_size = Vector2(72, 72) * _ui_scale
	close.add_theme_font_size_override("font_size", _popup_font_size(28))
	close.add_theme_stylebox_override("normal", _settings_close_style(Color("#244C6C")))
	close.add_theme_stylebox_override("hover", _settings_close_style(Color("#2D789D")))
	close.add_theme_stylebox_override("pressed", _settings_close_style(Color("#143A57")))
	close.pressed.connect(_close_settings_panel)
	heading.add_child(close)

	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7 * minf(1.0, viewport_size.y / 520.0))
	layout.add_child(content)

	var audio_row := GridContainer.new()
	audio_row.name = "SettingsAudioToggles"
	audio_row.columns = 2
	audio_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_theme_constant_override("h_separation", 12 * compact_scale)
	audio_row.add_theme_constant_override("v_separation", 8)
	content.add_child(audio_row)
	_add_settings_switch(audio_row, "MusicToggle", "Music", AudioManager.music_enabled, AudioManager.set_music_enabled)
	_add_settings_switch(audio_row, "SfxToggle", "Sounds", AudioManager.sfx_enabled, AudioManager.set_sfx_enabled)

	var actions := GridContainer.new()
	actions.name = "SettingsMainActions"
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 12 * compact_scale)
	actions.add_theme_constant_override("v_separation", 7 * compact_scale)
	content.add_child(actions)
	_add_settings_action(actions, "SettingsAboutButton", "About", _show_settings_about)
	_add_settings_action(actions, "SettingsChangeCityNameButton", "Change City Name", _show_change_city_name)
	_add_settings_action(actions, "SettingsHelpButton", "Help", _show_settings_help)
	_add_settings_action(actions, "SettingsNotificationsButton", "Notification Settings", _show_notification_settings)
	_add_settings_action(actions, "SettingsWalletButton", "Wallet", _show_wallet_panel)

	var account_note := Label.new()
	account_note.name = "SettingsAccountPrompt"
	account_note.text = "Sign in to save your progress and continue playing on multiple devices."
	account_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	account_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_note.add_theme_font_size_override("font_size", _settings_font_size(18))
	account_note.add_theme_color_override("font_color", Color("#FFD9D3"))
	account_note.visible = false
	content.add_child(account_note)

	_settings_account_status = Label.new()
	_settings_account_status.name = "SettingsAccountStatus"
	_settings_account_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_account_status.add_theme_font_size_override("font_size", _settings_font_size(18))
	_settings_account_status.add_theme_color_override("font_color", Color("#D3E9FA"))
	content.add_child(_settings_account_status)

	_settings_account_action = Button.new()
	_settings_account_action.name = "SettingsGoogleAccountAction"
	_settings_account_action.custom_minimum_size = Vector2(0, 62 * compact_scale)
	_settings_account_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_account_action.add_theme_stylebox_override("normal", _settings_google_button_style(Color("#FFFFFF")))
	_settings_account_action.add_theme_stylebox_override("hover", _settings_google_button_style(Color("#FFF1F0")))
	_settings_account_action.add_theme_stylebox_override("pressed", _settings_google_button_style(Color("#FFE0DD")))
	_settings_account_action.focus_mode = Control.FOCUS_NONE
	_settings_account_action.pressed.connect(_on_settings_account_action_pressed)
	var gmail_content := HBoxContainer.new()
	gmail_content.name = "GmailButtonContent"
	gmail_content.alignment = BoxContainer.ALIGNMENT_CENTER
	gmail_content.add_theme_constant_override("separation", 14)
	gmail_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_account_action.add_child(gmail_content)
	var gmail_icon := TextureRect.new()
	gmail_icon.name = "GmailIcon"
	gmail_icon.texture = load("res://assets/ui/gmail-mark.svg") as Texture2D
	gmail_icon.custom_minimum_size = Vector2(44, 44)
	gmail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gmail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gmail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gmail_content.add_child(gmail_icon)
	var gmail_text := RichTextLabel.new()
	gmail_text.name = "GmailButtonText"
	gmail_text.bbcode_enabled = true
	gmail_text.fit_content = true
	gmail_text.scroll_active = false
	gmail_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	gmail_text.selection_enabled = false
	gmail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gmail_text.add_theme_font_size_override("normal_font_size", _settings_font_size(23))
	gmail_text.text = "[center][color=#EA4335]Continue with [/color][color=#4285F4]G[/color][color=#EA4335]o[/color][color=#FBBC05]o[/color][color=#4285F4]g[/color][color=#34A853]l[/color][color=#EA4335]e[/color][/center]"
	gmail_content.add_child(gmail_text)
	_settings_account_action.pivot_offset = Vector2(panel_width * 0.5 - 22 * compact_scale, 31 * compact_scale)
	_settings_account_action.mouse_entered.connect(func() -> void: _settings_button_hover(_settings_account_action, true))
	_settings_account_action.mouse_exited.connect(func() -> void: _settings_button_hover(_settings_account_action, false))
	_settings_account_action.pressed.connect(func() -> void: _settings_button_press(_settings_account_action))
	content.add_child(_settings_account_action)
	_refresh_settings_account_section()


func _settings_google_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#EA4335")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.55, 0.12, 0.10, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _settings_action_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#D7F7FF", 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.01, 0.04, 0.10, 0.38)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _settings_green_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#B6F2FF")
	style.set_border_width_all(1)
	style.border_width_bottom = 4
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.01, 0.04, 0.10, 0.38)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	return style


func _settings_close_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#67D7F6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(36)
	style.shadow_color = Color(0.01, 0.04, 0.10, 0.32)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


func _settings_button_hover(button: Control, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(1.025, 1.025) if hovered else Vector2.ONE, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _settings_button_press(button: Control) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.97, 0.97), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_settings_action(parent: GridContainer, node_name: String, caption: String, action: Callable) -> void:
	var compact_scale := minf(1.0, get_viewport().get_visible_rect().size.y / 520.0)
	var button := Button.new()
	button.name = node_name
	button.text = caption
	var icon_by_action := {
		"SettingsAboutButton": "info",
		"SettingsChangeCityNameButton": "level",
		"SettingsHelpButton": "info",
		"SettingsNotificationsButton": "warning",
		"SettingsWalletButton": "money"
	}
	var action_icon_id := str(icon_by_action.get(node_name, ""))
	if not action_icon_id.is_empty():
		button.icon = Icons.get_icon_tex(action_icon_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = false
		button.add_theme_constant_override("h_separation", 14 * compact_scale)
	button.custom_minimum_size = Vector2(0, 66 * compact_scale)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", _settings_font_size(21))
	button.add_theme_color_override("font_color", Color("#F5FBFF"))
	button.add_theme_color_override("font_shadow_color", Color("#12334C"))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", _settings_green_button_style(Color("#23658B")))
	button.add_theme_stylebox_override("hover", _settings_green_button_style(Color("#2C85AF")))
	button.add_theme_stylebox_override("pressed", _settings_green_button_style(Color("#164A6D")))
	button.focus_mode = Control.FOCUS_NONE
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.mouse_entered.connect(func() -> void: _settings_button_hover(button, true))
	button.mouse_exited.connect(func() -> void: _settings_button_hover(button, false))
	button.pressed.connect(func() -> void: _settings_button_press(button))
	button.pressed.connect(action)
	parent.add_child(button)


func _add_settings_switch(parent: GridContainer, node_name: String, caption: String, enabled: bool, setter: Callable) -> void:
	var compact_scale := minf(1.0, get_viewport().get_visible_rect().size.y / 520.0)
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(row)
	var toggle := Button.new()
	toggle.name = node_name
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.text = "On" if enabled else "Off"
	toggle.custom_minimum_size = Vector2(90, 52 * compact_scale)
	toggle.add_theme_font_size_override("font_size", _settings_font_size(20))
	toggle.add_theme_color_override("font_color", Color("#FFFFFF"))
	toggle.add_theme_color_override("font_shadow_color", Color("#385C00"))
	toggle.add_theme_constant_override("shadow_offset_x", 1)
	toggle.add_theme_constant_override("shadow_offset_y", 2)
	toggle.add_theme_stylebox_override("normal", _settings_green_button_style(Color("#286D91")))
	toggle.add_theme_stylebox_override("hover", _settings_green_button_style(Color("#3598BD")))
	toggle.add_theme_stylebox_override("pressed", _settings_green_button_style(Color("#175273")))
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pivot_offset = toggle.custom_minimum_size * 0.5
	toggle.mouse_entered.connect(func() -> void: _settings_button_hover(toggle, true))
	toggle.mouse_exited.connect(func() -> void: _settings_button_hover(toggle, false))
	toggle.toggled.connect(func(value: bool) -> void:
		toggle.text = "On" if value else "Off"
		setter.call(value)
	)
	row.add_child(toggle)
	var label := Label.new()
	label.name = node_name + "Label"
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _settings_font_size(22))
	label.add_theme_color_override("font_color", Color("#F2FAFF"))
	row.add_theme_color_override("font_shadow_color", Color("#0A2338"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(label)


func _style_settings_dialog(dialog: Window, size: Vector2i) -> void:
	var scale_factor := _ui_scale
	dialog.add_theme_color_override("font_color", Color("#EAF7FF"))
	dialog.add_theme_color_override("title_color", Color("#F5FBFF"))
	dialog.add_theme_color_override("font_shadow_color", Color("#082A42"))
	dialog.add_theme_constant_override("shadow_offset_x", 1)
	dialog.add_theme_constant_override("shadow_offset_y", 1)
	dialog.add_theme_font_size_override("font_size", _popup_font_size(18))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#142E49")
	panel_style.border_color = Color("#51D4F3")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(22)
	panel_style.shadow_color = Color(0.01, 0.04, 0.12, 0.58)
	panel_style.shadow_size = 22
	panel_style.shadow_offset = Vector2(0, 8)
	panel_style.content_margin_left = 24 * scale_factor
	panel_style.content_margin_right = 24 * scale_factor
	panel_style.content_margin_top = 20 * scale_factor
	panel_style.content_margin_bottom = 18 * scale_factor
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_stylebox_override("button", _settings_green_button_style(Color("#24678C")))
	dialog.add_theme_stylebox_override("button_hover", _settings_green_button_style(Color("#318AB5")))
	dialog.add_theme_stylebox_override("button_pressed", _settings_green_button_style(Color("#174B6D")))
	dialog.add_theme_color_override("line_edit_font_color", Color("#142B45"))
	dialog.add_theme_color_override("line_edit_font_selected_color", Color("#FFFFFF"))
	dialog.add_theme_stylebox_override("line_edit", _settings_action_style(Color("#F0FAFF")))
	dialog.add_theme_stylebox_override("line_edit_focus", _settings_action_style(Color("#FFFFFF")))
	dialog.add_theme_color_override("check_button_color", Color("#54D8F5"))
	dialog.add_theme_color_override("slider_color", Color("#53D6F4"))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(size)

func _show_settings_about() -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "SettingsAboutDialog"
	dialog.title = "About Mshin · Advanced settings"
	var viewport_size := get_viewport().get_visible_rect().size
	var advanced_scroll := ScrollContainer.new()
	advanced_scroll.name = "AdvancedSettingsScroll"
	advanced_scroll.custom_minimum_size = Vector2(0, minf(480.0, viewport_size.y * 0.62))
	advanced_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	advanced_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog.add_child(advanced_scroll)
	var content := VBoxContainer.new()
	content.name = "AdvancedSettingsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	advanced_scroll.add_child(content)
	var about_text := Label.new()
	about_text.text = "Mshin City Builder — build, grow and manage your own city. Your progress is saved locally and can be synchronized after signing in with Google."
	about_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(about_text)
	var graphics_heading := Label.new()
	graphics_heading.text = "3D GRAPHICS QUALITY"
	content.add_child(graphics_heading)
	var graphics_select := OptionButton.new()
	graphics_select.name = "GraphicsQualitySelect"
	var quality_names := GraphicsSettingsManager.get_quality_names()
	for quality_name in quality_names:
		var preset: Dictionary = GraphicsSettingsManager.get_quality_preset(quality_name)
		graphics_select.add_item(str(preset.get("label", quality_name.capitalize())))
	graphics_select.select(quality_names.find(GraphicsSettingsManager.quality))
	graphics_select.item_selected.connect(_on_graphics_quality_selected)
	content.add_child(graphics_select)
	var audio_heading := Label.new()
	audio_heading.text = "ADVANCED VOLUME"
	content.add_child(audio_heading)
	_add_audio_setting_slider(content, "MasterVolumeSlider", "Master volume", AudioManager.master_volume, AudioManager.set_master_volume)
	_add_audio_setting_slider(content, "MusicVolumeSlider", "Music volume", AudioManager.music_volume, AudioManager.set_music_volume)
	_add_audio_setting_slider(content, "AmbientVolumeSlider", "City ambience", AudioManager.ambient_volume, AudioManager.set_ambient_volume)
	_add_audio_setting_slider(content, "SfxVolumeSlider", "Sound effects", AudioManager.sfx_volume, AudioManager.set_sfx_volume)
	var benchmark := Button.new()
	benchmark.name = "RunDeviceBenchmarkButton"
	benchmark.text = "Run 30-second device test"
	benchmark.pressed.connect(_start_performance_benchmark)
	content.add_child(benchmark)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_style_settings_dialog(dialog, Vector2i(roundi(minf(720.0, viewport_size.x * 0.90)), roundi(minf(640.0, viewport_size.y * 0.88))))


func _show_settings_help() -> void:
	_close_settings_panel()
	var scene := get_tree().current_scene
	var guide := scene.get_node_or_null("TutorialGuide") if scene != null else null
	if is_instance_valid(guide) and guide.has_method("open_help"):
		guide.open_help()
		return
	var dialog := AcceptDialog.new()
	dialog.name = "SettingsHelpDialog"
	dialog.title = "How to play"
	dialog.dialog_text = "Build roads first, then place buildings beside connected roads.\n\nTap a building to manage it. Drag production items into an empty queue slot. Use the bottom action bar for storage, city needs, trade, regions and saving."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_style_settings_dialog(dialog, Vector2i(640, 360))


func _show_change_city_name() -> void:
	if not PlayerAccountManager.is_authenticated():
		var login_dialog := ConfirmationDialog.new()
		login_dialog.name = "CityNameLoginRequiredDialog"
		login_dialog.title = "Sign in required"
		login_dialog.dialog_text = "Sign in with Google before changing your city name. Your city profile will be saved to your private player JSON file."
		login_dialog.ok_button_text = "Continue with Google"
		login_dialog.confirmed.connect(_on_settings_account_action_pressed)
		login_dialog.canceled.connect(login_dialog.queue_free)
		add_child(login_dialog)
		_style_settings_dialog(login_dialog, Vector2i(520, 220))
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ChangeCityNameDialog"
	dialog.title = "Change City Name"
	dialog.ok_button_text = "Save city name"
	var input := LineEdit.new()
	input.name = "CityNameInput"
	input.text = GameManager.city_name
	input.max_length = 28
	input.placeholder_text = "Enter your city name"
	input.custom_minimum_size.x = 360 * _ui_scale
	dialog.add_child(input)
	dialog.confirmed.connect(func() -> void:
		var previous_name := GameManager.city_name
		if not GameManager.set_city_name(input.text):
			status_label.text = "Enter a city name with at least one visible character."
			dialog.queue_free()
			return
		SaveManager.save_game()
		var saved_state: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.get_active_save_path()))
		var synced := false
		if saved_state is Dictionary:
			synced = await PlayerAccountManager.save_profile_now(saved_state)
		if synced:
			status_label.text = "City name updated and securely saved to your player profile."
		else:
			GameManager.city_name = previous_name
			SaveManager.save_game()
			status_label.text = "Could not sync your city name. Please check your connection and try again."
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	_style_settings_dialog(dialog, Vector2i(520, 220))
	input.grab_focus()


func _apply_notification_preference(key: String, enabled: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if key == "building_alerts":
		var alert_layer := scene.get_node_or_null("HUD/BuildingNotificationLayer")
		if is_instance_valid(alert_layer) and alert_layer.has_method("set_building_alerts_enabled"):
			alert_layer.set_building_alerts_enabled(enabled)
	elif key == "city_updates":
		var citizen_feedback := scene.get_node_or_null("CitizenFeedback")
		if is_instance_valid(citizen_feedback) and citizen_feedback.has_method("set_city_updates_enabled"):
			citizen_feedback.set_city_updates_enabled(enabled)

func _show_notification_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://notification_preferences.cfg")
	var dialog := AcceptDialog.new()
	dialog.name = "NotificationSettingsDialog"
	dialog.title = "Notification Settings"
	var content := VBoxContainer.new()
	content.name = "NotificationSettingsContent"
	content.add_theme_constant_override("separation", 12)
	dialog.add_child(content)
	for preference in [{"key":"building_alerts","node_name":"BuildingAlertsToggle","label":"Building and production alerts"},{"key":"city_updates","node_name":"CityUpdatesToggle","label":"City progress updates"}]:
		var toggle := CheckButton.new()
		toggle.name = str(preference.node_name)
		toggle.text = str(preference.label)
		toggle.button_pressed = bool(config.get_value("notifications", str(preference.key), true))
		toggle.toggled.connect(func(value: bool) -> void:
			var key := str(preference.key)
			config.set_value("notifications", key, value)
			var save_error := config.save("user://notification_preferences.cfg")
			if save_error == OK:
				_apply_notification_preference(key, value)
			else:
				push_warning("Could not save notification preference '%s': %s" % [key, error_string(save_error)])
		)
		content.add_child(toggle)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	_style_settings_dialog(dialog, Vector2i(560, 260))


func _show_wallet_panel() -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "SettingsWalletDialog"
	dialog.title = "City Wallet"
	dialog.dialog_text = "Simoleons: %s\nSimCash: %s\nGolden Keys: %s\n\nReal-money purchases and bank gateway are not enabled yet." % [ _format_compact_number(EconomyManager.simoleons), _format_compact_number(EconomyManager.sim_cash), _format_compact_number(EconomyManager.golden_keys)]
	var top_up := Button.new()
	top_up.name = "WalletTopUpDisabled"
	top_up.text = "Add funds — coming soon"
	top_up.disabled = true
	top_up.custom_minimum_size = Vector2(300, 48) * _ui_scale
	dialog.add_child(top_up)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	_style_settings_dialog(dialog, Vector2i(560, 320))


func _format_compact_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


func _add_audio_setting_toggle(parent: GridContainer, node_name: String, label_text: String, initial_value: bool, setter: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = label_text
	toggle.button_pressed = initial_value
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_font_size_override("font_size", _popup_font_size(17))
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
	label.add_theme_font_size_override("font_size", _popup_font_size(18))
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
	var render_metrics: Dictionary = report.get("render_metrics", {})
	var draw_calls: Dictionary = render_metrics.get("draw_calls", {})
	var average_draw_calls := float(draw_calls.get("average", 0.0))
	var p95_draw_calls := float(draw_calls.get("p95", 0.0))
	var report_path := str(report.get("report_path", "save failed"))
	status_label.text = "Device benchmark: %.1f avg FPS · frame p95 %.1f ms · draw calls %.0f avg / %.0f p95 · 60 FPS: %s · %s" % [average_fps, p95_frame_ms, average_draw_calls, p95_draw_calls, target_result, report_path]

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
		title.add_theme_font_size_override("font_size", _popup_font_size(18))
		title.add_theme_color_override("font_color", Color("#A87522") if bool(region.get("active", false)) else Color("#24485B"))
		details.add_child(title)
		var climate := Label.new()
		climate.text = "%s climate  ·  Mayor Level %d+" % [str(region.get("climate", "temperate")).capitalize(), int(region.get("unlock_level", 1))]
		climate.add_theme_font_size_override("font_size", _popup_font_size(14))
		details.add_child(climate)
		var population := Label.new()
		population.text = "Saved regional population: %s" % str(int(region.get("population", 0)))
		population.add_theme_font_size_override("font_size", _popup_font_size(14))
		population.add_theme_color_override("font_color", Color("#526D7D"))
		details.add_child(population)
		if str(region.get("id", "")) != "capital":
			var regional_content := Label.new()
			regional_content.text = "Regional resource: %s  ·  Building: %s" % [str(region.get("signature_material", "—")), str(region.get("signature_building", "—"))]
			regional_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			regional_content.add_theme_font_size_override("font_size", _popup_font_size(13))
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
	summary.add_theme_font_size_override("font_size", _popup_font_size(18))
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
		title.add_theme_font_size_override("font_size", _popup_font_size(17))
		title.add_theme_color_override("font_color", Color("#A87522") if bool(entry.get("unlocked", false)) else Color("#24485B"))
		header.add_child(title)
		var state := Label.new()
		state.text = "UNLOCKED" if bool(entry.get("unlocked", false)) else "%d / %d" % [int(entry.get("progress", 0)), int(entry.get("target", 1))]
		state.add_theme_font_size_override("font_size", _popup_font_size(14))
		state.add_theme_color_override("font_color", Color("#34734D") if bool(entry.get("unlocked", false)) else Color("#607989"))
		header.add_child(state)
		var description := Label.new()
		description.text = str(entry.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", _popup_font_size(14))
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
		reward.add_theme_font_size_override("font_size", _popup_font_size(13))
		reward.add_theme_color_override("font_color", Color("#8A672B"))
		content.add_child(reward)

func _close_achievements_panel() -> void:
	if is_instance_valid(achievements_overlay):
		achievements_overlay.queue_free()
	achievements_overlay = null

func _on_save_pressed() -> void:
	status_label.text = "City saved successfully." if SaveManager.save_game() else "Could not save the city."
