extends RefCounted
class_name ProductionCapacitySimulator

# Deterministic replay of the production component contract:
# - factory slots run independently and retain ready output until collection;
# - each commercial building runs one active order, with additional slots
#   acting as a FIFO queue;
# - commercial inputs are consumed atomically when an order is accepted;
# - collection is blocked by warehouse capacity and never discards output;
# - cash is generated only by an explicit cash_sale action (never by crafting).
static func simulate(config: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var horizon := maxi(0, int(config.get("horizon_seconds", 0)))
	var capacity := maxi(0, int(config.get("storage_capacity", 50)))
	var inventory: Dictionary = _positive_inventory(config.get("initial_inventory", {}), errors)
	var used := _inventory_used(inventory)
	if used > capacity:
		errors.append("Initial inventory exceeds warehouse capacity.")
	var raw_catalog: Dictionary = config.get("raw_materials", {})
	var recipes: Dictionary = config.get("crafted_items", {})
	var factory_materials: Dictionary = config.get("factory_materials", {})
	var facilities: Dictionary = {}
	for raw_facility in config.get("facilities", []):
		if not raw_facility is Dictionary:
			errors.append("Facility entry must be a Dictionary.")
			continue
		var facility: Dictionary = raw_facility.duplicate(true)
		var facility_id := str(facility.get("id", ""))
		var kind := str(facility.get("kind", ""))
		var slot_count := int(facility.get("slot_count", 0))
		if facility_id.is_empty() or facilities.has(facility_id):
			errors.append("Facility id is empty or duplicated: %s." % facility_id)
			continue
		if not ["factory", "store"].has(kind) or slot_count <= 0:
			errors.append("Facility %s has invalid kind or slot_count." % facility_id)
			continue
		facility["slots"] = []
		for _slot_index in range(slot_count):
			facility["slots"].append({})
		facility["operational"] = bool(facility.get("operational", true))
		facility["kind"] = kind
		facility["queue_limit"] = slot_count
		facilities[facility_id] = facility

	var actions: Array = config.get("actions", []).duplicate(true)
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("at_seconds", 0)) < int(b.get("at_seconds", 0))
	)
	var action_index := 0
	var rejected_actions := 0
	var consumed_inputs: Dictionary = {}
	var collected_outputs: Dictionary = {}
	var sale_events: Array[Dictionary] = []
	var production_log: Array[Dictionary] = []
	var sales_total := 0

	for second in range(horizon + 1):
		# Complete timers before player actions at this timestamp.
		for facility_id_variant in facilities.keys():
			var facility_id := str(facility_id_variant)
			var facility: Dictionary = facilities[facility_id]
			for slot_index in range(facility.slots.size()):
				var slot: Dictionary = facility.slots[slot_index]
				if slot.is_empty() or bool(slot.get("ready", false)):
					continue
				if int(slot.get("finish_seconds", 0)) <= second:
					slot["ready"] = true
					facility.slots[slot_index] = slot
					production_log.append({"at_seconds": second, "event": "ready", "facility_id": facility_id, "item_id": str(slot.get("item_id", "")), "slot_index": slot_index})
			facilities[facility_id] = facility

		# A store may start its next queued order as soon as its active order
		# becomes ready. Ready-but-uncollected products do not block its lane.
		for facility_id_variant in facilities.keys():
			var facility_id := str(facility_id_variant)
			var facility: Dictionary = facilities[facility_id]
			if str(facility.kind) == "store" and bool(facility.operational):
				_start_store_order(facility, facility_id, second, recipes, production_log)
			facilities[facility_id] = facility

		while action_index < actions.size() and int(actions[action_index].get("at_seconds", 0)) <= second:
			var action: Dictionary = actions[action_index]
			action_index += 1
			var action_time := int(action.get("at_seconds", 0))
			var facility_id := str(action.get("facility_id", ""))
			var action_type := str(action.get("type", ""))
			var item_id := str(action.get("item_id", ""))
			var quantity := int(action.get("quantity", 1))
			var success := false
			if action_time < 0 or action_time > horizon or quantity <= 0:
				errors.append("Invalid action timestamp or quantity at index %d." % (action_index - 1))
			elif action_type == "collect":
				if facilities.has(facility_id):
					var facility: Dictionary = facilities[facility_id]
					var slot_index := int(action.get("slot_index", -1))
					if slot_index >= 0 and slot_index < facility.slots.size():
						var slot: Dictionary = facility.slots[slot_index]
						if not slot.is_empty() and bool(slot.get("ready", false)) and _inventory_used(inventory) + 1 <= capacity:
							inventory[item_id if item_id != "" else str(slot.get("item_id", ""))] = int(inventory.get(item_id if item_id != "" else str(slot.get("item_id", "")), 0)) + 1
							var collected_id := item_id if item_id != "" else str(slot.get("item_id", ""))
							collected_outputs[collected_id] = int(collected_outputs.get(collected_id, 0)) + 1
							facility.slots[slot_index] = {}
							success = true
							production_log.append({"at_seconds": second, "event": "collected", "facility_id": facility_id, "item_id": collected_id, "slot_index": slot_index})
							if str(facility.kind) == "store":
								_start_store_order(facility, facility_id, second, recipes, production_log)
							facilities[facility_id] = facility
			elif action_type == "start_factory":
				if facilities.has(facility_id):
					var facility: Dictionary = facilities[facility_id]
					var allowed: Array = factory_materials.get(str(facility.get("factory_type", "")), [])
					if bool(facility.operational) and str(facility.kind) == "factory" and raw_catalog.has(item_id) and allowed.has(item_id):
						var slot_index := _first_empty_slot(facility.slots)
						if slot_index >= 0:
							var duration := maxi(1, int(raw_catalog[item_id].get("time_sec", raw_catalog[item_id].get("time", 0))))
							facility.slots[slot_index] = {"item_id": item_id, "start_seconds": second, "finish_seconds": second + duration, "ready": false, "queued": false}
							success = true
							production_log.append({"at_seconds": second, "event": "started", "facility_id": facility_id, "item_id": item_id, "slot_index": slot_index, "finish_seconds": second + duration})
					facilities[facility_id] = facility
			elif action_type == "enqueue_store":
				if facilities.has(facility_id):
					var facility: Dictionary = facilities[facility_id]
					var recipe: Dictionary = recipes.get(item_id, {})
					var inputs: Dictionary = recipe.get("requires", {})
					var slot_index := _first_empty_slot(facility.slots)
					if bool(facility.operational) and str(facility.kind) == "store" and str(recipe.get("store", "")) == str(facility.get("shop_id", "")) and not inputs.is_empty() and slot_index >= 0 and _has_inventory(inventory, inputs):
						# Match ProductionComponent.start_craft: reserve the entire
						# recipe at queue admission, not when its timer begins.
						_remove_inventory(inventory, inputs)
						for input_id in inputs:
							consumed_inputs[str(input_id)] = int(consumed_inputs.get(str(input_id), 0)) + int(inputs[input_id])
						facility.slots[slot_index] = {"item_id": item_id, "start_seconds": 0, "finish_seconds": 0, "ready": false, "queued": true}
						success = true
						production_log.append({"at_seconds": second, "event": "queued", "facility_id": facility_id, "item_id": item_id, "slot_index": slot_index, "inputs_consumed": inputs.duplicate(true)})
						_start_store_order(facility, facility_id, second, recipes, production_log)
					facilities[facility_id] = facility
			elif action_type == "cash_sale":
				var unit_value := int(action.get("unit_value", 0))
				if inventory.has(item_id) and int(inventory[item_id]) >= quantity and unit_value > 0:
					_remove_inventory(inventory, {item_id: quantity})
					var proceeds := unit_value * quantity
					sales_total += proceeds
					sale_events.append({"at_seconds": second, "type": "production_sale", "item_id": item_id, "quantity": quantity, "amount": proceeds})
					success = true
					production_log.append({"at_seconds": second, "event": "cash_sale", "item_id": item_id, "quantity": quantity, "proceeds": proceeds})
			else:
				errors.append("Unsupported production action: %s." % action_type)
			if not success:
				rejected_actions += 1
				production_log.append({"at_seconds": second, "event": "rejected", "action_type": action_type, "facility_id": facility_id, "item_id": item_id})

	var pending_jobs: Array[Dictionary] = []
	var ready_jobs: Array[Dictionary] = []
	var facility_summary: Array[Dictionary] = []
	for facility_id_variant in facilities.keys():
		var facility_id := str(facility_id_variant)
		var facility: Dictionary = facilities[facility_id]
		var busy := 0
		var queued := 0
		for slot_index in range(facility.slots.size()):
			var slot: Dictionary = facility.slots[slot_index]
			if slot.is_empty():
				continue
			var snapshot := {"facility_id": facility_id, "slot_index": slot_index, "item_id": str(slot.get("item_id", "")), "ready": bool(slot.get("ready", false)), "queued": bool(slot.get("queued", false)), "finish_seconds": int(slot.get("finish_seconds", 0))}
			if bool(slot.get("ready", false)):
				ready_jobs.append(snapshot)
			else:
				pending_jobs.append(snapshot)
			if bool(slot.get("queued", false)):
				queued += 1
			else:
				busy += 1
		facility_summary.append({"facility_id": facility_id, "kind": str(facility.kind), "slot_count": facility.slots.size(), "occupied_slots": busy + queued, "active_or_ready_slots": busy, "queued_slots": queued})
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"horizon_seconds": horizon,
		"storage_capacity": capacity,
		"ending_inventory": inventory,
		"ending_storage_used": _inventory_used(inventory),
		"ending_storage_free": maxi(0, capacity - _inventory_used(inventory)),
		"consumed_inputs": consumed_inputs,
		"collected_outputs": collected_outputs,
		"pending_jobs": pending_jobs,
		"ready_uncollected_jobs": ready_jobs,
		"facility_summary": facility_summary,
		"rejected_actions": rejected_actions,
		"sales_total": sales_total,
		"cash_events": sale_events,
		"production_log": production_log
	}

