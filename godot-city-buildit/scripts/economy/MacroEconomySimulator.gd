extends RefCounted
class_name MacroEconomySimulator

# Deterministic player-action replay model. All action volumes and timings are
# explicit inputs; the simulator never invents demand, production throughput,
# construction frequency, or market sell-through.
const DEPOT_LISTING_SECONDS := 120
const TAX_TICK_SECONDS := 60
const HAPPINESS_XP_TICK_SECONDS := 60
const HAPPINESS_XP_PER_TICK := 5
const MAX_LEVEL := 60
const ProductionSimulator = preload("res://scripts/economy/ProductionCapacitySimulator.gd")


# Convenience entry point for a live city. The player-action schedule remains
# explicit; this method only snapshots current facilities, timers and inventory.
static func simulate_live_city(config: Dictionary) -> Dictionary:
	var live_config: Dictionary = config.duplicate(true)
	var horizon := maxi(0, int(live_config.get("horizon_seconds", 0)))
	var actions: Array = live_config.get("production_actions", [])
	var production_snapshot := ProductionSimulator.capture_live_city_config(horizon, actions)
	if production_snapshot.has("capture_error"):
		return {"valid": false, "errors": [str(production_snapshot.get("capture_error", "Production snapshot failed."))]}
	live_config["production"] = production_snapshot
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return {"valid": false, "errors": ["A live SceneTree is required to read city economy state."]}
	var root := scene_tree.root
	var production_manager = root.get_node_or_null("ProductionManager")
	var game_manager = root.get_node_or_null("GameManager")
	var economy_manager = root.get_node_or_null("EconomyManager")
	var level_progression = root.get_node_or_null("LevelProgression")
	var build_manager = root.get_node_or_null("BuildManager")
	if production_manager == null or game_manager == null or economy_manager == null or level_progression == null or build_manager == null:
		return {"valid": false, "errors": ["One or more required city/economy autoloads are unavailable."]}
	if not live_config.has("initial_simoleons"):
		live_config["initial_simoleons"] = int(economy_manager.simoleons)
	if not live_config.has("population"):
		live_config["population"] = int(game_manager.population)
	if not live_config.has("happiness"):
		live_config["happiness"] = float(game_manager.happiness)
	if not live_config.has("level"):
		live_config["level"] = int(game_manager.level)
	if not live_config.has("experience"):
		live_config["experience"] = int(game_manager.experience)
	if not live_config.has("xp_table"):
		live_config["xp_table"] = level_progression.xp_table.duplicate(true)
	if not live_config.has("occupied_homes"):
		var occupied_homes := 0
		for building in build_manager.buildings.values():
			if not is_instance_valid(building):
				continue
			var building_type := str(building.get("building_type"))
			var definition: Dictionary = build_manager.building_types.get(building_type, {})
			if str(definition.get("category", "")) == "residential" and str(building.get("status")) == "completed" and int(building.get("current_population")) > 0:
				occupied_homes += 1
		live_config["occupied_homes"] = occupied_homes
	live_config["realized_trade_accounting"] = _summarize_realized_trade_ledger(economy_manager.transaction_ledger, int(economy_manager.transaction_sequence))
	if not live_config.has("item_values"):
		var values: Dictionary = {}
		for item_id in production_manager.raw_materials:
			values[str(item_id)] = production_manager.get_item_value(str(item_id))
		for item_id in production_manager.crafted_items:
			values[str(item_id)] = production_manager.get_item_value(str(item_id))
		live_config["item_values"] = values
	return simulate(live_config)


