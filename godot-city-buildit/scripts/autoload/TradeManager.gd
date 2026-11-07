extends Node

signal trade_completed(item_id: String, amount: int, earned: int)
signal order_completed(reward: int)

var sell_slots: Array = []
const MAX_SELL_SLOTS := 4
var current_orders: Array = []

func _ready() -> void:
	print("[TradeManager] Trade system online")
	_generate_orders()

func can_sell(item_id: String, amount: int = 1) -> bool:
	return StorageManager.get_item_count(item_id) >= amount and sell_slots.size() < MAX_SELL_SLOTS

func list_for_sale(item_id: String, amount: int = 1) -> bool:
	if not can_sell(item_id, amount):
		return false
	var value = ProductionManager.get_item_value(item_id)
	var price = value * amount
	if StorageManager.remove_item(item_id, amount):
		sell_slots.append({"item_id": item_id, "amount": amount, "price": price, "time_left": 120.0})
		return true
	return false

func collect_sale(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= sell_slots.size():
		return
	var slot = sell_slots[slot_index]
	EconomyManager.add_simoleons(slot.price)
	trade_completed.emit(slot.item_id, slot.amount, slot.price)
	sell_slots.remove_at(slot_index)

func _process(delta: float) -> void:
	for i in range(sell_slots.size() - 1, -1, -1):
		sell_slots[i].time_left -= delta
		if sell_slots[i].time_left <= 0:
			collect_sale(i)

func _generate_orders() -> void:
	current_orders.clear()
	var possible = ["metal", "wood", "nails", "planks"]
	for i in range(3):
		var item = possible[randi() % possible.size()]
		var amount = randi_range(1, 3)
		var reward = ProductionManager.get_item_value(item) * amount * 2
		current_orders.append({"item_id": item, "amount": amount, "reward": reward, "completed": false})

func try_complete_order(order_index: int) -> bool:
	if order_index < 0 or order_index >= current_orders.size():
		return false
	var order = current_orders[order_index]
	if order.completed or StorageManager.get_item_count(order.item_id) < order.amount:
		return false
	StorageManager.remove_item(order.item_id, order.amount)
	EconomyManager.add_simoleons(order.reward)
	order.completed = true
	order_completed.emit(order.reward)
	return true

func get_sell_slots() -> Array:
	return sell_slots

func get_orders() -> Array:
	return current_orders
