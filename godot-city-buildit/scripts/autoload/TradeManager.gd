extends Node

signal trade_completed(item_id: String, amount: int, earned: int)
signal order_completed(reward: int)
signal trade_state_changed

const DEPOT_UNLOCK_POPULATION := 8000
const GLOBAL_TRADE_UNLOCK_POPULATION := 10000
const CARGO_SHIP_UNLOCK_POPULATION := 20000
const SHIP_RETURN_SECONDS := 180.0
const SHIP_CRATE_COUNT := 3
const MAX_SELL_SLOTS := 4
const SELL_LISTING_SECONDS := 120.0
const MARKET_REFRESH_SECONDS := 180.0
const MARKET_OFFER_COUNT := 6

var sell_slots: Array[Dictionary] = []
var current_orders: Array[Dictionary] = []
var market_offers: Array[Dictionary] = []
var market_refresh_time_left := MARKET_REFRESH_SECONDS
var market_refresh_unix: int = 0
var ship_crates: Array[Dictionary] = []
var ship_departed := false
var ship_return_time_left := 0.0
var ship_return_unix: int = 0
var ship_departures := 0
var completed_sales: int = 0
var market_purchases: int = 0

func _ready() -> void:
	print("[TradeManager] Trade system online")
	_generate_orders()
	_generate_market_offers()
	market_refresh_unix = int(Time.get_unix_time_from_system()) + int(MARKET_REFRESH_SECONDS)
	_generate_ship_manifest()

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

func is_cargo_ship_operational() -> bool:
	return GameManager.population >= CARGO_SHIP_UNLOCK_POPULATION and has_trade_building("cargo_port")

func can_list_for_sale(item_id: String, amount: int = 1) -> bool:
	if not is_depot_operational() or amount <= 0 or sell_slots.size() >= MAX_SELL_SLOTS:
		return false
	if not _item_exists(item_id):
		return false
	return StorageManager.get_count(item_id) >= amount

func can_sell(item_id: String, amount: int = 1) -> bool:
	return can_list_for_sale(item_id, amount)

