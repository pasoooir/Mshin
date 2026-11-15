extends Node

func _ready() -> void:
	await get_tree().process_frame
	var original_cash := EconomyManager.sim_cash
	var original_simoleons := EconomyManager.simoleons
	var original_keys := EconomyManager.golden_keys
	var original_ledger := PaymentManager.to_save_dict()
	var original_storage := StorageManager.to_save_dict()
	var original_trade := TradeManager.to_save_dict()
	var original_land := LandExpansionManager.to_save_dict()
	var original_level := GameManager.level
	var original_population := GameManager.population
	var original_buildings := BuildManager.buildings.duplicate()
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


	# Simoleons market follows the real Global Trade HQ offer system and its
	# operational gate; it must not bypass the HQ by selling a fake direct catalog.
	GameManager.level = 1
	GameManager.population = 10000
	StorageManager.from_save_dict({"capacity": 100, "items": {}})
	EconomyManager.simoleons = 1000
	var trade_hq = load("res://scenes/buildings/Building.tscn").instantiate()
	trade_hq.building_type = "global_trade_hq"
	trade_hq.status = "completed"
	add_child(trade_hq)
	BuildManager.buildings["currency_smoke_global_trade_hq"] = trade_hq
	TradeManager.market_offers = [{"item_id": "metal", "amount": 5, "price": 75, "sold": false}]
	if not TradeManager.is_global_trade_operational():
		failures.append("Global Trade HQ should unlock at the configured population/building gate")
	var market_buy := TradeManager.buy_global_offer(0)
	if not market_buy or StorageManager.get_count("metal") != 5 or EconomyManager.simoleons != 925:
		failures.append("Global Trade HQ offer did not atomically debit Simoleons and add purchased materials")
	var before_full := EconomyManager.simoleons
	StorageManager.from_save_dict({"capacity": 5, "items": {"metal": 5}})
	TradeManager.market_offers = [{"item_id": "metal", "amount": 1, "price": 15, "sold": false}]
	if TradeManager.buy_global_offer(0) or EconomyManager.simoleons != before_full:
		failures.append("warehouse-full Global Trade HQ purchase should not charge Simoleons")
	if TradeManager.is_trade_eligible_item("electrical"):
		failures.append("locked raw material was trade-eligible before its unlock level")
	trade_hq.queue_free()
	BuildManager.buildings = original_buildings
	GameManager.population = original_population
	TradeManager.from_save_dict(original_trade)
	EconomyManager.simoleons = 6000
	StorageManager.from_save_dict({"capacity": 100, "items": {}})

	# SimCash can buy the real expansion Special Items, but does not bypass
	# the land tile's item requirements or Mayor Level gate.
	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL
	StorageManager.from_save_dict({"capacity": 100, "items": {}})
	EconomyManager.sim_cash = 500
	var expansion_tile := LandExpansionManager.get_available_expansion_tiles()[0]
	var expansion_cost := LandExpansionManager.get_tile_cost(expansion_tile)
	for item_id in LandExpansionManager.EXPANSION_ITEM_IDS:
		for _unit in range(int(expansion_cost[item_id])):
			var bought_special := EconomyManager.buy_special_item_with_simcash(str(item_id), 24, LandExpansionManager.MIN_EXPANSION_LEVEL)
			if not bool(bought_special.get("success", false)):
				failures.append("SimCash could not buy the required expansion Special Item: " + str(item_id))
	if not LandExpansionManager.expand_tile(expansion_tile):
		failures.append("purchased dozer Special Items did not satisfy the normal land expansion transaction")
	var locked_special := EconomyManager.buy_special_item_with_simcash("dozer_wheel", 24, LandExpansionManager.MIN_EXPANSION_LEVEL)
	if bool(locked_special.get("success", true)):
		failures.append("expansion Special Item purchase ignored the Mayor Level gate")
	LandExpansionManager.from_save_dict(original_land)
	GameManager.level = 1
	EconomyManager.sim_cash = 10

	# SimCash production acceleration uses remaining time, spends once and
	# leaves the completed item on its production slot until collection.
	EconomyManager.sim_cash = 10
	var factory := ProductionComponent.new()
	factory.is_factory = true
	factory.factory_type = "factory_small"
	factory.slot_count = 2
	add_child(factory)
	await get_tree().process_frame
	if not factory.start_factory("metal", 0):
		failures.append("test factory could not start a raw-material order")
	else:
		var speedup_quote := factory.get_slot_speedup_quote(0)
		var speedup_result := factory.speed_up_slot(0)
		if speedup_quote.is_empty() or not bool(speedup_result.get("success", false)) or EconomyManager.sim_cash != 9 or not bool(factory.get_slot(0).get("ready", false)):
			failures.append("SimCash did not complete the active factory timer for the quoted cost")
		if not factory.collect(0) or StorageManager.get_count("metal") != 1:
			failures.append("speeded-up production did not collect exactly one item")
	factory.queue_free()
	await get_tree().process_frame

	# Purchased commercial queue capacity must notify the HUD and persist.
	EconomyManager.sim_cash = 10
	var store := ProductionComponent.new()
	store.is_factory = false
	store.shop_id = "building_supplies"
	store.slot_count = 2
	add_child(store)
	await get_tree().process_frame
	var cash_before_slot := EconomyManager.sim_cash
	var slot_added := store.purchase_store_queue_slot(4)
	if not slot_added or store.get_slot_count() != 3 or EconomyManager.sim_cash != cash_before_slot - 4:
		failures.append("SimCash queue-slot purchase did not atomically debit and add one slot")
	var saved_slots := store.to_save_array()
	var restored_store := ProductionComponent.new()
	restored_store.is_factory = false
	restored_store.shop_id = "building_supplies"
	add_child(restored_store)
	await get_tree().process_frame
	restored_store.from_save_array(saved_slots)
	if restored_store.get_slot_count() != 3:
		failures.append("purchased commercial queue slot did not survive slot save-data restore")
	store.queue_free()
	restored_store.queue_free()
	await get_tree().process_frame

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
	if popup_controller.find_child("CitySupplyMarketHeading", true, false) == null or popup_controller.find_child("GlobalTradeMarketLocked", true, false) == null:
		failures.append("Simoleons popup did not enforce the Global Trade HQ progression gate")
	popup_controller.open_store()
	await get_tree().process_frame
	if not popup_controller.visible or popup_controller.find_child("CurrencyPopupScroll", true, false) == null:
		failures.append("SimCash plus did not open the dedicated store popup")
	if popup_controller.find_child("CityProgressBoostsHeading", true, false) == null:
		failures.append("SimCash popup did not expose city progress acceleration controls")
	if popup_controller.find_child("BuyExpansionItem_dozer_wheel", true, false) == null:
		failures.append("SimCash popup did not expose expansion Special Item purchases")
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

	StorageManager.from_save_dict(original_storage)
	GameManager.level = original_level
	EconomyManager.sim_cash = original_cash
	EconomyManager.simoleons = original_simoleons
	EconomyManager.golden_keys = original_keys
	PaymentManager.from_save_dict(original_ledger)
	if not failures.is_empty():
		for failure in failures:
			push_error("[CurrencyEconomySmoke] " + failure)
		get_tree().quit(1)
		return
	print("[CurrencyEconomySmoke] PASS: atomic conversion, Global Trade HQ Simoleons offers, SimCash land expansion Special Items, SimCash production acceleration, sandbox order success/failure/cancel, idempotency, ledger restore and dimensional icon imports")
	get_tree().quit(0)
