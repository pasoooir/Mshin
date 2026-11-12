extends Node

signal item_produced(item_id: String, amount: int)

# SCBI Industrial Buildings timings are the canonical source for raw production.
# Keep legacy keys (time/value/level) because existing gameplay and HUD code reads them.
var raw_materials := {
	"metal": {"name":"Metal", "time":60.0, "time_sec":60, "value":10, "level":1},
	"wood": {"name":"Wood", "time":180.0, "time_sec":180, "value":20, "level":2},
	"plastic": {"name":"Plastic", "time":540.0, "time_sec":540, "value":25, "level":5},
	"seeds": {"name":"Seeds", "time":1200.0, "time_sec":1200, "value":30, "level":7},
	"minerals": {"name":"Minerals", "time":1800.0, "time_sec":1800, "value":40, "level":11},
	"chemicals": {"name":"Chemicals", "time":7200.0, "time_sec":7200, "value":60, "level":13},
	"textiles": {"name":"Textiles", "time":10800.0, "time_sec":10800, "value":90, "level":15},
	"sugar_spices": {"name":"Sugar and Spices", "time":14400.0, "time_sec":14400, "value":110, "level":17},
	"glass": {"name":"Glass", "time":18000.0, "time_sec":18000, "value":120, "level":19},
	"animal_feed": {"name":"Animal Feed", "time":21600.0, "time_sec":21600, "value":140, "level":23},
	"electrical": {"name":"Electrical Components", "time":25200.0, "time_sec":25200, "value":160, "level":29}
}

# Recipes are stored as "requires" for compatibility with Building.gd and as
# exact SCBI time_sec/input data for the new inventory-driven craft flow.
var crafted_items := {
	"nails": {"name":"Nails", "time":300.0, "time_sec":300, "value":80, "requires":{"metal":2}, "level":1, "store":"building_supplies"},
	"planks": {"name":"Planks", "time":1800.0, "time_sec":1800, "value":120, "requires":{"wood":2}, "level":3, "store":"building_supplies"},
	"bricks": {"name":"Bricks", "time":1200.0, "time_sec":1200, "value":190, "requires":{"minerals":2}, "level":13, "store":"building_supplies"},
	"cement": {"name":"Cement", "time":3000.0, "time_sec":3000, "value":440, "requires":{"minerals":2,"chemicals":1}, "level":14, "store":"building_supplies"},
	"glue": {"name":"Glue", "time":3600.0, "time_sec":3600, "value":440, "requires":{"plastic":1,"chemicals":2}, "level":15, "store":"building_supplies"},
	"paint": {"name":"Paint", "time":3600.0, "time_sec":3600, "value":320, "requires":{"metal":2,"minerals":1,"chemicals":2}, "level":16, "store":"building_supplies"},
	"hammer": {"name":"Hammer", "time":840.0, "time_sec":840, "value":90, "requires":{"metal":1,"wood":1}, "level":4, "store":"hardware_store", "source":"Community-reference"},
	"measuring_tape": {"name":"Measuring Tape", "time":1200.0, "time_sec":1200, "value":60, "requires":{"metal":1,"plastic":1}, "level":6, "store":"hardware_store", "source":"Community-reference"},
	"shovel": {"name":"Shovel", "time":1800.0, "time_sec":1800, "value":65, "requires":{"metal":1,"wood":1,"plastic":1}, "level":9, "store":"hardware_store", "source":"Community-reference"},
	"chair": {"name":"Chair", "time":2400.0, "time_sec":2400, "value":65, "requires":{"wood":1,"planks":1}, "level":10, "store":"furniture_store"},
	"table": {"name":"Table", "time":3300.0, "time_sec":3300, "value":90, "requires":{"planks":2}, "level":16, "store":"furniture_store"},
	"vegetables": {"name":"Vegetables", "time":3000.0, "time_sec":3000, "value":45, "requires":{"seeds":1}, "level":8, "store":"farmers_market"}
}

var upgrade_requirements := {
	1: [{"item":"nails","amount":1},{"item":"metal","amount":1}],
	2: [{"item":"planks","amount":1},{"item":"wood","amount":1}],
	3: [{"item":"hammer","amount":1},{"item":"nails","amount":2}],
	4: [{"item":"bricks","amount":1},{"item":"cement","amount":1}],
	5: [{"item":"paint","amount":1},{"item":"planks","amount":2},{"item":"glass","amount":1}]
}
var residential_population := {1:15,2:30,3:50,4:90,5:160,6:280}

func _ready() -> void:
	print("[ProductionManager] SCBI catalog: %d raw, %d crafted" % [raw_materials.size(), crafted_items.size()])

func get_available_raw() -> Array:
	var result: Array = []
	for item_id in raw_materials:
		if int(raw_materials[item_id].level) <= GameManager.level:
			result.append(item_id)
	return result

