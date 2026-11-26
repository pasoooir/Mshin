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
# FIFO acquisition-cost batches per item. Legacy inventory without batch history is explicitly unknown.
var item_cost_batches: Dictionary = {}
var _items: Dictionary = {}
var items: Dictionary:
	get:
		return _items
	set(value):
		# Replacing the whole inventory (legacy callers/tests) cannot retain stale costs.
		_items = value.duplicate(true)
		item_cost_batches.clear()
		for item_id in _items:
			var quantity := maxi(0, int(_items[item_id]))
			if quantity > 0:
				item_cost_batches[str(item_id)] = [{"quantity": quantity, "total_cost": 0, "known": false}]

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
	return add_item_with_cost(item_id, amount, 0, false)

func add_item_with_cost(item_id: String, amount: int, total_cost: int, cost_known: bool) -> bool:
	if item_id.is_empty() or amount <= 0 or total_cost < 0 or not can_add(item_id, amount):
		return false
	items[item_id] = get_count(item_id) + amount
	_append_cost_batch(item_id, amount, total_cost if cost_known else 0, cost_known)
	storage_changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	_consume_cost_batches({item_id: amount})
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
	_consume_cost_batches(requirements)
	for item_id in requirements:
		var amount := int(requirements[item_id])
		var remaining := get_count(str(item_id)) - amount
		if remaining <= 0:
			items.erase(str(item_id))
		else:
			items[str(item_id)] = remaining
	storage_changed.emit()
	return true

func remove_items_with_cost_batches(requirements: Dictionary) -> Dictionary:
	if requirements.is_empty() or not has_items(requirements):
		return {"success": false, "reason": "insufficient_inventory"}
	var normalized: Dictionary = {}
	for item_variant in requirements.keys():
		var item_id := str(item_variant)
		var amount := int(requirements[item_variant])
		if item_id.is_empty() or amount <= 0:
			return {"success": false, "reason": "invalid_requirements"}
		normalized[item_id] = amount
		_ensure_cost_batches_for_item(item_id)
	# Work on a copy so a malformed batch cannot partially consume inventory.
	var working_batches: Dictionary = item_cost_batches.duplicate(true)
	var removed_batches: Dictionary = {}
	for item_id in normalized:
		var remaining := int(normalized[item_id])
		var source: Array = working_batches.get(item_id, [])
		var retained: Array[Dictionary] = []
		var removed: Array[Dictionary] = []
		for batch_variant in source:
			if not batch_variant is Dictionary:
				return {"success": false, "reason": "invalid_cost_batch"}
			var batch: Dictionary = batch_variant.duplicate(true)
			var batch_quantity := maxi(0, int(batch.get("quantity", 0)))
			if batch_quantity <= 0:
				continue
			if remaining <= 0:
				retained.append(batch)
				continue
			var take := mini(remaining, batch_quantity)
			var batch_total := maxi(0, int(batch.get("total_cost", 0)))
			var cost_part := roundi(float(batch_total) * float(take) / float(batch_quantity))
			removed.append({
				"quantity": take,
				"total_cost": cost_part,
				"known": bool(batch.get("known", false))
			})
			remaining -= take
			var left := batch_quantity - take
			if left > 0:
				batch["quantity"] = left
				batch["total_cost"] = batch_total - cost_part
				retained.append(batch)
		if remaining > 0:
			return {"success": false, "reason": "cost_batch_quantity_mismatch"}
		working_batches[item_id] = retained
		removed_batches[item_id] = removed
	item_cost_batches = working_batches
	for item_id in normalized:
		var left := get_count(item_id) - int(normalized[item_id])
		if left <= 0:
			items.erase(item_id)
		else:
			items[item_id] = left
	storage_changed.emit()
	return {"success": true, "cost_batches": removed_batches}


