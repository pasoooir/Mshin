extends Node

signal storage_changed
signal capacity_changed(new_capacity: int)

const DEFAULT_CAPACITY: int = 50
const STORAGE_ITEM_IDS: Array[String] = ["storage_bar", "storage_lock", "storage_camera"]
const STORAGE_ITEM_SIMCASH_PRICE := 18
const STORAGE_UNLOCK_LEVEL := 4
const STORAGE_UPGRADE_GAIN := 5
const STORAGE_MAX_CAPACITY := 1000
var capacity: int = DEFAULT_CAPACITY
var items: Dictionary = {}

# Display metadata is registered by ProductionManager from its authoritative catalog.
var item_definitions: Dictionary = {}
var storage_upgrades_completed: int = 0

func _ready() -> void:
	register_item_definition("storage_bar", "Storage Bar", "special")
	register_item_definition("storage_lock", "Storage Lock", "special")
	register_item_definition("storage_camera", "Storage Camera", "special")


# Backwards-compatible aliases used by existing HUD, trade and save code.
var max_capacity: int:
	get: return capacity
	set(value): capacity = maxi(1, value)
var inventory: Dictionary:
	get: return items
	set(value): items = value
var current_used: int:
	get: return get_used()
	set(_value): pass

func register_item_definition(item_id: String, item_name: String, item_type: String) -> void:
	if item_id.is_empty() or item_name.is_empty():
		return
	item_definitions[item_id] = {"name":item_name,"type":item_type}

func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func get_item_count(item_id: String) -> int:
	return get_count(item_id)

func get_used() -> int:
	var total := 0
	for value in items.values():
		total += maxi(0, int(value))
	return total

func get_used_slots() -> int:
	return get_used()

func get_free() -> int:
	return maxi(0, capacity - get_used())

func get_free_space() -> int:
	return get_free()

func has_space(amount: int = 1) -> bool:
	return amount > 0 and get_free() >= amount

func can_add(_item_id: String, amount: int = 1) -> bool:
	return has_space(amount)

func add_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or not can_add(item_id, amount):
		return false
	items[item_id] = get_count(item_id) + amount
	storage_changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	var remaining := get_count(item_id) - amount
	if remaining == 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining
	storage_changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return amount >= 0 and get_count(item_id) >= amount

func has_items(requirements: Dictionary) -> bool:
	for item_id in requirements:
		var amount := int(requirements[item_id])
		if str(item_id).is_empty() or amount <= 0 or get_count(str(item_id)) < amount:
			return false
	return true

func remove_items(requirements: Dictionary) -> bool:
	# Validate the complete transaction before mutating any inventory row.
	if requirements.is_empty() or not has_items(requirements):
		return false
	for item_id in requirements:
		var amount := int(requirements[item_id])
		var remaining := get_count(str(item_id)) - amount
		if remaining <= 0:
			items.erase(str(item_id))
		else:
			items[str(item_id)] = remaining
	storage_changed.emit()
	return true

func add_items(additions: Dictionary) -> bool:
	if additions.is_empty():
		return false
	var total_to_add := 0
	for item_id in additions:
		var amount := int(additions[item_id])
		if str(item_id).is_empty() or amount <= 0:
			return false
		total_to_add += amount
	if get_free() < total_to_add:
		return false
	for item_id in additions:
		items[str(item_id)] = get_count(str(item_id)) + int(additions[item_id])
	storage_changed.emit()
	return true

# Community-reported City Storage thresholds, keyed by current capacity.
# Each upgrade consumes this many of EACH of Bar, Lock and Camera.
# EA confirms equal quantities and +5 capacity, but does not publish this table.
const STORAGE_ITEM_REQUIREMENT_THRESHOLDS: Array[int] = [
	40, 55, 70, 85, 105, 125, 145, 165, 185, 205,
	230, 255, 280, 305, 330, 355, 380, 405, 430, 455,
	495, 520, 545, 570, 585
]

