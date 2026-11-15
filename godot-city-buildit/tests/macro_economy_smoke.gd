extends SceneTree

const Simulator = preload("res://scripts/economy/MacroEconomySimulator.gd")
const ProductionSimulator = preload("res://scripts/economy/ProductionCapacitySimulator.gd")

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
	print("[MacroEconomySmoke] PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("[MacroEconomySmoke] " + message)
	quit(1)

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
