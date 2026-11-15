extends Node
signal simoleons_changed(new_amount: int)
signal sim_cash_changed(new_amount: int)
signal keys_changed(new_amount: int)
signal transaction_completed(type: String, amount: int)
const SIMCASH_TO_SIMOLEONS_RATE := 1000
const MAX_TRANSACTION_LEDGER_ENTRIES := 300
var transaction_ledger: Array[Dictionary] = []
var transaction_sequence: int = 0
var simoleons: int = 25000
var golden_keys: int = 10
var sim_cash: int = 25
var tax_income_per_minute: int = 0
var last_tax_time: float = 0.0
func _ready() -> void:
	print("[EconomyManager] Economy system online")
	last_tax_time = Time.get_unix_time_from_system()
func _process(_delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	if now - last_tax_time >= 60.0:
		last_tax_time = now
		if tax_income_per_minute > 0:
			add_simoleons(tax_income_per_minute)
func add_simoleons(amount: int) -> bool:
	if amount <= 0: return false
	var before := simoleons
	simoleons += amount
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simoleons_gain", amount)
	record_transaction("simoleons_gain", "simoleons", amount, before, simoleons, {}, {}, {"source": "economy"})
	return true
func spend_simoleons(amount: int) -> bool:
	if amount <= 0 or simoleons < amount: return false
	var before := simoleons
	simoleons -= amount
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simoleons_spend", amount)
	record_transaction("simoleons_spend", "simoleons", amount, before, simoleons, {}, {}, {"source": "economy"})
	return true
func add_sim_cash(amount: int) -> bool:
	if amount <= 0: return false
	var before := sim_cash
	sim_cash += amount
	sim_cash_changed.emit(sim_cash)
	transaction_completed.emit("simcash_gain", amount)
	record_transaction("simcash_gain", "simcash", amount, before, sim_cash, {}, {}, {"source": "economy"})
	return true
func spend_sim_cash(amount: int) -> bool:
	if amount <= 0 or sim_cash < amount: return false
	var before := sim_cash
	sim_cash -= amount
	sim_cash_changed.emit(sim_cash)
	transaction_completed.emit("simcash_spend", amount)
	record_transaction("simcash_spend", "simcash", amount, before, sim_cash, {}, {}, {"source": "economy"})
	return true
func convert_sim_cash_to_simoleons(simcash_amount: int) -> Dictionary:
	if simcash_amount <= 0: return {"success": false, "reason": "invalid_amount"}
	if sim_cash < simcash_amount: return {"success": false, "reason": "insufficient_simcash"}
	var granted := simcash_amount * SIMCASH_TO_SIMOLEONS_RATE
	sim_cash -= simcash_amount
	simoleons += granted
	sim_cash_changed.emit(sim_cash)
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simcash_conversion_spend", simcash_amount)
	transaction_completed.emit("simoleons_conversion_gain", granted)
	return {"success": true, "simcash_spent": simcash_amount, "simoleons_granted": granted}
func can_afford(amount: int) -> bool:
	# Zero-cost bootstrap buildings (e.g. the first small factory) remain affordable.
	return simoleons >= amount
func add_keys(amount: int) -> void:
	if amount <= 0: return
	golden_keys += amount
	keys_changed.emit(golden_keys)
func spend_keys(amount: int) -> bool:
	if amount <= 0 or golden_keys < amount: return false
	golden_keys -= amount
	keys_changed.emit(golden_keys)
	return true
func set_tax_income(amount: int) -> void:
	tax_income_per_minute = maxi(0, amount)
func buy_special_item_with_simcash(item_id: String, unit_cost: int, unlock_level: int) -> Dictionary:
	if item_id.is_empty() or unit_cost <= 0 or unlock_level < 1:
		return {"success": false, "reason": "invalid_offer"}
	if GameManager.level < unlock_level:
		return {"success": false, "reason": "item_locked", "unlock_level": unlock_level}
	if not StorageManager.item_definitions.has(item_id):
		return {"success": false, "reason": "unknown_special_item"}
	if StorageManager.get_free() < 1:
		return {"success": false, "reason": "warehouse_capacity"}
	var balance_before := sim_cash
	var inventory_before := StorageManager.get_all_items()
	if not spend_sim_cash(unit_cost):
		return {"success": false, "reason": "insufficient_simcash", "cost": unit_cost}
	if not StorageManager.add_item(item_id, 1):
		add_sim_cash(unit_cost)
		return {"success": false, "reason": "warehouse_capacity"}
	record_transaction("special_item_purchase", "simcash", unit_cost, balance_before, sim_cash, inventory_before, StorageManager.get_all_items(), {"source": "special_item_store", "item_id": item_id, "quantity": 1, "unlock_level": unlock_level})
	transaction_completed.emit("simcash_special_item_purchase", unit_cost)
	return {"success": true, "item_id": item_id, "amount": 1, "cost": unit_cost}

func record_transaction(
		type: String, currency: String, amount: int,
		balance_before: int, balance_after: int,
		inventory_before: Dictionary = {}, inventory_after: Dictionary = {},
		metadata: Dictionary = {}
	) -> void:
	if type.is_empty() or amount <= 0:
		return
	transaction_sequence += 1
	var entry := {
		"id": "econ-%d" % transaction_sequence,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"type": type,
		"currency": currency,
		"amount": amount,
		"balance_before": balance_before,
		"balance_after": balance_after,
		"inventory_before": inventory_before.duplicate(true),
		"inventory_after": inventory_after.duplicate(true),
		"metadata": metadata.duplicate(true)
	}
	transaction_ledger.append(entry)
	if transaction_ledger.size() > MAX_TRANSACTION_LEDGER_ENTRIES:
		transaction_ledger.pop_front()

func get_recent_transactions(limit: int = 50) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := maxi(0, transaction_ledger.size() - maxi(0, limit))
	for index in range(start, transaction_ledger.size()):
		result.append(transaction_ledger[index].duplicate(true))
	return result

func to_save_dict() -> Dictionary:
	return {
		"transaction_sequence": transaction_sequence,
		"transaction_ledger": transaction_ledger.duplicate(true)
	}

func from_save_dict(data: Dictionary) -> void:
	transaction_sequence = maxi(0, int(data.get("transaction_sequence", 0)))
	transaction_ledger.clear()
	for entry in data.get("transaction_ledger", []):
		if entry is Dictionary and not str(entry.get("id", "")).is_empty():
			transaction_ledger.append(entry.duplicate(true))
	while transaction_ledger.size() > MAX_TRANSACTION_LEDGER_ENTRIES:
		transaction_ledger.pop_front()

func get_simcash_time_skip_cost(remaining_seconds: int) -> int:
	if remaining_seconds <= 0:
		return 0
	# Mshin balancing rule: 1 SimCash per started minute, not an EA price claim.
	return maxi(1, int(ceil(float(remaining_seconds) / 60.0)))

func get_formatted_simoleons() -> String:
	if simoleons >= 1000000: return "%.1fM" % (simoleons / 1000000.0)
	if simoleons >= 1000: return "%.1fK" % (simoleons / 1000.0)
	return str(simoleons)
