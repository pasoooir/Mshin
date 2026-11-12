extends Node

signal simoleons_changed(new_amount: int)
signal keys_changed(new_amount: int)
signal transaction_completed(type: String, amount: int)

var simoleons: int = 25000
var golden_keys: int = 10
var sim_cash: int = 25
var tax_income_per_minute: int = 0
var last_tax_time: float = 0.0

func _ready() -> void:
	print("[EconomyManager] Economy system online")
	last_tax_time = Time.get_unix_time_from_system()

func _process(_delta: float) -> void:
	var now = Time.get_unix_time_from_system()
	if now - last_tax_time >= 60.0:
		last_tax_time = now
		if tax_income_per_minute > 0:
			add_simoleons(tax_income_per_minute)

func add_simoleons(amount: int) -> void:
	if amount <= 0:
		return
	simoleons += amount
	simoleons_changed.emit(simoleons)
	transaction_completed.emit("simoleons_gain", amount)

func spend_simoleons(amount: int) -> bool:
	if amount <= 0:
		return false
	if simoleons >= amount:
		simoleons -= amount
		simoleons_changed.emit(simoleons)
		transaction_completed.emit("simoleons_spend", amount)
		return true
	return false

func can_afford(amount: int) -> bool:
	return simoleons >= amount

func add_keys(amount: int) -> void:
	golden_keys += amount
	keys_changed.emit(golden_keys)

func spend_keys(amount: int) -> bool:
	if amount <= 0:
		return false
	if golden_keys >= amount:
		golden_keys -= amount
		keys_changed.emit(golden_keys)
		return true
	return false

func set_tax_income(amount: int) -> void:
	tax_income_per_minute = max(0, amount)

func get_formatted_simoleons() -> String:
	if simoleons >= 1000000:
		return "%.1fM" % (simoleons / 1000000.0)
	elif simoleons >= 1000:
		return "%.1fK" % (simoleons / 1000.0)
	return str(simoleons)
