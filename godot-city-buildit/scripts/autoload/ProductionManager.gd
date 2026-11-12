extends Node

signal item_produced(item_id: String, amount: int)

# SCBI Industrial Buildings timings are the canonical source for raw production.
# Keep legacy keys (time/value/level) because existing gameplay and HUD code reads them.
var raw_materials := {
	"metal": {"name":"Metal", "time":60.0, "time_sec":60, "value":10, "level":1, "source":"Community-reference"},
	"wood": {"name":"Wood", "time":180.0, "time_sec":180, "value":20, "level":2, "source":"Community-reference"},
	"plastic": {"name":"Plastic", "time":540.0, "time_sec":540, "value":25, "level":5, "source":"Community-reference"},
	"seeds": {"name":"Seeds", "time":1200.0, "time_sec":1200, "value":30, "level":7, "source":"Community-reference"},
	"minerals": {"name":"Minerals", "time":1800.0, "time_sec":1800, "value":40, "level":11, "source":"Community-reference"},
	"chemicals": {"name":"Chemicals", "time":7200.0, "time_sec":7200, "value":60, "level":13, "source":"Community-reference"},
	"textiles": {"name":"Textiles", "time":10800.0, "time_sec":10800, "value":90, "level":15, "source":"Community-reference"},
	"sugar_spices": {"name":"Sugar and Spices", "time":14400.0, "time_sec":14400, "value":110, "level":17, "source":"Community-reference"},
	"glass": {"name":"Glass", "time":18000.0, "time_sec":18000, "value":120, "level":19, "source":"Community-reference"},
	"animal_feed": {"name":"Animal Feed", "time":21600.0, "time_sec":21600, "value":140, "level":23, "source":"Community-reference"},
	"electrical": {"name":"Electrical Components", "time":25200.0, "time_sec":25200, "value":160, "level":29, "source":"Community-reference"}
}

# Recipes are stored as "requires" for compatibility with Building.gd and as
# exact SCBI time_sec/input data for the new inventory-driven craft flow.
var factory_materials := {
	"factory_small":["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"],
	"factory_basic":["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"],
	"factory_mass":["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"],
	"factory_hightech":["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"],
	"factory_nano":["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"],
	"industrial_1":["metal","wood"],
	"industrial_2":["metal","wood"],
	"industrial_3":["metal","wood","plastic"]
}

var crafted_items := {
	"nails": {"name":"Nails", "time":300.0, "time_sec":300, "value":80, "requires":{"metal":2}, "level":1, "store":"building_supplies", "source":"Community-reference"},
	"planks": {"name":"Planks", "time":1800.0, "time_sec":1800, "value":120, "requires":{"wood":2}, "level":3, "store":"building_supplies", "source":"Community-reference"},
	"bricks": {"name":"Bricks", "time":1200.0, "time_sec":1200, "value":190, "requires":{"minerals":2}, "level":13, "store":"building_supplies", "source":"Community-reference"},
	"cement": {"name":"Cement", "time":3000.0, "time_sec":3000, "value":440, "requires":{"minerals":2,"chemicals":1}, "level":14, "store":"building_supplies", "source":"Community-reference"},
	"glue": {"name":"Glue", "time":3600.0, "time_sec":3600, "value":440, "requires":{"plastic":1,"chemicals":2}, "level":15, "store":"building_supplies", "source":"Community-reference; CONFLICTING INGREDIENT DATA — verify"},
	"paint": {"name":"Paint", "time":3600.0, "time_sec":3600, "value":320, "requires":{"metal":2,"minerals":1,"chemicals":2}, "level":16, "store":"building_supplies", "source":"Community-reference; ingredient variants exist"},
	"hammer": {"name":"Hammer", "time":840.0, "time_sec":840, "value":90, "requires":{"metal":1,"wood":1}, "level":4, "store":"hardware_store", "source":"Community-reference"},
	"measuring_tape": {"name":"Measuring Tape", "time":1200.0, "time_sec":1200, "value":60, "requires":{"metal":1,"plastic":1}, "level":6, "store":"hardware_store", "source":"Community-reference"},
	"shovel": {"name":"Shovel", "time":1800.0, "time_sec":1800, "value":150, "requires":{"metal":1,"wood":1,"plastic":1}, "level":9, "store":"hardware_store", "source":"Community-reference"},
	"cooking_utensils": {"name":"Cooking Utensils", "time":2700.0, "time_sec":2700, "value":250, "requires":{"metal":2,"wood":2,"plastic":2}, "level":17, "store":"hardware_store", "source":"Community-reference; CONFLICTING INGREDIENT DATA — verify"},
	"ladder": {"name":"Ladder", "time":3600.0, "time_sec":3600, "value":420, "requires":{"planks":2,"metal":2}, "level":20, "store":"hardware_store", "source":"Community-reference"},
	"drill": {"name":"Drill", "time":7200.0, "time_sec":7200, "value":590, "requires":{"metal":2,"plastic":2,"electrical":1}, "level":30, "store":"hardware_store", "source":"Community-reference"},
	"chair": {"name":"Chair", "time":1200.0, "time_sec":1200, "value":300, "requires":{"wood":2,"nails":1,"hammer":1}, "level":10, "store":"furniture_store", "source":"Community-reference"},
	"home_textiles": {"name":"Home Textiles", "time":4500.0, "time_sec":4500, "value":610, "requires":{"textiles":2,"measuring_tape":1}, "level":25, "store":"furniture_store", "source":"Community-reference"},
	"cupboard": {"name":"Cupboard", "time":2700.0, "time_sec":2700, "value":900, "requires":{"planks":2,"glass":2,"paint":1}, "level":26, "store":"furniture_store", "source":"Community-reference"},
	"couch": {"name":"Couch", "time":9000.0, "time_sec":9000, "value":1810, "requires":{"textiles":3,"drill":1,"glue":1}, "level":33, "store":"furniture_store", "source":"Community-reference"},
	"table": {"name":"Table", "time":1800.0, "time_sec":1800, "value":500, "requires":{"planks":1,"nails":2,"hammer":1}, "level":16, "store":"furniture_store", "source":"Community-reference"},
	"vegetables": {"name":"Vegetables", "time":1200.0, "time_sec":1200, "value":160, "requires":{"seeds":2}, "level":8, "store":"farmers_market", "source":"Community-reference"},
	"flour_bag": {"name":"Flour Bag", "time":1800.0, "time_sec":1800, "value":570, "requires":{"seeds":2,"textiles":2}, "level":17, "store":"farmers_market", "source":"Community-reference; ingredient variants exist"},
	"cream": {"name":"Cream", "time":4500.0, "time_sec":4500, "value":440, "requires":{"animal_feed":1}, "level":23, "store":"farmers_market", "source":"Community-reference"},
	"corn": {"name":"Corn", "time":3600.0, "time_sec":3600, "value":280, "requires":{"minerals":1,"seeds":4}, "level":24, "store":"farmers_market", "source":"Community-reference; CONFLICTING INGREDIENT DATA — verify"},
	"cheese": {"name":"Cheese", "time":6300.0, "time_sec":6300, "value":660, "requires":{"animal_feed":2}, "level":26, "store":"farmers_market", "source":"Community-reference"},
	"beef": {"name":"Beef", "time":9000.0, "time_sec":9000, "value":860, "requires":{"animal_feed":3}, "level":27, "store":"farmers_market", "source":"Community-reference"}
}

