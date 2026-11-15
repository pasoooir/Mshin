extends RefCounted
class_name ProductionCapacitySimulator

# Deterministic replay of the production component contract:
# - factory slots run independently and retain ready output until collection;
# - each commercial building runs one active order, with additional slots
#   acting as a slot-order queue;
# - commercial inputs are consumed atomically when an order is accepted;
# - collection is blocked by warehouse capacity and never discards output;
# - cash is generated only by explicit Trade Depot collection after its listing timer (never by crafting).
static func simulate(config: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var horizon := maxi(0, int(config.get("horizon_seconds", 0)))
	var capacity := maxi(0, int(config.get("storage_capacity", 50)))
	var inventory: Dictionary = _positive_inventory(config.get("initial_inventory", {}), errors)
	var cost_batches: Dictionary = _initialize_cost_batches(inventory, config.get("initial_unit_costs", {}), errors)
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
		var initial_slots: Array = facility.get("initial_slots", [])
		facility["slots"] = []
		for slot_index in range(slot_count):
			if slot_index < initial_slots.size() and initial_slots[slot_index] is Dictionary:
				facility["slots"].append(initial_slots[slot_index].duplicate(true))
			else:
				facility["slots"].append({})
		facility["duration_overrides"] = facility.get("duration_overrides", {}).duplicate(true)
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
	var depot_listings: Dictionary = config.get("initial_depot_listings", {}).duplicate(true)
	var production_log: Array[Dictionary] = []
	var sales_total := 0
	var accounting_revenue := 0
	var accounting_cogs := 0
	var accounting_gross_margin := 0
	var unknown_cost_sale_quantity := 0
	var accounting_sales: Array[Dictionary] = []

	for second in range(horizon + 1):
		# Complete timers before player actions at this timestamp.
		for facility_id_variant in facilities.keys():
			var facility_id := str(facility_id_variant)
			var facility: Dictionary = facilities[facility_id]
			for slot_index in range(facility.slots.size()):
				var slot: Dictionary = facility.slots[slot_index]
				if slot.is_empty() or bool(slot.get("ready", false)) or bool(slot.get("queued", false)):
					continue
				if int(slot.get("finish_seconds", 0)) > 0 and int(slot.get("finish_seconds", 0)) <= second:
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
						if quantity == 1 and not slot.is_empty() and bool(slot.get("ready", false)) and (item_id.is_empty() or item_id == str(slot.get("item_id", ""))) and _inventory_used(inventory) + 1 <= capacity:
							inventory[item_id if item_id != "" else str(slot.get("item_id", ""))] = int(inventory.get(item_id if item_id != "" else str(slot.get("item_id", "")), 0)) + 1
							var collected_id := item_id if item_id != "" else str(slot.get("item_id", ""))
							_append_cost_batch(cost_batches, collected_id, 1, int(slot.get("cost_total", 0)), bool(slot.get("cost_known", false)))
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
					if quantity == 1 and bool(facility.operational) and str(facility.kind) == "factory" and raw_catalog.has(item_id) and allowed.has(item_id) and int(raw_catalog[item_id].get("level", 1)) <= int(config.get("mayor_level", 1)):
						var slot_index := _first_empty_slot(facility.slots)
						if slot_index >= 0:
							var duration := maxi(1, int(raw_catalog[item_id].get("time_sec", raw_catalog[item_id].get("time", 0))))
							var factory_cost := roundi(float(duration) * maxf(0.0, float(facility.get("operating_cost_per_second", 0.0))))
							facility.slots[slot_index] = {"item_id": item_id, "start_seconds": second, "finish_seconds": second + duration, "ready": false, "queued": false, "cost_known": true, "cost_total": factory_cost}
							success = true
							production_log.append({"at_seconds": second, "event": "started", "facility_id": facility_id, "item_id": item_id, "slot_index": slot_index, "finish_seconds": second + duration})
					facilities[facility_id] = facility
			elif action_type == "enqueue_store":
				if facilities.has(facility_id):
					var facility: Dictionary = facilities[facility_id]
					var recipe: Dictionary = recipes.get(item_id, {})
					var inputs: Dictionary = recipe.get("requires", {})
					var slot_index := _first_empty_slot(facility.slots)
					if quantity == 1 and bool(facility.operational) and str(facility.kind) == "store" and str(recipe.get("store", "")) == str(facility.get("shop_id", "")) and _recipe_unlocked(item_id, recipe, facility, raw_catalog, recipes, config) and not inputs.is_empty() and slot_index >= 0 and _has_inventory(inventory, inputs):
						# Match ProductionComponent.start_craft: reserve the entire
						# recipe at queue admission, not when its timer begins.
						_remove_inventory(inventory, inputs)
						var input_cost: Dictionary = _consume_cost_batches(cost_batches, inputs)
						for input_id in inputs:
							consumed_inputs[str(input_id)] = int(consumed_inputs.get(str(input_id), 0)) + int(inputs[input_id])
						facility.slots[slot_index] = {"item_id": item_id, "start_seconds": 0, "finish_seconds": 0, "ready": false, "queued": true, "cost_known": bool(input_cost.get("known", false)), "cost_total": int(input_cost.get("total_cost", 0))}
						success = true
						production_log.append({"at_seconds": second, "event": "queued", "facility_id": facility_id, "item_id": item_id, "slot_index": slot_index, "inputs_consumed": inputs.duplicate(true)})
						_start_store_order(facility, facility_id, second, recipes, production_log)
					facilities[facility_id] = facility
			elif action_type == "receive_inventory":
				var unit_cost := int(action.get("unit_cost", -1))
				var cost_known := bool(action.get("cost_known", true))
				if quantity > 0 and (raw_catalog.has(item_id) or recipes.has(item_id)) and unit_cost >= 0 and _inventory_used(inventory) + quantity <= capacity:
					inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
					_append_cost_batch(cost_batches, item_id, quantity, unit_cost, cost_known)
					success = true
					production_log.append({"at_seconds": second, "event": "inventory_received", "item_id": item_id, "quantity": quantity, "unit_cost": unit_cost, "cost_known": cost_known})
			elif action_type == "depot_list":
				var listing_id := str(action.get("listing_id", ""))
				var unit_value := int(action.get("unit_value", config.get("item_values", {}).get(item_id, 0)))
				if listing_id.is_empty():
					listing_id = "depot-listing-%d" % (action_index - 1)
				if bool(config.get("depot_operational", false)) and depot_listings.size() < 4 and not depot_listings.has(listing_id) and inventory.has(item_id) and int(inventory[item_id]) >= quantity and unit_value > 0:
					_remove_inventory(inventory, {item_id: quantity})
					var listing_cost: Dictionary = _consume_cost_batches(cost_batches, {item_id: quantity})
					depot_listings[listing_id] = {"item_id": item_id, "quantity": quantity, "unit_value": unit_value, "listed_at_seconds": second, "cost_known": bool(listing_cost.get("known", false)), "cost_total": int(listing_cost.get("total_cost", 0))}
					success = true
					production_log.append({"at_seconds": second, "event": "depot_listed", "listing_id": listing_id, "item_id": item_id, "quantity": quantity, "ready_at_seconds": second + 120})
			elif action_type == "depot_collect":
				var listing_id := str(action.get("listing_id", ""))
				if depot_listings.has(listing_id):
					var listing: Dictionary = depot_listings[listing_id]
					if quantity == 1 and bool(config.get("depot_operational", false)) and second - int(listing.get("listed_at_seconds", second)) >= 120:
						var proceeds := int(listing.get("unit_value", 0)) * int(listing.get("quantity", 0))
						if proceeds > 0:
							sales_total += proceeds
							accounting_revenue += proceeds
							var sold_quantity := int(listing.get("quantity", 0))
							var cost_known := bool(listing.get("cost_known", false))
							var cost_total := int(listing.get("cost_total", 0))
							if cost_known:
								accounting_cogs += cost_total
								accounting_gross_margin += proceeds - cost_total
							else:
								unknown_cost_sale_quantity += sold_quantity
							accounting_sales.append({"at_seconds": second, "listing_id": listing_id, "item_id": str(listing.get("item_id", "")), "quantity": sold_quantity, "revenue": proceeds, "cost_known": cost_known, "cost_basis": cost_total if cost_known else null, "gross_margin": proceeds - cost_total if cost_known else null})
							sale_events.append({"at_seconds": second, "type": "production_sale", "item_id": str(listing.get("item_id", "")), "quantity": sold_quantity, "amount": proceeds, "listing_id": listing_id, "cost_known": cost_known, "cost_basis": cost_total if cost_known else -1})
							depot_listings.erase(listing_id)
							success = true
							production_log.append({"at_seconds": second, "event": "depot_sale_collected", "listing_id": listing_id, "proceeds": proceeds})
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
		"accounting": {"gross_revenue": accounting_revenue, "known_cogs": accounting_cogs, "known_gross_margin": accounting_gross_margin, "unknown_cost_sale_quantity": unknown_cost_sale_quantity, "gross_margin_complete": unknown_cost_sale_quantity == 0, "sales": accounting_sales},
		"cost_batches": cost_batches,
		"active_depot_listings": depot_listings,
		"cash_events": sale_events,
		"production_log": production_log
	}


