extends Node

signal trade_completed(item_id: String, amount: int, earned: int)
signal order_completed(reward: int)
signal trade_state_changed

const DEPOT_UNLOCK_POPULATION := 8000
const GLOBAL_TRADE_UNLOCK_POPULATION := 10000
const MAX_SELL_SLOTS := 4
const SELL_LISTING_SECONDS := 120.0
const MARKET_REFRESH_SECONDS := 180.0
const MARKET_OFFER_COUNT := 6

var sell_slots: Array[Dictionary] = []
var current_orders: Array[Dictionary] = []
var market_offers: Array[Dictionary] = []
var market_refresh_time_left := MARKET_REFRESH_SECONDS

func _ready() -> void:
	print("[TradeManager] Trade system online")
	_generate_orders()
	_generate_market_offers()

func has_trade_building(type_id: String) -> bool:
	for building in BuildManager.buildings.values():
		if not is_instance_valid(building):
			continue
		if str(building.get("building_type")) == type_id and str(building.get("status")) == "completed":
			return true
	return false

func is_depot_operational() -> bool:
	return GameManager.population >= DEPOT_UNLOCK_POPULATION and has_trade_building("trade_depot")

func is_global_trade_operational() -> bool:
	return GameManager.population >= GLOBAL_TRADE_UNLOCK_POPULATION and has_trade_building("global_trade_hq")

func can_list_for_sale(item_id: String, amount: int = 1) -> bool:
	if not is_depot_operational() or amount <= 0 or sell_slots.size() >= MAX_SELL_SLOTS:
		return false
	if not _item_exists(item_id):
		return false
	return StorageManager.get_count(item_id) >= amount

func list_for_sale(item_id: String, amount: int = 1) -> bool:
	if not can_list_for_sale(item_id, amount):
		return false
	var price := ProductionManager.get_item_value(item_id) * amount
	if price <= 0 or not StorageManager.remove_items({item_id: amount}):
		return false
	sell_slots.append({
		"item_id": item_id,
		"amount": amount,
		"price": price,
		"time_left": SELL_LISTING_SECONDS,
		"ready": false
	})
	trade_state_changed.emit()
	return true

func collect_sale(slot_index: int) -> bool:
	if not is_depot_operational() or slot_index < 0 or slot_index >= sell_slots.size():
		return false
	var slot: Dictionary = sell_slots[slot_index]
	if not bool(slot.get("ready", false)):
		return false
	var item_id := str(slot.get("item_id", ""))
	var amount := int(slot.get("amount", 0))
	var price := int(slot.get("price", 0))
	if item_id.is_empty() or amount <= 0 or price <= 0:
		return false
	EconomyManager.add_simoleons(price)
	sell_slots.remove_at(slot_index)
	trade_completed.emit(item_id, amount, price)
	trade_state_changed.emit()
	return true

func _process(delta: float) -> void:
	var changed := false
	if is_depot_operational():
		for index in range(sell_slots.size()):
			var slot: Dictionary = sell_slots[index]
			if bool(slot.get("ready", false)):
				continue
			slot["time_left"] = maxf(0.0, float(slot.get("time_left", 0.0)) - delta)
			if float(slot["time_left"]) <= 0.0:
				slot["ready"] = true
			changed = true
			sell_slots[index] = slot
	if is_global_trade_operational():
		market_refresh_time_left = maxf(0.0, market_refresh_time_left - delta)
		if market_refresh_time_left <= 0.0:
			_generate_market_offers()
			market_refresh_time_left = MARKET_REFRESH_SECONDS
			changed = true
	if changed:
		trade_state_changed.emit()

func _item_exists(item_id: String) -> bool:
	return ProductionManager.raw_materials.has(item_id) or ProductionManager.crafted_items.has(item_id)

