extends Node
class_name ProductionComponent

signal slots_changed
signal item_collected(item_id: String)

@export var slot_count: int = 1
@export var is_factory: bool = false
@export var shop_id: String = ""
@export var factory_type: String = ""
var slots: Array[Dictionary] = []

func _ready() -> void:
	_ensure_slots()

func _process(_delta: float) -> void:
	refresh_slots()

func _ensure_slots() -> void:
	while slots.size() < maxi(1, slot_count):
		slots.append({})
	while slots.size() > maxi(1, slot_count):
		slots.pop_back()

func get_slot_count() -> int:
	_ensure_slots()
	return slots.size()

func get_slot(index: int) -> Dictionary:
	_ensure_slots()
	if index < 0 or index >= slots.size():
		return {}
	return slots[index].duplicate(true)

func refresh_slots() -> void:
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if slot.is_empty() or bool(slot.get("ready", false)):
			continue
		if now >= int(slot.get("finish_unix", 0)):
			slot["ready"] = true
			slots[index] = slot
			changed = true
	if changed:
		slots_changed.emit()

func start_factory(item_id: String, slot_index: int) -> bool:
	_ensure_slots()
	if not is_factory or slot_index < 0 or slot_index >= slots.size() or not slots[slot_index].is_empty():
		return false
	if not ProductionManager.get_factory_material_ids(factory_type).has(item_id) or not ProductionManager.raw_materials.has(item_id):
		return false
	var definition: Dictionary = ProductionManager.raw_materials[item_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return false
	slots[slot_index] = {
		"item_id": item_id,
		"start_unix": int(Time.get_unix_time_from_system()),
		"finish_unix": int(Time.get_unix_time_from_system()) + int(definition.get("time_sec", 60)),
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
	if int(recipe.get("level", 1)) > GameManager.level or not ProductionManager.are_recipe_inputs_unlocked(recipe):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	if not StorageManager.has_items(inputs):
		return false
	if not StorageManager.remove_items(inputs):
		return false
	slots[slot_index] = {
		"item_id": recipe_id,
		"start_unix": int(Time.get_unix_time_from_system()),
		"finish_unix": int(Time.get_unix_time_from_system()) + int(recipe.get("time_sec", 300)),
		"ready": false
	}
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
	_ensure_slots()
	for index in range(slots.size()):
		slots[index] = saved_slots[index].duplicate(true) if index < saved_slots.size() and saved_slots[index] is Dictionary else {}
	refresh_slots()
	slots_changed.emit()
