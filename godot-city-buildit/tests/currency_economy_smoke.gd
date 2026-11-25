extends Node

func _reference_plot_in_bounds(tile: Vector2i) -> bool:
	if (
		tile.x < LandExpansionManager.EXPANSION_MIN_TILE_X
		or tile.x > LandExpansionManager.EXPANSION_MAX_TILE_X
		or tile.y < LandExpansionManager.EXPANSION_MIN_TILE_Y
		or tile.y > LandExpansionManager.EXPANSION_MAX_TILE_Y
	):
		return false
	for cell_x in range(tile.x * LandExpansionManager.TILE_CELLS, (tile.x + 1) * LandExpansionManager.TILE_CELLS):
		for cell_y in range(tile.y * LandExpansionManager.TILE_CELLS, (tile.y + 1) * LandExpansionManager.TILE_CELLS):
			if not LandExpansionManager.is_cell_inside_coastal_build_boundary(Vector2i(cell_x, cell_y)):
				return false
	return true


func _audit_all_production_chains(failures: Array[String]) -> void:
	var raw_values: Dictionary = ProductionManager.raw_materials
	var recipes: Dictionary = ProductionManager.crafted_items
	var rows: Array[Dictionary] = []
	var missing_inputs: Array[String] = []
	for item_variant in recipes.keys():
		var item_id := str(item_variant)
		var recipe: Dictionary = recipes[item_variant]
		var expanded := _expand_recipe_cost(item_id, [], missing_inputs)
		var output_value := int(recipe.get("value", 0))
		var raw_cost := int(expanded.get("raw_cost", -1))
		var total_work_seconds := int(expanded.get("work_seconds", 0))
		if raw_cost < 0 or output_value <= 0:
			failures.append("Production-chain audit could not resolve recipe economics for " + item_id)
			continue
		var gross_margin := output_value - raw_cost
		var hq_buy_cost := raw_cost * 2
		var hq_margin := output_value - hq_buy_cost
		rows.append({
			"item": item_id, "sale_reference": output_value, "raw_input_opportunity_cost": raw_cost,
			"gross_margin": gross_margin, "gross_margin_percent": snappedf(float(gross_margin) / float(maxi(raw_cost, 1)) * 100.0, 0.1),
			"total_serial_work_seconds": total_work_seconds, "hq_input_cost_at_2x": hq_buy_cost,
			"margin_after_hq_inputs": hq_margin
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.margin_after_hq_inputs) < int(b.margin_after_hq_inputs))
	print("[EconomyChainAudit] recipes=", rows.size(), " unresolved_inputs=", missing_inputs.size())
	for row in rows:
		print("[EconomyChainAudit] ", JSON.stringify(row))
	for missing in missing_inputs:
		failures.append("Production-chain audit found unresolved ingredient: " + missing)
	if rows.size() != recipes.size():
		failures.append("Production-chain audit did not cover every catalog recipe")
	for multiplier in [1.0, 1.5, 2.0, 2.5, 3.0]:
		var profitable_count := 0
		var loss_count := 0
		for row in rows:
			var scenario_margin := float(row.sale_reference) - float(row.raw_input_opportunity_cost) * float(multiplier)
			if scenario_margin > 0.0:
				profitable_count += 1
			elif scenario_margin < 0.0:
				loss_count += 1
		print("[EconomyChainAudit] input_cost_multiplier=", multiplier, " loss_making_recipes=", loss_count, " profitable_recipes=", profitable_count, " total=", rows.size())
		if multiplier == 2.0 and loss_count != 12:
			failures.append("Global Trade HQ 2x scenario changed: review all production chain prices before accepting economy balance")


