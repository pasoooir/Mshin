extends Control

const Icons = preload("res://scripts/ui/Icons.gd")

var selected_tile := Vector2i(999, 999)
var requirement_label: Label
var confirm_button: Button
var selection_label: Label
var tile_grid: GridContainer
var status_label: Label
var requirements_row: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 180
	hide()

func open_panel() -> void:
	selected_tile = Vector2i(999, 999)
	_rebuild_panel()
	show()
	_set_world_expansion_preview(true)

func _set_world_expansion_preview(active: bool) -> void:
	var world := get_tree().root.get_node_or_null("Main/World/WorldPresentation")
	if is_instance_valid(world) and world.has_method("set_expansion_preview_visible"):
		world.set_expansion_preview_visible(active)

func _close_panel() -> void:
	_set_world_expansion_preview(false)
	hide()

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
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	style.content_margin_top = 20
	style.content_margin_bottom = 20
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
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#17364A"))
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(58, 54)
	close.add_theme_font_size_override("font_size", 36)
	close.add_theme_color_override("font_color", Color("#17364A"))
	close.pressed.connect(_close_panel)
	header.add_child(close)

	var hint := Label.new()
	hint.text = "Owned plots are green, available plots are gold, and locked plots are shaded. Expand outward one connected plot at a time."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#405B6C"))
	hint.add_theme_font_size_override("font_size", 17)
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "ExpansionPlotScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	tile_grid = GridContainer.new()
	tile_grid.columns = 2
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid.add_theme_constant_override("h_separation", 8)
	tile_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(tile_grid)

	for tile in LandExpansionManager.get_available_expansion_tiles():
		var cost: Dictionary = LandExpansionManager.get_tile_cost(tile)
		var card := PanelContainer.new()
		card.name = "ExpansionPlotCard_%d_%d" % [tile.x, tile.y]
		card.custom_minimum_size = Vector2(250, 112)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#EAF1F4")
		card_style.border_color = Color("#C6D5DC")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", card_style)
		var card_layout := VBoxContainer.new()
		card_layout.add_theme_constant_override("separation", 5)
		card.add_child(card_layout)
		var plot := Button.new()
		plot.name = "ExpansionPlot_%d_%d" % [tile.x, tile.y]
		plot.custom_minimum_size.y = 42
		plot.add_theme_font_size_override("font_size", 15)
		plot.text = "PLOT %d · %d m² · RING %d" % [tile.x, LandExpansionManager.get_tile_area_square_meters(), LandExpansionManager.get_tile_distance(tile) + 1]
		plot.tooltip_text = "Adjacent plot · %d m² · equipment cost increases with distance from your starter city." % LandExpansionManager.get_tile_area_square_meters()
		plot.pressed.connect(_select_tile.bind(tile))
		card_layout.add_child(plot)
		var item_strip := HBoxContainer.new()
		item_strip.alignment = BoxContainer.ALIGNMENT_CENTER
		item_strip.add_theme_constant_override("separation", 12)
		card_layout.add_child(item_strip)
		for item_id in LandExpansionManager.EXPANSION_ITEM_IDS:
			var item_group := HBoxContainer.new()
			item_group.add_theme_constant_override("separation", 3)
			item_group.add_child(Icons.make_item_icon("special", str(item_id), Vector2(28, 28)))
			var amount := Label.new()
			amount.text = str(int(cost[item_id]))
			amount.add_theme_font_size_override("font_size", 15)
			amount.add_theme_color_override("font_color", Color("#17364A"))
			item_group.add_child(amount)
			item_strip.add_child(item_group)
		tile_grid.add_child(card)

	selection_label = Label.new()
	selection_label.name = "ExpansionSelection"
	selection_label.text = "Select a highlighted adjacent plot."
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.add_theme_color_override("font_color", Color("#17364A"))
	selection_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(selection_label)
	requirement_label = Label.new()
	requirement_label.name = "ExpansionRequirements"
	requirement_label.text = "Mayor Level 10 is required. Expansion parts are available through Global Trade."
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement_label.add_theme_color_override("font_color", Color("#526D7D"))
	requirement_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(requirement_label)
	requirements_row = HBoxContainer.new()
	requirements_row.name = "ExpansionItemInventory"
	requirements_row.add_theme_constant_override("separation", 14)
	layout.add_child(requirements_row)
	status_label = Label.new()
	status_label.name = "ExpansionStatus"
	status_label.text = "Owned plots: %d · %d m² of city land" % [LandExpansionManager.get_owned_tile_count(), LandExpansionManager.get_owned_tile_count() * LandExpansionManager.get_tile_area_square_meters()]
	status_label.add_theme_color_override("font_color", Color("#28799C"))
	status_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmLandExpansion"
	confirm_button.text = "CONFIRM EXPANSION"
	confirm_button.custom_minimum_size = Vector2(0, 58)
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_confirm_expansion)
	layout.add_child(confirm_button)

func _select_tile(tile: Vector2i) -> void:
	selected_tile = tile
	var cost: Dictionary = LandExpansionManager.get_tile_cost(tile)
	selection_label.text = "Selected plot (%d, %d) · %d m² · expansion ring %d" % [tile.x, tile.y, LandExpansionManager.get_tile_area_square_meters(), LandExpansionManager.get_tile_distance(tile) + 1]
	requirement_label.text = "Expansion equipment · required / in storage"
	for child in requirements_row.get_children():
		child.queue_free()
	for item_id in LandExpansionManager.EXPANSION_ITEM_IDS:
		var item_group := VBoxContainer.new()
		item_group.add_theme_constant_override("separation", 2)
		item_group.add_child(Icons.make_item_icon("special", str(item_id), Vector2(42, 42)))
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.text = "%d / %d" % [StorageManager.get_count(str(item_id)), int(cost[item_id])]
		count.add_theme_font_size_override("font_size", 14)
		count.add_theme_color_override("font_color", Color("#17364A"))
		item_group.add_child(count)
		requirements_row.add_child(item_group)
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