# Products with a verified store identity but unresolved input recipes remain
# visible and disabled; never invent ingredient quantities or production times.
var store_catalog := {
	"fast_food": [
		{"id":"ice_cream_sandwich","name":"Ice Cream Sandwich","level":25,"source":"Community-reference; recipe needs verification"},
		{"id":"pizza","name":"Pizza","level":25,"source":"Community-reference; recipe needs verification"},
		{"id":"burger","name":"Burger","level":25,"source":"Community-reference; recipe needs verification"},
		{"id":"cheese_fries","name":"Cheese Fries","level":25,"source":"Community-reference; recipe needs verification"},
		{"id":"lemonade_bottle","name":"Lemonade Bottle","level":25,"source":"Community-reference; recipe needs verification"},
		{"id":"popcorn","name":"Popcorn","level":25,"source":"Community-reference; recipe needs verification"}
	]
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
	# ProductionManager is the authoritative item catalogue. Storage's display
	# metadata is a derived cache so item names/types are never maintained twice.
	for item_id in raw_materials:
		StorageManager.register_item_definition(str(item_id), str(raw_materials[item_id].get("name", item_id)), "raw")
	for item_id in crafted_items:
		StorageManager.register_item_definition(str(item_id), str(crafted_items[item_id].get("name", item_id)), "crafted")
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
		return "Recipe not verified — production disabled"
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

func get_factory_material_ids(factory_type: String) -> Array:
	if factory_materials.has(factory_type):
		return factory_materials[factory_type].duplicate()
	return raw_materials.keys()

func get_store_recipe_ids(store_id: String) -> Array:
	var result: Array = []
	for item_id in crafted_items:
		if str(crafted_items[item_id].get("store", "")) == store_id:
			result.append(str(item_id))
	return result

func get_store_catalog_ids(store_id: String) -> Array:
	var result := get_store_recipe_ids(store_id)
	for product in store_catalog.get(store_id, []):
		var item_id := str(product.get("id", ""))
		if not item_id.is_empty() and not result.has(item_id):
			result.append(item_id)
	return result

func get_store_item_definition(store_id: String, item_id: String) -> Dictionary:
	if crafted_items.has(item_id) and str(crafted_items[item_id].get("store", "")) == store_id:
		return crafted_items[item_id].duplicate(true)
	for product in store_catalog.get(store_id, []):
		if str(product.get("id", "")) == item_id:
			return product.duplicate(true)
	return {}

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