func _expand_recipe_cost(item_id: String, ancestry: Array[String], missing_inputs: Array[String]) -> Dictionary:
	if ancestry.has(item_id):
		missing_inputs.append("recipe cycle: " + " -> ".join(ancestry + [item_id]))
		return {"raw_cost": -1, "work_seconds": 0}
	var next_ancestry := ancestry.duplicate()
	next_ancestry.append(item_id)
	var recipe: Dictionary = ProductionManager.crafted_items.get(item_id, {})
	if recipe.is_empty():
		var raw: Dictionary = ProductionManager.raw_materials.get(item_id, {})
		if raw.is_empty():
			missing_inputs.append(item_id)
			return {"raw_cost": -1, "work_seconds": 0}
		return {"raw_cost": int(raw.get("value", 0)), "work_seconds": int(raw.get("time_sec", 0))}
	var raw_cost := 0
	var work_seconds := int(recipe.get("time_sec", 0))
	var requires: Dictionary = recipe.get("requires", {})
	for input_variant in requires.keys():
		var input_id := str(input_variant)
		var amount := int(requires[input_variant])
		var child := _expand_recipe_cost(input_id, next_ancestry, missing_inputs)
		if int(child.raw_cost) < 0:
			return {"raw_cost": -1, "work_seconds": work_seconds}
		raw_cost += int(child.raw_cost) * amount
		work_seconds += int(child.work_seconds) * amount
	return {"raw_cost": raw_cost, "work_seconds": work_seconds}


