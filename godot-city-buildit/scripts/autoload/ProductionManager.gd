extends Node

signal item_produced(item_id: String, amount: int)

var raw_materials := {
	"metal": {"name": "Metal", "time": 6.0, "value": 10, "level": 1},
	"wood": {"name": "Wood", "time": 10.0, "value": 20, "level": 2},
	"plastic": {"name": "Plastic", "time": 55.0, "value": 25, "level": 5},
	"seeds": {"name": "Seeds", "time": 80.0, "value": 30, "level": 7},
	"minerals": {"name": "Minerals", "time": 110.0, "value": 40, "level": 11},
	"chemicals": {"name": "Chemicals", "time": 160.0, "value": 60, "level": 13},
	"textiles": {"name": "Textiles", "time": 200.0, "value": 90, "level": 15},
	"sugar": {"name": "Sugar & Spices", "time": 240.0, "value": 110, "level": 17},
	"glass": {"name": "Glass", "time": 280.0, "value": 120, "level": 19},
	"feed": {"name": "Animal Feed", "time": 320.0, "value": 140, "level": 23},
	"electrical": {"name": "Electrical Components", "time": 360.0, "value": 160, "level": 29}
}

var crafted_items := {
	"nails": {"name": "Nails", "time": 30.0, "value": 80, "requires": {"metal": 2}, "level": 1, "store": "building_supplies"},
	"planks": {"name": "Planks", "time": 60.0, "value": 120, "requires": {"wood": 2}, "level": 3, "store": "building_supplies"},
	"bricks": {"name": "Bricks", "time": 45.0, "value": 60, "requires": {"minerals": 1}, "level": 13, "store": "building_supplies"},
	"cement": {"name": "Cement", "time": 60.0, "value": 80, "requires": {"minerals": 2}, "level": 14, "store": "building_supplies"},
	"glue": {"name": "Glue", "time": 40.0, "value": 55, "requires": {"plastic": 1}, "level": 15, "store": "building_supplies"},
	"paint": {"name": "Paint", "time": 50.0, "value": 70, "requires": {"plastic": 1, "chemicals": 1}, "level": 16, "store": "hardware_store"},
	"hammer": {"name": "Hammer", "time": 40.0, "value": 90, "requires": {"metal": 1, "wood": 1}, "level": 4, "store": "hardware_store"},
	"measuring_tape": {"name": "Measuring Tape", "time": 40.0, "value": 60, "requires": {"metal": 1, "plastic": 1}, "level": 6, "store": "hardware_store"},
	"shovel": {"name": "Shovel", "time": 45.0, "value": 65, "requires": {"metal": 1, "wood": 1, "plastic": 1}, "level": 9, "store": "hardware_store"},
	"chair": {"name": "Chair", "time": 40.0, "value": 65, "requires": {"wood": 1, "planks": 1}, "level": 10, "store": "furniture_store"},
	"table": {"name": "Table", "time": 55.0, "value": 90, "requires": {"planks": 2}, "level": 16, "store": "furniture_store"},
	"vegetables": {"name": "Vegetables", "time": 50.0, "value": 45, "requires": {"seeds": 1}, "level": 8, "store": "farmers_market"}
}

var upgrade_requirements := {
	1: [{"item": "nails", "amount": 1}, {"item": "metal", "amount": 1}],
	2: [{"item": "planks", "amount": 1}, {"item": "wood", "amount": 1}],
	3: [{"item": "hammer", "amount": 1}, {"item": "nails", "amount": 2}],
	4: [{"item": "bricks", "amount": 1}, {"item": "cement", "amount": 1}],
	5: [{"item": "paint", "amount": 1}, {"item": "planks", "amount": 2}, {"item": "glass", "amount": 1}]
}

var residential_population := {1: 15, 2: 30, 3: 50, 4: 90, 5: 160, 6: 280}

func _ready() -> void:
	print("[ProductionManager] ", raw_materials.size(), " raw, ", crafted_items.size(), " crafted")

func get_available_raw() -> Array:
	var result: Array = []
	for item_id in raw_materials:
		if raw_materials[item_id].level <= GameManager.level:
			result.append(item_id)
	return result

func get_available_crafted() -> Array:
	var result: Array = []
	for item_id in crafted_items:
		if crafted_items[item_id].level <= GameManager.level:
			result.append(item_id)
	return result

func can_craft(item_id: String) -> bool:
	var recipe := get_recipe(item_id)
	if recipe.is_empty() or int(recipe.get("level", 1)) > GameManager.level:
		return false
	for material in recipe.get("inputs", {}):
		if not StorageManager.has_item(str(material), int(recipe.inputs[material])):
			return false
	return true

func consume_inputs(item_id: String) -> bool:
	if not can_craft(item_id):
		return false
	var inputs: Dictionary = get_recipe(item_id).get("inputs", {})
	# Validate all inputs before mutating inventory, so consumption is atomic.
	for material in inputs:
		if not StorageManager.has_item(str(material), int(inputs[material])):
			return false
	for material in inputs:
		if not StorageManager.remove_item(str(material), int(inputs[material])):
			push_error("Production input changed during atomic consumption: " + str(material))
			return false
	return true

func craft_item(item_id: String) -> bool:
	if not can_craft(item_id) or not StorageManager.has_space(1):
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
	for item_id in crafted_items:
		if str(crafted_items[item_id].get("store", "")) == building_type:
			if int(crafted_items[item_id].get("level", 1)) <= GameManager.level:
				return item_id
	return ""

func get_missing_inputs_text(item_id: String) -> String:
	var recipe := get_recipe(item_id)
	if recipe.is_empty():
		return "Unknown recipe"
	var missing: Array[String] = []
	for material in recipe.get("inputs", {}):
		var needed := int(recipe.inputs[material])
		var available := StorageManager.get_item_count(str(material))
		if available < needed:
			var material_name := str(raw_materials.get(material, {}).get("name", material.capitalize()))
			missing.append("%d %s" % [needed - available, material_name])
	return ", ".join(missing)

func get_item_value(item_id: String) -> int:
	if raw_materials.has(item_id):
		return raw_materials[item_id].value
	if crafted_items.has(item_id):
		return crafted_items[item_id].value
	return 5

func get_production_time(item_id: String) -> float:
	if raw_materials.has(item_id):
		return raw_materials[item_id].time
	if crafted_items.has(item_id):
		return crafted_items[item_id].time
	return 20.0

func get_upgrade_requirements(from_stage: int) -> Array:
	return upgrade_requirements.get(from_stage, [])

func get_population_for_stage(stage: int) -> int:
	return residential_population.get(clamp(stage, 1, 6), 15)

func can_afford_upgrade(from_stage: int) -> bool:
	var requirements = get_upgrade_requirements(from_stage)
	if requirements.is_empty():
		return false
	for requirement in requirements:
		if StorageManager.get_item_count(requirement.item) < requirement.amount:
			return false
	return true

func consume_upgrade_materials(from_stage: int) -> bool:
	if not can_afford_upgrade(from_stage):
		return false
	for requirement in get_upgrade_requirements(from_stage):
		StorageManager.remove_item(requirement.item, requirement.amount)
	return true
