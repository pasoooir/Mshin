extends Node

func _ready() -> void:
	await get_tree().process_frame
	var original_cash := EconomyManager.sim_cash
	var original_simoleons := EconomyManager.simoleons
	var original_keys := EconomyManager.golden_keys
	var original_ledger := PaymentManager.to_save_dict()
	var failures: Array[String] = []

	EconomyManager.sim_cash = 25
	EconomyManager.simoleons = 1000
	var insufficient := EconomyManager.convert_sim_cash_to_simoleons(50)
	if bool(insufficient.get("success", true)) or EconomyManager.sim_cash != 25 or EconomyManager.simoleons != 1000:
		failures.append("insufficient SimCash conversion mutated balances")
	var invalid := EconomyManager.convert_sim_cash_to_simoleons(0)
	if bool(invalid.get("success", true)):
		failures.append("zero conversion amount was accepted")
	var converted := EconomyManager.convert_sim_cash_to_simoleons(5)
	if not bool(converted.get("success", false)) or EconomyManager.sim_cash != 20 or EconomyManager.simoleons != 6000:
		failures.append("valid conversion did not atomically update both balances")

	var catalog := PaymentManager.get_catalog()
	if catalog.size() != 8:
		failures.append("SimCash catalog must contain all eight configured store packs")
	var success_order := PaymentManager.create_order("simcash_pocketful")
	if not bool(success_order.get("success", false)):
		failures.append("valid SimCash order could not be created")
	else:
		var order_id := str(success_order.order.order_id)
		var before_grant := EconomyManager.sim_cash
		var paid := PaymentManager.complete_sandbox_order(order_id, "success")
		if not bool(paid.get("success", false)) or EconomyManager.sim_cash != before_grant + 275:
			failures.append("successful sandbox payment did not grant exact catalog amount")
		var retry := PaymentManager.complete_sandbox_order(order_id, "success")
		if bool(retry.get("success", true)) or EconomyManager.sim_cash != before_grant + 275:
			failures.append("duplicate callback granted SimCash more than once")

	var failed_order := PaymentManager.create_order("simcash_little_stack")
	if bool(failed_order.get("success", false)):
		var before_failure := EconomyManager.sim_cash
		var failed_result := PaymentManager.complete_sandbox_order(str(failed_order.order.order_id), "failed")
		if bool(failed_result.get("success", true)) or EconomyManager.sim_cash != before_failure:
			failures.append("failed payment granted SimCash")
	var cancelled_order := PaymentManager.create_order("simcash_nice_pile")
	if bool(cancelled_order.get("success", false)):
		var before_cancel := EconomyManager.sim_cash
		var cancelled_result := PaymentManager.complete_sandbox_order(str(cancelled_order.order.order_id), "cancelled")
		if bool(cancelled_result.get("success", true)) or EconomyManager.sim_cash != before_cancel:
			failures.append("cancelled payment granted SimCash")

	var popup_controller := preload("res://scripts/ui/CurrencyPanels.gd").new()
	add_child(popup_controller)
	popup_controller.open_conversion()
	await get_tree().process_frame
	if not popup_controller.visible or popup_controller.find_child("ConfirmSimCashConversion", true, false) == null:
		failures.append("Simoleons plus did not open the dedicated conversion popup")
	popup_controller.open_store()
	await get_tree().process_frame
	if not popup_controller.visible or popup_controller.find_child("CurrencyPopupScroll", true, false) == null:
		failures.append("SimCash plus did not open the dedicated store popup")
	popup_controller.close_panel()
	popup_controller.queue_free()

	var ledger_snapshot := PaymentManager.to_save_dict()
	PaymentManager.from_save_dict(ledger_snapshot)
	if PaymentManager.get_recent_orders(10).size() < 3:
		failures.append("purchase ledger did not survive save-data round trip")
	for asset in ["simcash_bundle.png", "simoleons_coins.png", "bonus_gift.png"]:
		var path: String = "res://assets/icons/ui/currency/" + asset
		if not ResourceLoader.exists(path) or ResourceLoader.load(path) == null:
			failures.append("3D currency icon failed to load: " + asset)

	EconomyManager.sim_cash = original_cash
	EconomyManager.simoleons = original_simoleons
	EconomyManager.golden_keys = original_keys
	PaymentManager.from_save_dict(original_ledger)
	if not failures.is_empty():
		for failure in failures:
			push_error("[CurrencyEconomySmoke] " + failure)
		get_tree().quit(1)
		return
	print("[CurrencyEconomySmoke] PASS: atomic conversion, sandbox order success/failure/cancel, idempotency, ledger restore and dimensional icon imports")
	get_tree().quit(0)
