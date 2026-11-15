extends Node

signal storage_changed
signal capacity_changed(new_capacity: int)

const DEFAULT_CAPACITY: int = 50
var capacity: int = DEFAULT_CAPACITY
var items: Dictionary = {}
# Reservations keep materials visible in inventory but unavailable to competing orders.
var reservations: Dictionary = {}

# Display metadata is registered by ProductionManager from its authoritative catalog.
var item_definitions: Dictionary = {}


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

func get_reserved_count(item_id: String) -> int:
	var total := 0
	for requirements in reservations.values():
		if requirements is Dictionary:
			total += maxi(0, int(requirements.get(item_id, 0)))
	return total

func get_available_count(item_id: String) -> int:
	return maxi(0, get_count(item_id) - get_reserved_count(item_id))

func get_reserved_items() -> Dictionary:
	var result: Dictionary = {}
	for requirements in reservations.values():
		if not requirements is Dictionary:
			continue
		for item_id in requirements:
			result[str(item_id)] = int(result.get(str(item_id), 0)) + maxi(0, int(requirements[item_id]))
	return result

func reserve_items(reservation_id: String, requirements: Dictionary) -> bool:
	if reservation_id.is_empty() or reservations.has(reservation_id) or requirements.is_empty() or not has_items(requirements):
		return false
	var normalized: Dictionary = {}
	for item_id in requirements:
		var amount := int(requirements[item_id])
		if str(item_id).is_empty() or amount <= 0:
			return false
		normalized[str(item_id)] = amount
	reservations[reservation_id] = normalized
	storage_changed.emit()
	return true

func consume_reservation(reservation_id: String) -> bool:
	if not reservations.has(reservation_id):
		return false
	var requirements: Dictionary = reservations[reservation_id]
	for item_id in requirements:
		if get_count(str(item_id)) < int(requirements[item_id]):
			return false
	for item_id in requirements:
		var key := str(item_id)
		var remaining := get_count(key) - int(requirements[item_id])
		if remaining <= 0:
			items.erase(key)
		else:
			items[key] = remaining
	reservations.erase(reservation_id)
	storage_changed.emit()
	return true

func release_reservation(reservation_id: String) -> bool:
	if not reservations.has(reservation_id):
		return false
	reservations.erase(reservation_id)
	storage_changed.emit()
	return true

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
	if amount <= 0 or get_available_count(item_id) < amount:
		return false
	var remaining := get_count(item_id) - amount
	if remaining == 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining
	storage_changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return amount >= 0 and get_available_count(item_id) >= amount

func has_items(requirements: Dictionary) -> bool:
	for item_id in requirements:
		var amount := int(requirements[item_id])
		if str(item_id).is_empty() or amount <= 0 or get_available_count(str(item_id)) < amount:
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

func upgrade_capacity(extra: int = 10) -> void:
	if extra <= 0:
		return
	capacity += extra
	capacity_changed.emit(capacity)
	storage_changed.emit()

func try_upgrade_capacity(cost_money: int, gain: int = 10) -> bool:
	if cost_money < 0 or gain <= 0 or EconomyManager.simoleons < cost_money:
		return false
	if not EconomyManager.spend_simoleons(cost_money):
		return false
	upgrade_capacity(gain)
	return true

func get_storage_ratio() -> String:
	return "%d/%d" % [get_used(), capacity]

func get_all_items() -> Dictionary:
	return items.duplicate(true)

func to_save_dict() -> Dictionary:
	return {"capacity": capacity, "items": items.duplicate(true), "reservations": reservations.duplicate(true)}

func from_save_dict(data: Dictionary) -> void:
	capacity = maxi(1, int(data.get("capacity", data.get("max_capacity", DEFAULT_CAPACITY))))
	items = data.get("items", data.get("inventory", {})).duplicate(true)
	reservations = {}
	var saved_reservations: Variant = data.get("reservations", {})
	if saved_reservations is Dictionary:
		for reservation_id in saved_reservations:
			var saved_requirements: Variant = saved_reservations[reservation_id]
			if str(reservation_id).is_empty() or not saved_requirements is Dictionary or saved_requirements.is_empty():
				continue
			var normalized: Dictionary = {}
			var valid := true
			for item_id in saved_requirements:
				var amount := int(saved_requirements[item_id])
				if str(item_id).is_empty() or amount <= 0:
					valid = false
					break
				normalized[str(item_id)] = amount
			if valid:
				reservations[str(reservation_id)] = normalized
	# Discard malformed/negative entries and clamp legacy saves to the capacity.
	for item_id in items.keys():
		var count := int(items[item_id])
		if count <= 0:
			items.erase(item_id)
	# Keep only reservations backed by real inventory. A corrupt or stale
	# reservation is dropped rather than making stock permanently unavailable.
	var reserved_totals := get_reserved_items()
	for item_id in reserved_totals:
		if int(reserved_totals[item_id]) > get_count(str(item_id)):
			reservations.clear()
			break
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