func restore_items_with_cost_batches(additions: Dictionary, cost_batches: Dictionary) -> bool:
	if additions.is_empty() or cost_batches.is_empty():
		return false
	var total_to_add := 0
	var normalized_batches: Dictionary = {}
	for item_variant in additions.keys():
		var item_id := str(item_variant)
		var amount := int(additions[item_variant])
		if item_id.is_empty() or amount <= 0:
			return false
		var raw_batches: Variant = cost_batches.get(item_id, null)
		if not raw_batches is Array or raw_batches.is_empty():
			return false
		var batches: Array[Dictionary] = []
		var batch_quantity_total := 0
		for batch_variant in raw_batches:
			if not batch_variant is Dictionary:
				return false
			var batch: Dictionary = batch_variant
			var quantity := int(batch.get("quantity", 0))
			var total_cost := int(batch.get("total_cost", 0))
			if quantity <= 0 or total_cost < 0:
				return false
			batches.append({
				"quantity": quantity,
				"total_cost": total_cost,
				"known": bool(batch.get("known", false))
			})
			batch_quantity_total += quantity
		if batch_quantity_total != amount:
			return false
		normalized_batches[item_id] = batches
		total_to_add += amount
	if normalized_batches.size() != additions.size() or get_free() < total_to_add:
		return false
	for item_id in additions:
		var key := str(item_id)
		items[key] = get_count(key) + int(additions[item_id])
		var existing: Array = item_cost_batches.get(key, []).duplicate(true)
		for batch in normalized_batches[key]:
			existing.append(batch.duplicate(true))
		item_cost_batches[key] = existing
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
		_append_cost_batch(str(item_id), int(additions[item_id]), 0, false)
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



func fill_catalog_inventory_for_testing(raw_catalog: Dictionary, crafted_catalog: Dictionary, extra_catalog: Dictionary = {}, amount: int = 1000) -> Dictionary:
	# Explicit test-only grant: replace every known production item quantity while
	# preserving special storage expansion items. This deliberately expands the
	# warehouse beyond normal gameplay limits so the player can test all upgrade
	# tiers without spending time producing or selling materials.
	if amount <= 0:
		return {"success": false, "reason": "invalid_amount"}
	var test_inventory: Dictionary = {}
	for item_variant in raw_catalog.keys():
		var item_id := str(item_variant)
		if not item_id.is_empty():
			test_inventory[item_id] = amount
	for item_variant in crafted_catalog.keys():
		var item_id := str(item_variant)
		if not item_id.is_empty():
			test_inventory[item_id] = amount
	for store_variant in extra_catalog.keys():
		var products: Variant = extra_catalog[store_variant]
		if products is Array:
			for product_variant in products:
				if product_variant is Dictionary:
					var item_id := str(product_variant.get("id", ""))
					if not item_id.is_empty():
						test_inventory[item_id] = amount
	for special_item_id in STORAGE_ITEM_IDS:
		var existing_special_count := get_count(special_item_id)
		if existing_special_count > 0:
			test_inventory[special_item_id] = existing_special_count
	if test_inventory.is_empty():
		return {"success": false, "reason": "empty_catalog"}
	items = test_inventory
	var required_capacity := get_used()
	if capacity < required_capacity:
		capacity = required_capacity
	capacity_changed.emit(capacity)
	storage_changed.emit()
	return {"success": true, "item_types": test_inventory.size(), "quantity_each": amount, "total_items": get_used(), "capacity": capacity}

func get_cost_basis(requirements: Dictionary) -> Dictionary:
	if requirements.is_empty() or not has_items(requirements):
		return {"known": false, "total_cost": 0, "reason": "insufficient_inventory"}
	for item_variant in requirements.keys():
		_ensure_cost_batches_for_item(str(item_variant))
	var working: Dictionary = item_cost_batches.duplicate(true)
	return _consume_cost_batches_from(working, requirements)

func _append_cost_batch(item_id: String, quantity: int, total_cost: int, known: bool) -> void:
	if item_id.is_empty() or quantity <= 0:
		return
	var batches: Array = item_cost_batches.get(item_id, [])
	batches.append({"quantity": quantity, "total_cost": total_cost if known else 0, "known": known})
	item_cost_batches[item_id] = batches

