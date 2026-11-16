extends Control
## World-space notification manager. It derives durable alerts from the real
## building, production-slot and warehouse state; no duplicate notification
## save data is required because production slots/upgrades are already saved.
const AnchorScript = preload("res://scripts/ui/BuildingNotificationAnchor.gd")
const NotificationScript = preload("res://scripts/ui/BuildingNotification.gd")

const REFRESH_INTERVAL := 0.35
const MAX_VISIBLE_PER_BUILDING := 2

var _refresh_elapsed := 0.0
var _anchors: Dictionary = {}
var _hud: Node
var _connected_components: Dictionary = {}

func _ready() -> void:
	name = "BuildingNotificationLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not StorageManager.storage_changed.is_connected(refresh_now):
		StorageManager.storage_changed.connect(refresh_now)
	_sync_notifications()

func configure(hud: Node) -> void:
	_hud = hud

func refresh_now() -> void:
	_sync_notifications()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		_sync_notifications()

func _sync_notifications() -> void:
	var wanted: Dictionary = {}
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building) or str(building.status) != "completed":
			continue
		var building_id := str(building.building_id)
		var notifications := _build_notifications(building)
		if not notifications.is_empty():
			wanted[building_id] = {"building": building, "notifications": notifications}
			var component = building.production_component
			if is_instance_valid(component) and not _connected_components.has(component.get_instance_id()):
				if component.has_signal("slots_changed"):
					component.slots_changed.connect(refresh_now)
				_connected_components[component.get_instance_id()] = weakref(component)

	for building_id in _anchors.keys():
		if not wanted.has(building_id):
			var old_anchor = _anchors[building_id]
			if is_instance_valid(old_anchor):
				old_anchor.queue_free()
			_anchors.erase(building_id)

	for building_id in wanted:
		var data: Dictionary = wanted[building_id]
		var building: Node3D = data.building
		var anchor: Node3D = _anchors.get(building_id)
		if not is_instance_valid(anchor):
			anchor = AnchorScript.new()
			anchor.name = "BuildingNotificationAnchor"
			building.add_child(anchor)
			anchor.set_anchor_position(_get_roof_anchor_local(building))
			anchor.notification_pressed.connect(_on_notification_pressed)
			_anchors[building_id] = anchor
		else:
			anchor.set_anchor_position(_get_roof_anchor_local(building))
		anchor.set_notifications(data.notifications)

	_prune_component_connections()

func _build_notifications(building: Node3D) -> Array[BuildingNotification]:
	var result: Array[BuildingNotification] = []
	var building_id := str(building.get("building_id"))
	var component = building.get("production_component")
	var ready_groups: Dictionary = {}
	var has_queued_work := false
	if is_instance_valid(component):
		component.refresh_slots()
		ready_groups = get_ready_product_groups(component)
		for index in range(component.get_slot_count()):
			var slot: Dictionary = component.get_slot(index)
			if not slot.is_empty():
				has_queued_work = true
		for item_variant in ready_groups.keys():
			var item_id := str(item_variant)
			var slot_indices: Array = ready_groups[item_variant]
			result.append(NotificationScript.make(
				building_id,
				NotificationScript.Type.PRODUCTION_READY,
				item_id,
				slot_indices.size(),
				"Ready to collect"
			))
		if not ready_groups.is_empty() and StorageManager.get_free() <= 0:
			result.append(NotificationScript.make(
				building_id,
				NotificationScript.Type.STORAGE_FULL,
				"", 1, "City Storage is full. Free space before collecting."
			))

	if bool(building.get("upgrade_ready")):
		result.append(NotificationScript.make(
			building_id,
			NotificationScript.Type.UPGRADE_READY,
			"", 1, "Upgrade is ready"
		))

	if is_instance_valid(component) and ready_groups.is_empty() and not has_queued_work:
		var missing := _find_missing_store_materials(component) if not bool(component.is_factory) else {}
		if not missing.is_empty():
			var product_id := str(missing.get("item_id", ""))
			result.append(NotificationScript.make(
				building_id,
				NotificationScript.Type.NEEDS_MATERIALS,
				product_id,
				1,
				str(missing.get("detail", "Required materials are missing"))
			))
		elif BuildManager.is_building_operational(building):
			result.append(NotificationScript.make(
				building_id,
				NotificationScript.Type.IDLE,
				"", 1, "No active production"
			))

	result.sort_custom(func(a: BuildingNotification, b: BuildingNotification) -> bool:
		return a.priority > b.priority
	)
	if result.size() > MAX_VISIBLE_PER_BUILDING:
		result.resize(MAX_VISIBLE_PER_BUILDING)
	return result

