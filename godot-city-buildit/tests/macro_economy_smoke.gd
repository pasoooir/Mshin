extends SceneTree

const Simulator = preload("res://scripts/economy/MacroEconomySimulator.gd")
const ProductionSimulator = preload("res://scripts/economy/ProductionCapacitySimulator.gd")

var failed := false

func _initialize() -> void:
	var values := {"metal": 10, "nails": 80}
	var base_config := {
		"initial_simoleons": 10000,
		"population": 1000,
		"happiness": 100.0,
		"occupied_homes": 0,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 86400,
		"item_values": values,
		"events": [
			{"type": "depot_sale", "item_id": "metal", "quantity": 3, "listed_at_seconds": 0, "at_seconds": 120},
			{"type": "hq_purchase", "item_id": "metal", "quantity": 2, "at_seconds": 60},
			{"type": "delivery_order", "item_id": "nails", "quantity": 2, "at_seconds": 60},
			{"type": "construction", "amount": 100, "at_seconds": 60}
		]
	}
	var two_x := base_config.duplicate(true)
	two_x["hq_multiplier"] = 2.0
	var result_2x: Dictionary = Simulator.simulate(two_x)
	if not bool(result_2x.get("valid", false)):
		_fail("2x scenario invalid: " + str(result_2x.get("errors", [])))
		return
	if int(result_2x.get("source_breakdown", {}).get("taxes", 0)) != 216000:
		_fail("tax projection does not match the live population × happiness × 0.15/min rule")
		return
	if int(result_2x.get("source_breakdown", {}).get("depot_sales", 0)) != 30:
		_fail("Trade Depot sale did not settle at catalog value after 120 seconds")
		return

	var too_early := base_config.duplicate(true)
	too_early["events"][0]["at_seconds"] = 119
	var early_result: Dictionary = Simulator.simulate(too_early)
	if bool(early_result.get("valid", true)) or int(early_result.get("source_breakdown", {}).get("depot_sales", 0)) != 0:
		_fail("Trade Depot collection was accepted before the 120-second ready time")
		return
	if int(result_2x.get("source_breakdown", {}).get("delivery_orders", 0)) != 320:
		_fail("delivery order reward does not match the live 2x catalog formula")
		return
	if int(result_2x.get("sink_breakdown", {}).get("global_trade_hq", 0)) != 40:
		_fail("2x Global Trade HQ purchase multiplier was not applied")
		return
	if int(result_2x.get("sink_breakdown", {}).get("construction", 0)) != 100:
		_fail("construction sink was not included")
		return

	var one_x := base_config.duplicate(true)
	one_x["hq_multiplier"] = 1.0
	var result_1x: Dictionary = Simulator.simulate(one_x)
	if int(result_1x.get("sink_breakdown", {}).get("global_trade_hq", 0)) != 20:
		_fail("1x HQ scenario did not halve the current 2x purchase cost")
		return
	if int(result_1x.get("ending_simoleons", 0)) - int(result_2x.get("ending_simoleons", 0)) != 20:
		_fail("HQ multiplier scenario delta is not deterministic")
		return

	var xp_config := {
		"initial_simoleons": 0,
		"population": 0,
		"happiness": 100.0,
		"occupied_homes": 1,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 360,
		"xp_table": {2: 30},
		"item_values": {},
		"events": []
	}
	var xp_result: Dictionary = Simulator.simulate(xp_config)
	if int(xp_result.get("ending_level", 0)) != 2 or int(xp_result.get("ending_experience", -1)) != 0:
		_fail("happiness XP cadence or level-up threshold did not match the live rules")
		return
	if int(xp_result.get("source_breakdown", {}).get("level_rewards", 0)) != 200:
		_fail("level-up Simoleon reward does not match new_level × 100")
		return

	_test_production_capacity_and_cashflow()
	_test_delivery_order_inventory_and_costs()
	_test_automatic_chain_dependency_replay()
	if failed:
		push_error("[MacroEconomySmoke] FAIL: one or more assertions failed.")
		quit(1)
		return
	print("[MacroEconomySmoke] PASS")
	quit(0)