static func _recipe_unlocked(item_id: String, recipe: Dictionary, facility: Dictionary, raw_catalog: Dictionary, recipes: Dictionary, config: Dictionary) -> bool:
	var mayor_level := int(config.get("mayor_level", 1))
	if item_id in config.get("invalid_recipe_ids", []):
		return false
	if not bool(recipe.get("unlock_level_verified", true)) or int(recipe.get("level", 1)) > mayor_level:
		return false
	if int(recipe.get("required_stars", 0)) > int(facility.get("store_star_level", 0)):
		return false
	var source_text := str(recipe.get("source", "")).to_lower()
	if source_text.contains("conflict") or source_text.contains("variant") or source_text.contains("verify"):
		return false
	for input_variant in recipe.get("requires", {}).keys():
		var input_id := str(input_variant)
		if raw_catalog.has(input_id) and int(raw_catalog[input_id].get("level", 1)) > mayor_level:
			return false
		if recipes.has(input_id):
			var input_recipe: Dictionary = recipes[input_id]
			if not bool(input_recipe.get("unlock_level_verified", true)) or int(input_recipe.get("level", 1)) > mayor_level:
				return false
	return true

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
		var duration := maxi(1, int(facility.get("duration_overrides", {}).get(str(slot.get("item_id", "")), recipe.get("time_sec", recipe.get("time", 0)))))
		if not bool(slot.get("operating_cost_applied", false)):
			slot["cost_total"] = int(slot.get("cost_total", 0)) + roundi(float(duration) * maxf(0.0, float(facility.get("operating_cost_per_second", 0.0))))
			slot["operating_cost_applied"] = true
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