static func _summarize_realized_trade_ledger(ledger: Array, total_sequence: int = -1) -> Dictionary:
	var revenue := 0
	var known_cogs := 0
	var known_gross_margin := 0
	var unknown_cost_quantity := 0
	var sale_count := 0
	var history_complete := total_sequence < 0 or total_sequence <= ledger.size()
	for entry_variant in ledger:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		if not ["trade_sale_collected", "delivery_order_completed"].has(str(entry.get("type", ""))):
			continue
		var metadata: Dictionary = entry.get("metadata", {})
		var sale_revenue := int(entry.get("amount", 0))
		var quantity := maxi(0, int(metadata.get("quantity", 0)))
		if sale_revenue <= 0 or quantity <= 0:
			continue
		revenue += sale_revenue
		sale_count += 1
		if bool(metadata.get("cost_known", false)) and int(metadata.get("cost_basis", -1)) >= 0:
			var cogs := int(metadata.get("cost_basis", 0))
			known_cogs += cogs
			known_gross_margin += sale_revenue - cogs
		else:
			unknown_cost_quantity += quantity
	return {
		"gross_revenue": revenue,
		"known_cogs": known_cogs,
		"known_gross_margin": known_gross_margin,
		"unknown_cost_sale_quantity": unknown_cost_quantity,
		"gross_margin_complete": unknown_cost_quantity == 0 and history_complete,
		"history_complete": history_complete,
		"ledger_entries": ledger.size(),
		"sale_count": sale_count
	}

