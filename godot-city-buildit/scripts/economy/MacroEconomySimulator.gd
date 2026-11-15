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
	var scheduled_events: Array[Dictionary] = []
	for event_variant in events:
		if not event_variant is Dictionary:
			errors.append("Every economy event must be a Dictionary.")
			continue
		var scheduled_event: Dictionary = event_variant.duplicate(true)
		if str(scheduled_event.get("type", "")) == "depot_sale":
			scheduled_event["at_seconds"] = int(scheduled_event.get("at_seconds", 0)) + DEPOT_LISTING_SECONDS
		scheduled_events.append(scheduled_event)
	events = scheduled_events
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("at_seconds", 0)) < int(b.get("at_seconds", 0))
	)

	var sources := {"taxes": 0, "depot_sales": 0, "delivery_orders": 0, "level_rewards": 0, "other": 0}
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
					if not item_values.has(item_id) or quantity <= 0:
						errors.append("Invalid depot_sale event for %s." % item_id)
						continue
					# The event timestamp was shifted by the 120-second listing timer above.
					flow = int(item_values[item_id]) * quantity
					source_bucket = "depot_sales"
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
		"model_notes": [
			"Tax formula and happiness XP cadence are read from the current Mshin game rules.",
			"Delivery order reward uses the current 2x catalog-value formula.",
			"Global Trade HQ price multiplier is a scenario input; current game default is 2x.",
			"Depot sales use catalog value and the current 120-second listing timer.",
			"Action events are player-supplied; no demand, sales probability, or production capacity is fabricated."
		]
	}