static func _initialize_cost_batches(inventory: Dictionary, unit_costs: Variant, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if not unit_costs is Dictionary:
		errors.append("initial_unit_costs must be a Dictionary.")
		unit_costs = {}
	for item_id_variant in inventory.keys():
		var item_id := str(item_id_variant)
		var quantity := int(inventory[item_id_variant])
		var entry: Variant = unit_costs.get(item_id, null)
		var known := entry != null
		var unit_cost := 0
		if entry is Dictionary:
			known = bool(entry.get("known", true))
			unit_cost = int(entry.get("unit_cost", 0))
		elif entry != null:
			unit_cost = int(entry)
		if unit_cost < 0:
			errors.append("Negative initial unit cost for %s." % item_id)
			known = false
			unit_cost = 0
		result[item_id] = [{"quantity": quantity, "unit_cost": unit_cost, "known": known}]
	return result

static func _append_cost_batch(cost_batches: Dictionary, item_id: String, quantity: int, unit_cost: int, known: bool) -> void:
	if item_id.is_empty() or quantity <= 0:
		return
	var batches: Array = cost_batches.get(item_id, [])
	batches.append({"quantity": quantity, "unit_cost": maxi(0, unit_cost), "known": known})
	cost_batches[item_id] = batches

static func _consume_cost_batches(cost_batches: Dictionary, requirements: Dictionary) -> Dictionary:
	var total_cost := 0
	var all_known := true
	var consumed: Dictionary = {}
	for item_variant in requirements.keys():
		var item_id := str(item_variant)
		var remaining := int(requirements[item_variant])
		var batches: Array = cost_batches.get(item_id, []).duplicate(true)
		var rebuilt: Array[Dictionary] = []
		for batch_variant in batches:
			if remaining <= 0:
				rebuilt.append(batch_variant.duplicate(true))
				continue
			var batch: Dictionary = batch_variant.duplicate(true)
			var take := mini(remaining, int(batch.get("quantity", 0)))
			if take <= 0:
				continue
			if bool(batch.get("known", false)):
				total_cost += take * int(batch.get("unit_cost", 0))
			else:
				all_known = false
			remaining -= take
			var left := int(batch.get("quantity", 0)) - take
			if left > 0:
				batch["quantity"] = left
				rebuilt.append(batch)
		if remaining > 0:
			all_known = false
		cost_batches[item_id] = rebuilt
		consumed[item_id] = int(requirements[item_variant])
	return {"known": all_known, "total_cost": total_cost if all_known else 0, "consumed": consumed}

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

# Snapshot the actual active city. The returned dictionary can be passed
# directly as MacroEconomySimulator's "production" field. Scenario actions
# remain explicit so this snapshot never invents player decisions or demand.
static func capture_live_city_config(horizon_seconds: int, actions: Array = []) -> Dictionary:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return {"capture_error": "A live SceneTree is required."}
	var root := scene_tree.root
	var production_manager = root.get_node_or_null("ProductionManager")
	var storage_manager = root.get_node_or_null("StorageManager")
	var trade_manager = root.get_node_or_null("TradeManager")
	var game_manager = root.get_node_or_null("GameManager")
	if production_manager == null or storage_manager == null or trade_manager == null or game_manager == null:
		return {"capture_error": "One or more required production/economy autoloads are unavailable."}
	var now := int(Time.get_unix_time_from_system())
	var facilities: Array[Dictionary] = []
	var has_automatic_chain_jobs := false
	for component in scene_tree.get_nodes_in_group("production_components"):
		if not is_instance_valid(component) or not component.is_in_group("production_components"):
			continue
		var owner = component.owner_building
		var facility_id := str(owner.get("building_id")) if is_instance_valid(owner) else ""
		if facility_id.is_empty():
			facility_id = "production_component_%d" % component.get_instance_id()
		var kind := "factory" if component.is_factory else "store"
		var initial_slots: Array[Dictionary] = []
		var duration_overrides: Dictionary = {}
		for slot_variant in component.slots:
			var slot: Dictionary = slot_variant.duplicate(true)
			if not str(slot.get("auto_chain_id", "")).is_empty():
				has_automatic_chain_jobs = true
			if not slot.is_empty():
				var finish_unix := int(slot.get("finish_unix", 0))
				var remaining := maxi(0, finish_unix - now) if finish_unix > 0 else 0
				slot["finish_seconds"] = remaining
				slot["start_seconds"] = 0
				slot["ready"] = bool(slot.get("ready", false)) or (finish_unix > 0 and remaining == 0)
			initial_slots.append(slot)
		if not component.is_factory:
			for recipe_id in production_manager.get_store_recipe_ids(str(component.shop_id)):
				duration_overrides[str(recipe_id)] = int(ceil(component.get_item_production_time(str(recipe_id))))
		facilities.append({
			"id": facility_id,
			"kind": kind,
			"factory_type": str(component.factory_type),
			"shop_id": str(component.shop_id),
			"store_star_level": int(component.store_star_level),
			"slot_count": component.get_slot_count(),
			"operational": component._owner_has_road_access(),
			"initial_slots": initial_slots,
			"duration_overrides": duration_overrides
		})
	if has_automatic_chain_jobs:
		return {"capture_error": "Live automatic dependency chains are active; their dependency graph is not yet included in this snapshot."}
	var depot_snapshot: Dictionary = {}
	for listing_variant in trade_manager.sell_slots:
		var listing: Dictionary = listing_variant.duplicate(true)
		var listing_id := str(listing.get("listing_id", ""))
		if listing_id.is_empty():
			continue
		var remaining := maxi(0, int(listing.get("finish_unix", now)) - now)
		if bool(listing.get("ready", false)):
			remaining = 0
		var age := 120 - mini(120, remaining)
		depot_snapshot[listing_id] = {
			"item_id": str(listing.get("item_id", "")),
			"quantity": int(listing.get("amount", 0)),
			"unit_value": int(listing.get("price", 0)) / maxi(1, int(listing.get("amount", 1))),
			"listed_at_seconds": -age
		}
	var raw_catalog: Dictionary = production_manager.raw_materials.duplicate(true)
	var crafted_catalog: Dictionary = production_manager.crafted_items.duplicate(true)
	return {
		"horizon_seconds": maxi(0, horizon_seconds),
		"storage_capacity": int(storage_manager.capacity),
		"initial_inventory": storage_manager.get_all_items(),
		"raw_materials": raw_catalog,
		"crafted_items": crafted_catalog,
		"factory_materials": production_manager.factory_materials.duplicate(true),
		"mayor_level": int(game_manager.level),
		"invalid_recipe_ids": production_manager.get_recipe_validation_report().get("invalid_recipe_ids", []),
		"facilities": facilities,
		"actions": actions.duplicate(true),
		"depot_operational": trade_manager.is_depot_operational(),
		"initial_depot_listings": depot_snapshot
	}
