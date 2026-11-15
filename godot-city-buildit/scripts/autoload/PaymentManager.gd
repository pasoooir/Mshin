extends Node
## Local sandbox purchase orchestration. This is deliberately not a real payment provider.
signal order_updated(order: Dictionary)
const CATALOG: Array[Dictionary] = [
	{"id":"simcash_pocketful","name":"Pocketful of SimCash","base_amount":250,"bonus_amount":25,"total_amount":275,"tier":"starter","featured":false},
	{"id":"simcash_little_stack","name":"Little Stack of SimCash","base_amount":550,"bonus_amount":55,"total_amount":605,"tier":"popular","featured":true},
	{"id":"simcash_nice_pile","name":"Nice Pile of SimCash","base_amount":1300,"bonus_amount":130,"total_amount":1430,"tier":"value","featured":false},
	{"id":"simcash_briefcase","name":"Briefcase of SimCash","base_amount":2625,"bonus_amount":265,"total_amount":2890,"tier":"premium","featured":false},
	{"id":"simcash_big_sack","name":"Big Sack of SimCash","base_amount":4000,"bonus_amount":400,"total_amount":4400,"tier":"premium","featured":false},
	{"id":"simcash_huge_vault","name":"Huge Vault of SimCash","base_amount":8500,"bonus_amount":850,"total_amount":9350,"tier":"premium","featured":false},
	{"id":"simcash_plentiful","name":"Plentiful of SimCash","base_amount":22455,"bonus_amount":2245,"total_amount":24700,"tier":"special","featured":false},
	{"id":"simcash_flood","name":"Flood of SimCash","base_amount":47545,"bonus_amount":4755,"total_amount":52300,"tier":"special","featured":false}
]
const SANDBOX_PROVIDER := "mshin_mock_gateway"
var orders: Array[Dictionary] = []
var processed_order_ids: Dictionary = {}
var _order_sequence := 0
func get_catalog() -> Array[Dictionary]:
	return CATALOG.duplicate(true)
func get_product(product_id: String) -> Dictionary:
	for product in CATALOG:
		if str(product.id) == product_id: return product.duplicate(true)
	return {}
func create_order(product_id: String) -> Dictionary:
	var product := get_product(product_id)
	if product.is_empty(): return {"success": false, "reason": "unknown_product"}
	_order_sequence += 1
	var order_id := "MSHIN-%d-%04d" % [int(Time.get_unix_time_from_system()), _order_sequence]
	var order := {"order_id":order_id,"product_id":product_id,"product_name":str(product.name),"currency":"SIMCASH","base_amount":int(product.base_amount),"bonus_amount":int(product.bonus_amount),"grant_amount":int(product.total_amount),"price_minor":0,"price_currency":"TBD","payment_provider":SANDBOX_PROVIDER,"payment_mode":"SANDBOX_NO_REAL_CHARGE","status":"pending","created_at":int(Time.get_unix_time_from_system()),"completed_at":0}
	orders.append(order)
	order_updated.emit(order.duplicate(true))
	_persist_if_possible()
	return {"success":true,"order":order.duplicate(true)}
func complete_sandbox_order(order_id: String, outcome: String = "success") -> Dictionary:
	if processed_order_ids.has(order_id): return {"success":false,"reason":"already_processed","order":get_order(order_id)}
	var index := _find_order_index(order_id)
	if index < 0: return {"success":false,"reason":"order_not_found"}
	if str(orders[index].status) != "pending": return {"success":false,"reason":"order_not_pending","order":orders[index].duplicate(true)}
	if not ["success","failed","cancelled"].has(outcome): return {"success":false,"reason":"invalid_outcome"}
	var order: Dictionary = orders[index]
	order.status = "paid_sandbox" if outcome == "success" else ("failed" if outcome == "failed" else "cancelled")
	order.completed_at = int(Time.get_unix_time_from_system())
	if outcome == "success":
		processed_order_ids[order_id] = true
		if not EconomyManager.add_sim_cash(int(order.grant_amount)):
			order.status = "failed"
			processed_order_ids.erase(order_id)
			orders[index] = order
			return {"success":false,"reason":"currency_grant_failed","order":order.duplicate(true)}
	orders[index] = order
	order_updated.emit(order.duplicate(true))
	_persist_if_possible()
	return {"success":outcome == "success","order":order.duplicate(true),"reason":outcome}
func get_order(order_id: String) -> Dictionary:
	var index := _find_order_index(order_id)
	return orders[index].duplicate(true) if index >= 0 else {}
func get_recent_orders(limit: int = 20) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(orders.size() - 1, maxi(-1, orders.size() - maxi(0, limit) - 1), -1):
		result.append(orders[index].duplicate(true))
	return result
func to_save_dict() -> Dictionary:
	return {"orders":orders.duplicate(true),"processed_order_ids":processed_order_ids.duplicate(true),"order_sequence":_order_sequence}
func from_save_dict(data: Dictionary) -> void:
	orders.clear()
	for item in data.get("orders", []):
		if item is Dictionary: orders.append(item.duplicate(true))
	processed_order_ids = data.get("processed_order_ids", {}).duplicate(true)
	_order_sequence = maxi(0, int(data.get("order_sequence", 0)))
func _find_order_index(order_id: String) -> int:
	for index in range(orders.size()):
		if str(orders[index].get("order_id", "")) == order_id: return index
	return -1
func _persist_if_possible() -> void:
	if has_node("/root/SaveManager"): SaveManager.save_game()