func _test_delivery_order_inventory_and_costs() -> void:
	var config := {
		"initial_simoleons": 100,
		"population": 0,
		"happiness": 100.0,
		"occupied_homes": 0,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 1,
		"item_values": {"nails": 80},
		"events": [],
		"production": {
			"storage_capacity": 5,
			"depot_operational": true,
			"initial_inventory": {"nails": 1},
			"initial_unit_costs": {"nails": 30},
			"raw_materials": {},
			"crafted_items": {},
			"factory_materials": {},
			"facilities": [],
			"actions": [{"type": "delivery_order", "order_id": "order-1", "item_id": "nails", "quantity": 1, "reward": 80, "at_seconds": 1}]
		}
	}
	var result: Dictionary = Simulator.simulate(config)
	if not bool(result.get("valid", false)):
		_fail("Delivery-order inventory simulation invalid: " + str(result.get("errors", [])))
		return
	if int(result.get("source_breakdown", {}).get("delivery_orders", -1)) != 80 or int(result.get("ending_simoleons", -1)) != 180:
		_fail("Explicit delivery order must add its exact reward to macro cashflow.")
		return
	if result.get("production", {}).get("ending_inventory", {}).has("nails"):
		_fail("Delivery order must consume the requested inventory from the production simulation.")
		return
	var accounting: Dictionary = result.get("production_accounting", {})
	if int(accounting.get("gross_revenue", -1)) != 80 or int(accounting.get("known_cogs", -1)) != 30 or int(accounting.get("known_gross_margin", -1)) != 50:
		_fail("Delivery order must propagate FIFO COGS 30 and report gross margin 50.")
		return
	var unknown_config: Dictionary = config.duplicate(true)
	unknown_config["production"].erase("initial_unit_costs")
	var unknown_result: Dictionary = Simulator.simulate(unknown_config)
	var unknown_accounting: Dictionary = unknown_result.get("production_accounting", {})
	var unknown_sales: Array = unknown_accounting.get("sales", [])
	if bool(unknown_accounting.get("gross_margin_complete", true)) or int(unknown_accounting.get("unknown_cost_sale_quantity", 0)) != 1:
		_fail("Delivery order with unknown inventory acquisition cost must not claim complete gross margin.")
		return
	if unknown_sales.size() != 1 or unknown_sales[0].get("gross_margin", 0) != null:
		_fail("Delivery order with unknown COGS must report null margin rather than fabricate a cost.")
		return

func _fail(message: String) -> void:
	failed = true
	push_error("[MacroEconomySmoke] " + message)