func _generate_market_offers() -> void:
	market_offers.clear()
	var pool: Array[String] = []
	for item_id in ProductionManager.raw_materials.keys():
		var definition: Dictionary = ProductionManager.raw_materials[item_id]
		if int(definition.get("level", 1)) <= GameManager.level:
			pool.append(str(item_id))
	for item_id in ProductionManager.crafted_items.keys():
		var definition: Dictionary = ProductionManager.crafted_items[item_id]
		if int(definition.get("level", 1)) <= GameManager.level:
			pool.append(str(item_id))
	pool.shuffle()
	for index in range(mini(MARKET_OFFER_COUNT, pool.size())):
		var item_id := pool[index]
		var amount := randi_range(1, 3)
		market_offers.append({
			"item_id": item_id,
			"amount": amount,
			"price": maxi(1, ProductionManager.get_item_value(item_id) * amount * 2),
			"sold": false
		})

func buy_global_offer(offer_index: int) -> bool:
	if not is_global_trade_operational() or offer_index < 0 or offer_index >= market_offers.size():
		return false
	var offer: Dictionary = market_offers[offer_index]
	if bool(offer.get("sold", false)):
		return false
	var item_id := str(offer.get("item_id", ""))
	var amount := int(offer.get("amount", 0))
	var price := int(offer.get("price", 0))
	if not _item_exists(item_id) or amount <= 0 or price <= 0:
		return false
	if StorageManager.get_free() < amount or not EconomyManager.spend_simoleons(price):
		return false
	if not StorageManager.add_item(item_id, amount):
		EconomyManager.add_simoleons(price)
		return false
	offer["sold"] = true
	market_offers[offer_index] = offer
	trade_state_changed.emit()
	return true

func _generate_orders() -> void:
	current_orders.clear()
	var possible := ["metal", "wood", "nails", "planks"]
	for index in range(3):
		var item_id: String = possible[randi() % possible.size()]
		var amount := randi_range(1, 3)
		var reward := ProductionManager.get_item_value(item_id) * amount * 2
		current_orders.append({"item_id": item_id, "amount": amount, "reward": reward, "completed": false})

func try_complete_order(order_index: int) -> bool:
	if not is_depot_operational() or order_index < 0 or order_index >= current_orders.size():
		return false
	var order: Dictionary = current_orders[order_index]
	var item_id := str(order.get("item_id", ""))
	var amount := int(order.get("amount", 0))
	if bool(order.get("completed", false)) or amount <= 0 or StorageManager.get_count(item_id) < amount:
		return false
	if not StorageManager.remove_items({item_id: amount}):
		return false
	var reward := int(order.get("reward", 0))
	EconomyManager.add_simoleons(reward)
	order["completed"] = true
	current_orders[order_index] = order
	order_completed.emit(reward)
	trade_state_changed.emit()
	return true

func to_save_dict() -> Dictionary:
	return {
		"sell_slots": sell_slots.duplicate(true),
		"current_orders": current_orders.duplicate(true),
		"market_offers": market_offers.duplicate(true),
		"market_refresh_time_left": market_refresh_time_left
	}

func from_save_dict(data: Dictionary) -> void:
	sell_slots.clear()
	current_orders.clear()
	market_offers.clear()
	for slot in data.get("sell_slots", []):
		if slot is Dictionary:
			sell_slots.append(slot.duplicate(true))
	for order in data.get("current_orders", []):
		if order is Dictionary:
			current_orders.append(order.duplicate(true))
	for offer in data.get("market_offers", []):
		if offer is Dictionary:
			market_offers.append(offer.duplicate(true))
	market_refresh_time_left = maxf(0.0, float(data.get("market_refresh_time_left", MARKET_REFRESH_SECONDS)))
	if current_orders.is_empty():
		_generate_orders()
	if market_offers.is_empty():
		_generate_market_offers()
	trade_state_changed.emit()

func get_sell_slots() -> Array:
	return sell_slots

func get_market_offers() -> Array:
	return market_offers

func get_orders() -> Array:
	return current_orders
