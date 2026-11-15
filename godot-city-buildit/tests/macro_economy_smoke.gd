extends SceneTree

const Simulator = preload("res://scripts/economy/MacroEconomySimulator.gd")

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
			{"type": "depot_sale", "item_id": "metal", "quantity": 3, "at_seconds": 0},
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
	too_early["horizon_seconds"] = 119
	var early_result: Dictionary = Simulator.simulate(too_early)
	if int(early_result.get("source_breakdown", {}).get("depot_sales", 0)) != 0:
		_fail("Trade Depot sale settled before the 120-second listing timer")
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

	print("[MacroEconomySmoke] PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("[MacroEconomySmoke] " + message)
	quit(1)
