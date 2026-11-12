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
@export_range(0, 3, 1) var store_star_level: int = 0
var slots: Array[Dictionary] = []

func _ready() -> void:
	if not is_factory:
		slot_count = clampi(maxi(slot_count, MIN_STORE_QUEUE_SLOTS), MIN_STORE_QUEUE_SLOTS, MAX_STORE_QUEUE_SLOTS)
	_ensure_slots()

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
	else:
		costs = [8, 14, 20, 26, 32, 38, 44, 50, 56]
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
	slots_changed.emit()
	return true

# Store queue expansion is deliberately price-driven by the caller. This keeps
# SimCash costs sourced/configured by the UI/catalog instead of inventing prices.
func purchase_store_queue_slot(simcash_cost: int) -> bool:
	_ensure_slots()
	if is_factory or slot_count >= MAX_STORE_QUEUE_SLOTS or simcash_cost <= 0:
		return false
	if EconomyManager.sim_cash < simcash_cost:
		return false
	EconomyManager.sim_cash -= simcash_cost
	EconomyManager.transaction_completed.emit("sim_cash_spend", simcash_cost)
	slot_count += 1
	_ensure_slots()
	slots_changed.emit()
	return true

func refresh_slots() -> void:
	_ensure_slots()
	var now := int(Time.get_unix_time_from_system())
	var changed := false
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
		slots_changed.emit()

func _start_next_store_order() -> bool:
	if is_factory:
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
		var item_id := str(slot.get("item_id", ""))
		var duration := int(ceil(get_item_production_time(item_id)))
		slot["start_unix"] = int(Time.get_unix_time_from_system())
		slot["finish_unix"] = int(slot["start_unix"]) + maxi(1, duration)
		slot["queued"] = false
		slots[index] = slot
		return true
	return false

func start_factory(item_id: String, slot_index: int) -> bool:
	_ensure_slots()
	if not is_factory or slot_index < 0 or slot_index >= slots.size() or not slots[slot_index].is_empty():
		return false
	if not ProductionManager.get_factory_material_ids(factory_type).has(item_id) or not ProductionManager.raw_materials.has(item_id):
		return false
	var definition: Dictionary = ProductionManager.raw_materials[item_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return false
	# Raw factory materials have no inputs: each slot starts independently.
	var now := int(Time.get_unix_time_from_system())
	slots[slot_index] = {
		"item_id": item_id,
		"start_unix": now,
		"finish_unix": now + int(definition.get("time_sec", 60)),
		"ready": false
	}
	slots_changed.emit()
	return true

func start_craft(recipe_id: String, slot_index: int) -> bool:
	_ensure_slots()
	if is_factory or slot_index < 0 or slot_index >= slots.size() or not slots[slot_index].is_empty():
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
	if not StorageManager.has_items(inputs) or not StorageManager.remove_items(inputs):
		return false
	slots[slot_index] = {
		"item_id": recipe_id,
		"start_unix": 0,
		"finish_unix": 0,
		"ready": false,
		"queued": true
	}
	_start_next_store_order()
	slots_changed.emit()
	return true

func collect(slot_index: int) -> bool:
	_ensure_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if slot.is_empty() or not bool(slot.get("ready", false)):
		return false
	var item_id := str(slot.get("item_id", ""))
	# If the warehouse is full, keep the completed product on the building.
	if not StorageManager.add_item(item_id, 1):
		return false
	slots[slot_index] = {}
	item_collected.emit(item_id)
	slots_changed.emit()
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
	refresh_slots()
	slots_changed.emit()