func get_next_storage_upgrade_requirement() -> int:
	var required := 1
	for index in range(1, STORAGE_ITEM_REQUIREMENT_THRESHOLDS.size()):
		if capacity < STORAGE_ITEM_REQUIREMENT_THRESHOLDS[index]:
			break
		required = index + 1
	return mini(required, 25)

func can_upgrade_storage_with_items() -> bool:
	if GameManager.level < STORAGE_UNLOCK_LEVEL or capacity >= STORAGE_MAX_CAPACITY:
		return false
	var required := get_next_storage_upgrade_requirement()
	for item_id in STORAGE_ITEM_IDS:
		if get_count(item_id) < required:
			return false
	return true

func upgrade_storage_with_items() -> Dictionary:
	if GameManager.level < STORAGE_UNLOCK_LEVEL:
		return {"success": false, "reason": "storage_upgrade_locked", "unlock_level": STORAGE_UNLOCK_LEVEL}
	if capacity >= STORAGE_MAX_CAPACITY:
		return {"success": false, "reason": "storage_capacity_maximum"}
	var required := get_next_storage_upgrade_requirement()
	var inventory_before := get_all_items()
	var requirements: Dictionary = {}
	for item_id in STORAGE_ITEM_IDS:
		requirements[item_id] = required
	if not has_items(requirements):
		return {"success": false, "reason": "missing_storage_special_items", "required_each": required, "items": requirements}
	if not remove_items(requirements):
		return {"success": false, "reason": "storage_item_transaction_failed"}
	capacity = mini(STORAGE_MAX_CAPACITY, capacity + STORAGE_UPGRADE_GAIN)
	storage_upgrades_completed += 1
	EconomyManager.record_transaction("storage_capacity_upgrade", "items", required * STORAGE_ITEM_IDS.size(), EconomyManager.simoleons, EconomyManager.simoleons, inventory_before, get_all_items(), {"source": "city_storage", "required_each": required, "capacity_before": capacity - STORAGE_UPGRADE_GAIN, "capacity_after": capacity})
	capacity_changed.emit(capacity)
	storage_changed.emit()
	return {"success": true, "capacity": capacity, "items_consumed_each": required}

func upgrade_capacity(extra: int = 10) -> void:
	# Administrative/test helper only. Gameplay uses upgrade_storage_with_items().
	if extra <= 0:
		return
	capacity = mini(STORAGE_MAX_CAPACITY, capacity + extra)
	capacity_changed.emit(capacity)
	storage_changed.emit()

func try_upgrade_capacity(cost_money: int, gain: int = 10) -> bool:
	# Retained only for compatibility; the old currency-only bypass is disabled.
	return false

func get_storage_ratio() -> String:
	return "%d/%d" % [get_used(), capacity]

func get_all_items() -> Dictionary:
	return items.duplicate(true)

func to_save_dict() -> Dictionary:
	return {"capacity": capacity, "items": items.duplicate(true), "storage_upgrades_completed": storage_upgrades_completed}

func from_save_dict(data: Dictionary) -> void:
	capacity = maxi(1, int(data.get("capacity", data.get("max_capacity", DEFAULT_CAPACITY))))
	items = data.get("items", data.get("inventory", {})).duplicate(true)
	storage_upgrades_completed = maxi(0, int(data.get("storage_upgrades_completed", 0)))
	# Discard malformed/negative entries and clamp legacy saves to the capacity.
	for item_id in items.keys():
		var count := int(items[item_id])
		if count <= 0:
			items.erase(item_id)
	var overflow := get_used() - capacity
	if overflow > 0:
		for item_id in items.keys():
			var remove_count := mini(overflow, int(items[item_id]))
			items[item_id] = int(items[item_id]) - remove_count
			overflow -= remove_count
			if int(items[item_id]) <= 0:
				items.erase(item_id)
			if overflow <= 0:
				break
	storage_changed.emit()
	capacity_changed.emit(capacity)
