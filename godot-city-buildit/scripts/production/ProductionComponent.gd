extends Node
class_name ProductionComponent

signal slots_changed
signal item_collected(item_id: String)

const MIN_STORE_QUEUE_SLOTS: int = 2
const MAX_STORE_QUEUE_SLOTS: int = 11

@export var slot_count: int = 1
@export var is_factory: bool = false
@export var shop_id: String = ""
@export var factory_type: String = ""
var owner_building: Node = null
@export_range(0, 3, 1) var store_star_level: int = 0
var slots: Array[Dictionary] = []

func _emit_slots_changed() -> void:
	slots_changed.emit()
	if has_node("/root/SaveManager"):
		SaveManager.schedule_save()


func _ready() -> void:
	if not is_factory:
		slot_count = clampi(maxi(slot_count, MIN_STORE_QUEUE_SLOTS), MIN_STORE_QUEUE_SLOTS, MAX_STORE_QUEUE_SLOTS)
	_ensure_slots()
	add_to_group("production_components")

func get_queue_delay_seconds() -> float:
	# A store runs one active order at a time; queued orders ahead of a new
	# request therefore add their full base durations. Ready orders do not block.
	if is_factory:
		return 0.0
	var now := int(Time.get_unix_time_from_system())
	var delay := 0.0
	for slot in slots:
		if slot.is_empty() or bool(slot.get("ready", false)):
			continue
		var finish_unix := int(slot.get("finish_unix", 0))
		if finish_unix > now:
			delay = maxf(delay, float(finish_unix - now))
		elif bool(slot.get("queued", false)) or finish_unix <= 0:
			delay += get_item_production_time(str(slot.get("item_id", "")))
	return delay

func _process(_delta: float) -> void:
	refresh_slots()

func _ensure_slots() -> void:
	var target_count := maxi(1, slot_count)
	if not is_factory:
		target_count = clampi(maxi(target_count, MIN_STORE_QUEUE_SLOTS), MIN_STORE_QUEUE_SLOTS, MAX_STORE_QUEUE_SLOTS)
		slot_count = target_count
	while slots.size() < target_count:
		slots.append({})
	while slots.size() > target_count:
		slots.pop_back()

func get_slot_count() -> int:
	_ensure_slots()
	return slots.size()

func get_slot(index: int) -> Dictionary:
	_ensure_slots()
	if index < 0 or index >= slots.size():
		return {}
	return slots[index].duplicate(true)

func get_item_production_time(item_id: String) -> float:
	return ProductionManager.get_production_time(item_id, 0 if is_factory else store_star_level)

func get_next_store_queue_slot_cost() -> int:
	_ensure_slots()
	if is_factory or slot_count >= MAX_STORE_QUEUE_SLOTS:
		return 0
	var next_slot := slot_count + 1
	var costs: Array = []
	if shop_id == "building_supplies" or shop_id == "hardware_store":
		costs = [4, 10, 16, 22, 28, 34, 40, 46, 52]
	elif [
		"farmers_market", "furniture_store", "gardening_supplies", "donut_shop",
		"fashion_store", "fast_food", "home_appliances", "sports_shop",
		"toy_store", "restoration_office", "farmers_store", "dessert_shop"
	].has(shop_id):
		costs = [8, 14, 20, 26, 32, 38, 44, 50, 56]
	else:
		# Mshin-only/custom stores have no SCBI slot-price reference.
		return 0
	var cost_index := next_slot - 3
	return int(costs[cost_index]) if cost_index >= 0 and cost_index < costs.size() else 0

func upgrade_store_star() -> bool:
	if is_factory:
		return false
	var offer := ProductionManager.get_store_star_offer(shop_id, store_star_level)
	if offer.is_empty() or GameManager.level < int(offer.get("level", 999)):
		return false
	var cost := int(offer.get("cost", 0))
	if not EconomyManager.spend_simoleons(cost):
		return false
	store_star_level = int(offer.get("star", store_star_level + 1))
	_emit_slots_changed()
	return true

# Store queue expansion is deliberately price-driven by the caller. This keeps
# SimCash costs sourced/configured by the UI/catalog instead of inventing prices.
func purchase_store_queue_slot(simcash_cost: int) -> bool:
	_ensure_slots()
	if is_factory or slot_count >= MAX_STORE_QUEUE_SLOTS or simcash_cost <= 0:
		return false
	if not EconomyManager.spend_sim_cash(simcash_cost):
		return false
	slot_count += 1
	_ensure_slots()
	_emit_slots_changed()
	return true