func _find_missing_store_materials(component: Node) -> Dictionary:
	if not is_instance_valid(component) or bool(component.is_factory):
		return {}
	var recipe_ids: Array = ProductionManager.crafted_items.keys()
	recipe_ids.sort()
	for recipe_variant in recipe_ids:
		var recipe_id := str(recipe_variant)
		var recipe := ProductionManager.get_recipe(recipe_id)
		if recipe.is_empty() or str(recipe.get("store", "")) != str(component.shop_id):
			continue
		if int(recipe.get("level", 1)) > GameManager.level:
			continue
		if not ProductionManager.get_recipe_lock_reason(recipe_id, int(component.store_star_level)).is_empty():
			continue
		if not ProductionManager.are_recipe_inputs_unlocked(recipe):
			continue
		var inputs: Dictionary = recipe.get("inputs", {})
		var missing: Array[String] = []
		for item_variant in inputs.keys():
			var item_id := str(item_variant)
			var required := int(inputs[item_variant])
			var available := StorageManager.get_count(item_id)
			if available < required:
				missing.append("%s %d/%d" % [str(ProductionManager.get_item_definition(item_id).get("name", item_id)), available, required])
		if not missing.is_empty():
			return {
				"item_id": recipe_id,
				"detail": "Needs materials for %s: %s" % [
					str(ProductionManager.get_item_definition(recipe_id).get("name", recipe_id)),
					", ".join(missing)
				]
			}
	return {}

func _on_notification_pressed(notification: BuildingNotification) -> void:
	if notification == null:
		return
	match notification.type:
		NotificationScript.Type.PRODUCTION_READY:
			_collect_product(notification.building_id, notification.item_id)
		NotificationScript.Type.UPGRADE_READY:
			_open_upgrade(notification.building_id)
		NotificationScript.Type.STORAGE_FULL:
			_set_status("City Storage is full. Free warehouse space; ready products remain safely on their buildings.")
		NotificationScript.Type.NEEDS_MATERIALS:
			_set_status(notification.detail)
		NotificationScript.Type.IDLE:
			_set_status("This building is idle. Choose a product to start production.")

func _collect_product(building_id: String, item_id: String) -> void:
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

func _open_upgrade(building_id: String) -> void:
	var building = BuildManager.buildings.get(building_id)
	if not is_instance_valid(building) or not bool(building.upgrade_ready) or not is_instance_valid(_hud):
		return
	if str(building.definition.get("category", "")) == "residential" and _hud.has_method("open_residential_panel"):
		_hud.call("open_residential_panel", building)
	elif _hud.has_method("open_building_upgrade_panel"):
		_hud.call("open_building_upgrade_panel", building)

func _set_status(message: String) -> void:
	if is_instance_valid(_hud) and is_instance_valid(_hud.get("status_label")):
		_hud.status_label.text = message

func _prune_component_connections() -> void:
	for instance_id in _connected_components.keys():
		var reference: WeakRef = _connected_components[instance_id]
		var component = reference.get_ref()
		if not is_instance_valid(component):
			_connected_components.erase(instance_id)

func _get_roof_anchor_local(building: Node3D) -> Vector3:
	var roof_y := 5.5 + float(building.get("upgrade_stage")) * 0.35
	var mesh_root := building.get_node_or_null("MeshRoot")
	if is_instance_valid(mesh_root):
		for node in mesh_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			var local_top := building.to_local(world_bounds.end).y
			roof_y = maxf(roof_y, local_top)
	return Vector3(0.0, roof_y + 1.15, 0.0)

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
