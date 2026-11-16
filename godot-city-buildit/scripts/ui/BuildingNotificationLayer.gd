extends Control
## Persistent building-state notifications. Each entry is derived from the
## building's persisted production/upgrade state; no duplicate save state exists.
const Icons = preload("res://scripts/ui/Icons.gd")
const NotificationData = preload("res://scripts/ui/BuildingNotification.gd")
const NotificationVisualScript = preload("res://scripts/ui/NotificationVisual.gd")

const REFRESH_INTERVAL := 0.35
const PRODUCT_BUTTON_SIZE := Vector2(82.0, 76.0)
const BUTTON_GAP := 8.0
const MAX_NOTIFICATIONS_PER_BUILDING := 2

var _refresh_elapsed := 0.0
var _entries: Dictionary = {}
var _hud: Node

func _ready() -> void:
	name = "BuildingNotificationLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if StorageManager.has_signal("storage_changed") and not StorageManager.storage_changed.is_connected(_on_storage_changed):
		StorageManager.storage_changed.connect(_on_storage_changed)
	if StorageManager.has_signal("capacity_changed") and not StorageManager.capacity_changed.is_connected(_on_storage_changed):
		StorageManager.capacity_changed.connect(_on_storage_changed)

func _on_storage_changed(_unused = null) -> void:
	call_deferred("refresh_now")

func _on_production_slots_changed() -> void:
	call_deferred("refresh_now")

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
	var candidates: Dictionary = {}
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or str(building.status) != "completed":
			continue
		var building_id := str(building.building_id)
		var component = building.production_component
		if is_instance_valid(component):
			if component.has_signal("slots_changed") and not component.slots_changed.is_connected(_on_production_slots_changed):
				component.slots_changed.connect(_on_production_slots_changed)
			component.refresh_slots()
			var groups := get_ready_product_groups(component)
			for item_id in groups:
				var can_store := StorageManager.can_add(str(item_id), 1)
				var kind := "product" if can_store else "storage_full"
				var key := _entry_key(building_id, kind, str(item_id))
				candidates[key] = _make_entry(building, kind, str(item_id), groups[item_id])
			if groups.is_empty() and _component_has_no_orders(component) and BuildManager.is_building_operational(building):
				var missing := _find_missing_material_recipe(component)
				if not missing.is_empty():
					var key := _entry_key(building_id, "needs_materials", str(missing.item_id))
					candidates[key] = _make_entry(building, "needs_materials", str(missing.item_id), [], str(missing.get("missing_text", "")))
				else:
					var key := _entry_key(building_id, "idle", "")
					candidates[key] = _make_entry(building, "idle", "", [])
		if bool(building.upgrade_ready):
			var upgrade_key := _entry_key(building_id, "upgrade", "")
			candidates[upgrade_key] = _make_entry(building, "upgrade", "", [])

	var wanted := _limit_per_building(candidates, MAX_NOTIFICATIONS_PER_BUILDING)
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
		entry["missing_text"] = data.get("missing_text", "")
		_entries[key] = entry
		var button: Button = entry.button
		match str(data.kind):
			"product":
				button.tooltip_text = "Tap to collect %s" % _item_name(str(data.item_id))
				button.modulate = Color.WHITE
			"storage_full":
				button.tooltip_text = "Storage full — free space, then tap to collect"
				button.modulate = Color(1.0, 0.72, 0.68, 1.0)
			"upgrade":
				button.tooltip_text = "Tap to view upgrade requirements"
			"needs_materials":
				button.tooltip_text = str(data.get("missing_text", "Missing materials — tap to view requirements"))
			"idle":
				button.tooltip_text = "Building is idle — tap to open production"
		var count_label := button.get_node_or_null("Count")
		if count_label is Label:
			count_label.text = "×%d" % data.slots.size()

func _make_entry(building: Node, kind: String, item_id: String, slots: Array, missing_text: String = "") -> Dictionary:
	return {
		"building": building,
		"kind": kind,
		"item_id": item_id,
		"slots": slots.duplicate(),
		"missing_text": missing_text,
		"priority": get_notification_priority(kind)
	}

func _component_has_no_orders(component: Node) -> bool:
	for slot_index in range(component.get_slot_count()):
		if not component.get_slot(slot_index).is_empty():
			return false
	return true

func _find_missing_material_recipe(component: Node) -> Dictionary:
	if bool(component.is_factory):
		return {}
	for item_id_variant in ProductionManager.crafted_items.keys():
		var item_id := str(item_id_variant)
		var definition: Dictionary = ProductionManager.crafted_items[item_id]
		if str(definition.get("store", "")) != str(component.shop_id):
			continue
		if int(definition.get("level", 1)) > GameManager.level:
			continue
		if not ProductionManager.get_recipe_lock_reason(item_id, int(component.store_star_level)).is_empty():
			continue
		var recipe := ProductionManager.get_recipe(item_id)
		var inputs: Dictionary = recipe.get("inputs", recipe.get("requires", {}))
		if inputs.is_empty() or StorageManager.has_items(inputs):
			continue
		var missing_text := ProductionManager.get_missing_inputs_text(item_id)
		return {"item_id": item_id, "missing_text": missing_text}
	return {}