static func simulate(config: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var horizon_seconds := maxi(0, int(config.get("horizon_seconds", 0)))
	var balance := int(config.get("initial_simoleons", 0))
	var population := maxi(0, int(config.get("population", 0)))
	var happiness := clampf(float(config.get("happiness", 100.0)), 0.0, 100.0)
	var occupied_homes := maxi(0, int(config.get("occupied_homes", 0)))
	var level := clampi(int(config.get("level", 1)), 1, MAX_LEVEL)
	var xp := maxi(0, int(config.get("experience", 0)))
	var hq_multiplier := maxf(0.0, float(config.get("hq_multiplier", 2.0)))
	var item_values: Dictionary = config.get("item_values", {})
	var xp_table: Dictionary = config.get("xp_table", {})
	var events: Array = config.get("events", []).duplicate(true)
	var production_result: Dictionary = {}
	if config.has("production"):
		var production_config: Dictionary = config.get("production", {}).duplicate(true)
		production_config["horizon_seconds"] = horizon_seconds
		production_config["item_values"] = item_values
		production_result = ProductionSimulator.simulate(production_config)
		if not bool(production_result.get("valid", false)):
			for production_error in production_result.get("errors", []):
				errors.append("Production: " + str(production_error))
		else:
			events.append_array(production_result.get("cash_events", []))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("at_seconds", 0)) < int(b.get("at_seconds", 0))
	)

	var sources := {"taxes": 0, "depot_sales": 0, "delivery_orders": 0, "production_sales": 0, "level_rewards": 0, "other": 0}
	var sinks := {"global_trade_hq": 0, "construction": 0, "roads": 0, "upgrades": 0, "other": 0}
	var daily: Array[Dictionary] = []
	var event_index := 0
	var rejected_events := 0
	var first_negative_second := -1
	var day_start_balance := balance
	var day_sources := 0
	var day_sinks := 0

	for second in range(1, horizon_seconds + 1):
		if second % TAX_TICK_SECONDS == 0:
			var tax := roundi(float(population) * (happiness / 100.0) * 0.15)
			if tax > 0:
				balance += tax
				sources.taxes += tax
				day_sources += tax

		if second % HAPPINESS_XP_TICK_SECONDS == 0 and occupied_homes > 0 and happiness >= 80.0 and level < MAX_LEVEL:
			xp += HAPPINESS_XP_PER_TICK
			while level < MAX_LEVEL:
				var next_level := level + 1
				var needed := int(xp_table.get(next_level, next_level * 500))
				if needed <= 0 or xp < needed:
					break
				xp -= needed
				level = next_level
				var reward := level * 100
				balance += reward
				sources.level_rewards += reward
				day_sources += reward

		while event_index < events.size() and int(events[event_index].get("at_seconds", 0)) <= second:
			var event: Dictionary = events[event_index]
			event_index += 1
			var event_type := str(event.get("type", ""))
			var item_id := str(event.get("item_id", ""))
			var quantity := int(event.get("quantity", 0))
			var amount := int(event.get("amount", 0))
			var flow := 0
			var source_bucket := ""
			var sink_bucket := ""

			match event_type:
				"depot_sale":
					var listed_at := int(event.get("listed_at_seconds", -1))
					var collected_at := int(event.get("at_seconds", 0))
					if not item_values.has(item_id) or quantity <= 0 or listed_at < 0 or collected_at - listed_at < DEPOT_LISTING_SECONDS:
						errors.append("Invalid or premature depot_sale collection for %s." % item_id)
						continue
					# The player explicitly collects a ready listing; readiness is not automatic sale.
					flow = int(item_values[item_id]) * quantity
					source_bucket = "depot_sales"
				"production_sale":
					if quantity <= 0 or amount <= 0:
						errors.append("Invalid production_sale event for %s." % item_id)
						continue
					flow = amount
					source_bucket = "production_sales"
				"delivery_order_reward":
					if quantity <= 0 or amount <= 0:
						errors.append("Invalid delivery_order_reward event for %s." % item_id)
						continue
					flow = amount
					source_bucket = "delivery_orders"
				"delivery_order":
					if not item_values.has(item_id) or quantity <= 0:
						errors.append("Invalid delivery_order event for %s." % item_id)
						continue
					flow = int(item_values[item_id]) * quantity * 2
					source_bucket = "delivery_orders"
				"hq_purchase":
					if not item_values.has(item_id) or quantity <= 0:
						errors.append("Invalid hq_purchase event for %s." % item_id)
						continue
					flow = roundi(float(int(item_values[item_id]) * quantity * 2) * hq_multiplier / 2.0)
					sink_bucket = "global_trade_hq"
				"construction":
					flow = amount
					sink_bucket = "construction"
				"road":
					flow = amount
					sink_bucket = "roads"
				"upgrade":
					flow = amount
					sink_bucket = "upgrades"
				"other_income":
					flow = amount
					source_bucket = "other"
				"other_spend":
					flow = amount
					sink_bucket = "other"
				_:
					errors.append("Unsupported economy event type: %s." % event_type)
					continue

			if flow <= 0:
				errors.append("Economy event %s must have a positive value." % event_type)
				continue
			if not sink_bucket.is_empty():
				if balance < flow:
					rejected_events += 1
					continue
				balance -= flow
				sinks[sink_bucket] += flow
				day_sinks += flow
			elif not source_bucket.is_empty():
				balance += flow
				sources[source_bucket] += flow
				day_sources += flow

			if balance < 0 and first_negative_second < 0:
				first_negative_second = second

		if second % 86400 == 0 or second == horizon_seconds:
			daily.append({
				"day": int(floor(float(second) / 86400.0)) + (1 if second % 86400 != 0 else 0),
				"balance_start": day_start_balance,
				"balance_end": balance,
				"source_total": day_sources,
				"sink_total": day_sinks,
				"net_cashflow": day_sources - day_sinks,
				"level": level,
				"experience": xp
			})
			day_start_balance = balance
			day_sources = 0
			day_sinks = 0

	var total_sources := 0
	var total_sinks := 0
	for value in sources.values():
		total_sources += int(value)
	for value in sinks.values():
		total_sinks += int(value)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"duration_seconds": horizon_seconds,
		"initial_simoleons": int(config.get("initial_simoleons", 0)),
		"ending_simoleons": balance,
		"net_simoleons": balance - int(config.get("initial_simoleons", 0)),
		"source_breakdown": sources,
		"sink_breakdown": sinks,
		"total_sources": total_sources,
		"total_sinks": total_sinks,
		"rejected_spend_events": rejected_events,
		"first_negative_second": first_negative_second,
		"ending_level": level,
		"ending_experience": xp,
		"daily": daily,
		"production": production_result,
		"production_accounting": production_result.get("accounting", {}),
		"realized_trade_accounting": config.get("realized_trade_accounting", {}),
		"model_notes": [
			"Tax formula and happiness XP cadence are read from the current Mshin game rules.",
			"Delivery order reward uses the current 2x catalog-value formula for reward-only events; production delivery_order actions also consume inventory and propagate FIFO COGS.",
			"Global Trade HQ price multiplier is a scenario input; current game default is 2x.",
			"Depot sales use catalog value and the current 120-second listing timer.",
			"Production capacity, queue actions, input consumption and warehouse limits are replayed from explicit production configuration. Cash sales are explicit player actions; no market demand or sell-through is fabricated.",
			"Production gross-margin accounting uses FIFO inventory cost batches. Missing acquisition costs remain unknown; catalog sale values are never substituted as purchase costs, and COGS is reported without deducting cash a second time."
		]
	}
