extends Node
signal simoleons_changed(new_amount: int)
signal sim_cash_changed(new_amount: int)
signal keys_changed(new_amount: int)
signal transaction_completed(type: String, amount: int)
const SIMCASH_TO_SIMOLEONS_RATE := 1000
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
	simoleons += amount
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simoleons_gain", amount)
	return true
func spend_simoleons(amount: int) -> bool:
	if amount <= 0 or simoleons < amount: return false
	simoleons -= amount
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simoleons_spend", amount)
	return true
func add_sim_cash(amount: int) -> bool:
	if amount <= 0: return false
	sim_cash += amount
	sim_cash_changed.emit(sim_cash)
	transaction_completed.emit("simcash_gain", amount)
	return true
func spend_sim_cash(amount: int) -> bool:
	if amount <= 0 or sim_cash < amount: return false
	sim_cash -= amount
	sim_cash_changed.emit(sim_cash)
	transaction_completed.emit("simcash_spend", amount)
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
func get_simcash_time_skip_cost(remaining_seconds: int) -> int:
	if remaining_seconds <= 0:
		return 0
	# Mshin balancing rule: 1 SimCash per started minute, not an EA price claim.
	return maxi(1, int(ceil(float(remaining_seconds) / 60.0)))

func get_formatted_simoleons() -> String:
	if simoleons >= 1000000: return "%.1fM" % (simoleons / 1000000.0)
	if simoleons >= 1000: return "%.1fK" % (simoleons / 1000.0)
	return str(simoleons)