func _limit_per_building(candidates: Dictionary, maximum: int) -> Dictionary:
	var grouped: Dictionary = {}
	for key in candidates:
		var data: Dictionary = candidates[key]
		var building_id := str(data.building.building_id)
		if not grouped.has(building_id):
			grouped[building_id] = []
		var list: Array = grouped[building_id]
		list.append({"key": key, "priority": int(data.priority)})
		grouped[building_id] = list
	var selected: Dictionary = {}
	for building_id in grouped:
		var list: Array = grouped[building_id]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.priority) == int(b.priority):
				return str(a.key) < str(b.key)
			return int(a.priority) > int(b.priority)
		)
		for index in range(mini(maximum, list.size())):
			var key := str(list[index].key)
			selected[key] = candidates[key]
	return selected

static func get_notification_priority(kind: String) -> int:
	match kind:
		"product": return NotificationData.Type.PRODUCTION_READY
		"storage_full": return NotificationData.Type.STORAGE_FULL
		"upgrade": return NotificationData.Type.UPGRADE_READY
		"needs_materials": return NotificationData.Type.NEEDS_MATERIALS
		"idle": return NotificationData.Type.IDLE
	return 0

static func select_notification_kinds_by_priority(kinds: Array, maximum: int = 2) -> Array:
	var ordered := kinds.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return get_notification_priority(a) > get_notification_priority(b)
	)
	return ordered.slice(0, mini(maximum, ordered.size()))

func _create_button(data: Dictionary) -> Button:
	var kind := str(data.kind)
	var button := NotificationVisualScript.new() as Button
	button.name = "BuildingNotice_%s_%s" % [str(data.building.building_id), kind]
	button.custom_minimum_size = PRODUCT_BUTTON_SIZE
	button.size = PRODUCT_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 40
	var style := StyleBoxFlat.new()
	match kind:
		"storage_full": style.bg_color = Color("#FFE1DD")
		"upgrade": style.bg_color = Color("#FFF0BE")
		"needs_materials": style.bg_color = Color("#E7F0FF")
		"idle": style.bg_color = Color("#E8F4FF")
		_: style.bg_color = Color("#FFF7D8")
	style.border_color = Color("#E3B83E") if kind in ["product", "upgrade"] else Color("#7898B5")
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

	var icon: Control
	if kind in ["product", "storage_full"]:
		var component = data.building.production_component
		icon = Icons.make_item_icon("raw" if component.is_factory else "crafted", str(data.item_id), Vector2(52, 52))
	elif kind == "upgrade":
		icon = Icons.make_icon("hard_hat", Vector2(52, 52))
	else:
		var label := Label.new()
		label.text = "Zzz" if kind == "idle" else "!"
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color("#36516E"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon = label
	icon.name = "NotificationIcon"
	icon.size = Vector2(52, 52)
	icon.position = Vector2(15, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	if kind in ["product", "storage_full"]:
		var count := Label.new()
		count.name = "Count"
		count.text = "×%d" % data.slots.size()
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

	match kind:
		"product", "storage_full":
			button.pressed.connect(_on_product_pressed.bind(str(data.building.building_id), str(data.item_id)))
		"upgrade":
			button.pressed.connect(_on_upgrade_pressed.bind(str(data.building.building_id)))
		_:
			button.pressed.connect(_on_building_attention_pressed.bind(str(data.building.building_id)))
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
		var columns := mini(2, entries.size())
		var rows := int(ceil(float(entries.size()) / 2.0))
		var total_width := columns * PRODUCT_BUTTON_SIZE.x + maxf(0, columns - 1) * BUTTON_GAP
		var start_x := screen.x - total_width * 0.5
		for index in range(entries.size()):
			var button: Control = entries[index].button
			var column := index % 2
			var row := int(index / 2)
			var x := clampf(start_x + column * (PRODUCT_BUTTON_SIZE.x + BUTTON_GAP), 6.0, maxf(6.0, viewport_size.x - PRODUCT_BUTTON_SIZE.x - 6.0))
			var y := clampf(screen.y - PRODUCT_BUTTON_SIZE.y - 8.0 - float(rows - row - 1) * (PRODUCT_BUTTON_SIZE.y + BUTTON_GAP), 6.0, maxf(6.0, viewport_size.y - PRODUCT_BUTTON_SIZE.y - 6.0))
			button.size = PRODUCT_BUTTON_SIZE
			if button.has_method("set_anchor_position"):
				button.call("set_anchor_position", Vector2(x, y))
			else:
				button.position = Vector2(x, y)
			if button.has_method("set_lod_distance"):
				button.call("set_lod_distance", camera.global_position.distance_to(anchor))
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

func _on_building_attention_pressed(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or not is_instance_valid(_hud):
		return
	if is_instance_valid(building.production_component) and _hud.has_method("open_production_panel"):
		_hud.call("open_production_panel", building)

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
