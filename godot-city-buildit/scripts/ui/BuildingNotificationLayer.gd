extends Control
## Persistent, tappable world-anchored notifications for actions that need the
## player's attention. CitizenFeedbackBubbles remains a separate, transient
## hint system; this layer is reserved for durable building state.
const Icons = preload("res://scripts/ui/Icons.gd")

const REFRESH_INTERVAL := 0.35
const PRODUCT_BUTTON_SIZE := Vector2(82.0, 76.0)
const BUTTON_GAP := 8.0

var _refresh_elapsed := 0.0
var _entries: Dictionary = {}
var _hud: Node

func _ready() -> void:
	name = "BuildingNotificationLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(hud: Node) -> void:
	_hud = hud

func refresh_now() -> void:
	_sync_notifications()
	_update_positions()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		_sync_notifications()
	_update_positions()

func _sync_notifications() -> void:
	var wanted: Dictionary = {}
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or str(building.status) != "completed":
			continue
		var building_id := str(building.building_id)
		var component = building.production_component
		if is_instance_valid(component):
			component.refresh_slots()
			var groups := get_ready_product_groups(component)
			for item_id in groups:
				var key := _entry_key(building_id, "product", str(item_id))
				wanted[key] = {"building": building, "kind": "product", "item_id": str(item_id), "slots": groups[item_id]}
		if bool(building.upgrade_ready):
			var upgrade_key := _entry_key(building_id, "upgrade", "")
			wanted[upgrade_key] = {"building": building, "kind": "upgrade", "item_id": "", "slots": []}

	for key in _entries.keys():
		if not wanted.has(key):
			var old_button: Control = _entries[key].get("button")
			if is_instance_valid(old_button):
				old_button.queue_free()
			_entries.erase(key)

	for key in wanted:
		var data: Dictionary = wanted[key]
		if not _entries.has(key) or not is_instance_valid(_entries[key].get("button")):
			var button := _create_button(data)
			add_child(button)
			_entries[key] = {"button": button}
		var entry: Dictionary = _entries[key]
		entry["building"] = data.building
		entry["kind"] = data.kind
		entry["item_id"] = data.item_id
		entry["slots"] = data.slots
		_entries[key] = entry
		var button: Button = entry.button
		if str(data.kind) == "product":
			var can_store := StorageManager.can_add(str(data.item_id), 1)
			button.tooltip_text = "Tap to collect %s" % _item_name(str(data.item_id))
			if not can_store:
				button.tooltip_text = "Storage full — free space, then tap to collect"
				button.modulate = Color(1.0, 0.72, 0.68, 1.0)
			else:
				button.modulate = Color.WHITE
			var count_label := button.get_node_or_null("Count")
			if count_label is Label:
				count_label.text = "×%d" % data.slots.size()
		else:
			button.tooltip_text = "Tap to view upgrade requirements"