func list_for_sale(item_id: String, amount: int = 1) -> bool:
	if not can_list_for_sale(item_id, amount):
		return false
	var price := ProductionManager.get_item_value(item_id) * amount
	var requested_items: Dictionary = {}
	requested_items[item_id] = amount
	if price <= 0 or not StorageManager.remove_items(requested_items):
		return false
	sell_slots.append({
		"item_id": item_id,
		"amount": amount,
		"price": price,
		"time_left": SELL_LISTING_SECONDS,
		"finish_unix": int(Time.get_unix_time_from_system()) + int(SELL_LISTING_SECONDS),
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
	completed_sales += 1
	sell_slots.remove_at(slot_index)
	trade_completed.emit(item_id, amount, price)
	trade_state_changed.emit()
	return true

func _process(_delta: float) -> void:
	var changed := false
	var now := int(Time.get_unix_time_from_system())
	if is_depot_operational():
		for index in range(sell_slots.size()):
			var slot: Dictionary = sell_slots[index]
			if bool(slot.get("ready", false)):
				continue
			var previous_display_seconds := ceili(float(slot.get("time_left", 0.0)))
			var finish_unix := int(slot.get("finish_unix", 0))
			if finish_unix <= 0:
				# Backward compatibility for older saves that only stored time_left.
				finish_unix = now + ceili(maxf(0.0, float(slot.get("time_left", 0.0))))
				slot["finish_unix"] = finish_unix
			slot["time_left"] = maxf(0.0, float(finish_unix - now))
			if float(slot["time_left"]) <= 0.0:
				slot["ready"] = true
			if ceili(float(slot["time_left"])) != previous_display_seconds or bool(slot["ready"]):
				changed = true
			sell_slots[index] = slot
	if is_global_trade_operational():
		var previous_market_seconds := ceili(market_refresh_time_left)
		if market_refresh_unix <= 0:
			market_refresh_unix = now + ceili(maxf(0.0, market_refresh_time_left))
		market_refresh_time_left = maxf(0.0, float(market_refresh_unix - now))
		if market_refresh_time_left <= 0.0:
			_generate_market_offers()
			market_refresh_unix = now + int(MARKET_REFRESH_SECONDS)
			market_refresh_time_left = MARKET_REFRESH_SECONDS
			changed = true
		elif ceili(market_refresh_time_left) != previous_market_seconds:
			changed = true
	if is_cargo_ship_operational() and ship_departed:
		var previous_ship_seconds := ceili(ship_return_time_left)
		if ship_return_unix <= 0:
			ship_return_unix = now + ceili(maxf(0.0, ship_return_time_left))
		ship_return_time_left = maxf(0.0, float(ship_return_unix - now))
		if ship_return_time_left <= 0.0:
			ship_departed = false
			ship_return_time_left = 0.0
			ship_return_unix = 0
			_generate_ship_manifest()
			_set_ship_visual_departed(false)
			changed = true
		elif ceili(ship_return_time_left) != previous_ship_seconds:
			changed = true
	if changed:
		trade_state_changed.emit()

func is_trade_eligible_item(item_id: String) -> bool:
	if ProductionManager.raw_materials.has(item_id):
		var raw_definition: Dictionary = ProductionManager.raw_materials[item_id]
		return int(raw_definition.get("level", 1)) <= GameManager.level and ProductionManager.get_item_value(item_id) > 0
	if ProductionManager.crafted_items.has(item_id):
		var recipe: Dictionary = ProductionManager.crafted_items[item_id]
		return bool(recipe.get("unlock_level_verified", true)) and int(recipe.get("level", 1)) <= GameManager.level and ProductionManager.get_item_value(item_id) > 0
	return false

func get_trade_eligible_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in ProductionManager.raw_materials:
		if is_trade_eligible_item(str(item_id)):
			result.append(str(item_id))
	for item_id in ProductionManager.crafted_items:
		if is_trade_eligible_item(str(item_id)):
			result.append(str(item_id))
	return result

func _generate_ship_manifest() -> void:
	ship_crates.clear()
	var pool: Array[String] = get_trade_eligible_item_ids()
	pool.shuffle()
	if pool.is_empty():
		pool.append("metal")
	for index in range(SHIP_CRATE_COUNT):
		var item_id := pool[index % pool.size()]
		var amount := randi_range(2, 4)
		ship_crates.append({
			"item_id": item_id,
			"amount": amount,
			"delivered": false
		})
	trade_state_changed.emit()

func deliver_ship_crate(crate_index: int) -> bool:
	if not is_cargo_ship_operational() or ship_departed or crate_index < 0 or crate_index >= ship_crates.size():
		return false
	var crate: Dictionary = ship_crates[crate_index]
	if bool(crate.get("delivered", false)):
		return false
	var item_id := str(crate.get("item_id", ""))
	var amount := int(crate.get("amount", 0))
	if not _item_exists(item_id) or amount <= 0 or StorageManager.get_count(item_id) < amount:
		return false
	var requested_items: Dictionary = {}
	requested_items[item_id] = amount
	if not StorageManager.remove_items(requested_items):
		return false
	crate["delivered"] = true
	ship_crates[crate_index] = crate
	var all_delivered := true
	for entry in ship_crates:
		if not bool(entry.get("delivered", false)):
			all_delivered = false
			break
	if all_delivered:
		ship_departed = true
		ship_return_time_left = SHIP_RETURN_SECONDS
		ship_return_unix = int(Time.get_unix_time_from_system()) + int(SHIP_RETURN_SECONDS)
		ship_departures += 1
		EconomyManager.add_keys(1)
		_set_ship_visual_departed(true)
	trade_state_changed.emit()
	return true

func get_ship_crates() -> Array:
	return ship_crates

func _set_ship_visual_departed(departed: bool) -> void:
	var scene := get_tree().current_scene
	var visual = scene.get_node_or_null("World/WorldPresentation/CargoShipVisual") if scene else null
	if visual and visual.has_method("set_departed"):
		visual.set_departed(departed)

func _item_exists(item_id: String) -> bool:
	return ProductionManager.raw_materials.has(item_id) or ProductionManager.crafted_items.has(item_id)

func _generate_market_offers() -> void:
	market_offers.clear()
	var pool: Array[String] = get_trade_eligible_item_ids()
	pool.shuffle()
	# Keep all three SCBI-style expansion parts discoverable in every market
	# refresh after Mayor Level 10 instead of relying on a lucky random roll.
	if GameManager.level >= 10:
		for item_id in ["dozer_wheel", "dozer_blade", "dozer_exhaust"]:
			if not pool.has(item_id):
				continue
			var amount := 1
			market_offers.append({
				"item_id": item_id,
				"amount": amount,
				"price": maxi(1, ProductionManager.get_item_value(item_id) * amount * 2),
				"sold": false
			})
			pool.erase(item_id)
	for item_id in pool:
		if market_offers.size() >= MARKET_OFFER_COUNT:
			break
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
	market_purchases += 1
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
	var requested_items: Dictionary = {}
	requested_items[item_id] = amount
	if not StorageManager.remove_items(requested_items):
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
		"market_refresh_time_left": market_refresh_time_left,
		"market_refresh_unix": market_refresh_unix,
		"ship_crates": ship_crates.duplicate(true),
		"ship_departed": ship_departed,
		"ship_return_time_left": ship_return_time_left,
		"ship_return_unix": ship_return_unix,
		"ship_departures": ship_departures,
		"completed_sales": completed_sales,
		"market_purchases": market_purchases
	}

func from_save_dict(data: Dictionary) -> void:
	var now := int(Time.get_unix_time_from_system())
	sell_slots.clear()
	current_orders.clear()
	market_offers.clear()
	for slot in data.get("sell_slots", []):
		if slot is Dictionary:
			var restored_slot: Dictionary = slot.duplicate(true)
			if not bool(restored_slot.get("ready", false)) and int(restored_slot.get("finish_unix", 0)) <= 0:
				# Legacy save: start its remaining countdown from this load.
				restored_slot["finish_unix"] = now + ceili(maxf(0.0, float(restored_slot.get("time_left", 0.0))))
			sell_slots.append(restored_slot)
	for order in data.get("current_orders", []):
		if order is Dictionary:
			current_orders.append(order.duplicate(true))
	for offer in data.get("market_offers", []):
		if offer is Dictionary:
			market_offers.append(offer.duplicate(true))
	market_refresh_time_left = maxf(0.0, float(data.get("market_refresh_time_left", MARKET_REFRESH_SECONDS)))
	market_refresh_unix = int(data.get("market_refresh_unix", 0))
	if market_refresh_unix <= 0:
		market_refresh_unix = now + ceili(market_refresh_time_left)
	ship_crates.clear()
	for crate in data.get("ship_crates", []):
		if crate is Dictionary:
			ship_crates.append(crate.duplicate(true))
	ship_departed = bool(data.get("ship_departed", false))
	ship_return_time_left = maxf(0.0, float(data.get("ship_return_time_left", 0.0)))
	ship_return_unix = int(data.get("ship_return_unix", 0))
	if ship_departed and ship_return_unix <= 0:
		ship_return_unix = now + ceili(ship_return_time_left)
	ship_departures = maxi(0, int(data.get("ship_departures", 0)))
	completed_sales = maxi(0, int(data.get("completed_sales", 0)))
	market_purchases = maxi(0, int(data.get("market_purchases", 0)))
	if ship_crates.is_empty():
		_generate_ship_manifest()
	_set_ship_visual_departed(ship_departed)
	if current_orders.is_empty():
		_generate_orders()
	var expansion_market_complete := true
	if GameManager.level >= 10:
		for expansion_item in ["dozer_wheel", "dozer_blade", "dozer_exhaust"]:
			var found := false
			for offer in market_offers:
				if str(offer.get("item_id", "")) == expansion_item:
					found = true
					break
			if not found:
				expansion_market_complete = false
				break
	if market_offers.is_empty() or not expansion_market_complete:
		_generate_market_offers()
	trade_state_changed.emit()

func get_sell_slots() -> Array:
	return sell_slots

func get_market_offers() -> Array:
	return market_offers

func get_orders() -> Array:
	return current_orders