func _ensure_cost_batches_for_item(item_id: String) -> void:
	var quantity := get_count(item_id)
	var raw_batches: Variant = item_cost_batches.get(item_id, [])
	var batches: Array = raw_batches.duplicate(true) if raw_batches is Array else []
	var tracked := 0
	var sanitized: Array[Dictionary] = []
	for batch_variant in batches:
		if not batch_variant is Dictionary:
			continue
		var batch: Dictionary = batch_variant
		var batch_quantity := maxi(0, int(batch.get("quantity", 0)))
		if batch_quantity <= 0:
			continue
		batch["quantity"] = batch_quantity
		batch["total_cost"] = maxi(0, int(batch.get("total_cost", 0)))
		batch["known"] = bool(batch.get("known", false))
		sanitized.append(batch)
		tracked += batch_quantity
	batches = sanitized
	if tracked < quantity:
		batches.append({"quantity": quantity - tracked, "total_cost": 0, "known": false})
	elif tracked > quantity:
		var overflow := tracked - quantity
		for index in range(batches.size() - 1, -1, -1):
			if overflow <= 0:
				break
			var batch: Dictionary = batches[index]
			var remove_count := mini(overflow, int(batch.get("quantity", 0)))
			batch["quantity"] = int(batch.get("quantity", 0)) - remove_count
			if int(batch["quantity"]) <= 0:
				batches.remove_at(index)
			else:
				var original_quantity := int(batch.get("quantity", 0)) + remove_count
				var old_total := int(batch.get("total_cost", 0))
				batch["total_cost"] = old_total - roundi(float(old_total) * float(remove_count) / float(maxi(1, original_quantity)))
				batches[index] = batch
			overflow -= remove_count
	item_cost_batches[item_id] = batches

func _consume_cost_batches(requirements: Dictionary) -> Dictionary:
	for item_variant in requirements.keys():
		_ensure_cost_batches_for_item(str(item_variant))
	return _consume_cost_batches_from(item_cost_batches, requirements)

func _consume_cost_batches_from(source: Dictionary, requirements: Dictionary) -> Dictionary:
	var total_cost := 0
	var all_known := true
	for item_variant in requirements.keys():
		var item_id := str(item_variant)
		var remaining := int(requirements[item_variant])
		var raw_batches: Variant = source.get(item_id, [])
		var batches: Array = raw_batches.duplicate(true) if raw_batches is Array else []
		var rebuilt: Array[Dictionary] = []
		for batch_variant in batches:
			if not batch_variant is Dictionary:
				all_known = false
				continue
			var batch: Dictionary = batch_variant.duplicate(true)
			if remaining <= 0:
				rebuilt.append(batch)
				continue
			var batch_quantity := maxi(0, int(batch.get("quantity", 0)))
			var take := mini(remaining, batch_quantity)
			if take <= 0:
				continue
			var batch_total := maxi(0, int(batch.get("total_cost", 0)))
			var cost_part := roundi(float(batch_total) * float(take) / float(maxi(1, batch_quantity)))
			if bool(batch.get("known", false)):
				total_cost += cost_part
			else:
				all_known = false
			remaining -= take
			var left := batch_quantity - take
			if left > 0:
				batch["quantity"] = left
				batch["total_cost"] = batch_total - cost_part
				rebuilt.append(batch)
		if remaining > 0:
			all_known = false
		source[item_id] = rebuilt
	return {"known": all_known, "total_cost": total_cost if all_known else 0}

func get_all_items() -> Dictionary:
	return items.duplicate(true)

func to_save_dict() -> Dictionary:
	return {"capacity": capacity, "items": items.duplicate(true), "item_cost_batches": item_cost_batches.duplicate(true), "storage_upgrades_completed": storage_upgrades_completed}

func from_save_dict(data: Dictionary) -> void:
	capacity = maxi(1, int(data.get("capacity", data.get("max_capacity", DEFAULT_CAPACITY))))
	items = data.get("items", data.get("inventory", {})).duplicate(true)
	var saved_cost_batches: Variant = data.get("item_cost_batches", {})
	item_cost_batches = saved_cost_batches.duplicate(true) if saved_cost_batches is Dictionary else {}
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
	for item_id_variant in item_cost_batches.keys():
		if not items.has(str(item_id_variant)):
			item_cost_batches.erase(item_id_variant)
	for item_id_variant in items.keys():
		_ensure_cost_batches_for_item(str(item_id_variant))
	storage_changed.emit()
	capacity_changed.emit(capacity)