static func _start_store_order(facility: Dictionary, facility_id: String, now: int, recipes: Dictionary, log: Array) -> void:
	if not bool(facility.get("operational", true)) or str(facility.get("kind", "")) != "store":
		return
	for slot in facility.slots:
		if not slot.is_empty() and not bool(slot.get("ready", false)) and int(slot.get("finish_seconds", 0)) > 0:
			return
	for slot_index in range(facility.slots.size()):
		var slot: Dictionary = facility.slots[slot_index]
		if slot.is_empty() or bool(slot.get("ready", false)) or int(slot.get("finish_seconds", 0)) > 0:
			continue
		var recipe: Dictionary = recipes.get(str(slot.get("item_id", "")), {})
		var duration := maxi(1, int(recipe.get("time_sec", recipe.get("time", 0))))
		slot["start_seconds"] = now
		slot["finish_seconds"] = now + duration
		slot["queued"] = false
		facility.slots[slot_index] = slot
		log.append({"at_seconds": now, "event": "started", "facility_id": facility_id, "item_id": str(slot.get("item_id", "")), "slot_index": slot_index, "finish_seconds": now + duration})
		return

static func _first_empty_slot(slots: Array) -> int:
	for index in range(slots.size()):
		if slots[index].is_empty():
			return index
	return -1

static func _positive_inventory(source: Variant, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if not source is Dictionary:
		errors.append("initial_inventory must be a Dictionary.")
		return result
	for item_variant in source.keys():
		var item_id := str(item_variant)
		var amount := int(source[item_variant])
		if item_id.is_empty() or amount < 0:
			errors.append("Invalid initial inventory entry: %s." % item_id)
		elif amount > 0:
			result[item_id] = amount
	return result

static func _inventory_used(inventory: Dictionary) -> int:
	var total := 0
	for amount in inventory.values():
		total += maxi(0, int(amount))
	return total

static func _has_inventory(inventory: Dictionary, requirements: Dictionary) -> bool:
	for item_id in requirements:
		if int(requirements[item_id]) <= 0 or int(inventory.get(str(item_id), 0)) < int(requirements[item_id]):
			return false
	return true

static func _remove_inventory(inventory: Dictionary, requirements: Dictionary) -> void:
	for item_id in requirements:
		var key := str(item_id)
		var remaining := int(inventory.get(key, 0)) - int(requirements[item_id])
		if remaining <= 0:
			inventory.erase(key)
		else:
			inventory[key] = remaining