func _ready() -> void:
	await get_tree().process_frame
	var original_cash := EconomyManager.sim_cash
	var original_simoleons := EconomyManager.simoleons
	var original_keys := EconomyManager.golden_keys
	var original_ledger := PaymentManager.to_save_dict()
	var original_economy_ledger := EconomyManager.to_save_dict()
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

	# Community reference-price regression checks. These are maximum Trade
	# Depot sale values, not EA-guaranteed purchase prices or guaranteed profit.
	var community_max_sale_prices := {
		"metal": 10, "wood": 20, "plastic": 25, "seeds": 30,
		"minerals": 40, "chemicals": 60, "textiles": 90,
		"sugar_spices": 110, "glass": 120, "animal_feed": 140,
		"electrical": 160, "nails": 80, "planks": 120,
		"bricks": 190, "cement": 440, "glue": 440, "paint": 320,
		"hammer": 90, "measuring_tape": 110, "shovel": 150,
		"cooking_utensils": 250
	}
	for priced_item in community_max_sale_prices:
		if ProductionManager.get_item_value(str(priced_item)) != int(community_max_sale_prices[priced_item]):
			failures.append("Trade Depot price catalog differs from community max-sale reference for " + str(priced_item))
	var known_recipe_margins := {
		"nails": 60, "planks": 80, "bricks": 110,
		"cement": 300, "glue": 295, "paint": 140,
		"hammer": 60, "measuring_tape": 75, "shovel": 95
	}
	for recipe_item in known_recipe_margins:
		var recipe: Dictionary = ProductionManager.crafted_items.get(str(recipe_item), {})
		var input_cost := 0
		for input_id in recipe.get("requires", {}):
			input_cost += ProductionManager.get_item_value(str(input_id)) * int(recipe.requires[input_id])
		var expected_margin := int(community_max_sale_prices.get(recipe_item, 0)) - input_cost
		if expected_margin != int(known_recipe_margins[recipe_item]):
			failures.append("Reference production margin mismatch for " + str(recipe_item))

	# Full Trade Depot lifecycle: reserve on listing, block unsafe cancellation
	# when the warehouse has no room, return goods on cancel, and pay once on collect.
	GameManager.population = 8000
	var depot: Variant = load("res://scenes/buildings/Building.tscn").instantiate()
	depot.building_type = "trade_depot"
	depot.status = "completed"
	add_child(depot)
	BuildManager.buildings["currency_smoke_trade_depot"] = depot
	TradeManager.sell_slots.clear()
	StorageManager.from_save_dict({"capacity": 3, "items": {"metal": 2}})
	var listing_inventory_before := StorageManager.get_all_items()
	if not TradeManager.list_for_sale("metal", 2):
		failures.append("Trade Depot rejected a valid listing despite sufficient inventory and an operational depot")
	if StorageManager.get_count("metal") != 0 or TradeManager.sell_slots.size() != 1:
		failures.append("Trade Depot listing did not reserve the exact quantity from City Storage")
	var listing_inventory_after := StorageManager.get_all_items()
	if listing_inventory_before.get("metal", 0) != 2 or listing_inventory_after.get("metal", 0) != 0:
		failures.append("Trade Depot reservation inventory before/after snapshot is incorrect")
	StorageManager.add_item("wood", 3)
	var full_inventory_before_cancel := StorageManager.get_all_items()
	var listing_count_before_cancel := TradeManager.sell_slots.size()
	if TradeManager.cancel_sale_listing(0):
		failures.append("Trade Depot allowed cancellation while the warehouse had no capacity for the reserved goods")
	if StorageManager.get_all_items() != full_inventory_before_cancel or TradeManager.sell_slots.size() != listing_count_before_cancel:
		failures.append("failed full-warehouse cancellation mutated inventory or removed the listing")
	StorageManager.remove_item("wood", 2)
	var cancel_inventory_before := StorageManager.get_all_items()
	if not TradeManager.cancel_sale_listing(0):
		failures.append("Trade Depot could not cancel a listing after enough warehouse capacity was freed")
	if StorageManager.get_count("metal") != 2 or not TradeManager.sell_slots.is_empty():
		failures.append("successful Trade Depot cancellation did not return all reserved goods and remove the listing")
	var cancel_audit := EconomyManager.get_recent_transactions(1)
	if cancel_audit.is_empty() or str(cancel_audit[0].get("type", "")) != "trade_listing_cancelled" or cancel_audit[0].get("inventory_before", {}) != cancel_inventory_before or cancel_audit[0].get("inventory_after", {}).get("metal", 0) != 2:
		failures.append("Trade Depot cancellation ledger is missing correct before/after inventory snapshots")

	StorageManager.from_save_dict({"capacity": 3, "items": {"metal": 1}})
	var sale_balance_before := EconomyManager.simoleons
	if not TradeManager.list_for_sale("metal", 1):
		failures.append("Trade Depot could not create the sale collection test listing")
	else:
		var sale_listing: Dictionary = TradeManager.sell_slots[0]
		sale_listing["ready"] = true
		TradeManager.sell_slots[0] = sale_listing
		if not TradeManager.collect_sale(0):
			failures.append("Trade Depot failed to collect a ready sale")
		if EconomyManager.simoleons != sale_balance_before + ProductionManager.get_item_value("metal"):
			failures.append("Trade Depot sale did not credit the exact configured sale value once")
		if not TradeManager.sell_slots.is_empty():
			failures.append("collected Trade Depot listing was not removed")
	var sale_audit := EconomyManager.get_recent_transactions(1)
	if sale_audit.is_empty() or str(sale_audit[0].get("type", "")) != "trade_sale_collected" or int(sale_audit[0].get("balance_after", -1)) != EconomyManager.simoleons:
		failures.append("Trade Depot sale ledger is missing the balance after collection")
	var economy_ledger_snapshot := EconomyManager.to_save_dict()
	EconomyManager.transaction_ledger.clear()
	EconomyManager.from_save_dict(economy_ledger_snapshot)
	if EconomyManager.get_recent_transactions(10).is_empty():
		failures.append("economy transaction ledger did not survive save-data round trip")
	depot.queue_free()
	BuildManager.buildings = original_buildings
	TradeManager.from_save_dict(original_trade)
	GameManager.population = original_population
	TradeManager.from_save_dict(original_trade)
	EconomyManager.simoleons = 6000
	StorageManager.from_save_dict({"capacity": 100, "items": {}})

	# City Storage uses the three actual Special Items, with 18 SimCash
	# purchase price and a five-slot upgrade consuming equal quantities.
	GameManager.level = StorageManager.STORAGE_UNLOCK_LEVEL
	StorageManager.from_save_dict({"capacity": 50, "items": {}})
	EconomyManager.sim_cash = 100
	for storage_item_id in StorageManager.STORAGE_ITEM_IDS:
		var storage_purchase := EconomyManager.buy_special_item_with_simcash(str(storage_item_id), StorageManager.STORAGE_ITEM_SIMCASH_PRICE, StorageManager.STORAGE_UNLOCK_LEVEL)
		if not bool(storage_purchase.get("success", false)):
			failures.append("could not buy City Storage Special Item " + str(storage_item_id))
		if StorageManager.get_count(str(storage_item_id)) != 1:
			failures.append("purchased City Storage Special Item was not stored")
	var purchase_audit := EconomyManager.get_recent_transactions(1)
	if purchase_audit.is_empty() or str(purchase_audit[0].get("type", "")) != "special_item_purchase" or purchase_audit[0].get("inventory_after", {}).get("storage_camera", 0) != 1:
		failures.append("Storage Special Item purchase audit is missing its inventory before/after snapshot")
	var capacity_before := StorageManager.capacity
	var storage_upgrade := StorageManager.upgrade_storage_with_items()
	if not bool(storage_upgrade.get("success", false)) or StorageManager.capacity != capacity_before + 5:
		failures.append("City Storage upgrade did not consume the three parts and add exactly five slots")
	for storage_item_id in StorageManager.STORAGE_ITEM_IDS:
		if StorageManager.get_count(str(storage_item_id)) != 0:
			failures.append("City Storage upgrade did not consume " + str(storage_item_id))
	var upgrade_audit := EconomyManager.get_recent_transactions(1)
	if upgrade_audit.is_empty() or str(upgrade_audit[0].get("type", "")) != "storage_capacity_upgrade" or upgrade_audit[0].get("inventory_before", {}).get("storage_bar", 0) != 1 or upgrade_audit[0].get("inventory_after", {}).get("storage_bar", 0) != 0:
		failures.append("City Storage upgrade audit is missing exact consumed inventory snapshots")
	# Regression-test the community-published capacity thresholds; values
	# are quantities required of EACH of the three storage parts.
	var expected_storage_requirements := {
		40: 1, 50: 1, 55: 2, 70: 3, 85: 4, 105: 5, 205: 10,
		230: 11, 455: 20, 495: 21, 520: 22, 545: 23, 570: 24, 585: 25, 995: 25
	}
	for capacity_key in expected_storage_requirements:
		StorageManager.capacity = int(capacity_key)
		if StorageManager.get_next_storage_upgrade_requirement() != int(expected_storage_requirements[capacity_key]):
			failures.append("City Storage community threshold mismatch at capacity %d" % int(capacity_key))
	StorageManager.capacity = capacity_before + 5
	var no_parts_upgrade := StorageManager.upgrade_storage_with_items()
	if bool(no_parts_upgrade.get("success", true)) or StorageManager.capacity != capacity_before + 5:
		failures.append("City Storage upgraded without the full three-item requirement")
	var legacy_bypass := StorageManager.try_upgrade_capacity(500, 10)
	if legacy_bypass or StorageManager.capacity != capacity_before + 5:
		failures.append("legacy Simoleons-only capacity bypass remains active")
	GameManager.level = 3
	var locked_storage_upgrade := StorageManager.upgrade_storage_with_items()
	if bool(locked_storage_upgrade.get("success", true)):
		failures.append("City Storage Special Item upgrade ignored level 4 unlock")
	GameManager.level = 1
	StorageManager.from_save_dict(original_storage)

	# SimCash can buy the real expansion Special Items, but does not bypass
	# the land tile's item requirements or Mayor Level gate.
	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL
	StorageManager.from_save_dict({"capacity": 100, "items": {}})
	EconomyManager.sim_cash = 500
	var expansion_tile := LandExpansionManager.get_available_expansion_tiles()[0]
	if LandExpansionManager.get_tile_state(expansion_tile) != "available":
		failures.append("adjacent unowned plot was not classified as immediately available")
	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL - 1
	if LandExpansionManager.get_tile_state(expansion_tile) != "level_locked":
		failures.append("adjacent expansion plot was not visibly classified as Mayor-Level locked")
	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL
	if LandExpansionManager.get_tile_state(LandExpansionManager.get_owned_tiles()[0]) != "owned":
		failures.append("starter land was not classified as owned")
	if LandExpansionManager.get_tile_area_square_meters() != 256:
		failures.append("8x8 plot dimensions no longer resolve to a 256 m² land parcel")
	var found_locked_plot := false
	for plot_x in range(LandExpansionManager.EXPANSION_MIN_TILE_X, LandExpansionManager.EXPANSION_MAX_TILE_X + 1):
		for plot_y in range(LandExpansionManager.EXPANSION_MIN_TILE_Y, LandExpansionManager.EXPANSION_MAX_TILE_Y + 1):
			var candidate := Vector2i(plot_x, plot_y)
			if LandExpansionManager.get_tile_state(candidate) == "locked":
				found_locked_plot = true
				break
		if found_locked_plot:
			break
	if not found_locked_plot:
		failures.append("future non-adjacent plots are not represented as locked land")
	if LandExpansionManager.get_tile_distance(expansion_tile) < 1:
		failures.append("expansion ring distance must be measured from the free starter area")
	# Only complete inland parcels may appear in the purchase list. This
	# catches regressions where the UI shows coastal/partial tiles that the
	# transaction itself would later reject.
	var available_tiles := LandExpansionManager.get_available_expansion_tiles()
	var available_keys: Dictionary = {}
	for available_tile in available_tiles:
		var available_key := "%d:%d" % [available_tile.x, available_tile.y]
		if available_keys.has(available_key):
			failures.append("expansion purchase list contains a duplicate plot")
		available_keys[available_key] = true
		if not LandExpansionManager._is_tile_in_bounds(available_tile):
			failures.append("expansion purchase list contains a plot crossing the coastline")
		if LandExpansionManager.is_tile_owned(available_tile) or not LandExpansionManager._is_adjacent_to_owned(available_tile):
			failures.append("expansion purchase list contains owned or disconnected land")
	for plot_x in range(LandExpansionManager.EXPANSION_MIN_TILE_X, LandExpansionManager.EXPANSION_MAX_TILE_X + 1):
		for plot_y in range(LandExpansionManager.EXPANSION_MIN_TILE_Y, LandExpansionManager.EXPANSION_MAX_TILE_Y + 1):
			var candidate := Vector2i(plot_x, plot_y)
			var expected_bounds := _reference_plot_in_bounds(candidate)
			var actual_bounds := LandExpansionManager._is_tile_in_bounds(candidate)
			if actual_bounds != expected_bounds:
				failures.append("cached coastal parcel boundary differs from exhaustive 64-cell reference at %s" % str(candidate))
			if not actual_bounds and available_keys.has("%d:%d" % [plot_x, plot_y]):
				failures.append("coastal boundary plot was incorrectly exposed as purchasable")
	if available_tiles.is_empty():
		failures.append("starter city has no adjacent expansion plots")

	var expansion_cost := LandExpansionManager.get_tile_cost(expansion_tile)
	for item_id in LandExpansionManager.EXPANSION_ITEM_IDS:
		for _unit in range(int(expansion_cost[item_id])):
			var bought_special := EconomyManager.buy_special_item_with_simcash(str(item_id), 24, LandExpansionManager.MIN_EXPANSION_LEVEL)
			if not bool(bought_special.get("success", false)):
				failures.append("SimCash could not buy the required expansion Special Item: " + str(item_id))
	if not LandExpansionManager.expand_tile(expansion_tile):
		failures.append("purchased dozer Special Items did not satisfy the normal land expansion transaction")
	else:
		var newly_owned_cell := Vector2i(expansion_tile.x * LandExpansionManager.TILE_CELLS + 2, expansion_tile.y * LandExpansionManager.TILE_CELLS + 2)
		if not LandExpansionManager.is_cell_buildable(newly_owned_cell) or not LandExpansionManager.is_cell_road_buildable(newly_owned_cell):
			failures.append("claiming a land plot did not immediately unlock its interior for buildings and roads")
		if LandExpansionManager.get_tile_state(expansion_tile) != "owned":
			failures.append("successfully purchased plot did not transition to owned state")
	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL - 1
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
	var factory_balance_before_order := EconomyManager.simoleons
	var expected_metal_order_cost := ProductionManager.get_factory_order_cost("metal")
	if expected_metal_order_cost != 5:
		failures.append("Mshin factory order fee for the 60-second starter metal order must be 5 Simoleons")
	if not factory.start_factory("metal", 0):
		failures.append("test factory could not start a raw-material order")
	else:
		if EconomyManager.simoleons != factory_balance_before_order - expected_metal_order_cost or int(factory.get_slot(0).get("order_cost", -1)) != expected_metal_order_cost:
			failures.append("factory order did not atomically debit and retain its exact Simoleons price")
		var factory_charge_audit := EconomyManager.get_recent_transactions(1)
		if factory_charge_audit.is_empty() or str(factory_charge_audit[0].get("metadata", {}).get("source", "")) != "factory_order" or str(factory_charge_audit[0].get("metadata", {}).get("item_id", "")) != "metal":
			failures.append("factory order Simoleons debit is missing its factory/item audit metadata")
		var speedup_quote := factory.get_slot_speedup_quote(0)
		var speedup_result := factory.speed_up_slot(0)
		if speedup_quote.is_empty() or not bool(speedup_result.get("success", false)) or EconomyManager.sim_cash != 9 or not bool(factory.get_slot(0).get("ready", false)):
			failures.append("SimCash did not complete the active factory timer for the quoted cost")
		if not factory.collect(0) or StorageManager.get_count("metal") != 1:
			failures.append("speeded-up production did not collect exactly one item")
	var balance_before_rejected_order := EconomyManager.simoleons
	EconomyManager.simoleons = 0
	var rejected_for_funds := factory.start_factory("metal", 1)
	if rejected_for_funds or not factory.get_slot(1).is_empty() or EconomyManager.simoleons != 0:
		failures.append("factory accepted an unaffordable order or mutated its queue/balance")
	EconomyManager.simoleons = balance_before_rejected_order
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

	GameManager.level = LandExpansionManager.MIN_EXPANSION_LEVEL
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
	GameManager.level = original_level

	var ledger_snapshot := PaymentManager.to_save_dict()
	PaymentManager.from_save_dict(ledger_snapshot)
	if PaymentManager.get_recent_orders(10).size() < 3:
		failures.append("purchase ledger did not survive save-data round trip")
	for asset in ["simcash_bundle.png", "simoleons_coins.png", "bonus_gift.png"]:
		var path: String = "res://assets/icons/ui/currency/" + asset
		if not ResourceLoader.exists(path) or ResourceLoader.load(path) == null:
			failures.append("3D currency icon failed to load: " + asset)
	# City expansion uses the three distinct bulldozer Special Items as local PNGs.
	for expansion_item_id in LandExpansionManager.EXPANSION_ITEM_IDS:
		var expansion_icon_path := "res://assets/icons/special/%s.png" % str(expansion_item_id)
		if not ResourceLoader.exists(expansion_icon_path):
			failures.append("land expansion PNG icon is missing: " + str(expansion_item_id))
			continue
		var expansion_texture := ResourceLoader.load(expansion_icon_path) as Texture2D
		if expansion_texture == null or expansion_texture.get_image() == null or expansion_texture.get_image().is_empty():
			failures.append("land expansion PNG icon failed to import: " + str(expansion_item_id))
	var icon_catalog: Script = load("res://scripts/ui/Icons.gd")
	if icon_catalog.get_icon_tex("dozer_wheel") == null or icon_catalog.get_icon_tex("dozer_blade") == null or icon_catalog.get_icon_tex("dozer_exhaust") == null:
		failures.append("land expansion item catalog does not resolve all three dozer icons")

	StorageManager.from_save_dict(original_storage)
	GameManager.level = original_level
	EconomyManager.sim_cash = original_cash
	EconomyManager.simoleons = original_simoleons
	EconomyManager.golden_keys = original_keys
	PaymentManager.from_save_dict(original_ledger)
	EconomyManager.from_save_dict(original_economy_ledger)
	_audit_all_production_chains(failures)
	if not failures.is_empty():
		for failure in failures:
			push_error("[CurrencyEconomySmoke] " + failure)
		get_tree().quit(1)
		return
	print("[CurrencyEconomySmoke] PASS: atomic conversion, Global Trade HQ Simoleons offers, SimCash land expansion Special Items, SimCash production acceleration, sandbox order success/failure/cancel, idempotency, ledger restore and dimensional icon imports")
	get_tree().quit(0)