func _owner_has_road_access() -> bool:
	# Standalone components are used by isolated catalog tests. In-game
	# components always receive their owning Building before they can run.
	if owner_building == null:
		return true
	if not is_instance_valid(owner_building):
		return false
	if is_factory:
		return BuildManager.is_production_building_operational(owner_building)
	return BuildManager.is_building_operational(owner_building)

func refresh_slots() -> void:
	_ensure_slots()
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	if not _owner_has_road_access():
		for index in range(slots.size()):
			var paused_slot: Dictionary = slots[index]
			if paused_slot.is_empty() or bool(paused_slot.get("ready", false)):
				continue
			if int(paused_slot.get("finish_unix", 0)) > 0 and int(paused_slot.get("paused_at_unix", 0)) <= 0:
				paused_slot["paused_at_unix"] = now
				slots[index] = paused_slot
				changed = true
		if changed:
			_emit_slots_changed()
		return
	# Preserve the remaining production time while a road connection is lost.
	for index in range(slots.size()):
		var resumed_slot: Dictionary = slots[index]
		var paused_at := int(resumed_slot.get("paused_at_unix", 0))
		if paused_at <= 0:
			continue
		if int(resumed_slot.get("finish_unix", 0)) > 0:
			resumed_slot["finish_unix"] = int(resumed_slot["finish_unix"]) + maxi(0, now - paused_at)
		resumed_slot.erase("paused_at_unix")
		slots[index] = resumed_slot
		changed = true
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if slot.is_empty() or bool(slot.get("ready", false)):
			continue
		var finish_unix := int(slot.get("finish_unix", 0))
		if finish_unix > 0 and now >= finish_unix:
			slot["ready"] = true
			slots[index] = slot
			changed = true
	if not is_factory and _start_next_store_order():
		changed = true
	if changed:
		_emit_slots_changed()

func _start_next_store_order() -> bool:
	if is_factory or not _owner_has_road_access():
		return false
	# One store runs one active order at a time. A completed order occupies its
	# queue slot until collected, while the next queued order may begin.
	for slot in slots:
		if not slot.is_empty() and not bool(slot.get("ready", false)) and int(slot.get("finish_unix", 0)) > 0:
			return false
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if slot.is_empty() or bool(slot.get("ready", false)) or int(slot.get("finish_unix", 0)) > 0:
			continue
		# Automatic chain jobs are advanced by ProductionManager only after all
		# recursively required ingredients have been produced and reserved.
		if not str(slot.get("auto_chain_id", "")).is_empty():
			continue
		var item_id := str(slot.get("item_id", ""))
		var duration := int(ceil(get_item_production_time(item_id)))
		slot["start_unix"] = int(Time.get_unix_time_from_system())
		slot["finish_unix"] = int(slot["start_unix"]) + maxi(1, duration)
		slot["queued"] = false
		slots[index] = slot
		return true
	return false

