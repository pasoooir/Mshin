extends Node

signal item_produced(item_id: String, amount: int)

# SCBI Industrial Buildings timings are the canonical source for raw production.
# Keep legacy keys (time/value/level) because existing gameplay and HUD code reads them.
var raw_materials := {
	"metal": {"name":"Metal", "time":60.0, "time_sec":60, "value":10, "level":1, "source":"Fandom"},
	"wood": {"name":"Wood", "time":180.0, "time_sec":180, "value":20, "level":2, "source":"Fandom"},
	"plastic": {"name":"Plastic", "time":540.0, "time_sec":540, "value":25, "level":5, "source":"Fandom"},
	"seeds": {"name":"Seeds", "time":1200.0, "time_sec":1200, "value":30, "level":7, "source":"Fandom"},
	"minerals": {"name":"Minerals", "time":1800.0, "time_sec":1800, "value":40, "level":11, "source":"Fandom"},
	"chemicals": {"name":"Chemicals", "time":7200.0, "time_sec":7200, "value":60, "level":13, "source":"Fandom"},
	"textiles": {"name":"Textiles", "time":10800.0, "time_sec":10800, "value":90, "level":15, "source":"Fandom"},
	"sugar_spices": {"name":"Sugar and Spices", "time":14400.0, "time_sec":14400, "value":110, "level":17, "source":"Fandom"},
	"glass": {"name":"Glass", "time":18000.0, "time_sec":18000, "value":120, "level":19, "source":"Fandom"},
	"animal_feed": {"name":"Animal Feed", "time":21600.0, "time_sec":21600, "value":140, "level":23, "source":"Fandom"},
	"electrical": {"name":"Electrical Components", "time":25200.0, "time_sec":25200, "value":160, "level":29, "source":"Fandom"}
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
	"nails": {"name":"Nails", "time":300.0, "time_sec":300, "value":80, "requires":{"metal":2}, "level":1, "store":"building_supplies", "source":"Fandom"},
	"planks": {"name":"Planks", "time":1800.0, "time_sec":1800, "value":120, "requires":{"wood":2}, "level":3, "store":"building_supplies", "source":"Fandom"},
	"bricks": {"name":"Bricks", "time":1200.0, "time_sec":1200, "value":190, "requires":{"minerals":2}, "level":13, "store":"building_supplies", "source":"Fandom"},
	"cement": {"name":"Cement", "time":3000.0, "time_sec":3000, "value":440, "requires":{"minerals":2,"chemicals":1}, "level":14, "store":"building_supplies", "source":"Fandom"},
	"glue": {"name":"Glue", "time":3600.0, "time_sec":3600, "value":440, "requires":{"plastic":1,"chemicals":2}, "level":15, "store":"building_supplies", "source":"Fandom"},
	"paint": {"name":"Paint", "time":3600.0, "time_sec":3600, "value":320, "requires":{"metal":2,"minerals":1,"chemicals":2}, "level":16, "required_stars":1, "store":"building_supplies", "source":"Fandom"},
	"hammer": {"name":"Hammer", "time":840.0, "time_sec":840, "value":90, "requires":{"metal":1,"wood":1}, "level":4, "store":"hardware_store", "source":"Fandom"},
	"measuring_tape": {"name":"Measuring Tape", "time":1200.0, "time_sec":1200, "value":110, "requires":{"metal":1,"plastic":1}, "level":6, "store":"hardware_store", "source":"Fandom"},
	"shovel": {"name":"Shovel", "time":1800.0, "time_sec":1800, "value":150, "requires":{"metal":1,"wood":1,"plastic":1}, "level":9, "store":"hardware_store", "source":"Fandom"},
	"cooking_utensils": {"name":"Cooking Utensils", "time":2700.0, "time_sec":2700, "value":250, "requires":{"metal":2,"wood":2,"plastic":2}, "level":17, "store":"hardware_store", "source":"Fandom"},
	"ladder": {"name":"Ladder", "time":3600.0, "time_sec":3600, "value":420, "requires":{"planks":2,"metal":2}, "level":20, "required_stars":1, "store":"hardware_store", "source":"Fandom"},
	"drill": {"name":"Drill", "time":7200.0, "time_sec":7200, "value":590, "requires":{"metal":2,"plastic":2,"electrical":1}, "level":30, "store":"hardware_store", "source":"Fandom"},
	"chair": {"name":"Chair", "time":1200.0, "time_sec":1200, "value":300, "requires":{"wood":2,"nails":1,"hammer":1}, "level":10, "store":"furniture_store", "source":"Fandom"},
	"home_textiles": {"name":"Home Textiles", "time":4500.0, "time_sec":4500, "value":610, "requires":{"textiles":2,"measuring_tape":1}, "level":25, "store":"furniture_store", "source":"Fandom"},
	"cupboard": {"name":"Cupboard", "time":2700.0, "time_sec":2700, "value":900, "requires":{"planks":2,"glass":2,"paint":1}, "level":26, "required_stars":1, "store":"furniture_store", "source":"Fandom"},
	"couch": {"name":"Couch", "time":9000.0, "time_sec":9000, "value":1810, "requires":{"textiles":3,"drill":1,"glue":1}, "level":33, "store":"furniture_store", "source":"Fandom"},
	"table": {"name":"Table", "time":1800.0, "time_sec":1800, "value":500, "requires":{"planks":1,"nails":2,"hammer":1}, "level":16, "store":"furniture_store", "source":"Fandom"},
	"vegetables": {"name":"Vegetables", "time":1200.0, "time_sec":1200, "value":160, "requires":{"seeds":2}, "level":8, "store":"farmers_market", "source":"Fandom"},
	"flour_bag": {"name":"Flour Bag", "time":1800.0, "time_sec":1800, "value":570, "requires":{"seeds":2,"textiles":2}, "level":17, "store":"farmers_market", "source":"Fandom"},
	"cream": {"name":"Cream", "time":4500.0, "time_sec":4500, "value":440, "requires":{"animal_feed":1}, "level":23, "store":"farmers_market", "source":"Fandom"},
	"corn": {"name":"Corn", "time":3600.0, "time_sec":3600, "value":280, "requires":{"minerals":1,"seeds":4}, "level":24, "required_stars":1, "store":"farmers_market", "source":"Fandom"},
	"cheese": {"name":"Cheese", "time":6300.0, "time_sec":6300, "value":660, "requires":{"animal_feed":2}, "level":26, "store":"farmers_market", "source":"Fandom"},
	"beef": {"name":"Beef", "time":7200.0, "time_sec":7200, "value":860, "requires":{"animal_feed":3}, "level":27, "store":"farmers_market", "source":"Fandom"},
	"fruit_berries": {"name":"Fruit & Berries", "time":5400.0, "time_sec":5400, "value":730, "requires":{"seeds":2,"tree_sapling":1}, "level":18, "store":"farmers_market", "source":"HubsInfo;Fandom"},
	"bread_roll": {"name":"Bread Roll", "time":3600.0, "time_sec":3600, "value":1840, "requires":{"flour_bag":2,"cream":1}, "level":24, "store":"donut_shop", "source":"Fandom"},
	"bbq_grill": {"name":"BBQ Grill", "time":9900.0, "time_sec":9900, "value":530, "requires":{"metal":3,"cooking_utensils":1}, "level":29, "store":"home_appliances", "source":"Fandom"},
	"microwave_oven": {"name":"Microwave Oven", "time":7200.0, "time_sec":7200, "value":480, "requires":{"metal":4,"glass":1,"electrical":1}, "level":42, "required_stars":1, "store":"home_appliances", "source":"Fandom"},
	"pizza": {"name":"Pizza", "time":1440.0, "time_sec":1440, "value":2560, "requires":{"flour_bag":1,"cheese":1,"beef":1}, "level":28, "store":"fast_food", "source":"Fandom"},
	"cheese_fries": {"name":"Cheese Fries", "time":1200.0, "time_sec":1200, "value":1050, "requires":{"cheese":1,"vegetables":1}, "level":33, "store":"fast_food", "source":"Fandom"},
	"ice_cream_sandwich": {"name":"Ice Cream Sandwich", "time":840.0, "time_sec":840, "value":2560, "requires":{"cream":1,"bread_roll":1}, "level":25, "store":"fast_food", "source":"Fandom"},
	"burger": {"name":"Burger", "time":2100.0, "time_sec":2100, "value":3620, "requires":{"beef":1,"bread_roll":1,"bbq_grill":1}, "level":31, "store":"fast_food", "source":"Fandom"},
	"lemonade_bottle": {"name":"Lemonade Bottle", "time":3600.0, "time_sec":3600, "value":1690, "requires":{"glass":2,"sugar_spices":2,"fruit_berries":1}, "level":37, "store":"fast_food", "source":"Fandom"},
	"popcorn": {"name":"Popcorn", "time":1800.0, "time_sec":1800, "value":1250, "requires":{"corn":2,"microwave_oven":1}, "level":43, "required_stars":1, "store":"fast_food", "source":"Fandom"},
	"grass": {"name":"Grass", "time":1800.0, "time_sec":1800, "value":310, "requires":{"seeds":1,"shovel":1}, "level":14, "store":"gardening_supplies", "source":"HubsInfo"},
	"tree_sapling": {"name":"Tree Saplings", "time":5400.0, "time_sec":5400, "value":420, "requires":{"seeds":2,"shovel":1}, "level":16, "store":"gardening_supplies", "source":"HubsInfo"},
	"lawn_mower": {"name":"Lawn Mower", "time":7200.0, "time_sec":7200, "value":840, "requires":{"metal":3,"electrical":1,"paint":1}, "level":30, "required_stars":1, "store":"gardening_supplies", "source":"Fandom"},
	"garden_furniture": {"name":"Garden Furniture", "time":8100.0, "time_sec":8100, "value":820, "requires":{"plastic":2,"textiles":2,"planks":2}, "level":21, "store":"gardening_supplies", "source":"HubsInfo"},
	"fire_pit": {"name":"Fire Pit", "time":14400.0, "time_sec":14400, "value":1740, "requires":{"bricks":2,"cement":2,"shovel":1}, "level":28, "store":"gardening_supplies", "source":"HubsInfo"},
	"garden_gnome": {"name":"Garden Gnomes", "time":5400.0, "time_sec":5400, "value":1600, "requires":{"cement":2,"glue":1}, "level":34, "store":"gardening_supplies", "source":"HubsInfo"},
	"donuts": {"name":"Donuts", "time":2700.0, "time_sec":2700, "value":950, "requires":{"sugar_spices":1,"flour_bag":1}, "level":18, "store":"donut_shop", "source":"HubsInfo"},
	"green_smoothie": {"name":"Green Smoothie", "time":1800.0, "time_sec":1800, "value":1150, "requires":{"vegetables":1,"fruit_berries":1}, "level":20, "store":"donut_shop", "source":"HubsInfo"},
	"cherry_cheesecake": {"name":"Cherry Cheesecake", "time":5400.0, "time_sec":5400, "value":2240, "requires":{"flour_bag":1,"fruit_berries":1,"cheese":1}, "level":27, "store":"donut_shop", "source":"HubsInfo"},
	"frozen_yogurt": {"name":"Frozen Yogurt", "time":14400.0, "time_sec":14400, "value":1750, "requires":{"sugar_spices":1,"fruit_berries":1,"cream":1}, "level":28, "store":"donut_shop", "source":"HubsInfo"},
	"coffee": {"name":"Coffee", "time":3600.0, "time_sec":3600, "value":750, "requires":{"seeds":2,"sugar_spices":1,"cream":1}, "level":33, "required_stars":1, "store":"donut_shop", "source":"HubsInfo;Fandom"},
	"cap": {"name":"Cap", "time":3600.0, "time_sec":3600, "value":600, "requires":{"textiles":2,"measuring_tape":1}, "level":19, "store":"fashion_store", "source":"HubsInfo"},
	"shoes": {"name":"Shoes", "time":4500.0, "time_sec":4500, "value":980, "requires":{"plastic":1,"textiles":2,"glue":1}, "level":21, "store":"fashion_store", "source":"HubsInfo"},
	"watch": {"name":"Watch", "time":5400.0, "time_sec":5400, "value":580, "requires":{"plastic":2,"glass":1,"chemicals":1}, "level":22, "store":"fashion_store", "source":"HubsInfo"},
	"business_suit": {"name":"Business Suits", "time":12600.0, "time_sec":12600, "value":1170, "requires":{"textiles":3,"glue":1,"measuring_tape":1}, "level":32, "store":"fashion_store", "source":"HubsInfo"},
	"refrigerator": {"name":"Refrigerator", "time":12600.0, "time_sec":12600, "value":1060, "requires":{"plastic":2,"chemicals":2,"electrical":2}, "level":35, "store":"home_appliances", "source":"HubsInfo"},
	"lighting_system": {"name":"Lighting System", "time":6300.0, "time_sec":6300, "value":890, "requires":{"chemicals":1,"glass":1,"electrical":1}, "level":36, "store":"home_appliances", "source":"HubsInfo"},
	"tv": {"name":"TV", "time":9000.0, "time_sec":9000, "value":1280, "requires":{"plastic":2,"glass":2,"electrical":2}, "level":38, "store":"home_appliances", "source":"HubsInfo"},
	"ping_pong_table": {"name":"Ping-Pong Table", "time":5400.0, "time_sec":5400, "value":1245, "requires":{"table":1,"minerals":4,"wood":4}, "level":55, "required_stars":1, "store":"sports_shop", "source":"Fandom;Japanese"},
	"block_letters": {"name":"Letter Blocks", "time":3600.0, "time_sec":3600, "value":360, "requires":{"wood":4,"measuring_tape":1}, "level":40, "store":"toy_store", "source":"Fandom;Japanese"},
	"game_console": {"name":"Game Console", "time":4500.0, "time_sec":4500, "value":2240, "requires":{"lighting_system":1,"glass":3,"electrical":3}, "level":58, "store":"toy_store", "source":"Fandom;Japanese"},
	"forged_iron": {"name":"Wrought Iron", "time":1800.0, "time_sec":1800, "value":560, "requires":{"metal":4,"hammer":2,"chemicals":2}, "level":45, "store":"restoration_office", "source":"Fandom;Japanese"},
	"carved_wood": {"name":"Carved Wood", "time":3600.0, "time_sec":3600, "value":2800, "requires":{"planks":5,"measuring_tape":2,"drill":2}, "level":54, "store":"restoration_office", "source":"Fandom;Japanese"},
	"wool_shirt": {"name":"Wool Shirt", "time":4500.0, "time_sec":4500, "value":1700, "requires":{"textiles":4,"measuring_tape":2,"paint":2}, "level":50, "store":"farmers_store", "source":"Fandom;Japanese"},
	"picnic_basket": {"name":"Picnic Basket", "time":3600.0, "time_sec":3600, "value":6000, "requires":{"fruit_berries":4,"textiles":4,"glue":2}, "level":59, "store":"farmers_store", "source":"Fandom;Japanese"},
	"apple_jam": {"name":"Apple Jam", "time":3600.0, "time_sec":3600, "value":3700, "requires":{"seeds":4,"glass":2,"flour_bag":4}, "level":73, "required_stars":1, "store":"farmers_store", "source":"Fandom;Japanese"},
	"tiramisu": {"name":"Tiramisu", "time":2700.0, "time_sec":2700, "value":1250, "requires":{"sugar_spices":1,"vegetables":1,"cream":1}, "level":55, "store":"dessert_shop", "source":"Fandom;Japanese"},
	"churros": {"name":"Churros", "time":2100.0, "time_sec":2100, "value":1750, "requires":{"cooking_utensils":1,"flour_bag":2}, "level":63, "store":"dessert_shop", "source":"Fandom;Japanese"},
	"profiterole": {"name":"Profiterole", "time":2100.0, "time_sec":2100, "value":6550, "requires":{"donuts":2,"bread_roll":2,"cream":1}, "level":71, "store":"dessert_shop", "source":"Fandom;Japanese"},
	"mochi": {"name":"Mochi", "time":2700.0, "time_sec":2700, "value":3950, "requires":{"frozen_yogurt":1,"green_smoothie":1}, "level":79, "store":"dessert_shop", "source":"Fandom;Japanese"},
	"pavlova": {"name":"Pavlova", "time":5400.0, "time_sec":5400, "value":3470, "requires":{"cooking_utensils":1,"fruit_berries":2,"cream":2}, "level":87, "required_stars":1, "store":"dessert_shop", "source":"Fandom;Japanese"},
	"backpack": {"name":"Backpack", "time":7200.0, "time_sec":7200, "value":430, "requires":{"textiles":2,"plastic":2,"measuring_tape":1}, "level":34, "store":"fashion_store", "source":"Fandom item page; Fashion Store table", "source_url":"https://simcity-buildit.fandom.com/wiki/Backpack", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Fashion_Store"},
	"tennis_racket": {"name":"Tennis Racket", "time":2700.0, "time_sec":2700, "value":780, "requires":{"minerals":4,"hammer":2}, "level":35, "store":"sports_shop", "source":"Fandom item page; Sports Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Tennis_Racket", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Sports_Shop"},
	"sports_drink": {"name":"Sports Drink", "time":2100.0, "time_sec":2100, "value":270, "requires":{"fruit_berries":2,"sugar_spices":4}, "level":39, "store":"sports_shop", "source":"Fandom item page; Sports Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Sports_Drink", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Sports_Shop"},
	"soccer_shoes": {"name":"Football Shoes", "time":2100.0, "time_sec":2100, "value":920, "requires":{"shoes":1,"chemicals":3}, "level_verified":false, "unlock_level_note":"The item-specific Mayor Level is not listed in the available source; Sports Shop building unlock level is not substituted.", "store":"sports_shop", "source":"Fandom item page; Sports Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Football_Shoes", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Sports_Shop"},
	"protein_bar": {"name":"Protein Bar", "time":2700.0, "time_sec":2700, "value":1045, "requires":{"cherry_cheesecake":1,"sugar_spices":2}, "level":35, "store":"sports_shop", "source":"Fandom item page; Sports Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Protein_Bar", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Sports_Shop"},
	"kite": {"name":"Kite", "time":4500.0, "time_sec":4500, "value":1000, "requires":{"home_textiles":2,"planks":2,"paint":2}, "level_verified":false, "unlock_level_note":"The item-specific Mayor Level is not listed in the available source; Toy Shop building unlock level is not substituted.", "store":"toy_store", "source":"Fandom item page; Toy Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Kite", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Toy_Shop"},
	"teddy_bear": {"name":"Teddy Bear", "time":3600.0, "time_sec":3600, "value":600, "requires":{"home_textiles":4,"plastic":2}, "level_verified":false, "unlock_level_note":"The item-specific Mayor Level is not listed in the available source; Toy Shop building unlock level is not substituted.", "store":"toy_store", "source":"Fandom item page; Toy Shop table", "source_url":"https://simcity-buildit.fandom.com/wiki/Teddy_Bear", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Toy_Shop"},
	"cut_stone": {"name":"Chiseled Stone", "time":9000.0, "time_sec":9000, "value":2300, "requires":{"hammer":2,"minerals":6,"drill":2}, "level":59, "store":"restoration_office", "source":"Fandom Bureau of Restoration table", "source_url":"https://simcity-buildit.fandom.com/wiki/Bureau_of_Restoration"},
	"tapestries": {"name":"Tapestry", "time":12600.0, "time_sec":12600, "value":2560, "requires":{"textiles":4,"paint":2,"glue":2}, "level_verified":false, "unlock_level_note":"The item-specific Mayor Level is not listed in the available source; Bureau of Restoration building unlock level is not substituted.", "store":"restoration_office", "source":"Fandom item page; Bureau of Restoration table", "source_url":"https://simcity-buildit.fandom.com/wiki/Tapestry", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Bureau_of_Restoration"},
	"stained_glass": {"name":"Stained Glass", "time":14400.0, "time_sec":14400, "value":2300, "requires":{"metal":5,"glass":6,"glue":2}, "level":76, "required_stars":1, "store":"restoration_office", "source":"Fandom item page; Bureau of Restoration table", "source_url":"https://simcity-buildit.fandom.com/wiki/Stained_Glass", "time_source_url":"https://simcity-buildit.fandom.com/wiki/Bureau_of_Restoration"}
}

# Catalog-only identities are retained only when no reliable recipe row exists.
# Every currently listed commercial product now has a sourced recipe record;
# this empty fallback remains for future products with unknown ingredients/times.
var store_catalog := {
	"fast_food": [],
	"donut_shop": [],
	"home_appliances": [],
	"gardening_supplies": [],
	"fashion_store": [],
	"sports_shop": [],
	"toy_store": [],
	"restoration_office": [],
	"farmers_store": [],
	"dessert_shop": []
}

# Residential material plans below are Mshin fallback templates, not an exact
# SimCity BuildIt plan-roll table. The reference system randomizes material type
# and quantity per requirement slot; do not treat these rows as verified SCBI data.
var upgrade_requirements := {
	1: [{"item":"nails","amount":1},{"item":"metal","amount":1}],
	2: [{"item":"planks","amount":1},{"item":"wood","amount":1}],
	3: [{"item":"hammer","amount":1},{"item":"nails","amount":2}],
	4: [{"item":"bricks","amount":1},{"item":"cement","amount":1}],
	5: [{"item":"paint","amount":1},{"item":"planks","amount":2},{"item":"glass","amount":1}]
}
var residential_population := {1:52,2:104,3:154,4:313,5:752,6:1836}

func _ready() -> void:
	# ProductionManager is the authoritative item catalogue. Storage's display
	# metadata is a derived cache so item names/types are never maintained twice.
	for item_id in raw_materials:
		StorageManager.register_item_definition(str(item_id), str(raw_materials[item_id].get("name", item_id)), "raw")
	for item_id in crafted_items:
		StorageManager.register_item_definition(str(item_id), str(crafted_items[item_id].get("name", item_id)), "crafted")
	for store_id in store_catalog:
		for product in store_catalog[store_id]:
			StorageManager.register_item_definition(str(product.get("id", "")), str(product.get("name", product.get("id", ""))), "crafted")
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
	return not recipe.is_empty() and get_recipe_lock_reason(item_id).is_empty() and are_recipe_inputs_unlocked(recipe) and StorageManager.has_items(recipe.get("inputs", {}))

func get_recipe_lock_reason(item_id: String, store_star_level: int = 0) -> String:
	var recipe := get_recipe(item_id)
	if recipe.is_empty():
		return "Recipe not verified — production disabled"
	var source_text := str(recipe.get("source", "")).to_lower()
	if source_text.contains("conflict") or source_text.contains("variant") or source_text.contains("verify"):
		return "Recipe data unresolved — production disabled until verified"
	if recipe.has("level_verified") and not bool(recipe.get("level_verified", true)):
		return str(recipe.get("unlock_level_note", "Item unlock level is not verified — production disabled."))
	if int(recipe.get("level", 1)) > GameManager.level:
		return "Unlocks at Level %d" % int(recipe.level)
	var required_stars := int(recipe.get("required_stars", 0))
	if store_star_level < required_stars:
		return "Requires %d Store Star%s" % [required_stars, "" if required_stars == 1 else "s"]
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

func get_catalog_supplier_id(item_id: String) -> String:
	if crafted_items.has(item_id):
		return str(crafted_items[item_id].get("store", ""))
	for store_id in store_catalog:
		for product in store_catalog[store_id]:
			if str(product.get("id", "")) == item_id:
				return str(store_id)
	return ""

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
		var recipe: Dictionary = crafted_items[item_id]
		if str(recipe.get("store", "")) != recipe_store:
			continue
		if recipe.has("level_verified") and not bool(recipe.get("level_verified", true)):
			continue
		if int(recipe.get("level", 1)) <= GameManager.level:
			return item_id
	return ""

func get_item_definition(item_id: String) -> Dictionary:
	if raw_materials.has(item_id):
		return raw_materials[item_id].duplicate(true)
	if crafted_items.has(item_id):
		return crafted_items[item_id].duplicate(true)
	for store_id in store_catalog:
		for product in store_catalog[store_id]:
			if str(product.get("id", "")) == item_id:
				return product.duplicate(true)
	return {}

func get_recipe_dependency_text(item_id: String) -> String:
	var lines: Array[String] = []
	var remaining_stock: Dictionary = {}
	_append_recipe_dependency_lines(item_id, 1, 0, lines, {}, remaining_stock)
	return "\n".join(lines)

func _append_recipe_dependency_lines(item_id: String, amount: int, depth: int, lines: Array[String], ancestry: Dictionary, remaining_stock: Dictionary) -> void:
	var definition := get_item_definition(item_id)
	if definition.is_empty():
		lines.append("%s• %s ×%d — definition unavailable" % ["  ".repeat(depth), item_id, amount])
		return
	var item_name := str(definition.get("name", item_id))
	var stock_available := int(remaining_stock.get(item_id, StorageManager.get_count(item_id)))
	var used_from_stock := mini(amount, stock_available)
	var missing_amount := maxi(0, amount - used_from_stock)
	remaining_stock[item_id] = maxi(0, stock_available - used_from_stock)
	var stock_line := "%s• %s — required %d | stock %d | missing %d" % [
		"  ".repeat(depth), item_name, amount, stock_available, missing_amount
	]
	lines.append(stock_line)
	if missing_amount <= 0:
		return
	if raw_materials.has(item_id):
		lines[lines.size() - 1] += " | factory raw material"
		return
	if not crafted_items.has(item_id):
		lines[lines.size() - 1] += " | recipe not verified; do not assume inputs"
		return
	var source_text := str(definition.get("source", "")).to_lower()
	if source_text.contains("conflict") or source_text.contains("variant") or source_text.contains("verify"):
		lines[lines.size() - 1] += " | recipe data unresolved"
		return
	if ancestry.has(item_id):
		lines[lines.size() - 1] += " | dependency cycle detected"
		return
	var next_ancestry := ancestry.duplicate(true)
	next_ancestry[item_id] = true
	var requirements: Dictionary = crafted_items[item_id].get("requires", {})
	for input_id in requirements:
		_append_recipe_dependency_lines(
			str(input_id),
			missing_amount * int(requirements[input_id]),
			depth + 1,
			lines,
			next_ancestry,
			remaining_stock
		)

func get_estimated_chain_seconds(item_id: String) -> float:
	# Display-only estimate: raw inputs are treated as parallel and each
	# commercial output batch is sequential. This value is never stored in a recipe.
	return _estimate_item_chain_seconds(item_id, 1, {}, {})

func _estimate_item_chain_seconds(item_id: String, amount: int, remaining_stock: Dictionary, ancestry: Dictionary) -> float:
	var stock_available := int(remaining_stock.get(item_id, StorageManager.get_count(item_id)))
	var used_from_stock := mini(amount, stock_available)
	var missing_amount := maxi(0, amount - used_from_stock)
	remaining_stock[item_id] = maxi(0, stock_available - used_from_stock)
	if missing_amount <= 0:
		return 0.0
	if raw_materials.has(item_id):
		return float(raw_materials[item_id].get("time_sec", 0))
	if not crafted_items.has(item_id) or ancestry.has(item_id):
		return -1.0
	var recipe: Dictionary = crafted_items[item_id]
	var source_text := str(recipe.get("source", "")).to_lower()
	if source_text.contains("conflict") or source_text.contains("variant") or source_text.contains("verify"):
		return -1.0
	var dependency_max := 0.0
	var next_ancestry := ancestry.duplicate(true)
	next_ancestry[item_id] = true
	var requirements: Dictionary = recipe.get("requires", {})
	for input_id in requirements:
		var dependency_seconds := _estimate_item_chain_seconds(
			str(input_id),
			missing_amount * int(requirements[input_id]),
			remaining_stock,
			next_ancestry
		)
		if dependency_seconds < 0.0:
			return -1.0
		dependency_max = maxf(dependency_max, dependency_seconds)
	# Repeated outputs from one commercial store are sequential jobs.
	return dependency_max + float(missing_amount * int(recipe.get("time_sec", 0)))

func get_missing_inputs_text(item_id: String) -> String:
	var recipe := get_recipe(item_id)
	if recipe.is_empty():
		return "Unknown recipe"
	var missing: Array[String] = []
	for material in recipe.inputs:
		var needed := int(recipe.inputs[material])
		var available := StorageManager.get_count(str(material))
		if available < needed:
			var material_name := str(get_item_definition(str(material)).get("name", str(material).capitalize()))
			missing.append("%d %s" % [needed - available, material_name])
	return ", ".join(missing)

func get_item_value(item_id: String) -> int:
	if raw_materials.has(item_id): return int(raw_materials[item_id].value)
	if crafted_items.has(item_id): return int(crafted_items[item_id].value)
	return 5

func get_production_time(item_id: String, store_star_level: int = 0) -> float:
	if raw_materials.has(item_id):
		return float(raw_materials[item_id].time_sec)
	if not crafted_items.has(item_id):
		return 20.0
	var recipe: Dictionary = crafted_items[item_id]
	var base_seconds := float(recipe.get("time_sec", 60))
	var store_id := str(recipe.get("store", ""))
	if store_star_level <= 0 or not is_store_star_upgrade_supported(store_id):
		return base_seconds
	var reduction: float = float([0.0, 0.10, 0.15, 0.20][clampi(store_star_level, 0, 3)])
	return maxf(1.0, ceil(base_seconds * (1.0 - reduction)))

# Each tier is enabled only when both its Mayor Level gate and Simoleon
# price are backed by store-specific references. Partial arrays intentionally
# stop before any tier whose level gate is still unknown.
func get_store_star_offer(store_id: String, current_star_level: int) -> Dictionary:
	var upgrade_data: Dictionary = {
		"building_supplies": [
			{"level": 13, "cost": 12000, "reduction": 10},
			{"level": 25, "cost": 24000, "reduction": 15},
			{"level": 33, "cost": 32000, "reduction": 20}
		],
		"hardware_store": [
			{"level": 16, "cost": 15000, "reduction": 10},
			{"level": 28, "cost": 27000, "reduction": 15},
			{"level": 36, "cost": 35000, "reduction": 20}
		],
		"farmers_market": [
			{"level": 20, "cost": 19000, "reduction": 10},
			{"level": 32, "cost": 31000, "reduction": 15},
			{"level": 40, "cost": 39000, "reduction": 20}
		],
		"furniture_store": [
			{"level": 22, "cost": 21000, "reduction": 10},
			{"level": 34, "cost": 33000, "reduction": 15},
			{"level": 42, "cost": 41000, "reduction": 20}
		],
		"gardening_supplies": [
			{"level": 27, "cost": 25000, "reduction": 10},
			{"level": 38, "cost": 37000, "reduction": 15},
			{"level": 46, "cost": 45000, "reduction": 20}
		],
		"fashion_store": [
			{"level": 31, "cost": 30000, "reduction": 10},
			{"level": 43, "cost": 42000, "reduction": 15},
			{"level": 51, "cost": 50000, "reduction": 20}
		],
		"home_appliances": [
			{"level": 41, "cost": 40000, "reduction": 10},
			{"level": 53, "cost": 52000, "reduction": 15},
			{"level": 61, "cost": 60000, "reduction": 20}
		],
		"fast_food": [
			{"level": 37, "cost": 36000, "reduction": 10},
			{"level": 49, "cost": 48000, "reduction": 15},
			{"level": 57, "cost": 56000, "reduction": 20}
		],
		"donut_shop": [
			{"level": 30, "cost": 29000, "reduction": 10},
			{"level": 42, "cost": 41000, "reduction": 15},
			{"level": 50, "cost": 49000, "reduction": 20}
		],
		"sports_shop": [
			{"level": 55, "cost": 250000, "reduction": 10},
			{"level": 60, "cost": 350000, "reduction": 15}
		],
		"toy_store": [
			{"level": 58, "cost": 280000, "reduction": 10}
		],
		"restoration_office": [
			{"level": 76, "cost": 450000, "reduction": 10},
			{"level": 81, "cost": 600000, "reduction": 15}
		],
		"farmers_store": [
			{"level": 73, "cost": 310000, "reduction": 10},
			{"level": 85, "cost": 400000, "reduction": 15}
		],
		"dessert_shop": [
			{"level": 87, "cost": 450000, "reduction": 10}
		]
	}
	if not upgrade_data.has(store_id):
		return {}
	var next_star := current_star_level + 1
	var tiers: Array = upgrade_data[store_id]
	if next_star < 1 or next_star > tiers.size():
		return {}
	var offer: Dictionary = tiers[next_star - 1].duplicate(true)
	offer["star"] = next_star
	return offer

func is_store_star_upgrade_supported(store_id: String) -> bool:
	return get_store_star_offer(store_id, 0).size() > 0

func get_store_star_status_note(store_id: String, current_star_level: int) -> String:
	var verified_tier_count := {
		"sports_shop": 2,
		"toy_store": 1,
		"restoration_office": 2,
		"farmers_store": 2,
		"dessert_shop": 1
	}
	var highest_verified := int(verified_tier_count.get(store_id, 3))
	if current_star_level >= highest_verified and current_star_level < 3:
		return "NEXT STAR LEVEL UNVERIFIED"
	return ""

func get_upgrade_requirements(from_stage: int) -> Array:
	return upgrade_requirements.get(from_stage, [])

func get_upgrade_plan_note(from_stage: int) -> String:
	if from_stage == 1:
		return "MSHIN STARTER TEMPLATE — Nails + Metal; exact SCBI material quantities, population, XP, and Simoleon rewards are not independently verified."
	return "MSHIN FALLBACK TEMPLATE — SCBI plan slots, material quantities, population tiers, and reward ranges vary; exact values are not verified."

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