func _test_production_capacity_and_cashflow() -> void:
	var production_config := {
		"storage_capacity": 2,
		"depot_operational": true,
		"initial_inventory": {},
		"raw_materials": {"metal": {"time_sec": 60}},
		"crafted_items": {},
		"factory_materials": {"factory_small": ["metal"]},
		"facilities": [
			{"id": "factory-a", "kind": "factory", "factory_type": "factory_small", "slot_count": 2}
		],
		"actions": [
			{"type": "start_factory", "facility_id": "factory-a", "item_id": "metal", "at_seconds": 0},
			{"type": "start_factory", "facility_id": "factory-a", "item_id": "metal", "at_seconds": 0},
			{"type": "collect", "facility_id": "factory-a", "slot_index": 0, "at_seconds": 60},
			{"type": "collect", "facility_id": "factory-a", "slot_index": 1, "at_seconds": 60},
			{"type": "depot_list", "listing_id": "metal-sale-1", "item_id": "metal", "quantity": 1, "at_seconds": 61},
			{"type": "depot_collect", "listing_id": "metal-sale-1", "at_seconds": 180},
			{"type": "depot_collect", "listing_id": "metal-sale-1", "at_seconds": 181}
		]
	}
	var macro_config := {
		"initial_simoleons": 100,
		"population": 0,
		"happiness": 100.0,
		"occupied_homes": 0,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 240,
		"item_values": {"metal": 10},
		"events": [],
		"production": production_config
	}
	var integrated: Dictionary = Simulator.simulate(macro_config)
	if not bool(integrated.get("valid", false)):
		_fail("Production/cashflow integration invalid: " + str(integrated.get("errors", [])))
		return
	var production: Dictionary = integrated.get("production", {})
	if int(production.get("collected_outputs", {}).get("metal", 0)) != 2:
		_fail("Parallel factory slots did not complete and collect both outputs.")
		return
	if int(integrated.get("source_breakdown", {}).get("production_sales", 0)) != 10:
		_fail("Trade Depot collection after its 120-second timer did not flow into macro Simoleon income.")
		return
	if int(production.get("rejected_actions", 0)) != 1:
		_fail("Trade Depot collection before 120 seconds must be rejected exactly once.")
		return
	if int(production.get("ending_inventory", {}).get("metal", 0)) != 1:
		_fail("Production sale did not remove exactly one item from warehouse inventory.")
		return

	var store_config := {
		"horizon_seconds": 600,
		"storage_capacity": 4,
		"initial_inventory": {"metal": 4},
		"raw_materials": {},
		"crafted_items": {"nails": {"time_sec": 300, "store": "building_supplies", "requires": {"metal": 2}}},
		"factory_materials": {},
		"facilities": [
			{"id": "store-a", "kind": "store", "shop_id": "building_supplies", "slot_count": 2}
		],
		"actions": [
			{"type": "enqueue_store", "facility_id": "store-a", "item_id": "nails", "at_seconds": 0},
			{"type": "enqueue_store", "facility_id": "store-a", "item_id": "nails", "at_seconds": 0},
			{"type": "collect", "facility_id": "store-a", "slot_index": 0, "at_seconds": 300},
			{"type": "collect", "facility_id": "store-a", "slot_index": 1, "at_seconds": 600}
		]
	}
	var store_result: Dictionary = ProductionSimulator.simulate(store_config)
	if not bool(store_result.get("valid", false)):
		_fail("Commercial queue simulation invalid: " + str(store_result.get("errors", [])))
		return
	if int(store_result.get("consumed_inputs", {}).get("metal", 0)) != 4:
		_fail("Commercial queue did not atomically reserve the full inputs for both accepted orders.")
		return
	if int(store_result.get("collected_outputs", {}).get("nails", 0)) != 2:
		_fail("Commercial store did not serialize two queued orders through its single active lane.")
		return


	var gate_config := {
		"horizon_seconds": 0,
		"storage_capacity": 5,
		"initial_inventory": {"metal": 1, "wood": 1},
		"mayor_level": 1,
		"raw_materials": {},
		"crafted_items": {
			"locked_item": {"time_sec": 60, "store": "building_supplies", "level": 2, "requires": {"metal": 2, "wood": 1}},
			"unknown_unlock": {"time_sec": 60, "store": "building_supplies", "level": 0, "unlock_level_verified": false, "requires": {"metal": 1}}
		},
		"factory_materials": {},
		"facilities": [
			{"id": "store-gates", "kind": "store", "shop_id": "building_supplies", "slot_count": 2}
		],
		"actions": [
			{"type": "enqueue_store", "facility_id": "store-gates", "item_id": "locked_item", "at_seconds": 0},
			{"type": "enqueue_store", "facility_id": "store-gates", "item_id": "unknown_unlock", "at_seconds": 0}
		]
	}
	var gate_result: Dictionary = ProductionSimulator.simulate(gate_config)
	if int(gate_result.get("rejected_actions", 0)) != 2 or gate_result.get("ending_inventory", {}) != {"metal": 1, "wood": 1}:
		_fail("Locked or unknown-unlock recipes must be rejected without partial inventory consumption.")
		return

	var blocked_config := {
		"horizon_seconds": 60,
		"storage_capacity": 1,
		"initial_inventory": {"wood": 1},
		"raw_materials": {"metal": {"time_sec": 60}},
		"crafted_items": {},
		"factory_materials": {"factory_small": ["metal"]},
		"facilities": [
			{"id": "factory-full", "kind": "factory", "factory_type": "factory_small", "slot_count": 1}
		],
		"actions": [
			{"type": "start_factory", "facility_id": "factory-full", "item_id": "metal", "at_seconds": 0},
			{"type": "collect", "facility_id": "factory-full", "slot_index": 0, "at_seconds": 60}
		]
	}
	var blocked: Dictionary = ProductionSimulator.simulate(blocked_config)
	if blocked.get("ready_uncollected_jobs", []).size() != 1 or int(blocked.get("ending_inventory", {}).get("wood", 0)) != 1:
		_fail("A full warehouse must keep ready production on its factory slot without losing stock.")
		return

	# FIFO cost basis is sourced from explicit acquisition costs, not the catalog's
	# selling/reference value. COGS is an accounting measure, not a second cash sink.
	var costed_macro_config := {
		"initial_simoleons": 100,
		"population": 0,
		"happiness": 100.0,
		"occupied_homes": 0,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 421,
		"item_values": {"nails": 80},
		"events": [],
		"production": {
			"storage_capacity": 10,
			"depot_operational": true,
			"initial_inventory": {"metal": 2},
			"initial_unit_costs": {"metal": 15},
			"raw_materials": {"metal": {"time_sec": 60}},
			"crafted_items": {"nails": {"time_sec": 300, "store": "building_supplies", "requires": {"metal": 2}}},
			"factory_materials": {},
			"facilities": [{"id": "costed-store", "kind": "store", "shop_id": "building_supplies", "slot_count": 1}],
			"actions": [
				{"type": "enqueue_store", "facility_id": "costed-store", "item_id": "nails", "at_seconds": 0},
				{"type": "collect", "facility_id": "costed-store", "slot_index": 0, "at_seconds": 300},
				{"type": "depot_list", "listing_id": "costed-nails", "item_id": "nails", "quantity": 1, "at_seconds": 301},
				{"type": "depot_collect", "listing_id": "costed-nails", "at_seconds": 421}
			]
		}
	}
	var costed_result: Dictionary = Simulator.simulate(costed_macro_config)
	if not bool(costed_result.get("valid", false)):
		_fail("Cost-basis production/cashflow simulation invalid: " + str(costed_result.get("errors", [])))
		return
	var accounting: Dictionary = costed_result.get("production_accounting", {})
	if int(accounting.get("gross_revenue", -1)) != 80 or int(accounting.get("known_cogs", -1)) != 30 or int(accounting.get("known_gross_margin", -1)) != 50:
		_fail("FIFO cost basis must carry the two Metal acquisition costs (2 × 15) into the Nails sale and report 80 revenue / 30 COGS / 50 gross margin.")
		return
	if not bool(accounting.get("gross_margin_complete", false)):
		_fail("Gross margin must be marked complete when every sold unit has a known acquisition cost.")
		return
	if int(costed_result.get("ending_simoleons", -1)) != 180:
		_fail("COGS must not be deducted from Simoleons a second time; the actual cash balance changes only by the collected 80-Simoleon sale.")
		return

	var unknown_cost_config: Dictionary = costed_macro_config.duplicate(true)
	unknown_cost_config["production"].erase("initial_unit_costs")
	var unknown_cost_result: Dictionary = Simulator.simulate(unknown_cost_config)
	var unknown_accounting: Dictionary = unknown_cost_result.get("production_accounting", {})
	if bool(unknown_accounting.get("gross_margin_complete", true)) or int(unknown_accounting.get("unknown_cost_sale_quantity", 0)) != 1:
		_fail("Missing acquisition costs must remain unknown and must prevent a false complete-profit claim.")
		return
	var unknown_sales: Array = unknown_accounting.get("sales", [])
	if unknown_sales.size() != 1 or unknown_sales[0].get("gross_margin", 0) != null:
		_fail("A sale with unknown COGS must expose null gross margin instead of inventing a cost or profit.")
		return

	var exact_batches_config: Dictionary = costed_macro_config.duplicate(true)
	exact_batches_config["production"].erase("initial_unit_costs")
	exact_batches_config["production"]["initial_cost_batches"] = {
		"metal": [
			{"quantity": 1, "total_cost": 11, "known": true},
			{"quantity": 1, "total_cost": 19, "known": true}
		]
	}
	var exact_batches_result: Dictionary = Simulator.simulate(exact_batches_config)
	var exact_batches_accounting: Dictionary = exact_batches_result.get("production_accounting", {})
	if not bool(exact_batches_result.get("valid", false)) or int(exact_batches_accounting.get("known_cogs", -1)) != 30 or int(exact_batches_accounting.get("known_gross_margin", -1)) != 50:
		_fail("Exact live FIFO cost batches must preserve per-batch total cost when replayed into production COGS.")
		return


