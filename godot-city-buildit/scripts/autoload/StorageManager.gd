extends Node

signal storage_changed
signal capacity_changed(new_capacity: int)

var max_capacity: int = 30
var current_used: int = 0
var inventory: Dictionary = {}

# Public aliases keep the storage API aligned with the production design document
# while preserving the existing SaveManager inventory/max_capacity fields.
var items: Dictionary:
	get:
		return inventory
	set(value):
		inventory = value

var capacity: int:
	get:
		return max_capacity
	set(value):
		max_capacity = maxi(1, value)

var item_definitions := {
	"metal": {"name": "Metal", "type": "raw"},
	"wood": {"name": "Wood", "type": "raw"},
	"plastic": {"name": "Plastic", "type": "raw"},
	"seeds": {"name": "Seeds", "type": "raw"},
	"minerals": {"name": "Minerals", "type": "raw"},
	"chemicals": {"name": "Chemicals", "type": "raw"},
	"textiles": {"name": "Textiles", "type": "raw"},
	"sugar": {"name": "Sugar & Spices", "type": "raw"},
	"glass": {"name": "Glass", "type": "raw"},
	"feed": {"name": "Animal Feed", "type": "raw"},
	"electrical": {"name": "Electrical Components", "type": "raw"},
	"nails": {"name": "Nails", "type": "crafted"},
	"planks": {"name": "Planks", "type": "crafted"},
	"bricks": {"name": "Bricks", "type": "crafted"},
	"cement": {"name": "Cement", "type": "crafted"},
	"glue": {"name": "Glue", "type": "crafted"},
	"paint": {"name": "Paint", "type": "crafted"},
	"hammer": {"name": "Hammer", "type": "crafted"},
	"measuring_tape": {"name": "Measuring Tape", "type": "crafted"},
	"shovel": {"name": "Shovel", "type": "crafted"},
	"chair": {"name": "Chair", "type": "crafted"},
	"table": {"name": "Table", "type": "crafted"},
	"vegetables": {"name": "Vegetables", "type": "crafted"},
}

func _ready() -> void:
	print("[StorageManager] Capacity ", max_capacity)

func get_free_space() -> int:
	return max_capacity - current_used

func has_space(amount: int = 1) -> bool:
	return current_used + amount <= max_capacity

func add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not has_space(amount):
		print("[StorageManager] Full or invalid amount")
		return false
	inventory[item_id] = inventory.get(item_id, 0) + amount
	current_used += amount
	storage_changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not inventory.has(item_id) or inventory[item_id] < amount:
		return false
	inventory[item_id] -= amount
	current_used -= amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	storage_changed.emit()
	return true

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func has_item(item_id: String, amount: int = 1) -> bool:
	return amount >= 0 and get_item_count(item_id) >= amount

func get_count(item_id: String) -> int:
	return get_item_count(item_id)

func get_used_slots() -> int:
	return current_used

func upgrade_capacity(extra: int = 10) -> void:
	max_capacity += extra
	capacity_changed.emit(max_capacity)

func get_storage_ratio() -> String:
	return "%d/%d" % [current_used, max_capacity]

func get_all_items() -> Dictionary:
	return inventory.duplicate()