func get_available_crafted() -> Array:
	var result: Array = []
	for item_id in crafted_items:
		if int(crafted_items[item_id].level) <= GameManager.level:
			result.append(item_id)
	return result

func are_recipe_inputs_unlocked(recipe: Dictionary) -> bool:
	for input_id in recipe.get("inputs", {}):
		var id := str(input_id)
		if raw_materials.has(id) and int(raw_materials[id].get("level", 1)) > GameManager.level:
			return false
		if crafted_items.has(id) and int(crafted_items[id].get("level", 1)) > GameManager.level:
			return false
	return true

func can_craft(item_id: String) -> bool:
	var recipe := get_recipe(item_id)
	return not recipe.is_empty() and int(recipe.get("level", 1)) <= GameManager.level and are_recipe_inputs_unlocked(recipe) and StorageManager.has_items(recipe.get("inputs", {}))

func get_recipe_lock_reason(item_id: String) -> String:
	var recipe := get_recipe(item_id)
	if recipe.is_empty():
		return "Recipe unavailable"
	if int(recipe.get("level", 1)) > GameManager.level:
		return "Unlocks at Level %d" % int(recipe.level)
	for input_id in recipe.get("inputs", {}):
		var id := str(input_id)
		if raw_materials.has(id) and int(raw_materials[id].get("level", 1)) > GameManager.level:
			return "%s unlocks at Level %d" % [str(raw_materials[id].name), int(raw_materials[id].level)]
		if crafted_items.has(id) and int(crafted_items[id].get("level", 1)) > GameManager.level:
			return "%s unlocks at Level %d" % [str(crafted_items[id].name), int(crafted_items[id].level)]
	return ""

func consume_inputs(item_id: String) -> bool:
	if not can_craft(item_id):
		return false
	return StorageManager.remove_items(get_recipe(item_id).get("inputs", {}))

# Legacy immediate craft API remains available to old callers. New building
# production uses Building.start_commercial_production() and timestamped timers.
func craft_item(item_id: String) -> bool:
	if not can_craft(item_id) or not StorageManager.can_add(item_id, 1):
		return false
	if not consume_inputs(item_id):
		return false
	if StorageManager.add_item(item_id, 1):
		item_produced.emit(item_id, 1)
		GameManager.add_experience(5)
		return true
	return false

func get_recipe(item_id: String) -> Dictionary:
	if not crafted_items.has(item_id):
		return {}
	var recipe: Dictionary = crafted_items[item_id].duplicate(true)
	recipe["inputs"] = recipe.get("requires", {}).duplicate(true)
	return recipe

func get_default_factory_product() -> String:
	return "metal"

func get_default_recipe_for_building(building_type: String) -> String:
	var recipe_store := "building_supplies" if building_type in ["shop_chain","building_supplies"] else building_type
	for item_id in crafted_items:
		if str(crafted_items[item_id].get("store","")) == recipe_store and int(crafted_items[item_id].level) <= GameManager.level:
			return item_id
	return ""

func get_missing_inputs_text(item_id: String) -> String:
	var recipe := get_recipe(item_id)
	if recipe.is_empty():
		return "Unknown recipe"
	var missing: Array[String] = []
	for material in recipe.inputs:
		var needed := int(recipe.inputs[material])
		var available := StorageManager.get_count(str(material))
		if available < needed:
			var material_name := str(raw_materials.get(material, {}).get("name", str(material).capitalize()))
			missing.append("%d %s" % [needed - available, material_name])
	return ", ".join(missing)

func get_item_value(item_id: String) -> int:
	if raw_materials.has(item_id): return int(raw_materials[item_id].value)
	if crafted_items.has(item_id): return int(crafted_items[item_id].value)
	return 5

func get_production_time(item_id: String) -> float:
	if raw_materials.has(item_id): return float(raw_materials[item_id].time_sec)
	if crafted_items.has(item_id): return float(crafted_items[item_id].time_sec)
	return 20.0

func get_upgrade_requirements(from_stage: int) -> Array:
	return upgrade_requirements.get(from_stage, [])

func get_population_for_stage(stage: int) -> int:
	return residential_population.get(clampi(stage,1,6),15)

func can_afford_upgrade(from_stage: int) -> bool:
	for requirement in get_upgrade_requirements(from_stage):
		if StorageManager.get_count(str(requirement.item)) < int(requirement.amount):
			return false
	return not get_upgrade_requirements(from_stage).is_empty()

func consume_upgrade_materials(from_stage: int) -> bool:
	var requirements := get_upgrade_requirements(from_stage)
	if requirements.is_empty() or not can_afford_upgrade(from_stage):
		return false
	var aggregate: Dictionary = {}
	for requirement in requirements:
		var id := str(requirement.item)
		aggregate[id] = int(aggregate.get(id,0)) + int(requirement.amount)
	return StorageManager.remove_items(aggregate)