func _test_automatic_chain_dependency_replay() -> void:
	var config := {
		"initial_simoleons": 100,
		"population": 0,
		"happiness": 100.0,
		"occupied_homes": 0,
		"level": 1,
		"experience": 0,
		"horizon_seconds": 171,
		"item_values": {"hammer": 90},
		"events": [],
		"production": {
			"storage_capacity": 8,
			"depot_operational": true,
			"initial_inventory": {},
			"raw_materials": {
				"metal": {"time_sec": 10, "level": 1},
				"wood": {"time_sec": 10, "level": 1}
			},
			"crafted_items": {
				"nails": {"time_sec": 20, "store": "building_supplies", "level": 1, "requires": {"metal": 2}},
				"hammer": {"time_sec": 20, "store": "hardware_store", "level": 1, "requires": {"nails": 1, "wood": 1}}
			},
			"factory_materials": {"factory_small": ["metal", "wood"]},
			"facilities": [
				{"id": "factory-auto", "kind": "factory", "factory_type": "factory_small", "slot_count": 3},
				{"id": "supplies-auto", "kind": "store", "shop_id": "building_supplies", "slot_count": 2},
				{"id": "hardware-auto", "kind": "store", "shop_id": "hardware_store", "slot_count": 2}
			],
			"actions": [
				{"type": "auto_chain", "facility_id": "hardware-auto", "item_id": "hammer", "chain_id": "hammer-root", "at_seconds": 0},
				{"type": "depot_list", "listing_id": "hammer-sale", "item_id": "hammer", "quantity": 1, "at_seconds": 51},
				{"type": "depot_collect", "listing_id": "hammer-sale", "at_seconds": 171}
			]
		}
	}
	var result: Dictionary = Simulator.simulate(config)
	if not bool(result.get("valid", false)):
		_fail("Nested AUTO CHAIN replay invalid: " + str(result.get("errors", [])))
		return
	var production: Dictionary = result.get("production", {})
	var outputs: Dictionary = production.get("collected_outputs", {})
	if int(outputs.get("metal", 0)) != 2 or int(outputs.get("wood", 0)) != 1 or int(outputs.get("nails", 0)) != 1 or int(outputs.get("hammer", 0)) != 1:
		_fail("Nested AUTO CHAIN must produce/collect raw materials, intermediate Nails and the requested Hammer.")
		return
	var consumed: Dictionary = production.get("consumed_inputs", {})
	if int(consumed.get("metal", 0)) != 2 or int(consumed.get("nails", 0)) != 1 or int(consumed.get("wood", 0)) != 1:
		_fail("Nested AUTO CHAIN must consume each BOM input exactly once.")
		return
	if int(result.get("source_breakdown", {}).get("production_sales", 0)) != 90 or int(result.get("ending_simoleons", 0)) != 190:
		_fail("AUTO CHAIN output must flow through explicit Depot collection into macro Simoleon cashflow. source=%s ending=%s production=%s" % [str(result.get("source_breakdown", {})), str(result.get("ending_simoleons", -1)), str(production)])
		return
	if not production.get("pending_jobs", []).is_empty() or not production.get("ready_uncollected_jobs", []).is_empty():
		_fail("Completed AUTO CHAIN scenario must leave no pending or uncollected production slots.")
		return