func _create_button(data: Dictionary) -> Button:
	var button := Button.new()
	button.name = "ReadyProduct_" + str(data.building.building_id) if str(data.kind) == "product" else "ReadyUpgrade_" + str(data.building.building_id)
	button.custom_minimum_size = PRODUCT_BUTTON_SIZE
	button.size = PRODUCT_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 40
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF7D8") if str(data.kind) == "product" else Color("#FFF0BE")
	style.border_color = Color("#E3B83E")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.02, 0.08, 0.12, 0.38)
	style.shadow_size = 9
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#FFFFFF")
	button.add_theme_stylebox_override("hover", hover)
	var icon := Icons.make_item_icon("raw" if data.building.production_component.is_factory else "crafted", str(data.item_id), Vector2(52, 52)) if str(data.kind) == "product" else Icons.make_icon("hard_hat", Vector2(52, 52))
	icon.name = "NotificationIcon"
	icon.size = Vector2(52, 52)
	icon.position = Vector2(15, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	if str(data.kind) == "product":
		var count := Label.new()
		count.name = "Count"
		count.text = "×1"
		count.position = Vector2(42, 2)
		count.size = Vector2(36, 25)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 17)
		count.add_theme_color_override("font_color", Color("#3C2C0B"))
		count.add_theme_color_override("font_shadow_color", Color("#FFFFFF"))
		count.add_theme_constant_override("shadow_offset_x", 1)
		count.add_theme_constant_override("shadow_offset_y", 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
	if str(data.kind) == "product":
		button.pressed.connect(_on_product_pressed.bind(str(data.building.building_id), str(data.item_id)))
	else:
		button.pressed.connect(_on_upgrade_pressed.bind(str(data.building.building_id)))
	return button

func _update_positions() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		for entry in _entries.values():
			var button: Control = entry.get("button")
			if is_instance_valid(button):
				button.hide()
		return
	var grouped: Dictionary = {}
	for entry in _entries.values():
		var building = entry.get("building")
		var button: Control = entry.get("button")
		if not is_instance_valid(building) or not is_instance_valid(button):
			continue
		var building_id := str(building.building_id)
		if not grouped.has(building_id):
			grouped[building_id] = []
		var list: Array = grouped[building_id]
		list.append(entry)
		grouped[building_id] = list
	var viewport_size := get_viewport().get_visible_rect().size
	for building_id in grouped:
		var entries: Array = grouped[building_id]
		var building = entries[0].get("building")
		var anchor := _get_roof_anchor(building)
		if camera.is_position_behind(anchor):
			for entry in entries:
				entry.button.hide()
			continue
		var screen := camera.unproject_position(anchor)
		var columns := mini(4, entries.size())
		var rows := int(ceil(float(entries.size()) / 4.0))
		var total_width := columns * PRODUCT_BUTTON_SIZE.x + maxf(0, columns - 1) * BUTTON_GAP
		var start_x := screen.x - total_width * 0.5
		for index in range(entries.size()):
			var button: Control = entries[index].button
			var column := index % 4
			var row := int(index / 4)
			var x := clampf(start_x + column * (PRODUCT_BUTTON_SIZE.x + BUTTON_GAP), 6.0, maxf(6.0, viewport_size.x - PRODUCT_BUTTON_SIZE.x - 6.0))
			var y := clampf(screen.y - PRODUCT_BUTTON_SIZE.y - 8.0 - float(rows - row - 1) * (PRODUCT_BUTTON_SIZE.y + BUTTON_GAP), 6.0, maxf(6.0, viewport_size.y - PRODUCT_BUTTON_SIZE.y - 6.0))
			button.position = Vector2(x, y)
			button.size = PRODUCT_BUTTON_SIZE
			button.show()

func _get_roof_anchor(building: Node3D) -> Vector3:
	var roof_y := building.global_position.y + 5.5 + float(building.get("upgrade_stage")) * 0.35
	var mesh_root := building.get_node_or_null("MeshRoot")
	if is_instance_valid(mesh_root):
		for node in mesh_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			roof_y = maxf(roof_y, bounds.end.y)
	return Vector3(building.global_position.x, roof_y + 1.15, building.global_position.z)

func _on_product_pressed(building_id: String, item_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or not is_instance_valid(building.production_component):
		return
	var component = building.production_component
	var collected := 0
	var blocked := false
	for slot_index in range(component.get_slot_count()):
		var slot: Dictionary = component.get_slot(slot_index)
		if slot.is_empty() or not bool(slot.get("ready", false)) or str(slot.get("item_id", "")) != item_id:
			continue
		if component.collect(slot_index):
			collected += 1
		else:
			blocked = true
			break
	if is_instance_valid(_hud) and _hud.has_method("_on_building_notification_collected"):
		_hud.call("_on_building_notification_collected", building_id, item_id, collected, blocked)
	_sync_notifications()

func _on_upgrade_pressed(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or not bool(building.upgrade_ready) or not is_instance_valid(_hud):
		return
	if str(building.definition.get("category", "")) == "residential" and _hud.has_method("open_residential_panel"):
		_hud.call("open_residential_panel", building)
	elif _hud.has_method("open_building_upgrade_panel"):
		_hud.call("open_building_upgrade_panel", building)

func _item_name(item_id: String) -> String:
	return str(ProductionManager.get_item_definition(item_id).get("name", item_id.capitalize()))

func _entry_key(building_id: String, kind: String, item_id: String) -> String:
	return "%s|%s|%s" % [building_id, kind, item_id]

static func get_ready_product_groups(component: Node) -> Dictionary:
	var groups: Dictionary = {}
	if not is_instance_valid(component):
		return groups
	for slot_index in range(component.get_slot_count()):
		var slot: Dictionary = component.get_slot(slot_index)
		if slot.is_empty() or not bool(slot.get("ready", false)):
			continue
		var item_id := str(slot.get("item_id", ""))
		if item_id.is_empty():
			continue
		if not groups.has(item_id):
			groups[item_id] = []
		var slots: Array = groups[item_id]
		slots.append(slot_index)
		groups[item_id] = slots
	return groups
