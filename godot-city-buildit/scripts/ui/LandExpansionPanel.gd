extends Control

var selected_tile := Vector2i(999, 999)
var requirement_label: Label
var confirm_button: Button
var selection_label: Label
var tile_grid: GridContainer
var status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 180
	hide()

func open_panel() -> void:
	selected_tile = Vector2i(999, 999)
	_rebuild_panel()
	show()

func _rebuild_panel() -> void:
	for child in get_children():
		child.queue_free()
	var shade := ColorRect.new()
	shade.name = "LandExpansionBackdrop"
	shade.color = Color(0.015, 0.025, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "LandExpansionDialog"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142C3A")
	style.border_color = Color("#E5B95C")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "CITY LAND EXPANSION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#F6D58A"))
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(42, 38)
	close.pressed.connect(hide)
	header.add_child(close)

	var hint := Label.new()
	hint.text = "Choose a plot connected to your current city limits. Each plot has its own equipment cost."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#E2EDF2"))
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "ExpansionPlotScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	tile_grid = GridContainer.new()
	tile_grid.columns = 4
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid.add_theme_constant_override("h_separation", 8)
	tile_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(tile_grid)

	for tile in LandExpansionManager.get_available_expansion_tiles():
		var cost: Dictionary = LandExpansionManager.get_tile_cost(tile)
		var plot := Button.new()
		plot.name = "ExpansionPlot_%d_%d" % [tile.x, tile.y]
		plot.custom_minimum_size = Vector2(145, 76)
		plot.text = "PLOT %d, %d\nW %d · B %d · E %d" % [tile.x, tile.y, int(cost["dozer_wheel"]), int(cost["dozer_blade"]), int(cost["dozer_exhaust"])]
		plot.tooltip_text = "Select this adjacent plot to inspect its expansion requirements."
		plot.pressed.connect(_select_tile.bind(tile))
		tile_grid.add_child(plot)

	selection_label = Label.new()
	selection_label.name = "ExpansionSelection"
	selection_label.text = "Select a highlighted adjacent plot."
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	layout.add_child(selection_label)
	requirement_label = Label.new()
	requirement_label.name = "ExpansionRequirements"
	requirement_label.text = "Mayor Level 10 is required. Expansion parts are available through Global Trade."
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement_label.add_theme_color_override("font_color", Color("#F4DFAF"))
	layout.add_child(requirement_label)
	status_label = Label.new()
	status_label.name = "ExpansionStatus"
	status_label.text = "Owned plots: %d" % LandExpansionManager.get_owned_tile_count()
	status_label.add_theme_color_override("font_color", Color("#A9D6E8"))
	layout.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmLandExpansion"
	confirm_button.text = "CONFIRM EXPANSION"
	confirm_button.custom_minimum_size = Vector2(0, 48)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_confirm_expansion)
	layout.add_child(confirm_button)

func _select_tile(tile: Vector2i) -> void:
	selected_tile = tile
	var cost: Dictionary = LandExpansionManager.get_tile_cost(tile)
	selection_label.text = "Selected plot (%d, %d)" % [tile.x, tile.y]
	requirement_label.text = "Required: %d Dozer Wheels · %d Dozer Blades · %d Dozer Exhausts\nIn storage: %d · %d · %d" % [
		int(cost["dozer_wheel"]), int(cost["dozer_blade"]), int(cost["dozer_exhaust"]),
		StorageManager.get_count("dozer_wheel"), StorageManager.get_count("dozer_blade"), StorageManager.get_count("dozer_exhaust")
	]
	var error := LandExpansionManager.get_tile_error(tile)
	if error.is_empty():
		status_label.text = "All requirements met. Confirm to claim this land."
	else:
		status_label.text = error
	confirm_button.disabled = not error.is_empty()

func _confirm_expansion() -> void:
	if selected_tile == Vector2i(999, 999):
		return
	var tile := selected_tile
	if not LandExpansionManager.expand_tile(tile):
		_select_tile(tile)
		return
	selected_tile = Vector2i(999, 999)
	_rebuild_panel()
	status_label.text = "Land claimed successfully. New building plots are now available."