func start_factory(item_id: String, slot_index: int, auto_chain_id: String = "") -> bool:
	_ensure_slots()
	if not is_factory or not _owner_has_road_access() or slot_index < 0 or slot_index >= slots.size() or not slots[slot_index].is_empty():
		return false
	if not ProductionManager.get_factory_material_ids(factory_type).has(item_id) or not ProductionManager.raw_materials.has(item_id):
		return false
	var definition: Dictionary = ProductionManager.raw_materials[item_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return false
	# Mshin factory order fee is a separate balancing rule, not the catalog's
	# maximum Trade Depot sale value. Validate and debit only after every other
	# rejection condition has passed, then occupy the slot in the same call.
	var order_cost := ProductionManager.get_factory_order_cost(item_id)
	if order_cost < 0 or EconomyManager.simoleons < order_cost:
		return false
	if not EconomyManager.spend_simoleons(order_cost, {
			"source": "factory_order",
			"factory_type": factory_type,
			"item_id": item_id,
			"duration_seconds": int(definition.get("time_sec", 60))
		}):
		return false
	var now := int(Time.get_unix_time_from_system())
	slots[slot_index] = {
		"item_id": item_id,
		"start_unix": now,
		"finish_unix": now + int(definition.get("time_sec", 60)),
		"ready": false,
		"auto_chain_id": auto_chain_id,
		"order_cost": order_cost,
		"cost_known": true,
		"cost_total": 0
	}
	_emit_slots_changed()
	return true

func start_craft(recipe_id: String, slot_index: int) -> bool:
	_ensure_slots()
	if is_factory or not _owner_has_road_access() or slot_index < 0 or slot_index >= slots.size() or not slots[slot_index].is_empty():
		return false
	var recipe := ProductionManager.get_recipe(recipe_id)
	if recipe.is_empty() or str(recipe.get("store", "")) != shop_id:
		return false
	if not ProductionManager.get_recipe_lock_reason(recipe_id, store_star_level).is_empty():
		return false
	if not ProductionManager.are_recipe_inputs_unlocked(recipe):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	# Validate and deduct the complete input set atomically when the order is
	# accepted into the store queue. Queued jobs never consume materials twice.
	if not StorageManager.has_items(inputs):
		return false
	var input_cost: Dictionary = StorageManager.get_cost_basis(inputs)
	if not StorageManager.remove_items(inputs):
		return false
	slots[slot_index] = {
		"item_id": recipe_id,
		"start_unix": 0,
		"finish_unix": 0,
		"ready": false,
		"queued": true,
		"cost_known": bool(input_cost.get("known", false)),
		"cost_total": int(input_cost.get("total_cost", 0))
	}
	_start_next_store_order()
	_emit_slots_changed()
	return true

func get_slot_speedup_quote(slot_index: int) -> Dictionary:
	_ensure_slots()
	if slot_index < 0 or slot_index >= slots.size() or slots[slot_index].is_empty() or bool(slots[slot_index].get("ready", false)) or not _owner_has_road_access():
		return {}
	var finish_unix := int(slots[slot_index].get("finish_unix", 0))
	if finish_unix <= 0:
		return {}
	var remaining := maxi(0, finish_unix - int(Time.get_unix_time_from_system()))
	if remaining <= 0:
		refresh_slots()
		return {}
	return {"slot_index": slot_index, "item_id": str(slots[slot_index].get("item_id", "")), "remaining_seconds": remaining, "simcash_cost": EconomyManager.get_simcash_time_skip_cost(remaining)}

func speed_up_slot(slot_index: int) -> Dictionary:
	var quote := get_slot_speedup_quote(slot_index)
	if quote.is_empty():
		return {"success": false, "reason": "slot_not_speedable"}
	var cost := int(quote.simcash_cost)
	if not EconomyManager.spend_sim_cash(cost):
		return {"success": false, "reason": "insufficient_simcash", "cost": cost}
	var slot: Dictionary = slots[slot_index]
	slot["finish_unix"] = int(Time.get_unix_time_from_system())
	slot.erase("paused_at_unix")
	slots[slot_index] = slot
	refresh_slots()
	return {"success": true, "cost": cost, "item_id": str(quote.item_id)}

func collect(slot_index: int) -> bool:
	_ensure_slots()
	if not _owner_has_road_access() or slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if slot.is_empty() or not bool(slot.get("ready", false)):
		return false
	var item_id := str(slot.get("item_id", ""))
	# If the warehouse is full, keep the completed product on the building.
	if not StorageManager.add_item_with_cost(item_id, 1, int(slot.get("cost_total", 0)), bool(slot.get("cost_known", false))):
		return false
	HapticsManager.pulse_for("collect")
	slots[slot_index] = {}
	item_collected.emit(item_id)
	_emit_slots_changed()
	ProductionManager.item_produced.emit(item_id, 1)
	GameManager.add_experience(2)
	return true

func to_save_array() -> Array:
	_ensure_slots()
	return slots.duplicate(true)

func from_save_array(saved_slots: Array) -> void:
	# Store capacity is inferred from the saved slot array so purchased slots
	# and their in-flight/ready products survive save/load.
	if not is_factory:
		slot_count = clampi(maxi(saved_slots.size(), MIN_STORE_QUEUE_SLOTS), MIN_STORE_QUEUE_SLOTS, MAX_STORE_QUEUE_SLOTS)
	_ensure_slots()
	for index in range(slots.size()):
		slots[index] = saved_slots[index].duplicate(true) if index < saved_slots.size() and saved_slots[index] is Dictionary else {}
		if not slots[index].is_empty() and not slots[index].has("cost_known"):
			# Older saves have no traceable acquisition cost for in-flight jobs.
			slots[index]["cost_known"] = false
			slots[index]["cost_total"] = 0
	refresh_slots()
	_emit_slots_changed()
