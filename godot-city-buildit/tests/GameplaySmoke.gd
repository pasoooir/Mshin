extends Node3D

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")
const Icons = preload("res://scripts/ui/Icons.gd")
const RoadSystemScript = preload("res://scripts/systems/RoadSystem.gd")
const ProductionComponentScript = preload("res://scripts/production/ProductionComponent.gd")
const BuildingScene = preload("res://scenes/buildings/Building.tscn")
const GhostPreviewScript = preload("res://scripts/systems/GhostPreview.gd")
const CameraControllerScript = preload("res://scripts/systems/CameraController.gd")
const BuildingModelLoader = preload("res://scripts/buildings/BuildingModelLoader.gd")

class FireHazardTestBuilding extends Node3D:
	var building_id: String = ""
	var building_type: String = ""
	var definition: Dictionary = {}
	var status: String = "constructing"
	var grid_pos: Vector2i = Vector2i.ZERO
	var smoke_active: bool = false
	var current_population: int = 0
	var upgrade_stage: int = 1

	func set_fire_smoke(active: bool) -> void:
		smoke_active = active

var failures: Array[String] = []
var storage_capacity_signal_count := 0
var storage_changed_signal_count := 0

func _on_test_storage_capacity_changed(_new_capacity: int) -> void:
	storage_capacity_signal_count += 1

func _on_test_storage_changed() -> void:
	storage_changed_signal_count += 1

func _ready() -> void:
	call_deferred("_run_gameplay_test")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[GameplaySmoke] " + message)

func _confirm_catalog_build(hud) -> void:
	var action := hud.catalog_info_panel.find_child("CatalogBuildButton", true, false) as Button
	_check(action != null, "Building info panel must expose its BUILD action.")
	if action != null and not action.disabled:
		action.pressed.emit()
	if not BuildManager.is_placing and hud._catalog_selected_type != "":
		hud._select_building_type(hud._catalog_selected_type)
	# BUILD must never turn every catalog item into a dark/white card.
	for child in hud.submenu.get_children():
		if child is Button:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				_check(child.get_theme_stylebox(state).get_class() == "StyleBoxEmpty", "Pressing BUILD must keep every submenu item background transparent.")

func _find_building(type_id: String):
	for building in BuildManager.buildings.values():
		if is_instance_valid(building) and building.building_type == type_id:
			return building
	return null

func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _test_storage_and_production_chain() -> void:
	var expected_residential_population := {1:52,2:104,3:154,4:313,5:752,6:1836}
	for stage in expected_residential_population:
		_check(ProductionManager.get_population_for_stage(stage) == expected_residential_population[stage], "Residential stage %d must use the approved Mshin population target." % stage)
	_check(ProductionManager.get_population_for_stage(0) == 52 and ProductionManager.get_population_for_stage(7) == 1836, "Residential population lookup must clamp to the supported stage range.")
	var saved_storage: Dictionary = StorageManager.to_save_dict()
	StorageManager.capacity = 50
	StorageManager.items = {}
	_check(StorageManager.capacity == 50 and StorageManager.get_used() == 0, "New City Storage must start with 50 empty slots.")
	_check(StorageManager.add_item("metal", 2), "Storage must accept items within its capacity.")
	_check(StorageManager.get_count("metal") == 2 and StorageManager.get_free() == 48, "Storage item count/free-space accounting is incorrect.")
	_check(StorageManager.remove_items({"metal":2}), "Storage must remove a validated recipe input set.")
	_check(StorageManager.get_used() == 0, "Removing recipe inputs must update used storage.")
	_check(not StorageManager.remove_items({"metal":-1}), "Storage must reject negative inventory transactions.")
	_check(StorageManager.add_items({"metal":2,"wood":1}), "Storage must atomically add a valid multi-item transaction.")
	_check(StorageManager.get_count("metal") == 2 and StorageManager.get_count("wood") == 1, "Atomic inventory addition lost an item.")
	_check(StorageManager.remove_items({"metal":2,"wood":1}), "Storage must atomically remove a valid multi-item transaction.")
	_check(StorageManager.get_used() == 0, "Atomic inventory removal must restore the original used capacity.")
	_check(int(ProductionManager.raw_materials.metal.time_sec) == 60, "Metal production must take 60 seconds.")
	_check(int(ProductionManager.raw_materials.wood.time_sec) == 180, "Wood production must take 180 seconds.")
	_check(int(ProductionManager.raw_materials.chemicals.time_sec) == 7200, "Chemicals production must take 2 hours.")
	_check(int(ProductionManager.raw_materials.electrical.time_sec) == 25200, "Electrical Components production must take 7 hours.")
	_check(ProductionManager.raw_materials.size() == 11, "The complete 11-item SCBI raw-material catalog is required.")
	var expected_raw_levels := {"metal":1,"wood":2,"plastic":5,"seeds":7,"minerals":11,"chemicals":13,"textiles":15,"sugar_spices":17,"glass":19,"animal_feed":23,"electrical":29}
	var expected_raw_times := {"metal":60,"wood":180,"plastic":540,"seeds":1200,"minerals":1800,"chemicals":7200,"textiles":10800,"sugar_spices":14400,"glass":18000,"animal_feed":21600,"electrical":25200}
	for raw_id in expected_raw_levels:
		_check(int(ProductionManager.raw_materials[raw_id].get("level", 0)) == int(expected_raw_levels[raw_id]), "%s must unlock at its SCBI Mayor Level." % raw_id)
		_check(int(ProductionManager.raw_materials[raw_id].get("time_sec", 0)) == int(expected_raw_times[raw_id]), "%s must retain its SCBI production time." % raw_id)
	_check(ProductionManager.get_factory_material_ids("factory_small").has("electrical") and not ProductionManager.get_factory_material_ids("industrial_1").has("electrical"), "Factory tier restrictions must come from the central catalog.")
	_check(int(ProductionManager.get_recipe("hammer").get("time_sec", 0)) == 840, "Hammer must use the documented 14-minute reference time.")
	_check(int(ProductionManager.get_recipe("measuring_tape").get("time_sec", 0)) == 1200, "Measuring Tape must use the documented 20-minute reference time.")
	_check(int(ProductionManager.get_recipe("shovel").get("time_sec", 0)) == 1800, "Shovel must use the documented 30-minute reference time.")
	_check(str(ProductionManager.get_recipe("hammer").get("store", "")) == "hardware_store", "Hammer must be supplied by Hardware Store.")
	_check(int(ProductionManager.get_recipe("cooking_utensils").get("time_sec", 0)) == 2700, "Cooking Utensils must use the documented 45-minute base time.")
	_check(int(ProductionManager.get_recipe("ladder").get("time_sec", 0)) == 3600, "Ladder must use the documented 60-minute base time.")
	_check(int(ProductionManager.get_recipe("drill").get("time_sec", 0)) == 7200, "Drill must use the documented 120-minute base time.")
	_check(int(ProductionManager.get_recipe("vegetables").get("time_sec", 0)) == 1200 and ProductionManager.get_recipe("vegetables").get("inputs", {}) == {"seeds":2}, "Vegetables must require two Seeds and take 20 minutes.")
	_check(int(ProductionManager.get_recipe("chair").get("time_sec", 0)) == 1200 and ProductionManager.get_recipe("chair").get("inputs", {}) == {"wood":2,"nails":1,"hammer":1}, "Chair recipe must use the documented three-stage input chain.")
	_check(int(ProductionManager.get_recipe("table").get("time_sec", 0)) == 1800 and ProductionManager.get_recipe("table").get("inputs", {}) == {"planks":1,"nails":2,"hammer":1}, "Table recipe must use the documented input chain.")
	_check(ProductionManager.get_store_recipe_ids("hardware_store").has("drill") and ProductionManager.get_store_recipe_ids("farmers_market").has("beef") and ProductionManager.get_store_recipe_ids("furniture_store").has("couch"), "Commercial store catalogs must include their verified product families.")
	for recipe_id in ["cooking_utensils","ladder","drill","flour_bag","cream","corn","cheese","beef","home_textiles","cupboard","couch","pizza","cheese_fries","fruit_berries","bread_roll","bbq_grill","microwave_oven","ice_cream_sandwich","burger","lemonade_bottle"]:
		_check(StorageManager.item_definitions.has(recipe_id), "%s must be registered in City Storage." % recipe_id)
		_check(Icons.CRAFTED_IDS.has(recipe_id), "%s must have a local product icon definition." % recipe_id)
	_check(not ProductionManager.get_store_recipe_ids("hardware_store").has("paint"), "Paint must not appear in Hardware Store; its supplier is Building Supplies.")
	var nails: Dictionary = ProductionManager.get_recipe("nails")
	_check(int(nails.get("time_sec",0)) == 300 and nails.get("inputs",{}) == {"metal":2}, "Nails must require 2 Metal and take 5 minutes.")
	_check(BuildManager.building_types.factory_small.get("production_slots",0) == 2, "Small Factory must expose two parallel production slots.")
	_check(BuildManager.building_types.factory_basic.get("production_slots",0) == 3 and BuildManager.building_types.factory_basic.get("population_required",0) == 4000, "Basic Factory must have 3 slots and require 4,000 population.")
	_check(BuildManager.building_types.factory_mass.get("production_slots",0) == 4 and BuildManager.building_types.factory_mass.get("population_required",0) == 27000, "Mass Production must have 4 slots and require 27,000 population.")
	_check(BuildManager.building_types.factory_hightech.get("production_slots",0) == 5 and BuildManager.building_types.factory_hightech.get("population_required",0) == 80000, "High-tech Factory must have 5 slots and require 80,000 population.")
	_check(BuildManager.building_types.factory_nano.get("production_slots",0) == 5 and BuildManager.building_types.factory_nano.get("pollution",1) == 0 and BuildManager.building_types.factory_nano.get("population_required",0) == 1500000, "Nano-tech Factory must have 5 slots, no pollution and require 1,500,000 population.")
	_check(ProductionManager.raw_materials.has("electrical"), "Small Factory must support all raw products, gated only by each material's Mayor Level.")
	_check(BuildManager.building_types.building_supplies.get("production_slots",0) == 2, "Building Supplies must expose a two-order queue.")
	_check(BuildManager.building_types.fast_food.get("production_slots",0) == 1 and int(BuildManager.building_types.fast_food.get("level", 0)) == 25, "Fast Food Restaurant must follow its SCBI unlock and open a production panel.")
	_check(BuildManager.building_types.donut_shop.get("production_slots",0) == 1 and BuildManager.building_types.home_appliances.get("production_slots",0) == 1 and BuildManager.building_types.gardening_supplies.get("production_slots",0) == 1, "Upstream SCBI stores must expose production panels.")
	_check(ProductionManager.get_store_catalog_ids("donut_shop").size() == 6 and ProductionManager.get_store_catalog_ids("home_appliances").size() == 5 and ProductionManager.get_store_catalog_ids("gardening_supplies").size() == 6, "Upstream stores must expose their complete product-family catalogs.")
	_check(ProductionManager.get_store_catalog_ids("fashion_store").size() == 5 and ProductionManager.get_store_catalog_ids("sports_shop").size() == 5 and ProductionManager.get_store_catalog_ids("toy_store").size() == 4, "Fashion, Sports and Toy stores must expose their SCBI product families.")
	for scbi_store_id in ["building_supplies","hardware_store","farmers_market","furniture_store","fast_food","donut_shop","home_appliances","gardening_supplies","fashion_store","sports_shop","toy_store","restoration_office","farmers_store","dessert_shop"]:
		_check(BuildManager.building_types.has(scbi_store_id), "%s must be selectable from the commercial build catalog." % scbi_store_id)
		_check(int(BuildManager.building_types.get(scbi_store_id, {}).get("production_slots", 0)) > 0, "%s must open its production panel." % scbi_store_id)
		_check(not ProductionManager.get_store_catalog_ids(scbi_store_id).is_empty(), "%s must expose its store-specific product catalog." % scbi_store_id)
		_check(Icons.COMMERCIAL_IDS.has(scbi_store_id), "%s must have a dedicated commercial icon." % scbi_store_id)
	_check(ProductionManager.get_store_catalog_ids("restoration_office").size() == 5 and ProductionManager.get_store_catalog_ids("farmers_store").size() == 3 and ProductionManager.get_store_catalog_ids("dessert_shop").size() == 5, "Restoration, Farmer's Store and Dessert Shop must expose their SCBI product families.")
	for store_id in ["fashion_store","sports_shop","toy_store","restoration_office","farmers_store","dessert_shop"]:
		_check(BuildManager.building_types.has(store_id) and int(BuildManager.building_types[store_id].get("production_slots", 0)) == 1, "%s must be selectable and have a production panel." % store_id)
	_check(ProductionManager.get_store_recipe_ids("donut_shop").has("bread_roll") and ProductionManager.get_store_recipe_ids("home_appliances").has("bbq_grill") and ProductionManager.get_store_recipe_ids("home_appliances").has("microwave_oven") and ProductionManager.get_store_recipe_ids("farmers_market").has("fruit_berries"), "Fast Food upstream supply chains must resolve to their correct stores.")
	_check(ProductionManager.get_store_catalog_ids("fast_food").size() == 6 and ProductionManager.get_store_recipe_ids("fast_food").has("pizza") and ProductionManager.get_store_recipe_ids("fast_food").has("cheese_fries"), "Fast Food must display all six products and activate verified recipes.")
	_check(ProductionManager.get_recipe("pizza").get("inputs", {}) == {"flour_bag":1,"cheese":1,"beef":1} and int(ProductionManager.get_recipe("pizza").get("time_sec", 0)) == 1440, "Pizza must use its verified 24-minute recipe.")
	_check(ProductionManager.get_recipe("cheese_fries").get("inputs", {}) == {"cheese":1,"vegetables":1} and int(ProductionManager.get_recipe("cheese_fries").get("time_sec", 0)) == 1200, "Cheese Fries must use its verified 20-minute recipe.")
	_check(ProductionManager.get_recipe("ice_cream_sandwich").get("inputs", {}) == {"cream":1,"bread_roll":1}, "Ice Cream Sandwich must use the verified Donut Shop supply chain.")
	_check(ProductionManager.get_recipe("burger").get("inputs", {}) == {"beef":1,"bread_roll":1,"bbq_grill":1}, "Burger must use the verified Home Appliances supply chain.")
	_check(ProductionManager.get_recipe("lemonade_bottle").get("inputs", {}) == {"glass":2,"sugar_spices":2,"fruit_berries":1}, "Lemonade Bottle must use the verified Farmer's Market supply chain.")
	_check(ProductionManager.get_recipe("popcorn").get("inputs", {}) == {"corn":2,"microwave_oven":1} and int(ProductionManager.get_recipe("popcorn").get("time_sec", 0)) == 1800 and int(ProductionManager.get_recipe("popcorn").get("value", 0)) == 1250, "Popcorn must use the Fandom-verified Corn x2 + Microwave Oven x1 recipe.")
	_check(ProductionManager.get_store_recipe_ids("fast_food").has("popcorn"), "Verified Popcorn must be an active Fast Food recipe.")
	_check(ProductionManager.get_recipe("lawn_mower").get("inputs", {}) == {"metal":3,"electrical":1,"paint":1} and int(ProductionManager.get_recipe("lawn_mower").get("time_sec", 0)) == 7200 and int(ProductionManager.get_recipe("lawn_mower").get("value", 0)) == 840, "Lawn Mower must use the Fandom-verified Metal, Electrical Components and Paint recipe.")
	_check(int(ProductionManager.get_recipe("measuring_tape").get("value", 0)) == 110 and int(ProductionManager.get_recipe("bbq_grill").get("value", 0)) == 530 and int(ProductionManager.get_recipe("bread_roll").get("value", 0)) == 1840, "Corrected commercial Max Values must match the Fandom item catalogue.")
	StorageManager.items = {"tree_sapling":1}
	var stocked_fruit_chain := ProductionManager.get_recipe_dependency_text("fruit_berries")
	_check(stocked_fruit_chain.contains("Tree Saplings — required 1 | stock 1 | missing 0") and not stocked_fruit_chain.contains("Shovel"), "Dependency tree must stop expanding a product already present in City Storage.")
	StorageManager.items = {"seeds":1}
	var shortage_fruit_chain := ProductionManager.get_recipe_dependency_text("fruit_berries")
	_check(shortage_fruit_chain.contains("Seeds — required 2 | stock 1 | missing 1") and shortage_fruit_chain.contains("Shovel"), "Dependency tree must calculate missing quantities and recursively expose intermediate ingredients.")
	StorageManager.items = {}
	_check(is_equal_approx(ProductionManager.get_estimated_chain_seconds("nails"), 360.0), "Nails chain estimate must show parallel Metal production plus five-minute store production.")
	_check(ProductionManager.get_estimated_chain_seconds("backpack") < 0.0, "Unverified catalog-only recipes must not receive a fabricated chain-time estimate.")
	StorageManager.items = {}
	for catalog_id in ["ice_cream_sandwich","pizza","burger","cheese_fries","lemonade_bottle","popcorn","bread_roll","bbq_grill","microwave_oven","fruit_berries","tree_sapling","donuts","green_smoothie","cherry_cheesecake","frozen_yogurt","coffee","refrigerator","lighting_system","tv","grass","garden_furniture","lawn_mower","fire_pit","garden_gnome","cap","shoes","watch","business_suit","backpack","tennis_racket","sports_drink","soccer_shoes","protein_bar","ping_pong_table","block_letters","kite","teddy_bear","game_console","forged_iron","carved_wood","cut_stone","tapestries","stained_glass","wool_shirt","picnic_basket","apple_jam","tiramisu","churros","profiterole","mochi","pavlova"]:
		_check(Icons.CRAFTED_IDS.has(catalog_id), "%s must have a local product icon." % catalog_id)
		_check(StorageManager.item_definitions.has(catalog_id), "%s must have a readable storage item definition." % catalog_id)
	# Mayor level unlocks materials; factory count and factory tier use separate gates.
	var original_level := GameManager.level
	var original_population := GameManager.population
	var original_factory_count := BuildManager.factory_count
	GameManager.level = 4
	_check(ProductionManager.get_available_raw().has("metal") and ProductionManager.get_available_raw().has("wood"), "Level 4 must offer Metal and Wood.")
	_check(not ProductionManager.get_available_raw().has("plastic") and not ProductionManager.get_available_raw().has("seeds"), "Level 4 must hide Plastic and Seeds until their own unlock levels.")
	GameManager.level = 5
	_check(ProductionManager.get_available_raw().has("plastic"), "Plastic must unlock at Mayor Level 5.")
	GameManager.level = 11
	_check(ProductionManager.get_available_raw().has("minerals"), "Minerals must unlock at Mayor Level 11.")
	GameManager.level = 13
	_check(ProductionManager.get_available_raw().has("chemicals"), "Chemicals must unlock at Mayor Level 13.")
	_check(LevelProgression.get_factory_limit_for_level(1) == 2 and LevelProgression.get_factory_limit_for_level(2) == 3 and LevelProgression.get_factory_limit_for_level(3) == 4, "Early-game factory count caps must be 2/3/4 at levels 1/2/3.")
	_check(LevelProgression.get_factory_limit_for_level(58) == 12, "Mayor Level 58 must unlock the 12th factory slot.")
	GameManager.level = 1
	GameManager.population = 3999
	_check(not BuildManager.can_build_factory_type("factory_basic"), "Basic Factory must remain population-locked below 4,000 residents.")
	GameManager.population = 4000
	_check(BuildManager.can_build_factory_type("factory_basic"), "Basic Factory must unlock at 4,000 residents.")
	GameManager.population = 26999
	_check(not BuildManager.can_build_factory_type("factory_mass"), "Mass Production must remain locked below 27,000 residents.")
	GameManager.population = 27000
	_check(BuildManager.can_build_factory_type("factory_mass"), "Mass Production must unlock at 27,000 residents.")
	GameManager.population = 79999
	_check(not BuildManager.can_build_factory_type("factory_hightech"), "High-tech Factory must remain locked below 80,000 residents.")
	GameManager.population = 80000
	_check(BuildManager.can_build_factory_type("factory_hightech"), "High-tech Factory must unlock at 80,000 residents.")
	GameManager.population = 1499999
	_check(not BuildManager.can_build_factory_type("factory_nano"), "Nano-tech Factory must remain locked below 1,500,000 residents.")
	GameManager.population = 1500000
	_check(BuildManager.can_build_factory_type("factory_nano"), "Nano-tech Factory must unlock at 1,500,000 residents.")
	var industrial_catalog := BuildManager.get_available_buildings("industrial")
	for factory_id in ["factory_small", "factory_basic", "factory_mass", "factory_hightech", "factory_nano"]:
		_check(industrial_catalog.has(factory_id), "%s must remain visible in the Industrial catalog while locked." % factory_id)
	GameManager.population = 0
	BuildManager.factory_count = 0
	_check(BuildManager.get_factory_build_lock_reason("factory_basic").contains("4000"), "Basic Factory lock must explain its 4,000 population requirement.")
	GameManager.population = original_population
	GameManager.level = 1
	BuildManager.factory_count = 2
	_check(not BuildManager.can_build_another_factory(), "A level 1 city must not build a third factory.")
	GameManager.level = 2
	_check(BuildManager.can_build_another_factory(), "A level 2 city must be allowed to build a third factory.")
	BuildManager.factory_count = original_factory_count
	GameManager.level = original_level
	GameManager.population = original_population

	var factory = ProductionComponentScript.new()
	factory.slot_count = 2
	factory.is_factory = true
	add_child(factory)
	_check(factory.get_slot_count() == 2, "Factory production component must create two parallel slots.")
	_check(factory.start_factory("metal", 0), "Factory must start Metal in an empty slot.")
	_check(factory.start_factory("metal", 1), "Factory must run a second Metal batch in parallel.")
	var saved_slots: Array = factory.to_save_array()
	var finish_time := int(saved_slots[0].get("finish_unix",0))
	var restored_factory = ProductionComponentScript.new()
	restored_factory.slot_count = 2
	restored_factory.is_factory = true
	add_child(restored_factory)
	restored_factory.from_save_array(saved_slots)
	_check(int(restored_factory.get_slot(0).get("finish_unix",0)) == finish_time, "Production save/load must preserve absolute finish timestamps.")
	for index in range(2):
		var slot: Dictionary = restored_factory.slots[index]
		slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
		restored_factory.slots[index] = slot
	restored_factory.refresh_slots()
	_check(bool(restored_factory.get_slot(0).get("ready",false)), "An elapsed offline factory timer must restore as ready.")
	_check(restored_factory.collect(0), "Ready factory output must collect into City Storage.")
	_check(StorageManager.get_count("metal") == 1, "Factory collection must add exactly one raw item to Storage.")

	var shop = ProductionComponentScript.new()
	shop.slot_count = 2
	shop.is_factory = false
	shop.shop_id = "building_supplies"
	add_child(shop)
	_check(StorageManager.add_item("metal",1), "Test setup must provide two Metal for Nails.")
	_check(shop.start_craft("nails",0), "Building Supplies must start Nails when 2 Metal are available.")
	_check(StorageManager.get_count("metal") == 0, "Crafting must deduct inputs from Storage at start.")
	var craft_slot: Dictionary = shop.slots[0]
	craft_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	shop.slots[0] = craft_slot
	shop.refresh_slots()
	_check(shop.collect(0), "Finished Nails must collect back into City Storage.")
	_check(StorageManager.get_count("nails") == 1, "Collected Nails must be returned to City Storage.")
	_check(not StorageManager.can_add("overflow_test", 51), "Storage must reject a collection larger than remaining capacity.")
	factory.queue_free()
	restored_factory.queue_free()
	shop.queue_free()
	StorageManager.from_save_dict(saved_storage)

func _test_wind_turbine_rotor_animation() -> void:
	# Use the real scene so every @onready node path exists in the test fixture.
	var test_building: Building = BuildingScene.instantiate()
	add_child(test_building)
	var rotor := Node3D.new()
	rotor.name = "WindTurbineRotor_Test"
	test_building.add_child(rotor)
	test_building._wind_turbine_rotor = rotor
	test_building.definition = {"power": 12, "category": "service"}
	test_building.status = "constructing"
	test_building._process(1.0)
	_check(is_zero_approx(rotor.rotation.z), "Wind turbine rotor must remain still while the structure is under construction.")
	test_building.status = "completed"
	test_building._process(1.0)
	_check(rotor.rotation.z > 0.5, "Completed wind turbine rotor must rotate continuously.")
	var first_rotation := rotor.rotation.z
	test_building._process(1.0)
	_check(rotor.rotation.z > first_rotation, "Wind turbine rotor animation must keep advancing every frame.")
	test_building.free()

func _test_immigration_coefficients() -> void:
	_check(is_equal_approx(HappinessManager._immigration_happiness_factor(60.0), 0.3), "Immigration happiness factor at 60% must be 0.3.")
	_check(is_equal_approx(HappinessManager._immigration_happiness_factor(70.0), 0.55), "Immigration happiness factor at 70% must be 0.55.")
	_check(is_equal_approx(HappinessManager._immigration_happiness_factor(80.0), 0.8), "Immigration happiness factor at 80% must be 0.8.")
	_check(is_equal_approx(HappinessManager._immigration_happiness_factor(90.0), 1.0), "Immigration happiness factor at 90% must be 1.0.")
	_check(is_equal_approx(HappinessManager._immigration_service_factor(false, false, false), 0.4), "No-service immigration factor must be 0.4.")
	_check(is_equal_approx(HappinessManager._immigration_service_factor(true, false, false), 0.7), "Single-utility immigration factor must be 0.7.")
	_check(is_equal_approx(HappinessManager._immigration_service_factor(true, true, false), 1.0), "Dual-utility immigration factor must be 1.0.")
	_check(is_equal_approx(HappinessManager._immigration_service_factor(true, true, true), 1.15), "Full-service immigration factor must be 1.15.")

func _test_camera_focus_math() -> void:
	var current := Vector3(-9.0, 0.0, 2.5)
	var target := Vector3(18.0, 0.0, -12.0)
	var focused_step := CameraControllerScript.interpolate_focus(current, target, 0.1, 8.0)
	_check(focused_step.distance_to(target) < current.distance_to(target), "Camera focus interpolation must move toward the selected building.")
	_check(is_equal_approx(focused_step.y, current.y), "Camera focus interpolation must preserve the rig height.")
	_check(focused_step.distance_to(target) > 0.0, "Camera focus must ease toward the building instead of teleporting instantly.")

func _test_camera_inertia_math() -> void:
	var initial_pan := Vector2(120.0, -60.0)
	var damped_pan := CameraControllerScript.decay_pan_velocity(initial_pan, 0.1, 8.0)
	_check(damped_pan.length() < initial_pan.length(), "Camera pan inertia must decay over time.")
	_check(damped_pan.dot(initial_pan) > 0.0, "Camera pan inertia must preserve the drag direction while decaying.")
	var initial_orbit := 2.0
	var damped_orbit := CameraControllerScript.decay_orbit_velocity(initial_orbit, 0.1, 10.0)
	_check(absf(damped_orbit) < absf(initial_orbit), "Camera orbit inertia must decay over time.")
	_check(damped_orbit > 0.0, "Camera orbit inertia must preserve the rotation direction while decaying.")

func _test_road_gateway_connectivity(road_system) -> void:
	_check(road_system.is_road_connected_to_gateway(RoadSystemScript.GATEWAY_ROAD_CELL), "The seeded highway gateway tile must belong to the connected road network.")
	_check(not road_system.remove_road(RoadSystemScript.GATEWAY_ROAD_CELL), "The permanent highway gateway tile must not be removable.")
	_check(road_system.is_road_connected_to_gateway(Vector2i(1, 0)), "The far end of the seeded starter connector must be connected to the gateway.")

	_check(road_system.remove_road(Vector2i(0, -1)), "The first gateway bridge tile must be removable for the connectivity test.")
	_check(road_system.remove_road(Vector2i(0, 0)), "The second gateway bridge tile must be removable for the connectivity test.")
	_check(not road_system.is_road_connected_to_gateway(Vector2i(1, 0)), "Removing both bridge tiles must disconnect the far road segment from the highway gateway.")
	_check(not BuildManager.has_road_access(Vector2i(1, 1), Vector2i.ONE), "A building beside a disconnected road segment must lose valid road access.")
	_check(road_system.get_road_upgrade_error(Vector2i(1, 0)).contains("connected to the highway Gateway"), "A disconnected road tile must not be upgraded.")
	var disconnected_building := FireHazardTestBuilding.new()
	disconnected_building.status = "completed"
	disconnected_building.grid_pos = Vector2i(1, 1)
	disconnected_building.definition = {"size": Vector2i.ONE, "category": "industrial"}
	add_child(disconnected_building)
	_check(not BuildManager.is_building_operational(disconnected_building), "A completed building beside a disconnected road must become non-operational.")
	var disconnected_factory = ProductionComponentScript.new()
	disconnected_factory.is_factory = true
	disconnected_factory.slot_count = 1
	disconnected_factory.factory_type = "factory_small"
	disconnected_factory.owner_building = disconnected_building
	add_child(disconnected_factory)
	_check(not disconnected_factory.start_factory("metal", 0), "A disconnected factory must not start production.")
	_check(road_system.get_road_placement_error(Vector2i(2, 0)).contains("highway network"), "New roads must not extend a disconnected road segment.")

	_check(road_system.place_road(Vector2i(0, -1)), "The first bridge tile must reconnect to the gateway.")
	_check(road_system.place_road(Vector2i(0, 0)), "The second bridge tile must reconnect the far segment.")
	_check(road_system.is_road_connected_to_gateway(Vector2i(1, 0)), "Restoring the bridge must reconnect the far road segment.")
	_check(BuildManager.is_building_operational(disconnected_building), "Restoring the gateway connection must reactivate the building.")
	_check(disconnected_factory.start_factory("metal", 0), "A reconnected factory must be able to resume production.")

	# A running factory must freeze its deadline while the road gateway is cut,
	# then add the disconnected interval back when access is restored.
	var active_slot: Dictionary = disconnected_factory.get_slot(0)
	var pause_test_now := int(Time.get_unix_time_from_system())
	active_slot["finish_unix"] = pause_test_now + 120
	disconnected_factory.slots[0] = active_slot
	_check(road_system.remove_road(Vector2i(0, -1)), "The first gateway tile must disconnect the factory for its timer-pause test.")
	_check(road_system.remove_road(Vector2i(0, 0)), "The second gateway tile must complete the factory timer-pause disconnection.")
	disconnected_factory.refresh_slots()
	var paused_slot: Dictionary = disconnected_factory.get_slot(0)
	_check(int(paused_slot.get("paused_at_unix", 0)) > 0, "A running factory slot must record when road access is lost.")
	# Move the pause timestamp back in a controlled way to test time compensation
	# without sleeping in the gameplay smoke test.
	paused_slot["paused_at_unix"] = pause_test_now - 15
	disconnected_factory.slots[0] = paused_slot
	_check(road_system.place_road(Vector2i(0, -1)), "The first gateway tile must reconnect the factory timer test.")
	_check(road_system.place_road(Vector2i(0, 0)), "The second gateway tile must reconnect the factory timer test.")
	disconnected_factory.refresh_slots()
	var resumed_slot: Dictionary = disconnected_factory.get_slot(0)
	_check(int(resumed_slot.get("finish_unix", 0)) >= pause_test_now + 135, "A factory must preserve its remaining production time across a 15-second road outage.")
	_check(not resumed_slot.has("paused_at_unix"), "A reconnected factory slot must clear its paused timestamp.")

	# Ready goods remain on the building while it is disconnected and cannot be
	# collected until the road connection is restored.
	resumed_slot["ready"] = true
	disconnected_factory.slots[0] = resumed_slot
	_check(road_system.remove_road(Vector2i(0, -1)), "The first gateway tile must disconnect the ready-product collection test.")
	_check(road_system.remove_road(Vector2i(0, 0)), "The second gateway tile must disconnect the ready-product collection test.")
	_check(not disconnected_factory.collect(0), "A disconnected factory must not allow collection of a ready product.")
	_check(road_system.place_road(Vector2i(0, -1)), "The first gateway tile must restore ready-product access.")
	_check(road_system.place_road(Vector2i(0, 0)), "The second gateway tile must restore ready-product access.")

	# Store queues obey the same road-operational boundary as factories.
	var disconnected_store := ProductionComponentScript.new()
	disconnected_store.is_factory = false
	disconnected_store.slot_count = 2
	disconnected_store.shop_id = "building_supplies"
	disconnected_store.owner_building = disconnected_building
	add_child(disconnected_store)
	var disconnected_home := load("res://scenes/buildings/Building.tscn").instantiate() as Building
	disconnected_home.building_id = "road_access_test_home"
	disconnected_home.building_type = "residential_villa"
	disconnected_home.grid_pos = Vector2i(1, 1)
	disconnected_home.definition = {"size": Vector2i.ONE, "category": "residential"}
	disconnected_home.status = "completed"
	add_child(disconnected_home)

	var store_pause_now := int(Time.get_unix_time_from_system())
	disconnected_store.slots[0] = {
		"item_id": "nails",
		"start_unix": store_pause_now,
		"finish_unix": store_pause_now + 120,
		"ready": false,
		"queued": false
	}
	_check(road_system.remove_road(Vector2i(0, -1)), "The first gateway tile must disconnect store and residential operation tests.")
	_check(road_system.remove_road(Vector2i(0, 0)), "The second gateway tile must disconnect store and residential operation tests.")
	_check(not disconnected_store.start_craft("nails", 1), "A disconnected commercial building must not accept a new store order.")
	disconnected_store.refresh_slots()
	var paused_store_slot: Dictionary = disconnected_store.get_slot(0)
	_check(int(paused_store_slot.get("paused_at_unix", 0)) > 0, "A running store order must record its pause when road access is lost.")
	_check(not disconnected_home.try_upgrade(), "A residential building disconnected from the gateway must reject an upgrade.")
	paused_store_slot["paused_at_unix"] = store_pause_now - 15
	disconnected_store.slots[0] = paused_store_slot
	_check(road_system.place_road(Vector2i(0, -1)), "The first gateway tile must reconnect store and residential operation tests.")
	_check(road_system.place_road(Vector2i(0, 0)), "The second gateway tile must reconnect store and residential operation tests.")
	disconnected_store.refresh_slots()
	var resumed_store_slot: Dictionary = disconnected_store.get_slot(0)
	_check(int(resumed_store_slot.get("finish_unix", 0)) >= store_pause_now + 135, "A store must preserve its remaining order time across a 15-second road outage.")
	_check(not resumed_store_slot.has("paused_at_unix"), "A reconnected store order must clear its paused timestamp.")

	disconnected_store.queue_free()
	disconnected_home.queue_free()
	disconnected_factory.queue_free()
	disconnected_building.queue_free()
	EconomyManager.add_simoleons(RoadSystemScript.ROAD_COST * 8)

func _test_road_traffic_capacity(road_system) -> void:
	var saved_level := GameManager.level
	var saved_population := GameManager.population
	var saved_money := EconomyManager.simoleons
	road_system.clear_roads()
	road_system.seed_starter_access()
	GameManager.level = 20
	EconomyManager.simoleons = 50000
	GameManager.set_population(5000)
	TrafficManager.recalculate_from_roads()
	_check(road_system.get_road_count() == 50, "Traffic capacity test must start with the 50-tile Gateway connector.")
	_check(TrafficManager.traffic_demand == 100, "Traffic demand must convert 5,000 residents into 100 Mshin traffic units.")
	_check(TrafficManager.road_capacity == 100, "Fifty connected two-lane road tiles must provide 100 traffic units of capacity.")
	_check(is_equal_approx(TrafficManager.congestion_ratio, 1.0), "Traffic congestion ratio must reflect demand divided by road capacity.")
	_check(is_equal_approx(TrafficManager.get_happiness_penalty(), -8.0), "At-capacity traffic must apply the documented Mshin -8 happiness penalty.")

	var upgrade_cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0)]
	for cell in upgrade_cells:
		for tier_step in range(3):
			_check(road_system.upgrade_road(cell), "Connected road tile must upgrade through all three tiers for traffic-capacity validation.")
	TrafficManager.recalculate_from_roads()
	_check(TrafficManager.road_capacity == 130, "Five Avenue tiles must add 30 traffic-capacity units to the Gateway network.")
	_check(TrafficManager.congestion_ratio < 0.8, "Upgrading roads must reduce congestion below the service-penalty threshold.")
	_check(is_equal_approx(TrafficManager.get_happiness_penalty(), 0.0), "Road capacity upgrades must remove the traffic happiness penalty when capacity is sufficient.")

	for cell in upgrade_cells:
		road_system.restore_road_level(cell, 1)
	GameManager.level = saved_level
	GameManager.set_population(saved_population)
	EconomyManager.simoleons = saved_money
	TrafficManager.recalculate_from_roads()

func _test_gateway_vehicle_route(road_system) -> void:
	var previous_enabled := TrafficManager.vehicle_simulation_enabled
	TrafficManager.vehicle_simulation_enabled = false
	TrafficManager.clear_active_vehicle()
	road_system.clear_roads()
	road_system.seed_starter_access()
	var connected_roads: Dictionary = road_system.get_gateway_connected_roads()
	var route: Array[Vector2i] = TrafficManager.build_gateway_round_trip_route()
	_check(route.size() >= 3, "A connected Gateway road network must produce an outbound-and-return vehicle route.")
	_check(route.front() == road_system.GATEWAY_ROAD_CELL and route.back() == road_system.GATEWAY_ROAD_CELL, "The simulated vehicle route must start and finish at the permanent Gateway.")
	for cell in route:
		_check(connected_roads.has(cell), "Every vehicle route cell must belong to the Gateway-connected road graph.")
	var vehicle := TrafficManager.spawn_vehicle_now()
	_check(is_instance_valid(vehicle), "TrafficManager must spawn a vehicle on the Gateway route.")
	if is_instance_valid(vehicle):
		_check(vehicle.get_node_or_null("Body") != null and vehicle.get_node_or_null("Cabin") != null, "The simulated vehicle must have visible original 3D body and cabin geometry.")
		var start_position := vehicle.global_position
		vehicle._process(0.25)
		_check(vehicle.global_position.distance_to(start_position) > 0.1, "The simulated vehicle must advance along its road route.")
	TrafficManager.clear_active_vehicle()
	TrafficManager.vehicle_simulation_enabled = previous_enabled
	TrafficManager.recalculate_from_roads()

func _test_road_painting_drag(road_system) -> void:
	var input_node = get_node("CityInput")
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	road_system.set_road_mode(true)
	var start_screen: Vector2 = active_camera.unproject_position(BuildManager.grid_to_world(Vector2i(1, 0)))
	var end_screen: Vector2 = active_camera.unproject_position(BuildManager.grid_to_world(Vector2i(5, 0)))
	input_node._start_road_stroke(77, start_screen)
	input_node._continue_road_stroke(77, end_screen)
	input_node._end_road_stroke(77)
	road_system.set_road_mode(false)
	_check(road_system.get_road_count() == 54, "Dragging the road tool should pave every connected tile between the start and end.")
	for x in range(2, 6):
		_check(road_system.has_road(Vector2i(x, 0)), "Road drag skipped connected grid tile %d." % x)
	_check(road_system.get_road_placement_error(Vector2i(20, 20)) != "", "Disconnected road placement should explain why it is blocked.")

func _simulate_building_drag(input_node, active_camera: Camera3D, type_id: String, target_grid: Vector2i) -> void:
	BuildManager.select_building(type_id)
	var target_screen: Vector2 = active_camera.unproject_position(BuildManager.grid_to_world(target_grid))
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = target_screen + Vector2(-48, 0)
	input_node._unhandled_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = target_screen
	drag.relative = Vector2(48, 0)
	input_node._unhandled_input(drag)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = target_screen
	input_node._unhandled_input(up)
	var placed = BuildManager.building_at_cell(target_grid)
	_check(placed != null and placed.building_type == type_id,
		"Drag-and-drop failed for %s at %s." % [type_id, target_grid])
	if placed != null:
		BuildManager.unregister_building(placed.building_id)
		placed.queue_free()

func _test_drag_gestures_do_not_place() -> void:
	var input_node = get_node("CityInput")
	var active_camera: Camera3D = get_viewport().get_camera_3d()

	# Exercise all three main placement categories through the actual touch
	# event path, not by calling BuildManager.place_building directly.
	_simulate_building_drag(input_node, active_camera, "residential_1", Vector2i(-2, 1))
	_simulate_building_drag(input_node, active_camera, "building_supplies", Vector2i(0, 1))
	_simulate_building_drag(input_node, active_camera, "industrial_1", Vector2i(2, 1))

	# A two-finger gesture must remain camera navigation and never place.
	var initial_count: int = BuildManager.buildings.size()
	var first_down := InputEventScreenTouch.new()
	first_down.index = 0
	first_down.pressed = true
	first_down.position = Vector2(420, 300)
	input_node._unhandled_input(first_down)
	var second_down := InputEventScreenTouch.new()
	second_down.index = 1
	second_down.pressed = true
	second_down.position = Vector2(700, 300)
	input_node._unhandled_input(second_down)
	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(730, 320)
	pinch_drag.relative = Vector2(30, 20)
	input_node._unhandled_input(pinch_drag)
	var second_up := InputEventScreenTouch.new()
	second_up.index = 1
	second_up.pressed = false
	second_up.position = Vector2(730, 320)
	input_node._unhandled_input(second_up)
	var first_up := InputEventScreenTouch.new()
	first_up.index = 0
	first_up.pressed = false
	first_up.position = Vector2(420, 300)
	input_node._unhandled_input(first_up)
	_check(BuildManager.buildings.size() == initial_count, "Two-finger gesture triggered an unintended placement.")
	BuildManager.cancel_placement()

func _node_has_label_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child in node.get_children():
		if _node_has_label_text(child, expected):
			return true
	return false

func _node_has_label_text_containing(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text.contains(expected):
		return true
	for child in node.get_children():
		if _node_has_label_text_containing(child, expected):
			return true
	return false

func _test_build_menu_visibility() -> void:
	# Allow the dynamically-created HUD containers to complete their first layout pass.
	await get_tree().process_frame
	await get_tree().process_frame
	var hud = get_node_or_null("HUD")
	_check(hud != null, "Main scene HUD is missing.")
	if hud == null:
		return
	# The Mayor Level badge must be procedural, glossy and geometrically centered.
	var level_badge := hud.find_child("LevelBadge", true, false) as Control
	var level_value := hud.find_child("LevelValue", true, false) as Label
	var level_visual := hud.find_child("LevelBadgeVisual", true, false)
	_check(level_badge != null and level_badge.custom_minimum_size.x >= 80.0 and is_equal_approx(level_badge.custom_minimum_size.x, level_badge.custom_minimum_size.y), "Mayor Level badge must retain a circular touch-independent footprint.")
	_check(level_visual != null, "Mayor Level badge must use the procedural glossy circle instead of a raster PNG.")
	_check(level_badge != null and level_badge.get_child_count() == 2, "Old level PNG must be removed; only the procedural circle and number may remain.")
	_check(level_value != null and level_value.anchor_left == 0.0 and level_value.anchor_top == 0.0 and level_value.anchor_right == 1.0 and level_value.anchor_bottom == 1.0, "Level number must fill the badge bounds for exact geometric centering.")
	_check(level_value != null and level_value.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and level_value.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Level number must be centered horizontally and vertically inside the circular badge.")
	if level_visual != null:
		var expected_xp_fraction := float(GameManager.experience) / float(maxi(1, GameManager.get_xp_needed()))
		_check(absf(float(level_visual.get("progress_fraction")) - expected_xp_fraction) < 0.001, "Circular XP ring must reflect the live Mayor XP progress.")
	var build_button := hud.get_node_or_null("BuildMenuButton")
	var toolbar := hud.get_node_or_null("RightToolbar") as Control
	_check(build_button == null, "Legacy hard-hat Build button must be removed from the HUD.")
	_check(toolbar != null and toolbar.visible, "Transparent right-side category PNG rail must be visible immediately.")
	if toolbar == null:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	_check(toolbar.get_global_rect().intersects(viewport_rect), "Right-side category PNG rail is outside the visible screen.")
	_check(toolbar.get_global_rect().size.x < viewport_rect.size.x * 0.12, "Transparent category rail covers too much of the mobile play area.")
	# The road category must expose an active upgrade action, not a disabled placeholder.
	hud._show_submenu("road")
	var road_upgrade_button := hud.find_child("road_upgrade", true, false) as Button
	_check(road_upgrade_button != null and not road_upgrade_button.disabled, "Road upgrade must be selectable from the road catalog.")
	var road_system_for_menu = get_node_or_null("World/RoadSystem")
	hud._on_submenu_option("road", "road_upgrade")
	_check(road_system_for_menu != null and road_system_for_menu.is_road_upgrade_mode, "Selecting Upgrade Road must activate tap-to-upgrade mode.")
	hud._on_cancel_pressed()
	_check(road_system_for_menu != null and not road_system_for_menu.is_road_upgrade_mode, "Cancel must exit road upgrade mode.")
	hud._show_submenu("services")
	_check(hud.context_header_subtitle.text.contains("Sewage") and hud.context_header_subtitle.text.contains("Waste") and hud.context_header_subtitle.text.contains("Traffic"), "The City Services header must show sewage, waste and traffic demand/capacity.")
	hud._on_cancel_pressed()
	var category_scroll := toolbar.get_node_or_null("CategoryScroll") as ScrollContainer
	_check(category_scroll != null and category_scroll.scroll_deadzone <= 4, "Right category rail must use a minimal vertical swipe deadzone.")
	_check(category_scroll != null and category_scroll.mouse_filter == Control.MOUSE_FILTER_PASS, "Right category scroller must capture touch drags.")
	_check(category_scroll != null and category_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Right category rail must enable vertical scrolling when its content exceeds the viewport.")

	var toolbar_items := toolbar.find_child("RightToolbarItems", true, false) as VBoxContainer
	_check(toolbar_items != null and toolbar_items.get_child_count() == 7, "Right rail must show seven categories in a vertical list.")
	var expected_names := ["Tool_Residential", "Tool_Commercial", "Tool_Industrial", "Tool_Services", "Tool_Specializations", "Tool_Road", "Tool_Bulldoze"]
	for i in range(expected_names.size()):
		var button := toolbar.find_child(expected_names[i], true, false) as Button
		_check(button != null, "Missing ordered category button: " + expected_names[i])
		if button and toolbar_items:
			_check(toolbar_items.get_child(i) == button, "Build categories are not in the required top-to-bottom order.")
			_check(button.custom_minimum_size.y >= 64.0, "Category touch target is too small.")
			var category_icon := button.get_node_or_null("CategoryPNG") as TextureRect
			_check(category_icon != null and category_icon.texture != null and category_icon.custom_minimum_size.x >= 64.0, "Category PNG must be transparent artwork at a readable size.")
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				_check(button.get_theme_stylebox(state).get_class() == "StyleBoxEmpty", "Category PNG must remain transparent in every interaction state.")
			_check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "Category image must pass touch drags to its vertical ScrollContainer.")
			if category_icon:
				_check(category_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Category PNG must not intercept touch drags before the button/scroll container.")
	_check(hud.get_node_or_null("BottomActions") != null, "Permanent city actions are missing.")
	_check(hud.get_node("BottomActions").visible, "Storage, City Needs, Trade and Save should be visible while no category is selected.")
	_check(hud.find_child("CityNeedsAction", true, false) is Button, "City Needs must have a persistent HUD shortcut.")
	var currency_stack := hud.find_child("TopRightCurrencies", true, false) as VBoxContainer
	_check(currency_stack != null and currency_stack.get_child_count() == 3, "Top-right resources must be exactly three compact rows.")
	for row_name in ["SimoleonsCurrencyRow", "MoneyCurrencyRow", "GoldenKeyCurrencyRow"]:
		_check(currency_stack != null and currency_stack.find_child(row_name, true, false) is HBoxContainer, "Missing resource row: " + row_name)
	_check(currency_stack != null and currency_stack.find_child("SimoleonsCurrencyPlus", true, false) is Button, "Simoleons row must show the blue + tile.")
	_check(currency_stack != null and currency_stack.find_child("SimCashCurrencyPlus", true, false) is Button, "SimCash row must show the blue + tile.")
	_check(currency_stack != null and currency_stack.find_child("GoldenKeysCurrencyPlus", true, false) == null, "Golden key row must not show an unnecessary + tile.")
	hud._on_category_pressed("services")
	await get_tree().process_frame
	_check(toolbar.visible, "Right-side transparent PNG shortcuts must remain visible while a category submenu is open.")
	_check(hud.submenu_scroll.visible and not hud.get_node("BottomActions").visible, "Selecting a category must replace city actions with its bottom submenu.")
	_check(hud.submenu_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Catalog horizontal scroll chrome must stay hidden.")
	_check(hud.submenu_scroll.scroll_deadzone <= 4, "Horizontal submenu swipe must respond with a minimal touch deadzone.")
	_check(hud.submenu_scroll.mouse_filter == Control.MOUSE_FILTER_PASS, "Submenu ScrollContainer must capture touch drags.")
	_check(hud.submenu.mouse_filter == Control.MOUSE_FILTER_PASS, "Submenu content must pass touch drags to its ScrollContainer.")
	_check(hud.submenu_scroll.get_h_scroll_bar().max_value > hud.submenu_scroll.get_h_scroll_bar().page, "Services catalog must expose a real horizontal overflow range for swipe testing.")

	_check(hud.submenu.alignment == BoxContainer.ALIGNMENT_BEGIN, "Horizontal submenu items must start at the leading edge for predictable swiping.")
	for group_id in ["group_power", "group_water", "group_sewage", "group_waste", "group_fire", "group_police", "group_health", "group_government"]:
		_check(hud.submenu.get_node_or_null(group_id) != null, "Services group is missing: " + group_id)
	_check(hud.submenu.get_child_count() == 8 and hud.get_node_or_null("CatalogAdvisor") != null, "Services level one must contain eight groups with the advisor in its dedicated side slot.")
	hud._on_submenu_option("services", "group_water")
	await get_tree().process_frame
	_check(hud.submenu.get_node_or_null("water_tower") != null, "Water submenu must contain the Water Tower.")
	_check(hud.submenu.get_node_or_null("water_pump") != null, "Water submenu must contain the Water Pump.")
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Water submenu must expose Back and Cancel.")
	var locked_pump := hud.submenu.get_node_or_null("water_pump") as Button
	_check(locked_pump != null and not locked_pump.disabled, "Locked Water Pump must remain tappable for unlock feedback.")
	if locked_pump:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			_check(locked_pump.get_theme_stylebox(state).get_class() == "StyleBoxEmpty", "Catalog cards must not gain black/white backgrounds in any state.")
		_check(locked_pump.mouse_filter == Control.MOUSE_FILTER_PASS, "Dragging from building artwork must reach the horizontal submenu scroller.")
		var pump_artwork := locked_pump.find_child("SubmenuArtwork", true, false) as TextureRect
		_check(pump_artwork != null and pump_artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Building PNG must pass touch drags to its card and horizontal scroller.")
	var unlocked_tower := hud.submenu.get_node_or_null("water_tower") as Button
	_check(unlocked_tower != null and unlocked_tower.find_child("UnlockLevelBadge", true, false) == null, "Unlocked Water Tower must not display a level badge.")
	if locked_pump:
		var unlock_badge := locked_pump.find_child("CatalogLock", true, false) as Label
		var unlock_text := unlock_badge
		var pump_art := locked_pump.find_child("SubmenuArtwork", true, false) as TextureRect
		_check(unlock_badge != null and unlock_text != null and unlock_text.text == "LOCKED", "Locked Water Pump must show a clear LV 12 unlock badge.")
		_check(pump_art != null and pump_art.modulate == Color.WHITE, "Submenu icon artwork must remain untinted when locked.")
		var pump_lock := locked_pump.find_child("CatalogLock", true, false) as Label
		_check(pump_lock != null and pump_lock.text == "LOCKED", "Locked catalog cards must show a visible lock state.")
		locked_pump.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 12"), "Tapping locked Water Pump must explain its unlock level.")
	_check(int(BuildManager.building_types["water_tower"].get("water", 0)) > 0 and int(BuildManager.building_types["water_pump"].get("water", 0)) > 0, "Water facilities must expose positive numeric water production.")
	_check(BuildManager.building_types["water_tower"].get("size", Vector2i.ZERO) == Vector2i(1, 1), "Water Tower footprint must be 1x1.")
	_check(BuildManager.building_types["water_pump"].get("size", Vector2i.ZERO) == Vector2i(2, 3), "Water Pump footprint must be 2x3.")

	# Sewage is catalogued independently from Water; capacity gameplay is intentionally deferred.
	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_sewage")
	await get_tree().process_frame
	for sewage_id in ["sewage_small", "sewage_basic", "sewage_deluxe"]:
		_check(hud.submenu.get_node_or_null(sewage_id) != null, "Sewage submenu is missing: " + sewage_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Sewage submenu must expose Back and Cancel.")
	var locked_sewage := hud.submenu.get_node_or_null("sewage_small") as Button
	_check(locked_sewage != null and not locked_sewage.disabled, "Locked Small Sewage must remain tappable for unlock feedback.")
	if locked_sewage:
		locked_sewage.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 8"), "Tapping locked Small Sewage must explain its unlock level.")
	for sewage_id in ["sewage_small", "sewage_basic", "sewage_deluxe"]:
		var sewage_definition: Dictionary = BuildManager.building_types[sewage_id]
		_check(int(sewage_definition.get("sewage", 0)) > 0, "Sewage facility must expose generic positive sewage capacity: " + sewage_id)
		_check(sewage_definition.get("service_group", "") == "sewage", "Sewage facility must remain in its own service group: " + sewage_id)
	_check(BuildManager.building_types["sewage_small"].get("size", Vector2i.ZERO) == Vector2i(1, 1), "Small Sewage footprint must be 1x1.")
	_check(BuildManager.building_types["sewage_basic"].get("size", Vector2i.ZERO) == Vector2i(2, 2), "Basic Sewage footprint must be 2x2.")
	_check(BuildManager.building_types["sewage_deluxe"].get("size", Vector2i.ZERO) == Vector2i(2, 3), "Deluxe Treatment footprint must be 2x3.")
	_check(int(BuildManager.building_types["sewage_small"].get("pollution", 0)) > 0 and float(BuildManager.building_types["sewage_small"].get("pollution_radius", 0.0)) > 0.0, "Small Sewage must expose dirty-site metadata.")
	_check(int(BuildManager.building_types["sewage_basic"].get("pollution", 0)) > 0 and float(BuildManager.building_types["sewage_basic"].get("pollution_radius", 0.0)) > 0.0, "Basic Sewage must expose dirty-site metadata.")
	_check(int(BuildManager.building_types["sewage_deluxe"].get("pollution", 0)) == 0 and float(BuildManager.building_types["sewage_deluxe"].get("pollution_radius", 0.0)) == 0.0, "Deluxe Treatment must be pollution-free.")

	# Waste handles solid garbage separately from liquid sewage; capacity gameplay is deferred.
	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_waste")
	await get_tree().process_frame
	for waste_id in ["waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling"]:
		_check(hud.submenu.get_node_or_null(waste_id) != null, "Waste submenu is missing: " + waste_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Waste submenu must expose Back and Cancel.")
	var locked_waste_facility := hud.submenu.get_node_or_null("waste_dump_small") as Button
	_check(locked_waste_facility != null and not locked_waste_facility.disabled, "Locked Small Garbage Dump must remain tappable for unlock feedback.")
	if locked_waste_facility:
		locked_waste_facility.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 14"), "Tapping locked Small Garbage Dump must explain its unlock level.")
	for waste_id in ["waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling"]:
		var waste_definition: Dictionary = BuildManager.building_types[waste_id]
		_check(int(waste_definition.get("waste", 0)) > 0, "Waste facility must expose generic positive solid-waste capacity: " + waste_id)
		_check(waste_definition.get("service_group", "") == "waste", "Waste facility must remain separate from Sewage: " + waste_id)
	_check(BuildManager.building_types["waste_dump_small"].get("size", Vector2i.ZERO) == Vector2i(2, 2), "Small Garbage Dump footprint must be 2x2.")
	_check(BuildManager.building_types["waste_dump"].get("size", Vector2i.ZERO) == Vector2i(2, 3), "Garbage Dump footprint must be 2x3.")
	_check(BuildManager.building_types["waste_incinerator"].get("size", Vector2i.ZERO) == Vector2i(2, 2), "Incinerator footprint must be 2x2.")
	_check(BuildManager.building_types["waste_recycling"].get("size", Vector2i.ZERO) == Vector2i(3, 2), "Recycling Center footprint must be 3x2.")
	_check(int(BuildManager.building_types["waste_dump_small"].get("pollution", 0)) > 0 and float(BuildManager.building_types["waste_dump_small"].get("pollution_radius", 0.0)) == 10.0, "Small Garbage Dump must expose 10-tile pollution metadata.")
	_check(int(BuildManager.building_types["waste_dump"].get("pollution", 0)) > 0 and float(BuildManager.building_types["waste_dump"].get("pollution_radius", 0.0)) == 12.0, "Garbage Dump must expose 12-tile pollution metadata.")
	_check(float(BuildManager.building_types["waste_incinerator"].get("pollution_radius", 0.0)) == 16.0, "Incinerator must have the largest 16-tile pollution radius.")
	_check(int(BuildManager.building_types["waste_recycling"].get("pollution", 0)) == 0 and float(BuildManager.building_types["waste_recycling"].get("pollution_radius", 0.0)) == 0.0, "Recycling Center must be pollution-free.")
	_check(BuildManager.building_types["waste_incinerator"].get("pollution_severity", "") == "heavy", "Incinerator must be marked as heavy pollution in the catalog.")

	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_fire")
	await get_tree().process_frame
	for fire_id in ["fire_station_small", "fire_station", "fire_station_deluxe"]:
		_check(hud.submenu.get_node_or_null(fire_id) != null, "Fire submenu is missing: " + fire_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Fire submenu must expose Back and Cancel.")
	var basic_fire_button := hud.submenu.get_node_or_null("fire_station") as Button
	_check(int(BuildManager.building_types["fire_station"].get("coverage_tiles", 0)) == 15, "Basic Fire Station must retain its 15-tile coverage metadata.")
	var basic_fire_badge := basic_fire_button.find_child("CatalogLock", true, false) as Label if basic_fire_button else null
	_check(basic_fire_badge != null and basic_fire_badge.text == "LOCKED", "Basic Fire Station must show its locked state.")
	var locked_small_fire := hud.submenu.get_node_or_null("fire_station_small") as Button
	_check(locked_small_fire != null and not locked_small_fire.disabled, "Locked Small Fire Station must remain tappable for unlock feedback.")
	if locked_small_fire:
		locked_small_fire.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 5"), "Tapping a locked Fire Station must explain its Level 5 unlock.")
	var fire_expected := {
		"fire_station_small": {"coverage": 10, "size": Vector2i(1, 1), "cost": 3100},
		"fire_station": {"coverage": 15, "size": Vector2i(2, 2), "cost": 5500},
		"fire_station_deluxe": {"coverage": 22, "size": Vector2i(4, 2), "cost": 21000}
	}
	for fire_id in fire_expected:
		var fire_definition: Dictionary = BuildManager.building_types[fire_id]
		var expected: Dictionary = fire_expected[fire_id]
		_check(int(fire_definition.get("fire", 0)) == 1, "Fire station must expose the generic fire coverage key: " + fire_id)
		_check(fire_definition.get("service_group", "") == "fire", "Fire station must belong to the Fire service group: " + fire_id)
		_check(int(fire_definition.get("coverage_tiles", 0)) == int(expected["coverage"]), "Fire station coverage tiles are incorrect: " + fire_id)
		_check(fire_definition.get("size", Vector2i.ZERO) == expected["size"], "Fire station footprint is incorrect: " + fire_id)
		_check(int(fire_definition.get("cost", 0)) == int(expected["cost"]), "Fire station cost is incorrect: " + fire_id)
		_check(int(fire_definition.get("level", 0)) == 5, "All Fire stations must unlock at Level 5: " + fire_id)
		_check(int(fire_definition.get("pollution", 0)) == 0, "Fire stations must not have pollution: " + fire_id)
		_check(is_equal_approx(FireHazardManager.get_coverage_radius_world(fire_definition), float(expected["coverage"]) * BuildManager.GRID_SIZE), "Fire station world coverage radius is incorrect: " + fire_id)

	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_police")
	await get_tree().process_frame
	for police_id in ["police_small", "police_basic", "police_precinct"]:
		_check(hud.submenu.get_node_or_null(police_id) != null, "Police submenu is missing: " + police_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Police submenu must expose Back and Cancel.")
	var locked_small_police := hud.submenu.get_node_or_null("police_small") as Button
	_check(locked_small_police != null and not locked_small_police.disabled, "Locked Small Police must remain tappable for unlock feedback.")
	if locked_small_police:
		locked_small_police.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 12"), "Tapping locked Small Police must explain its Level 12 unlock.")
	var police_expected := {
		"police_small": {"coverage": 10, "size": Vector2i(1, 1), "cost": 5100},
		"police_basic": {"coverage": 15, "size": Vector2i(2, 2), "cost": 9400},
		"police_precinct": {"coverage": 24, "size": Vector2i(4, 2), "cost": 36000}
	}
	for police_id in police_expected:
		var police_definition: Dictionary = BuildManager.building_types[police_id]
		var expected: Dictionary = police_expected[police_id]
		_check(int(police_definition.get("police", 0)) == 1, "Police station must expose the separate police key: " + police_id)
		_check(police_definition.get("service_group", "") == "police", "Police station must belong to Police group: " + police_id)
		_check(int(police_definition.get("coverage_tiles", 0)) == int(expected["coverage"]), "Police coverage tiles are incorrect: " + police_id)
		_check(police_definition.get("size", Vector2i.ZERO) == expected["size"], "Police footprint is incorrect: " + police_id)
		_check(int(police_definition.get("cost", 0)) == int(expected["cost"]), "Police cost is incorrect: " + police_id)
		_check(int(police_definition.get("level", 0)) == 12, "Police stations must unlock at Level 12: " + police_id)
		_check(int(police_definition.get("pollution", 0)) == 0, "Police stations must be pollution-free: " + police_id)
		_check(int(police_definition.get("fire", 0)) == 0 and int(police_definition.get("health", 0)) == 0, "Police metadata must remain separate from Fire and Health: " + police_id)

	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "back")
	hud._on_submenu_option("services", "group_power")
	await get_tree().process_frame
	for power_id in ["power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear"]:
		_check(hud.submenu.get_node_or_null(power_id) != null, "Power submenu is missing: " + power_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Power submenu must expose Back and Cancel.")
	var locked_deluxe := hud.submenu.get_node_or_null("power_wind_deluxe") as Button
	_check(locked_deluxe != null and not locked_deluxe.disabled, "Locked advanced power plant must remain tappable for unlock feedback.")
	if locked_deluxe:
		locked_deluxe.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 10"), "Tapping a locked Deluxe Wind must explain its unlock level.")
	_check(int(BuildManager.building_types["power_wind"].get("power", 0)) > 0 and int(BuildManager.building_types["power_coal"].get("power", 0)) > 0, "Wind and Coal must expose numeric power production.")
	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_fire")
	await get_tree().process_frame
	_check(hud.submenu.get_node_or_null("fire_station_small") != null, "Fire group must contain the Small Fire Station.")
	_check(hud.submenu.get_node_or_null("fire_station") != null, "Fire group must contain the Basic Fire Station.")
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null, "Second-level Services submenu must provide Back.")
	_check(hud.get_node_or_null("CatalogCloseButton") != null, "Active submenu must always provide Cancel.")
	hud._on_submenu_option("services", "back")
	_check(hud.submenu.get_node_or_null("group_power") != null, "Back must return to the Services group list.")
	hud._on_submenu_option("services", "group_health")
	await get_tree().process_frame
	for health_id in ["clinic_small", "clinic", "hospital"]:
		_check(hud.submenu.get_node_or_null(health_id) != null, "Health submenu is missing: " + health_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Health submenu must expose Back and Cancel.")
	var locked_small_clinic := hud.submenu.get_node_or_null("clinic_small") as Button
	_check(int(BuildManager.building_types["clinic_small"].get("coverage_tiles", 0)) == 10, "Small Clinic must retain its 10-tile coverage metadata.")
	var clinic_badge := locked_small_clinic.find_child("CatalogLock", true, false) as Label if locked_small_clinic else null
	_check(clinic_badge != null and clinic_badge.text == "LOCKED", "Locked Small Clinic must show its locked state.")
	_check(locked_small_clinic != null and not locked_small_clinic.disabled, "Locked Small Clinic must remain tappable for unlock feedback.")
	if locked_small_clinic:
		locked_small_clinic.emit_signal("pressed")
		_check(hud.status_label.text.contains("Level 16"), "Tapping a locked clinic must explain its Level 16 unlock.")
	var health_expected := {
		"clinic_small": {"coverage": 10, "size": Vector2i(2, 2), "cost": 14000},
		"clinic": {"coverage": 15, "size": Vector2i(2, 2), "cost": 21000},
		"hospital": {"coverage": 24, "size": Vector2i(4, 2), "cost": 58000}
	}
	for health_id in health_expected:
		var health_definition: Dictionary = BuildManager.building_types[health_id]
		var expected: Dictionary = health_expected[health_id]
		_check(int(health_definition.get("health", 0)) == 1, "Health facility must expose the separate health key: " + health_id)
		_check(health_definition.get("service_group", "") == "health", "Health facility must belong to Health group: " + health_id)
		_check(int(health_definition.get("coverage_tiles", 0)) == int(expected["coverage"]), "Health coverage tiles are incorrect: " + health_id)
		_check(health_definition.get("size", Vector2i.ZERO) == expected["size"], "Health footprint is incorrect: " + health_id)
		_check(int(health_definition.get("cost", 0)) == int(expected["cost"]), "Health cost is incorrect: " + health_id)
		_check(int(health_definition.get("level", 0)) == 16, "Health facilities must unlock at Level 16: " + health_id)
		_check(int(health_definition.get("pollution", 0)) == 0, "Health facilities must be pollution-free: " + health_id)
		_check(int(health_definition.get("fire", 0)) == 0 and int(health_definition.get("police", 0)) == 0, "Health metadata must remain separate from Fire and Police: " + health_id)
	# Government is administrative only: Town Hall must never provide emergency coverage.
	hud._on_submenu_option("services", "back")
	await get_tree().process_frame
	hud._on_submenu_option("services", "group_government")
	await get_tree().process_frame
	_check(hud.submenu.get_node_or_null("town_hall") != null, "Government submenu must contain Town Hall.")
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.get_node_or_null("CatalogCloseButton") != null, "Government submenu must expose Back and Cancel.")
	var town_hall_definition: Dictionary = BuildManager.building_types["town_hall"]
	_check(int(town_hall_definition.get("government", 0)) == 1, "Town Hall must expose the separate government metadata key.")
	_check(str(town_hall_definition.get("service_group", "")) == "government", "Town Hall must belong to the Government group.")
	_check(int(town_hall_definition.get("fire", 0)) == 0 and int(town_hall_definition.get("police", 0)) == 0 and int(town_hall_definition.get("health", 0)) == 0, "Town Hall must not provide Fire, Police or Health coverage.")
	_check(int(town_hall_definition.get("power", 0)) == 0 and int(town_hall_definition.get("water", 0)) == 0, "Town Hall must not provide utility capacity.")
	var saved_government_level := GameManager.level
	GameManager.level = 1
	hud._on_submenu_option("services", "town_hall")
	_confirm_catalog_build(hud)
	_check(BuildManager.is_placing and BuildManager.selected_building_type == "town_hall", "Town Hall must be buildable at Level 1.")
	BuildManager.cancel_placement()
	GameManager.level = saved_government_level
	hud._on_submenu_option("services", "back")
	_check(hud.submenu.get_node_or_null("group_government") != null, "Government Back must return to the Services group list.")
	hud._on_cancel_pressed()
	await get_tree().process_frame
	var previous_level := GameManager.level
	GameManager.level = 16
	hud._on_submenu_option("services", "clinic_small")
	_confirm_catalog_build(hud)
	_check(BuildManager.is_placing and BuildManager.selected_building_type == "clinic_small", "Unlocked Small Clinic must enter building placement mode.")
	BuildManager.cancel_placement()
	GameManager.level = previous_level
	hud._on_submenu_option("services", "back")
	hud._on_cancel_pressed()
	await get_tree().process_frame
	_check(not hud.submenu_scroll.visible and hud.get_node("BottomActions").visible, "Cancel must return to permanent city actions.")
	hud._close_build_menu()
	_check(toolbar.visible, "Closing a submenu must restore the persistent transparent category toolbar.")

func _create_service_test_home(building_id: String, service_demand: int, grid_pos: Vector2i) -> FireHazardTestBuilding:
	var home := FireHazardTestBuilding.new()
	add_child(home)
	home.building_id = building_id
	home.building_type = "residential_1"
	home.definition = {"category": "residential", "size": Vector2i(2, 2), "service_demand": service_demand}
	home.status = "completed"
	home.grid_pos = grid_pos
	home.global_position = Vector3.ZERO
	BuildManager.buildings[home.building_id] = home
	return home

func _test_sewage_service_happiness() -> void:
	var saved_buildings: Dictionary = BuildManager.buildings.duplicate()
	var saved_level := GameManager.level
	BuildManager.buildings.clear()
	GameManager.level = 8
	var road_system = get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.seed_starter_access()

	var low_home := _create_service_test_home("sewage_low_home", 1, Vector2i(1, 1))
	var medium_home := _create_service_test_home("sewage_medium_home", 2, Vector2i(1, 1))
	var high_home := _create_service_test_home("sewage_high_home", 5, Vector2i(1, 1))
	var disconnected_home := _create_service_test_home("sewage_disconnected_home", 1, Vector2i(35, 35))
	ServiceManager.recalculate_from_buildings()
	_check(ServiceManager.demand_sewage == 9, "Sewage demand must count low/medium/high homes and disconnected completed homes.")
	_check(ServiceManager.demand_power == 9 and ServiceManager.demand_water == 9, "Power and water demand must use the same per-home service-demand units.")
	_check(ServiceManager.total_sewage == 0 and ServiceManager.used_sewage == 0, "No sewage capacity may be served without a completed sewage facility.")
	var baseline_happiness := HappinessManager.calculate_home_happiness(low_home)

	var expected_capacities := {"sewage_small": 7, "sewage_basic": 28, "sewage_deluxe": 55}
	var service_positions := {"sewage_small": Vector2i(1, -2), "sewage_basic": Vector2i(1, -3), "sewage_deluxe": Vector2i(1, -4)}
	for sewage_id in expected_capacities.keys():
		var facility := FireHazardTestBuilding.new()
		add_child(facility)
		facility.building_id = "sewage_test_" + sewage_id
		facility.building_type = sewage_id
		facility.definition = BuildManager.building_types[sewage_id]
		facility.status = "completed"
		facility.grid_pos = service_positions[sewage_id]
		facility.global_position = Vector3.ZERO
		BuildManager.buildings[facility.building_id] = facility
		ServiceManager.recalculate_from_buildings()
		var expected_capacity: int = expected_capacities[sewage_id]
		_check(ServiceManager.total_sewage == expected_capacity, "Sewage tier capacity must match its catalog data: " + sewage_id)
		_check(ServiceManager.demand_sewage == 9, "Sewage demand must be independent of facility capacity.")
		_check(not ServiceManager.sewage_served_ids.has(disconnected_home.building_id), "A home without Gateway road access must not receive sewage service.")
		if expected_capacity == 7:
			_check(ServiceManager.used_sewage == 3, "A 7-unit sewage plant must serve the 1-unit and 2-unit homes but not the 5-unit home.")
			_check(not ServiceManager.sewage_served_ids.has(high_home.building_id), "A high-demand home must remain unserved when capacity is insufficient.")
		else:
			_check(ServiceManager.used_sewage == 8, "Sewage capacity above connected demand must serve all connected homes.")
			_check(ServiceManager.sewage_served_ids.has(high_home.building_id), "The 5-unit home must be served when sufficient capacity exists.")
		_check(HappinessManager._home_has_extra_service(low_home), "A sewage-served home must count as receiving an extra service.")
		_check(HappinessManager.calculate_home_happiness(low_home) > baseline_happiness, "Sewage service must improve happiness by replacing the shortage penalty with the service bonus.")

		facility.status = "constructing"
		ServiceManager.recalculate_from_buildings()
		_check(ServiceManager.total_sewage == 0 and ServiceManager.used_sewage == 0, "A sewage facility under construction must not contribute capacity: " + sewage_id)
		_check(not ServiceManager.sewage_served_ids.has(low_home.building_id), "A sewage facility under construction must not serve homes: " + sewage_id)

		facility.status = "completed"
		facility.grid_pos = Vector2i(35, 35)
		ServiceManager.recalculate_from_buildings()
		_check(ServiceManager.total_sewage == 0, "A sewage facility disconnected from the Gateway must not contribute capacity: " + sewage_id)

		BuildManager.buildings.erase(facility.building_id)
		remove_child(facility)
		facility.free()

	for home in [low_home, medium_home, high_home, disconnected_home]:
		BuildManager.buildings.erase(home.building_id)
		remove_child(home)
		home.free()
	BuildManager.buildings = saved_buildings
	GameManager.level = saved_level
	ServiceManager.recalculate_from_buildings()

func _test_power_water_coverage_preview() -> void:
	var power_preview: Dictionary = GhostPreviewScript.get_coverage_preview_data(BuildManager.building_types["power_wind"])
	var water_preview: Dictionary = GhostPreviewScript.get_coverage_preview_data(BuildManager.building_types["water_tower"])
	var sewage_preview: Dictionary = GhostPreviewScript.get_coverage_preview_data(BuildManager.building_types["sewage_small"])
	var waste_preview: Dictionary = GhostPreviewScript.get_coverage_preview_data(BuildManager.building_types["waste_dump_small"])
	_check(bool(power_preview.get("visible", false)), "Power placement must show a coverage preview.")
	_check(bool(water_preview.get("visible", false)), "Water placement must show a coverage preview.")
	_check(not bool(sewage_preview.get("visible", false)), "Sewage placement must not show a misleading local-radius preview.")
	_check(not bool(waste_preview.get("visible", false)), "Waste placement must not show a misleading local-radius preview.")
	_check(bool(sewage_preview.get("network_required", false)) and sewage_preview.get("network_scope", "") == "citywide", "Sewage placement must communicate city-wide road-network service.")
	_check(bool(waste_preview.get("network_required", false)) and waste_preview.get("network_scope", "") == "citywide", "Waste placement must communicate city-wide road-network service.")
	_check(is_equal_approx(float(power_preview.get("radius", -1.0)), ServiceManager.coverage_radius), "Power preview radius must match the live ServiceManager coverage radius.")
	_check(is_equal_approx(float(water_preview.get("radius", -1.0)), ServiceManager.coverage_radius), "Water preview radius must match the live ServiceManager coverage radius.")
	_check(power_preview.get("disc_color", Color.WHITE) != water_preview.get("disc_color", Color.WHITE), "Power and Water coverage previews must use distinct colors.")
	_check(not bool(GhostPreviewScript.get_coverage_preview_data(BuildManager.building_types["factory_small"]).get("visible", false)), "Non-service buildings must not show a coverage preview.")

func _test_waste_service_happiness() -> void:
	var saved_buildings: Dictionary = BuildManager.buildings.duplicate()
	var saved_level := GameManager.level
	BuildManager.buildings.clear()
	GameManager.level = 14
	var road_system = get_node_or_null("World/RoadSystem")
	if road_system:
		road_system.seed_starter_access()

	var low_home := _create_service_test_home("waste_low_home", 1, Vector2i(1, 1))
	var medium_home := _create_service_test_home("waste_medium_home", 2, Vector2i(1, 1))
	var high_home := _create_service_test_home("waste_high_home", 5, Vector2i(1, 1))
	var extra_homes: Array[FireHazardTestBuilding] = []
	for index in range(10):
		extra_homes.append(_create_service_test_home("waste_extra_home_%d" % index, 1, Vector2i(1, 1)))
	var disconnected_home := _create_service_test_home("waste_disconnected_home", 1, Vector2i(35, 35))
	ServiceManager.recalculate_from_buildings()
	_check(ServiceManager.demand_waste == 19, "Waste demand must count all completed homes, including uninhabited and disconnected homes.")
	_check(ServiceManager.demand_power == 19 and ServiceManager.demand_water == 19, "Power and water demand must use the same low/medium/high home demand units.")
	var baseline_happiness := HappinessManager.calculate_home_happiness(low_home)

	var expected_capacities := {"waste_dump_small": 15, "waste_dump": 31, "waste_incinerator": 40, "waste_recycling": 70}
	var service_positions := {"waste_dump_small": Vector2i(1, -3), "waste_dump": Vector2i(1, -4), "waste_incinerator": Vector2i(1, -3), "waste_recycling": Vector2i(1, -3)}
	for waste_id in expected_capacities.keys():
		var facility := FireHazardTestBuilding.new()
		add_child(facility)
		facility.building_id = "waste_test_" + waste_id
		facility.building_type = waste_id
		facility.definition = BuildManager.building_types[waste_id]
		facility.status = "completed"
		facility.grid_pos = service_positions[waste_id]
		facility.global_position = Vector3.ZERO
		BuildManager.buildings[facility.building_id] = facility
		ServiceManager.recalculate_from_buildings()
		var expected_capacity: int = expected_capacities[waste_id]
		_check(ServiceManager.total_waste == expected_capacity, "Waste tier capacity must match its catalog data: " + waste_id)
		_check(ServiceManager.demand_waste == 19, "Waste demand must remain independent of capacity.")
		_check(not ServiceManager.waste_served_ids.has(disconnected_home.building_id), "A home without Gateway road access must not receive waste service.")
		if expected_capacity == 15:
			_check(ServiceManager.used_waste == 15, "A 15-unit waste facility must serve only 15 of the 18 connected demand units.")
			_check(ServiceManager.waste_served_ids.size() == 10, "A small waste facility must leave three connected low-demand homes unserved.")
		else:
			_check(ServiceManager.used_waste == 18, "A larger waste facility must serve all connected demand units.")
			_check(ServiceManager.waste_served_ids.size() == 13, "A sufficient waste facility must serve all connected homes.")
		_check(HappinessManager._home_has_extra_service(low_home), "A waste-served home must count as receiving an extra service.")
		_check(HappinessManager.calculate_home_happiness(low_home) > baseline_happiness, "Waste service must improve happiness by replacing the shortage penalty with the service bonus.")

		facility.status = "constructing"
		ServiceManager.recalculate_from_buildings()
		_check(ServiceManager.total_waste == 0 and ServiceManager.used_waste == 0, "A waste facility under construction must not contribute capacity: " + waste_id)
		_check(not ServiceManager.waste_served_ids.has(low_home.building_id), "A waste facility under construction must not serve homes: " + waste_id)

		facility.status = "completed"
		facility.grid_pos = Vector2i(35, 35)
		ServiceManager.recalculate_from_buildings()
		_check(ServiceManager.total_waste == 0, "A waste facility disconnected from the Gateway must not contribute capacity: " + waste_id)

		BuildManager.buildings.erase(facility.building_id)
		remove_child(facility)
		facility.free()

	for home in [low_home, medium_home, high_home, disconnected_home]:
		BuildManager.buildings.erase(home.building_id)
		remove_child(home)
		home.free()
	for home in extra_homes:
		BuildManager.buildings.erase(home.building_id)
		remove_child(home)
		home.free()
	BuildManager.buildings = saved_buildings
	GameManager.level = saved_level
	ServiceManager.recalculate_from_buildings()


func _test_emergency_service_tier_happiness() -> void:
	var saved_buildings: Dictionary = BuildManager.buildings.duplicate()
	var saved_total_power := ServiceManager.total_power
	var saved_total_water := ServiceManager.total_water
	var saved_power_served: Dictionary = ServiceManager.power_served_ids.duplicate()
	var saved_water_served: Dictionary = ServiceManager.water_served_ids.duplicate()
	BuildManager.buildings.clear()
	ServiceManager.total_power = 1
	ServiceManager.total_water = 1
	ServiceManager.power_served_ids.clear()
	ServiceManager.water_served_ids.clear()

	var home := FireHazardTestBuilding.new()
	add_child(home)
	home.building_id = "emergency_service_test_home"
	home.building_type = "residential_1"
	home.definition = {"category": "residential", "size": Vector2i(2, 2)}
	home.status = "completed"
	home.grid_pos = Vector2i(35, 35)
	home.global_position = Vector3.ZERO
	BuildManager.buildings[home.building_id] = home
	var baseline_happiness := HappinessManager.calculate_home_happiness(home)

	var service_cases := {
		"fire": {"radius": 38.0, "bonus": 8.0, "ids": ["fire_station_small", "fire_station", "fire_station_deluxe"]},
		"police": {"radius": 38.0, "bonus": 8.0, "ids": ["police_station", "police_small", "police_basic", "police_precinct"]},
		"health": {"radius": 42.0, "bonus": 8.0, "ids": ["clinic_small", "clinic", "hospital"]}
	}
	for service_group in service_cases:
		var service_case: Dictionary = service_cases[service_group]
		var radius := float(service_case["radius"])
		var bonus := float(service_case["bonus"])
		for service_id in service_case["ids"]:
			var facility := FireHazardTestBuilding.new()
			add_child(facility)
			facility.building_id = "emergency_service_test_" + service_id
			facility.building_type = service_id
			facility.definition = BuildManager.building_types[service_id]
			facility.status = "completed"
			facility.global_position = Vector3(radius - 0.1, 0.0, 0.0)
			BuildManager.buildings[facility.building_id] = facility
			_check(str(facility.definition.get("service_group", "")) == service_group, "Emergency service catalog tier must belong to its declared service group: " + service_id)
			_check(is_equal_approx(HappinessManager.calculate_home_happiness(home), baseline_happiness + bonus), "Every completed emergency service tier must provide its existing happiness bonus: " + service_id)
			_check(HappinessManager._home_has_extra_service(home), "Every completed emergency service tier must count as an extra nearby service: " + service_id)

			facility.status = "constructing"
			_check(is_equal_approx(HappinessManager.calculate_home_happiness(home), baseline_happiness), "An emergency facility under construction must not provide happiness coverage: " + service_id)
			_check(not HappinessManager._home_has_extra_service(home), "An emergency facility under construction must not count as an extra service: " + service_id)

			facility.status = "completed"
			facility.global_position = Vector3(radius + 0.1, 0.0, 0.0)
			_check(is_equal_approx(HappinessManager.calculate_home_happiness(home), baseline_happiness), "An emergency facility outside its service radius must not add happiness: " + service_id)
			_check(not HappinessManager._home_has_extra_service(home), "An emergency facility outside its service radius must not count as an extra service: " + service_id)

			BuildManager.buildings.erase(facility.building_id)
			remove_child(facility)
			facility.free()

	BuildManager.buildings.erase(home.building_id)
	remove_child(home)
	home.free()
	BuildManager.buildings = saved_buildings
	ServiceManager.total_power = saved_total_power
	ServiceManager.total_water = saved_total_water
	ServiceManager.power_served_ids = saved_power_served
	ServiceManager.water_served_ids = saved_water_served

func _test_fire_hazard_state_machine() -> void:
	var saved_buildings: Dictionary = BuildManager.buildings.duplicate()
	var saved_timers: Dictionary = FireHazardManager.unprotected_time.duplicate()
	var saved_smoking: Dictionary = FireHazardManager.smoking_ids.duplicate()
	BuildManager.buildings.clear()
	FireHazardManager.unprotected_time.clear()
	FireHazardManager.smoking_ids.clear()

	var home = FireHazardTestBuilding.new()
	add_child(home)
	home.building_id = "fire_test_home"
	home.building_type = "residential_1"
	home.definition = {"category": "residential", "size": Vector2i(2, 2)}
	home.status = "completed"
	home.global_position = Vector3.ZERO
	BuildManager.buildings[home.building_id] = home

	var station = FireHazardTestBuilding.new()
	add_child(station)
	station.building_id = "fire_test_station"
	station.building_type = "fire_station"
	station.definition = {"category": "service", "fire": 1}
	station.status = "completed"
	station.global_position = Vector3(30.1, 0.0, 0.0)
	BuildManager.buildings[station.building_id] = station

	FireHazardManager._evaluate_hazards(10.0)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "A residential home must not smoke before 20 seconds without fire coverage.")
	FireHazardManager._evaluate_hazards(10.1)
	_check(FireHazardManager.smoking_ids.has(home.building_id), "An uncovered completed home must start smoking after 20 seconds.")
	station.global_position = Vector3(30.0, 0.0, 0.0)
	FireHazardManager._evaluate_hazards(0.0)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "A fire station exactly 15 tiles away must immediately stop smoke.")
	station.global_position = Vector3(30.1, 0.0, 0.0)
	FireHazardManager._evaluate_hazards(19.9)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "Losing fire coverage must restart the full 20-second warning timer.")
	FireHazardManager.reset_for_city_load()
	_check(is_zero_approx(float(FireHazardManager.unprotected_time.get(home.building_id, -1.0))), "Loading a city must reset uncovered time to zero.")
	FireHazardManager._evaluate_hazards(19.9)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "A restored uncovered home must wait another full 20 seconds.")
	FireHazardManager._evaluate_hazards(0.2)
	_check(FireHazardManager.smoking_ids.has(home.building_id), "Smoke must resume after a fresh continuous 20-second uncovered interval.")

	station.definition = {"category": "service", "fire": 1, "coverage_tiles": 10}
	station.global_position = Vector3(20.1, 0.0, 0.0)
	FireHazardManager._evaluate_hazards(0.0)
	FireHazardManager._evaluate_hazards(20.0)
	_check(FireHazardManager.smoking_ids.has(home.building_id), "Small Fire Station must use its own 10-tile coverage, not the default 15-tile radius.")
	station.definition = {"category": "service", "fire": 1, "coverage_tiles": 22}
	station.global_position = Vector3(44.0, 0.0, 0.0)
	FireHazardManager._evaluate_hazards(0.0)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "Deluxe Fire Station must cover homes within its 22-tile radius and stop smoke immediately.")

	home.status = "constructing"
	FireHazardManager._evaluate_hazards(0.0)
	_check(not FireHazardManager.smoking_ids.has(home.building_id), "Homes still under construction must not remain in the fire hazard system.")
	home.status = "completed"
	FireHazardManager._evaluate_hazards(0.0)
	BuildManager.buildings.erase(home.building_id)
	FireHazardManager._evaluate_hazards(0.0)
	_check(not FireHazardManager.unprotected_time.has(home.building_id) and not FireHazardManager.smoking_ids.has(home.building_id), "Demolished homes must have all fire hazard state cleared.")

	remove_child(home)
	home.free()
	remove_child(station)
	station.free()
	BuildManager.buildings = saved_buildings
	FireHazardManager.unprotected_time = saved_timers
	FireHazardManager.smoking_ids = saved_smoking
	FireHazardManager.on_city_changed()

func _test_building_model_loader_contract() -> void:
	_check(BuildingModelLoader.is_supported_model_path("res://assets/models/residential/villa_house.gltf"), "Local villa GLTF model paths must be accepted.")
	_check(BuildingModelLoader.is_supported_model_path("res://assets/models/commercial/neighborhood_shop.gltf"), "Local commercial GLTF model paths must be accepted.")
	_check(not BuildingModelLoader.is_supported_model_path("res://assets/models/vehicle.obj"), "Unsupported model formats must be rejected.")
	_check(not BuildingModelLoader.is_supported_model_path("res://outside/villa.glb"), "Model loading must be restricted to the local models directory.")
	_check(not BuildingModelLoader.is_supported_model_path("res://assets/models/../outside/villa.glb"), "Model paths must reject parent-directory traversal.")
	_check(not BuildingModelLoader.is_supported_model_path("https://example.com/villa.glb"), "Remote model URLs must not be accepted.")
	_check(BuildingModelLoader.load_model_scene("res://assets/models/not-installed.glb") == null, "A missing optional model must return null so the procedural fallback can render.")
	var model_paths := [
		"res://assets/models/residential/villa_house.gltf",
		"res://assets/models/residential/apartment_tower.gltf",
		"res://assets/models/commercial/neighborhood_shop.gltf",
		"res://assets/models/industrial/small_factory.gltf",
		"res://assets/models/residential/residential_tower_75m.gltf"
	]
	for model_path in model_paths:
		var packed_scene := BuildingModelLoader.load_model_scene(model_path)
		_check(packed_scene != null, "Required local building model must import and load: " + model_path)
		if packed_scene == null:
			continue
		var instance := packed_scene.instantiate()
		_check(instance is Node3D, "Imported building model root must be Node3D: " + model_path)
		if instance is Node3D:
			var mesh_nodes := instance.find_children("*", "MeshInstance3D", true, false)
			_check(mesh_nodes.size() > 0, "Imported building model must contain renderable mesh instances: " + model_path)
			var surfaces_found := 0
			for mesh_node in mesh_nodes:
				if mesh_node is MeshInstance3D and mesh_node.mesh != null:
					surfaces_found += mesh_node.mesh.get_surface_count()
			_check(surfaces_found > 0, "Imported building model must contain valid mesh surfaces: " + model_path)
		instance.free()
	_check(str(BuildManager.building_types["residential_villa"].get("model_path", "")) == model_paths[0], "Villa definitions must select the local villa model.")
	_check(str(BuildManager.building_types["residential_apartment"].get("model_path", "")) == model_paths[1], "Apartment definitions must select the local mid-rise model.")
	_check(not str(BuildManager.building_types["residential_apartment"].get("model_path", "")).ends_with("residential_tower_75m.gltf"), "The 75m tower must remain unwired until a compatible large footprint is implemented.")
	_check(str(BuildManager.building_types["hardware_store"].get("model_path", "")) == model_paths[2], "Generic commercial definitions must select the local shop model.")
	_check(str(BuildManager.building_types["factory_small"].get("model_path", "")) == model_paths[3], "Industrial definitions must select the local factory model.")
	_check(not BuildManager.building_types["building_supplies"].has("model_path"), "Building Supplies must retain its bespoke showcase visual.")
	_check(not BuildManager.building_types["art_supplies"].has("model_path"), "Art Supplies must retain its bespoke gallery visual.")
	var villa_visual_probe := Building.new()
	villa_visual_probe.building_type = "residential_villa"
	villa_visual_probe.definition = {"category": "residential", "subtype": "villa"}
	villa_visual_probe.upgrade_stage = 1
	_check(not villa_visual_probe._should_use_external_model(model_paths[0]), "Level-one starter villa must retain its bespoke hero visual.")
	villa_visual_probe.upgrade_stage = 2
	_check(villa_visual_probe._should_use_external_model(model_paths[0]), "Upgraded villa must be able to use the local GLTF model.")
	villa_visual_probe.free()

func _run_gameplay_test() -> void:
	await get_tree().process_frame
	_test_building_model_loader_contract()
	await _test_build_menu_visibility()
	_test_wind_turbine_rotor_animation()
	_test_storage_and_production_chain()
	_test_fire_hazard_state_machine()
	_test_sewage_service_happiness()
	_test_waste_service_happiness()
	_test_emergency_service_tier_happiness()
	_test_power_water_coverage_preview()
	_test_immigration_coefficients()
	_test_camera_inertia_math()
	_test_camera_focus_math()
	_check(is_equal_approx(HappinessManager.BASE_HAPPINESS, 100.0), "A new city home should not start with an unexplained 30% happiness score.")
	_check(IconAtlas.validate_all_icons(), "One or more local UI icon textures are missing or empty.")
	_check(IconAtlas.validate_required_build_icons(), "A required Build icon is missing, invalid or lacks transparent corners.")
	var input_node = get_node("CityInput")
	var world = get_node_or_null("World")
	_check(world != null and world.get_node_or_null("WorldPresentation/NaturalTerrain") != null, "Natural terrain was not generated.")
	_check(world != null and world.get_node_or_null("WorldPresentation/CoastalWater") != null, "Coastal water was not generated.")
	_check(world != null and world.get_node_or_null("WorldPresentation/BuildablePlotGrid") != null, "Buildable plot grid was not generated.")
	_check(world != null and world.get_node_or_null("WorldPresentation/CoastalHighway") != null, "Coastal highway was not generated.")
	_check(EconomyManager.simoleons >= 25000, "Starter Simoleons grant is too small.")
	_check(EconomyManager.golden_keys >= 10 and EconomyManager.sim_cash >= 25, "Starter premium currency grant is missing.")
	var road_system = get_node_or_null("World/RoadSystem")
	_check(road_system != null, "Main scene has no RoadSystem.")
	if road_system == null:
		_finish()
		return
	road_system.seed_starter_access()
	_test_road_gateway_connectivity(road_system)
	_test_road_traffic_capacity(road_system)
	_test_gateway_vehicle_route(road_system)
	var starter_road_count: int = road_system.get_road_count()
	_check(starter_road_count == 50, "Starter highway connector should contain 50 connected free road tiles.")

	_test_road_painting_drag(road_system)
	for x in range(6, 18):
		_check(road_system.place_road(Vector2i(x, 0)), "Could not extend starter road with tile %d." % x)

	# Neighbor-driven road topology and local mesh refresh regression coverage.
	_check(road_system.get_road_tile_kind(Vector2i(0, 0)) == RoadSystemScript.TILE_T, "A three-neighbor starter-road tile was not classified as a T-junction.")
	_check(road_system.get_road_tile_kind(Vector2i(0, -1)) == RoadSystemScript.TILE_T, "The opposite starter-road row did not resolve its T-junction topology.")
	var topology_center := Vector2i(18, 0)
	var money_before_topology := EconomyManager.simoleons
	_check(road_system.place_road(topology_center), "Could not create topology test end/stub road.")
	_check(EconomyManager.simoleons == money_before_topology - RoadSystemScript.ROAD_COST, "Road placement must retain the existing 50-Simoleon cost.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_END, "A road with one neighbor must be an End/stub.")
	var first_revision := int(road_system.roads[topology_center].get_meta("road_revision", 0))
	_check(road_system.place_road(Vector2i(19, 0)), "Could not extend topology test into a straight road.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_STRAIGHT, "Opposite neighbors must produce a Straight tile.")
	_check(road_system.roads[topology_center].get_meta("road_tile_kind") == RoadSystemScript.TILE_STRAIGHT, "Placed road mesh was not refreshed to Straight after its neighbor was added.")
	_check(int(road_system.roads[topology_center].get_meta("road_revision", 0)) > first_revision, "Road mesh revision did not advance after neighbor placement.")
	_check(road_system.roads[Vector2i(17, 0)].get_meta("road_tile_kind") == RoadSystemScript.TILE_STRAIGHT, "The adjacent road mesh was not refreshed after placement.")
	_check(road_system.place_road(Vector2i(18, -1)), "Could not create topology test corner/T connection.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_T, "Three connected neighbors must produce a T-junction.")
	_check(road_system.roads[topology_center].get_meta("road_tile_kind") == RoadSystemScript.TILE_T, "T-junction visual mesh was not refreshed.")
	_check(road_system.place_road(Vector2i(18, 1)), "Could not complete topology test four-way intersection.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_CROSS, "Four connected neighbors must produce a Cross intersection.")
	_check(road_system.roads[topology_center].get_meta("road_tile_kind") == RoadSystemScript.TILE_CROSS, "Cross visual mesh was not refreshed.")
	_check(road_system.remove_road(Vector2i(18, 1)), "Could not remove topology test cross arm.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_T, "Removing a cross arm must refresh the center back to T.")
	_check(road_system.remove_road(Vector2i(19, 0)), "Could not remove topology test straight arm.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_CORNER, "Removing one T arm must refresh the center to Corner.")
	_check(road_system.roads[topology_center].get_meta("road_tile_kind") == RoadSystemScript.TILE_CORNER, "Corner visual mesh was not refreshed after road removal.")
	_check(road_system.remove_road(Vector2i(18, -1)), "Could not remove topology test corner arm.")
	_check(road_system.get_road_tile_kind(topology_center) == RoadSystemScript.TILE_END, "Removing the corner arm must refresh the center to End.")
	_check(road_system.remove_road(topology_center), "Could not remove topology test center road.")
	_check(road_system.roads[Vector2i(17, 0)].get_meta("road_tile_kind") == RoadSystemScript.TILE_END, "Neighbor mesh was not refreshed after deleting the connecting road.")

	var hud = get_node_or_null("HUD")
	var saved_level := GameManager.level
	if hud:
		# Exercise the actual HUD reward handler and the full timed celebration.
		hud._on_level_up_rewarded(2, 200, 1)
		var celebration = hud.get_node_or_null("LevelUpCelebration")
		_check(celebration != null, "Level Up reward did not create its celebration overlay.")
		if celebration:
			var title = celebration.find_child("LevelUpTitle", true, false)
			var subtitle = celebration.find_child("MayorCongratulations", true, false)
			_check(title is Label and title.text == "LEVEL UP!", "Level Up title is missing.")
			_check(subtitle is Label and subtitle.text == "Congratulations Mayor!", "Mayor congratulations message is missing.")
			await _wait_seconds(1.3)
			var simoleon_reward = celebration.find_child("SimoleonReward", true, false)
			var key_reward = celebration.find_child("GoldenKeyReward", true, false)
			_check(simoleon_reward is Label and simoleon_reward.text == "+200 Simoleons", "Simoleon reward counter did not animate to the awarded amount.")
			_check(key_reward is Label and key_reward.text == "+1 Golden Key", "Golden Key reward counter did not animate to the awarded amount.")
			await _wait_seconds(1.6)
		_check(hud.get_node_or_null("LevelUpCelebration") == null, "Level Up celebration did not clean itself up after 2–3 seconds.")
	GameManager.level = 5
	if hud:
		var right_toolbar = hud.get_node_or_null("RightToolbar")
		_check(right_toolbar is PanelContainer and right_toolbar.visible, "Transparent category PNG rail must remain visible without a Build button.")
		_check(hud.get_node_or_null("BuildMenuButton") == null, "Hard-hat Build button must not be present.")
		var toolbar_items = right_toolbar.find_child("RightToolbarItems", true, false) if right_toolbar else null
		_check(toolbar_items is VBoxContainer and toolbar_items.get_child_count() == 7, "Right rail must retain all seven direct category shortcuts.")
		hud._on_category_pressed("residential")
		_check(hud.submenu_scroll.visible and hud.submenu.get_node_or_null("residential_villa") != null, "Residential submenu must show available house choices.")
		var catalog_base = hud.get_node_or_null("CatalogBaseBar") as PanelContainer
		var advisor_slot = hud.get_node_or_null("CatalogAdvisor") as Control
		var catalog_close = hud.get_node_or_null("CatalogCloseButton") as Control
		_check(catalog_base != null and catalog_base.visible, "Bright catalog base strip must be visible while selecting buildings.")
		_check(advisor_slot != null and advisor_slot.visible and is_equal_approx(advisor_slot.anchor_right, 0.15), "Advisor must occupy the dedicated left fifteen-percent slot.")
		_check(is_equal_approx(hud.submenu_scroll.anchor_left, 0.15) and is_equal_approx(hud.submenu_scroll.anchor_right, 0.95), "Building catalog must occupy the central eighty-percent width.")
		_check(catalog_close != null and catalog_close.visible and is_equal_approx(catalog_close.anchor_left, 0.95), "Simple X close action must occupy the right five-percent slot.")
		_check(hud.context_header != null and hud.context_header.visible, "Centered contextual header must be visible while a catalog category is open.")
		_check(hud.get_node_or_null("CatalogCloseButton") != null, "Residential submenu must always include Cancel.")
		hud._on_building_choice_pressed("residential_villa")
		_check(BuildManager.selected_building_type == "residential_villa" and BuildManager.is_placing, "Villa choice did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("commercial")
		_check(hud.submenu.get_node_or_null("hardware_store") != null, "Commercial menu is missing Hardware Store.")
		_check(hud.submenu.get_node_or_null("farmers_market") != null, "Commercial menu is missing Farmer's Market.")
		_check(hud.submenu.get_node_or_null("furniture_store") != null, "Commercial menu is missing Furniture Store.")
		_check(ProductionManager.get_default_recipe_for_building("shop_chain") == "nails", "Chain store should reuse the existing Nails recipe.")
		var saved_level_for_fast_food := GameManager.level
		GameManager.level = 25
		hud._on_submenu_option("commercial", "fast_food")
		_confirm_catalog_build(hud)
		GameManager.level = saved_level_for_fast_food
		_check(BuildManager.selected_building_type == "fast_food" and BuildManager.is_placing, "Fast Food choice did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("road")
		_check(hud.submenu.get_node_or_null("road_build") != null and hud.submenu.get_node_or_null("road_upgrade") != null and hud.submenu.get_node_or_null("bulldoze_road") != null, "Road submenu must show Build, Upgrade and Bulldoze.")
		hud._on_submenu_option("road", "road_build")
		_check(road_system.is_road_mode, "Road build menu action did not enable road placement.")
		hud._on_cancel_pressed()
		hud._on_category_pressed("road")
		hud._on_submenu_option("road", "bulldoze_road")
		_check(input_node.bulldoze_road_mode, "Road bulldozer menu action did not enable road removal.")
		hud._on_cancel_pressed()
		hud._on_category_pressed("industrial")
		_check(hud.submenu.get_node_or_null("factory_small") != null and hud.submenu.get_node_or_null("factory_basic") != null, "Factory choices must be listed.")
		var small_factory_button := hud.submenu.get_node("factory_small") as Button
		var factory_art := small_factory_button.find_child("SubmenuArtwork", true, false) as TextureRect if small_factory_button else null
		_check(factory_art != null and factory_art.texture != null, "Industrial submenu must show the original Small Factory artwork.")
		_check(small_factory_button.find_child("TitleLabel", true, false) == null and small_factory_button.find_child("DetailLabel", true, false) == null, "Icon-only industrial submenu must not create title/detail labels.")
		hud._on_submenu_option("industrial", "factory_small")
		_confirm_catalog_build(hud)
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "factory_small", "Small factory menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("services")
		for group_id in ["group_power", "group_water", "group_sewage", "group_waste", "group_fire", "group_police", "group_health", "group_government"]:
			_check(hud.submenu.get_node_or_null(group_id) != null, "Services submenu is missing group " + group_id)
		hud._on_submenu_option("services", "group_power")
		_check(hud.submenu.get_node_or_null("power_wind") != null, "Power group must contain Wind Power.")
		hud._on_submenu_option("services", "power_wind")
		_confirm_catalog_build(hud)
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "power_wind", "Wind power menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		var menu_test_level := GameManager.level
		GameManager.level = 1
		hud._on_category_pressed("services")
		hud._on_submenu_option("services", "group_fire")
		var locked_fire = hud.submenu.get_node_or_null("fire_station")
		_check(locked_fire != null and not locked_fire.disabled, "Locked fire station must remain clickable.")
		var fire_unlock_badge := locked_fire.find_child("CatalogLock", true, false) as Label if locked_fire else null
		var fire_unlock_text := fire_unlock_badge
		_check(fire_unlock_badge != null and fire_unlock_text.text == "LOCKED", "Locked fire station must show its lock state.")
		var fire_artwork := locked_fire.find_child("SubmenuArtwork", true, false) as TextureRect if locked_fire else null
		_check(fire_artwork != null and fire_artwork.modulate == Color.WHITE, "Locked fire station artwork must remain untinted.")
		_check(fire_unlock_text != null and fire_unlock_text.text == "LOCKED", "Locked fire station must clearly communicate its unlock level.")
		hud._on_submenu_option("services", "fire_station")
		_check(not BuildManager.is_placing and hud.status_label.text.find("Level 5") >= 0, "Locked fire station did not explain its unlock level.")
		GameManager.level = menu_test_level
		hud._on_category_pressed("specializations")
		_check(hud.submenu.get_node_or_null("group_parks") != null, "Specializations must show Parks as a subgroup.")
		hud._on_submenu_option("specializations", "group_parks")
		_check(hud.submenu.get_node_or_null("park_small") != null, "Parks subgroup must contain Small Park.")
		hud._on_submenu_option("specializations", "park_small")
		_confirm_catalog_build(hud)
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "park_small", "Small Park menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("bulldoze")
		_check(input_node.bulldoze_mode and not input_node.bulldoze_road_mode, "Main bulldozer category did not activate demolition mode.")
		_check(hud.submenu_scroll.visible and hud.get_node_or_null("CatalogCloseButton") != null, "Bulldoze mode must show its indicator and Cancel action.")
		var bulldozer_badge = hud.get_node_or_null("BulldozerModeIndicator")
		_check(bulldozer_badge != null and bulldozer_badge.visible, "Bulldozer active indicator was not shown.")
		var cancel_key := InputEventKey.new()
		cancel_key.pressed = true
		cancel_key.keycode = KEY_X
		hud._unhandled_input(cancel_key)
		_check(hud.get_node_or_null("BulldozerModeIndicator") == null or not hud.get_node("BulldozerModeIndicator").visible, "X did not hide the bulldozer indicator.")
		_check(not input_node.bulldoze_mode and not input_node.bulldoze_road_mode, "X/Cancel did not exit bulldozer mode.")
		# Exercise road-only demolition: one asphalt tile disappears, nothing else changes.
		var test_road_cell := Vector2i(18, 0)
		_check(road_system.place_road(test_road_cell), "Could not create test road tile for demolition.")
		input_node.set_bulldoze_road_mode(true)
		input_node._handle_bulldoze_cell(test_road_cell, road_system)
		_check(not road_system.has_road(test_road_cell), "Road-only bulldozer did not remove the selected asphalt tile.")
		input_node.set_bulldoze_road_mode(false)
		# The general bulldozer must also remove road tiles without touching buildings.
		var general_road_cell := Vector2i(18, 0)
		_check(road_system.place_road(general_road_cell), "Could not create test road tile for general bulldozer.")
		input_node.set_bulldoze_mode(true)
		input_node._handle_bulldoze_cell(general_road_cell, road_system)
		_check(not road_system.has_road(general_road_cell), "General bulldozer did not remove a road tile.")
		input_node.set_bulldoze_mode(false)
		# General building demolition requires a second tap and unregisters the whole footprint.
		var demo_cell := Vector2i(12, 1)
		_check(BuildManager.place_building(demo_cell, "residential_villa", 1, "completed"), "Could not create test building for demolition.")
		var demo_building = BuildManager.building_at_cell(demo_cell)
		var population_before_demo := GameManager.population
		print("[GameplaySmoke] demolition before=%d house_pop=%d city=%d" % [population_before_demo, demo_building.current_population if demo_building else -1, GameManager.population])
		input_node.set_bulldoze_mode(true)
		input_node._handle_bulldoze_cell(demo_cell, road_system)
		_check(BuildManager.building_at_cell(demo_cell) == demo_building, "First bulldozer tap should only request confirmation.")
		_check(demo_building.demolition_highlight_active, "First bulldozer tap did not highlight the selected building.")
		input_node._handle_bulldoze_cell(demo_cell, road_system)
		_check(BuildManager.building_at_cell(demo_cell) == null, "Second bulldozer tap did not remove the building footprint.")
		_check(not demo_building.demolition_highlight_active, "Demolition highlight was not cleared after removal.")
		print("[GameplaySmoke] demolition after=%d" % GameManager.population)
		_check(GameManager.population < population_before_demo, "Demolishing a residential building did not remove its population.")
		input_node.set_bulldoze_mode(false)
		# Factory removal must release its factory slot as well as its occupied cells.
		var factories_before_demo := BuildManager.factory_count
		var factory_demo_cell := Vector2i(14, 1)
		_check(BuildManager.place_building(factory_demo_cell, "industrial_1", 1, "completed"), "Could not create test factory for demolition.")
		var factory_demo = BuildManager.building_at_cell(factory_demo_cell)
		_check(BuildManager.factory_count == factories_before_demo + 1, "Test factory did not reserve a factory slot.")
		input_node.set_bulldoze_mode(true)
		input_node._handle_bulldoze_cell(factory_demo_cell, road_system)
		input_node._handle_bulldoze_cell(factory_demo_cell, road_system)
		_check(BuildManager.building_at_cell(factory_demo_cell) == null, "Bulldozer did not remove the factory footprint.")
		_check(BuildManager.factory_count == factories_before_demo, "Demolishing a factory did not release its factory slot.")
		input_node.set_bulldoze_mode(false)
		hud._close_building_submenu(false)
		# Verify the City Storage modal matches the reference inventory layout.
		var storage_before_panel: Dictionary = StorageManager.to_save_dict()
		StorageManager.capacity = 60
		StorageManager.items = {"metal": 1, "wood": 5, "bricks": 2}
		hud._show_storage_panel()
		_check(is_instance_valid(hud.storage_overlay), "Opening City Storage must create a full-screen modal overlay.")
		_check(hud.storage_overlay.find_child("StorageBackdrop", true, false) is ColorRect, "City Storage must dim the city behind its light inventory card.")
		_check(hud.storage_panel != null, "City Storage modal panel was not created.")
		_check(hud.storage_panel.find_child("StorageHeaderIcon", true, false) is TextureRect, "City Storage header must show the local blue storage icon.")
		_check(hud.storage_panel.find_child("StorageCapacityBar", true, false) is ProgressBar, "City Storage must show the orange/blue capacity bar.")
		var storage_grid := hud.storage_panel.find_child("StorageItemsGrid", true, false) as GridContainer
		_check(storage_grid != null and storage_grid.columns == 2, "City Storage products must be displayed in a two-column icon grid.")
		_check(storage_grid != null and storage_grid.find_child("StorageItem_metal", true, false) != null, "City Storage grid must show stored product icons.")
		var upgrade_button := hud.storage_panel.find_child("StorageIncreaseCapacity", true, false) as Button
		_check(upgrade_button != null, "City Storage must show its green Increase Capacity action.")
		if upgrade_button != null:
			_check(not upgrade_button.disabled, "Storage capacity upgrade action must be enabled.")
			_check(upgrade_button.text.contains("500") and upgrade_button.text.contains("10"), "Storage upgrade button must disclose its 500-Simoleon / +10-slot price.")
			StorageManager.capacity_changed.connect(_on_test_storage_capacity_changed)
			StorageManager.storage_changed.connect(_on_test_storage_changed)
			var saved_simoleons_for_storage := EconomyManager.simoleons
			EconomyManager.simoleons = 0
			upgrade_button.pressed.emit()
			_check(hud.status_label.text.contains("Not enough Simoleons"), "Unaffordable storage upgrade must show a clear status message.")
			_check(StorageManager.capacity == 60 and EconomyManager.simoleons == 0, "Unaffordable storage upgrade must not change capacity or money.")
			EconomyManager.simoleons = 500
			upgrade_button.pressed.emit()
			_check(StorageManager.capacity == 70, "Successful storage upgrade must add exactly 10 slots.")
			_check(EconomyManager.simoleons == 0, "Successful storage upgrade must deduct exactly 500 Simoleons.")
			_check(storage_capacity_signal_count == 1, "Successful storage upgrade must emit capacity_changed exactly once.")
			_check(storage_changed_signal_count == 1, "Successful storage upgrade must emit storage_changed exactly once.")
			var refreshed_capacity_label := hud.storage_panel.find_child("StorageCapacity", true, false) as Label
			var refreshed_capacity_bar := hud.storage_panel.find_child("StorageCapacityBar", true, false) as ProgressBar
			_check(refreshed_capacity_label != null and refreshed_capacity_label.text == "8/70", "Storage capacity label must refresh immediately after purchase.")
			_check(refreshed_capacity_bar != null and int(refreshed_capacity_bar.max_value) == 70 and int(refreshed_capacity_bar.value) == 8, "Storage capacity progress bar must refresh immediately after purchase.")
			_check(hud.status_label.text.contains("70"), "Successful storage upgrade must report the new capacity.")
			StorageManager.capacity_changed.disconnect(_on_test_storage_capacity_changed)
			StorageManager.storage_changed.disconnect(_on_test_storage_changed)
			EconomyManager.simoleons = saved_simoleons_for_storage
			EconomyManager.simoleons_changed.emit(EconomyManager.simoleons)
		hud._close_storage_panel()
		_check(not is_instance_valid(hud.storage_overlay), "Closing City Storage must remove its dimmed backdrop.")
		StorageManager.from_save_dict(storage_before_panel)
	else:
		_check(false, "HUD node is missing for building submenu tests.")
	GameManager.level = saved_level
	_check(not road_system.place_road(Vector2i(20, 20)), "Disconnected road was incorrectly accepted.")
	_check(not BuildManager.can_place_at(Vector2i(20, 20), "residential_1"), "Building without road access was incorrectly accepted.")
	_test_drag_gestures_do_not_place()

	BuildManager.select_building("residential_1")
	_check(BuildManager.can_place_at(Vector2i(0, 1)), "House plot beside road should be valid.")
	_check(BuildManager.place_building(Vector2i(0, 1)), "Could not place starter house.")
	var construction_fixture = BuildManager.building_at_cell(Vector2i(0, 1))
	_check(construction_fixture != null and construction_fixture.construction_finish_unix > int(Time.get_unix_time_from_system()), "New construction must store an authoritative finish timestamp.")
	var indexed_house = BuildManager.building_at_cell(Vector2i(0, 1))
	_check(indexed_house != null and indexed_house.building_type == "residential_1", "Building cell index did not resolve the placed house.")
	_check(BuildManager.building_at_cell(Vector2i(1, 2)) == indexed_house, "Building cell index did not cover the full house footprint.")
	var footprint_test_camera: Camera3D = get_viewport().get_camera_3d()
	var construction_roof_screen := footprint_test_camera.unproject_position(indexed_house.global_position + Vector3(0.0, 3.4, 0.0))
	_check(input_node._building_at_screen(construction_roof_screen) == indexed_house, "Oblique-camera ray hit on the house roof did not resolve the building volume.")
	input_node._begin_move_from_screen(77, construction_roof_screen)
	_check(get_node("HUD/StatusLabel").text == "Still under construction", "Long-pressing the visible roof of a building under construction did not report construction status.")
	input_node._begin_move_from_screen(78, footprint_test_camera.unproject_position(BuildManager.grid_to_world(Vector2i(12, 12))))
	_check(get_node("HUD/StatusLabel").text == "No building selected. Press and hold directly on a building to move it.", "Long-pressing empty ground did not provide feedback.")
	_check(not BuildManager.can_place_at(Vector2i(1, 1), "residential_1"), "Overlapping house footprint was incorrectly accepted.")

	BuildManager.select_building("industrial_1")
	_check(BuildManager.place_building(Vector2i(2, 1)), "Could not place factory.")
	BuildManager.select_building("building_supplies")
	_check(BuildManager.place_building(Vector2i(4, 1)), "Could not place Building Supplies shop.")
	BuildManager.select_building("power_wind")
	_check(BuildManager.place_building(Vector2i(6, 1)), "Could not place wind power utility.")
	BuildManager.select_building("water_tower")
	_check(BuildManager.place_building(Vector2i(7, 1)), "Could not place water tower.")

	await _wait_seconds(4.5)
	var home = _find_building("residential_1")
	var city_needs_snapshot: Dictionary = CityDemandManager.get_city_snapshot()
	_check(int(city_needs_snapshot.get("summary", {}).get("homes", 0)) >= 1, "City Needs must aggregate completed residential buildings.")
	var nails_need_found := false
	for city_item in city_needs_snapshot.get("items", []):
		if str(city_item.get("item_id", "")) == "nails":
			nails_need_found = int(city_item.get("required", 0)) >= 1
	_check(nails_need_found, "City Needs must expose the first residential plan's Nails requirement without opening the house.")
	var needs_hud = get_node("HUD")
	needs_hud.open_city_needs_panel()
	_check(needs_hud.find_child("CityNeedsPanel", true, false) != null, "HUD must expose a city-wide needs dashboard.")
	_check(needs_hud.find_child("CityNeed_nails", true, false) != null, "City Needs dashboard must show aggregated item shortage rows.")
	needs_hud._close_city_needs_panel()
	needs_hud.open_residential_panel(home)
	_check(needs_hud.find_child("ResidentialUpgradePanel", true, false) != null, "Selecting a residential building must open its detailed upgrade plan.")
	_check(needs_hud.find_child("ResidentialUpgradeButton", true, false) is Button, "Residential plan must expose an explicit upgrade action.")
	_check(needs_hud.find_child("ResidentialPlanStatus", true, false) is Label, "Residential plan must clearly show whether materials are missing or the home is ready.")
	needs_hud._close_residential_panel()
	var factory = _find_building("industrial_1")
	_check(home != null and home.status == "completed", "House construction did not finish.")
	_check(factory != null and factory.status == "completed", "Factory construction did not finish.")
	_check(GameManager.population > 0, "Completed house did not add any occupied population.")
	_check(GameManager.happiness > 0.0 and GameManager.happiness <= 100.0, "First completed house happiness must remain in the valid non-zero range.")
	_check(ServiceManager.total_power >= 12 and ServiceManager.total_water >= 12, "Power/water capacity was not registered.")
	_check(home != null and ServiceManager.is_building_served(home), "House was not served by nearby power and water.")
	var saved_power_service_ids: Dictionary = ServiceManager.power_served_ids.duplicate()
	ServiceManager.power_served_ids.erase(home.building_id)
	var service_warning_snapshot: Dictionary = HappinessManager.get_city_service_warnings()
	_check(int(service_warning_snapshot.get("counts", {}).get("power", 0)) >= 1, "Persistent city service warnings must count completed homes missing available power coverage.")
	_check(str(service_warning_snapshot.get("summary", "")).contains("power"), "Persistent city service warnings must explain the missing service.")
	ServiceManager.power_served_ids = saved_power_service_ids
	var restored_service_warning_snapshot: Dictionary = HappinessManager.get_city_service_warnings()
	_check(not str(restored_service_warning_snapshot.get("summary", "")).contains("power"), "Restoring power coverage must clear the corresponding service warning.")
	var service_warning_hud = get_node("HUD")
	service_warning_hud._update_service_warning_banner()
	_check(not service_warning_hud.service_warning_panel.visible, "The persistent service warning banner must hide when all currently unlocked services are covered.")

	# Exercise the actual touch long-press, drag and release event path while the build palette is still active.
	BuildManager.select_building("residential_1")
	var active_move_camera: Camera3D = get_viewport().get_camera_3d()
	var home_footprint: Vector2i = home.definition.get("size", Vector2i(2, 2))
	var home_center_offset := Vector3((home_footprint.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.0, (home_footprint.y - 1) * BuildManager.GRID_SIZE * 0.5)
	var home_center_world: Vector3 = BuildManager.grid_to_world(home.grid_pos) + home_center_offset
	# Start on the second cell of the 2x2 footprint, not its anchor cell.
	var non_anchor_cell_world: Vector3 = BuildManager.grid_to_world(Vector2i(1, 2))
	var move_input_screen: Vector2 = active_move_camera.unproject_position(home.global_position + Vector3(0.0, 3.5, 0.0))
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = move_input_screen
	input_node._unhandled_input(touch_down)
	# A browser/runtime may also synthesize mouse events for the same finger.
	# They must not create a second pointer and block the one-finger hold timer.
	var emulated_mouse_down := InputEventMouseButton.new()
	emulated_mouse_down.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse_down.pressed = true
	emulated_mouse_down.position = move_input_screen
	input_node._unhandled_input(emulated_mouse_down)
	var emulated_mouse_motion := InputEventMouseMotion.new()
	emulated_mouse_motion.position = move_input_screen + Vector2(4.0, 2.0)
	input_node._unhandled_input(emulated_mouse_motion)
	_check(input_node.pointer_start.size() == 1 and input_node.pointer_start.has(0), "Emulated mouse events duplicated a physical touch and blocked the long-press timer.")
	# Simulate normal finger tremor / touch-screen jitter before the hold timer expires.
	var jitter_drag := InputEventScreenDrag.new()
	jitter_drag.index = 0
	jitter_drag.position = move_input_screen + Vector2(18.0, 9.0)
	jitter_drag.relative = Vector2(18.0, 9.0)
	input_node._unhandled_input(jitter_drag)
	_check(input_node.is_building_press_pending(0), "Touching the visible house body/roof was not detected as a building press.")
	_check(not BuildManager.is_moving, "Small finger jitter activated Move before the long-press duration elapsed.")
	input_node._process(input_node.LONG_PRESS_SECONDS + 0.01)
	_check(BuildManager.is_moving and BuildManager.moving_building == home, "Long press on a completed residential building with small mobile touch jitter did not enter Move mode while placement was active.")
	_check(not BuildManager.is_placing, "Starting a building move did not exit the active placement palette.")
	var moved_to := Vector2i(8, 1)
	var moved_footprint: Vector2i = home.definition.get("size", Vector2i(2, 2))
	var moved_center_offset := Vector3((moved_footprint.x - 1) * BuildManager.GRID_SIZE * 0.5, 0.0, (moved_footprint.y - 1) * BuildManager.GRID_SIZE * 0.5)
	var moved_center_world: Vector3 = BuildManager.grid_to_world(moved_to) + moved_center_offset
	_check(input_node._move_anchor_from_world(moved_center_world) == moved_to, "Move drag did not map the building centre to the footprint anchor.")
	var moved_screen: Vector2 = active_move_camera.unproject_position(moved_center_world)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = moved_screen
	touch_drag.relative = moved_screen - move_input_screen
	input_node._unhandled_input(touch_drag)
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = moved_screen
	input_node._unhandled_input(touch_up)
	_check(home.grid_pos == moved_to and BuildManager.building_at_cell(moved_to) == home, "Touch release did not commit the valid building move.")
	_check(BuildManager.building_at_cell(Vector2i(0, 1)) == null, "Old building footprint remained occupied after moving.")
	_check(ServiceManager.is_building_served(home), "Moving a house failed to recalculate nearby power/water coverage.")
	# Occupied destination is red/invalid and release must restore the original footprint.
	_check(BuildManager.begin_move(home), "Could not re-enter Move mode for invalid-placement test.")
	_check(not BuildManager.preview_move_at(Vector2i(2, 1)), "Move preview accepted a destination occupied by the factory.")
	_check(not BuildManager.finish_move(), "Invalid move should not commit.")
	_check(home.grid_pos == moved_to and BuildManager.building_at_cell(moved_to) == home, "Invalid move did not restore the previous position.")
	# A pointer leaving the map must invalidate the last otherwise-green preview.
	_check(BuildManager.begin_move(home), "Could not begin move for out-of-map rejection test.")
	_check(BuildManager.preview_move_at(Vector2i(0, 1)), "Out-of-map test needs an initial valid preview.")
	BuildManager.invalidate_move_preview()
	_check(not BuildManager.finish_move(), "Move release outside the map must not commit a stale valid preview.")
	_check(home.grid_pos == moved_to and BuildManager.building_at_cell(moved_to) == home, "Out-of-map release did not restore the previous position.")
	# Cancel must restore the building even after a valid preview has been shown.
	_check(BuildManager.begin_move(home), "Could not begin move for Cancel test.")
	_check(BuildManager.preview_move_at(Vector2i(0, 1)), "Cancel test destination should be valid.")
	BuildManager.cancel_move()
	_check(not BuildManager.is_moving and home.grid_pos == moved_to and BuildManager.building_at_cell(moved_to) == home, "Cancel did not restore the building to its original location.")
	# Exercise desktop mouse long-press, drag and release to return the fixture.
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = moved_screen
	input_node._unhandled_input(mouse_down)
	input_node._process(input_node.LONG_PRESS_SECONDS + 0.01)
	var mouse_motion := InputEventMouseMotion.new()
	var home_center_screen: Vector2 = active_move_camera.unproject_position(home_center_world)
	mouse_motion.position = home_center_screen
	mouse_motion.relative = home_center_screen - moved_screen
	input_node._unhandled_input(mouse_motion)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = home_center_screen
	input_node._unhandled_input(mouse_up)
	_check(home.grid_pos == Vector2i(0, 1), "Mouse release did not commit the valid building move.")
	_check(BuildManager.MOVABLE_BUILDING_TYPES.size() == 47, "Move whitelist must include all 47 supported building types.")
	for movable_type in BuildManager.MOVABLE_BUILDING_TYPES:
		_check(BuildManager.building_types.has(movable_type), "Move whitelist references missing building type: %s" % movable_type)

	# Production acceptance uses real SCBI durations and advances timestamps in
	# the test fixture rather than sleeping for minutes.
	var production_hud = get_node("HUD")
	var factory_component = factory.production_component
	_check(factory_component != null and factory_component.get_slot_count() == 2, "Small Factory must expose two independent production slots.")
	production_hud.open_production_panel(factory)
	_check(is_instance_valid(production_hud.production_overlay), "Opening a factory must show the dimmed city production overlay.")
	_check(production_hud.production_overlay.find_child("ProductionBackdrop", true, false) != null, "Factory panel must dim the city behind the product selector.")
	_check(production_hud.production_panel.find_child("ProductionProductsScroll", true, false) != null, "Factory panel must show a horizontally browsable product-card row.")
	_check(production_hud.production_panel.find_child("QueueSlot0", true, false) != null, "Factory panel must show the production queue with empty slots.")
	var metal_button := production_hud.production_panel.find_child("Slot0_metal", true, false) as Button
	_check(metal_button != null, "Factory panel must offer unlocked Metal production.")
	if metal_button:
		metal_button.emit_signal("pressed")
		var factory_start := production_hud.production_panel.find_child("StartProduction", true, false) as Button
		_check(factory_start != null and not factory_start.disabled, "Selecting a factory material must open its detail card with an enabled Start action.")
		if factory_start:
			factory_start.emit_signal("pressed")
	_check(not factory_component.get_slot(0).is_empty(), "Confirming Metal production must start the first factory slot.")
	production_hud.open_production_panel(factory)
	_check(production_hud.production_panel.find_child("TimerSlot0", true, false) is Label, "Active factory production must show a live countdown label.")
	_check(production_hud.production_panel.find_child("ProgressSlot0", true, false) is ProgressBar, "Active factory production must show a live progress bar.")
	var second_metal_button := production_hud.production_panel.find_child("Slot1_metal", true, false) as Button
	_check(second_metal_button != null, "Factory panel must allow a second parallel Metal batch.")
	if second_metal_button:
		second_metal_button.emit_signal("pressed")
		var second_factory_start := production_hud.production_panel.find_child("StartProduction", true, false) as Button
		if second_factory_start:
			second_factory_start.emit_signal("pressed")
	_check(not factory_component.get_slot(1).is_empty(), "Factory must run two parallel batches.")
	for slot_index in range(2):
		var slot: Dictionary = factory_component.slots[slot_index]
		slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
		factory_component.slots[slot_index] = slot
	factory_component.refresh_slots()
	_check(bool(factory_component.get_slot(0).get("ready",false)), "Metal batch must become ready at its Unix finish timestamp.")
	production_hud.open_production_panel(factory)
	var collect_metal_0 := production_hud.production_panel.find_child("CollectSlot0", true, false) as Button
	if collect_metal_0:
		collect_metal_0.emit_signal("pressed")
	else:
		_check(false, "Ready Metal slot must expose a Collect button.")
	production_hud.open_production_panel(factory)
	var collect_metal_1 := production_hud.production_panel.find_child("CollectSlot1", true, false) as Button
	if collect_metal_1:
		collect_metal_1.emit_signal("pressed")
	else:
		_check(false, "Second ready Metal slot must expose a Collect button.")
	_check(StorageManager.get_count("metal") == 2, "Two parallel factory collections must add two Metal to City Storage.")

	var supplies = _find_building("building_supplies")
	var shop_component = supplies.production_component
	_check(shop_component != null and shop_component.get_slot_count() == 2, "Building Supplies must expose two craft queue slots.")
	StorageManager.items = {}
	_check(StorageManager.add_item("metal",4), "Test setup could not seed four Metal for two Nails orders.")
	production_hud.open_production_panel(supplies)
	var nails_button_0 := production_hud.production_panel.find_child("Slot0_nails", true, false) as Button
	_check(nails_button_0 != null and nails_button_0.find_child("HexagonBackground", true, false) is Polygon2D, "Production choices must use floating hexagonal item tiles like SimCity BuildIt.")
	if nails_button_0:
		nails_button_0.emit_signal("pressed")
		var detail_card: Node = production_hud.production_panel.find_child("ProductionItemDetails", true, false)
		var ingredient_label := production_hud.production_panel.find_child("IngredientsLabel", true, false) as Label
		_check(detail_card != null and ingredient_label != null, "Selecting a shop product must open its separate white recipe detail card.")
		if ingredient_label:
			_check(ingredient_label.text.contains("Metal") and ingredient_label.text.contains("2"), "Nails detail must clearly show its Metal x2 requirement.")
		var shop_start := production_hud.production_panel.find_child("StartProduction", true, false) as Button
		_check(shop_start != null and not shop_start.disabled, "Nails must be startable when two Metal are in City Storage.")
		if shop_start:
			shop_start.emit_signal("pressed")
	else:
		_check(false, "Building Supplies must offer Nails at level 1.")
	production_hud.open_production_panel(supplies)
	var nails_button_1 := production_hud.production_panel.find_child("Slot1_nails", true, false) as Button
	if nails_button_1:
		nails_button_1.emit_signal("pressed")
		var second_shop_start := production_hud.production_panel.find_child("StartProduction", true, false) as Button
		if second_shop_start:
			second_shop_start.emit_signal("pressed")
	else:
		_check(false, "Building Supplies second slot must accept a Nails order.")
	_check(StorageManager.get_count("metal") == 0, "Queuing two Nails orders must deduct their ingredients from City Storage.")
	_check(int(shop_component.get_slot(0).get("finish_unix", 0)) > 0 and int(shop_component.get_slot(1).get("finish_unix", 0)) == 0, "Commercial store orders must run sequentially, with later orders waiting in the queue.")
	var first_shop_slot: Dictionary = shop_component.slots[0]
	first_shop_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	shop_component.slots[0] = first_shop_slot
	shop_component.refresh_slots()
	_check(bool(shop_component.get_slot(0).get("ready", false)) and int(shop_component.get_slot(1).get("finish_unix", 0)) > 0, "The next commercial order must start when the previous order completes.")
	production_hud.open_production_panel(supplies)
	var collect_nails_0 := production_hud.production_panel.find_child("CollectSlot0", true, false) as Button
	if collect_nails_0:
		collect_nails_0.emit_signal("pressed")
	var second_shop_slot: Dictionary = shop_component.slots[1]
	second_shop_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	shop_component.slots[1] = second_shop_slot
	shop_component.refresh_slots()
	production_hud.open_production_panel(supplies)
	var collect_nails_1 := production_hud.production_panel.find_child("CollectSlot1", true, false) as Button
	if collect_nails_1:
		collect_nails_1.emit_signal("pressed")
	_check(StorageManager.get_count("nails") == 2, "Both completed Nails orders must return to City Storage.")

	# Sourced star progression and queue-slot pricing are exposed in the live panel.
	var previous_level_for_store_star := GameManager.level
	var previous_simoleons_for_store_star := EconomyManager.simoleons
	var previous_sim_cash_for_store_slots := EconomyManager.sim_cash
	# Level 50 unlocks Coffee and Popcorn so their star gates are the tested blocker.
	GameManager.level = 50
	EconomyManager.simoleons = 50000
	EconomyManager.sim_cash = 100
	_check(ProductionManager.get_recipe_lock_reason("paint", shop_component.store_star_level).contains("Store Star"), "Paint must remain locked until Building Supplies reaches its sourced one-star requirement.")
	_check(is_equal_approx(ProductionManager.get_production_time("nails", 0), 300.0) and is_equal_approx(ProductionManager.get_production_time("nails", 1), 270.0), "Building Supplies one-star timing must apply the sourced 10% reduction.")
	production_hud.open_production_panel(supplies)
	_check(production_hud.production_panel.find_child("StoreStarStatus", true, false) is Label, "Supported commercial stores must display their current star level.")
	var star_upgrade_button := production_hud.production_panel.find_child("UpgradeStoreStar", true, false) as Button
	_check(star_upgrade_button != null and not star_upgrade_button.disabled, "Building Supplies one-star upgrade must be available at its sourced level and cost.")
	if star_upgrade_button:
		star_upgrade_button.emit_signal("pressed")
	_check(shop_component.store_star_level == 1 and ProductionManager.get_recipe_lock_reason("paint", shop_component.store_star_level).is_empty(), "Buying the first Building Supplies star must unlock Paint.")
	_check(is_equal_approx(shop_component.get_item_production_time("nails"), 270.0), "New Nails orders must use the one-star production time.")

	# Cross-store star upgrades are enabled only where level gates and prices are sourced.
	var verified_store_star_cases := {
		"farmers_market": {"level": 20, "cost": 19000, "item": "vegetables", "base": 1200.0},
		"furniture_store": {"level": 22, "cost": 21000, "item": "chair", "base": 1200.0},
		"gardening_supplies": {"level": 27, "cost": 25000, "item": "grass", "base": 1800.0},
		"fashion_store": {"level": 31, "cost": 30000, "item": "cap", "base": 3600.0},
		"home_appliances": {"level": 41, "cost": 40000, "item": "bbq_grill", "base": 9900.0},
		"fast_food": {"level": 37, "cost": 36000, "item": "pizza", "base": 1440.0},
		"donut_shop": {"level": 30, "cost": 29000, "item": "bread_roll", "base": 3600.0}
	}
	for store_id in verified_store_star_cases:
		var star_case: Dictionary = verified_store_star_cases[store_id]
		var offer := ProductionManager.get_store_star_offer(store_id, 0)
		_check(not offer.is_empty() and int(offer.get("level", 0)) == int(star_case.level) and int(offer.get("cost", 0)) == int(star_case.cost), "%s first-star level and price must match the cited store data." % store_id)
		_check(is_equal_approx(ProductionManager.get_production_time(str(star_case.item), 1), float(star_case.base) * 0.9), "%s one-star production must reduce the base duration by 10%%." % store_id)
	_check(ProductionManager.get_recipe_lock_reason("coffee", 0).contains("Store Star"), "Coffee must remain locked until Donut Shop reaches one star.")
	_check(ProductionManager.get_recipe_lock_reason("popcorn", 0).contains("Store Star"), "Popcorn must remain locked until Fast Food reaches one star.")

	var later_store_star_cases := {
		"sports_shop": {"level": 55, "cost": 250000, "last_verified": 2},
		"toy_store": {"level": 58, "cost": 280000, "last_verified": 1},
		"restoration_office": {"level": 76, "cost": 450000, "last_verified": 2},
		"farmers_store": {"level": 73, "cost": 310000, "last_verified": 2},
		"dessert_shop": {"level": 87, "cost": 450000, "last_verified": 1}
	}
	for later_store_id in later_store_star_cases:
		var later_case: Dictionary = later_store_star_cases[later_store_id]
		var later_offer := ProductionManager.get_store_star_offer(later_store_id, 0)
		_check(int(later_offer.get("level", 0)) == int(later_case.level) and int(later_offer.get("cost", 0)) == int(later_case.cost), "%s first-star offer must match sourced level and price." % later_store_id)
		_check(ProductionManager.get_store_star_offer(later_store_id, int(later_case.last_verified)).is_empty(), "%s must not expose an upgrade tier with an unknown level gate." % later_store_id)
		_check(ProductionManager.get_store_star_status_note(later_store_id, int(later_case.last_verified)) == "NEXT STAR LEVEL UNVERIFIED", "%s UI must explain why its next star is unavailable." % later_store_id)
	_check(int(BuildManager.building_types["sports_shop"].level) == 35 and int(BuildManager.building_types["sports_shop"].cost) == 80000, "Sports Shop unlock must use the current year-round level and cost.")
	_check(int(BuildManager.building_types["toy_store"].level) == 40 and int(BuildManager.building_types["toy_store"].cost) == 100000, "Toy Shop unlock must use the current year-round level and cost.")
	_check(int(BuildManager.building_types["restoration_office"].level) == 45 and int(BuildManager.building_types["restoration_office"].cost) == 250000, "Bureau of Restoration unlock must use the current year-round level and cost.")
	_check(int(BuildManager.building_types["farmers_store"].level) == 50 and int(BuildManager.building_types["farmers_store"].cost) == 300000, "Country Store unlock must use the current year-round level and cost.")
	_check(int(BuildManager.building_types["dessert_shop"].level) == 55 and int(BuildManager.building_types["dessert_shop"].cost) == 350000, "Dessert Shop unlock must use the current year-round level and cost.")

	GameManager.level = 90
	var verified_later_recipes := {
		"ping_pong_table": {"level": 55, "time": 5400, "stars": 1},
		"block_letters": {"level": 40, "time": 3600, "stars": 0},
		"game_console": {"level": 58, "time": 4500, "stars": 1},
		"forged_iron": {"level": 45, "time": 1800, "stars": 0},
		"carved_wood": {"level": 54, "time": 3600, "stars": 0},
		"wool_shirt": {"level": 50, "time": 4500, "stars": 0},
		"picnic_basket": {"level": 59, "time": 3600, "stars": 0},
		"apple_jam": {"level": 73, "time": 3600, "stars": 1},
		"tiramisu": {"level": 55, "time": 2700, "stars": 0},
		"churros": {"level": 63, "time": 2100, "stars": 0},
		"profiterole": {"level": 71, "time": 2100, "stars": 0},
		"mochi": {"level": 79, "time": 2700, "stars": 0},
		"pavlova": {"level": 87, "time": 5400, "stars": 1}
	}
	for item_id in verified_later_recipes:
		var later_recipe: Dictionary = ProductionManager.get_recipe(item_id)
		var later_recipe_case: Dictionary = verified_later_recipes[item_id]
		_check(not later_recipe.is_empty() and int(later_recipe.get("level", 0)) == int(later_recipe_case.level) and int(later_recipe.get("time_sec", 0)) == int(later_recipe_case.time), "%s must use its sourced level and production time." % item_id)
		if int(later_recipe_case.stars) > 0:
			_check(ProductionManager.get_recipe_lock_reason(item_id, 0).contains("Store Star"), "%s must require its sourced store star." % item_id)
			_check(ProductionManager.get_recipe_lock_reason(item_id, 1).is_empty(), "%s must unlock at its sourced store star." % item_id)
		else:
			_check(ProductionManager.get_recipe_lock_reason(item_id, 0).is_empty(), "%s must be craftable at its sourced Mayor Level." % item_id)
	_check(ProductionManager.get_recipe("kite").is_empty() and ProductionManager.get_recipe("teddy_bear").is_empty(), "Products with unverified unlock levels or missing recipe verification must remain disabled.")
	_check(ProductionManager.get_store_recipe_ids("dessert_shop").has("pavlova"), "Dessert Shop's verified product must appear in its production catalog.")
	var donut_third_star_offer := ProductionManager.get_store_star_offer("donut_shop", 2)
	_check(int(donut_third_star_offer.get("level", 0)) == 50 and int(donut_third_star_offer.get("cost", 0)) == 49000, "Donut Shop third star must use the 49,000 Simoleon value corroborated by the Japanese table and Planning Guide.")
	for star_gated_item in ["ladder", "corn", "cupboard", "lawn_mower", "microwave_oven"]:
		_check(ProductionManager.get_recipe_lock_reason(star_gated_item, 0).contains("Store Star"), "%s must require its source-documented first store star." % star_gated_item)
		_check(ProductionManager.get_recipe_lock_reason(star_gated_item, 1).is_empty(), "%s must unlock after its store receives one star." % star_gated_item)
	production_hud.open_production_panel(supplies)
	var buy_queue_slot := production_hud.production_panel.find_child("PurchaseQueueSlot", true, false) as Button
	_check(buy_queue_slot != null and buy_queue_slot.text.contains("4 SC") and not buy_queue_slot.disabled, "Building Supplies next queue slot must show its sourced 4 SimCash price.")
	if buy_queue_slot:
		buy_queue_slot.emit_signal("pressed")
	_check(shop_component.get_slot_count() == 3 and EconomyManager.sim_cash == 96, "Buying the next queue slot from the production UI must increase capacity and spend the sourced SimCash amount.")

	var standard_store_slot_probe = ProductionComponentScript.new()
	standard_store_slot_probe.shop_id = "farmers_market"
	add_child(standard_store_slot_probe)
	_check(standard_store_slot_probe.get_next_store_queue_slot_cost() == 8, "Standard SCBI commercial stores must use the published 8 SimCash third-slot price.")
	var custom_store_slot_probe = ProductionComponentScript.new()
	custom_store_slot_probe.shop_id = "art_supplies"
	add_child(custom_store_slot_probe)
	_check(custom_store_slot_probe.get_next_store_queue_slot_cost() == 0, "Mshin-only custom stores must not display an invented queue-slot price.")
	standard_store_slot_probe.queue_free()
	custom_store_slot_probe.queue_free()
	shop_component.store_star_level = 0
	GameManager.level = previous_level_for_store_star
	EconomyManager.simoleons = previous_simoleons_for_store_star
	EconomyManager.sim_cash = previous_sim_cash_for_store_slots

	# Verify a full warehouse blocks collection without losing the ready batch.
	_check(factory_component.start_factory("metal",0), "Factory must accept a new order after a collection.")
	var full_slot: Dictionary = factory_component.slots[0]
	full_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	factory_component.slots[0] = full_slot
	factory_component.refresh_slots()
	StorageManager.capacity = 1
	StorageManager.items = {"occupied":1}
	production_hud.open_production_panel(factory)
	var storage_full_collect := production_hud.production_panel.find_child("CollectSlot0", true, false) as Button
	_check(storage_full_collect != null and storage_full_collect.disabled and storage_full_collect.text == "STORAGE FULL", "A ready product must show a disabled Storage Full collection state when the warehouse is full.")
	_check(not factory_component.collect(0) and bool(factory_component.get_slot(0).get("ready",false)), "Storage full must block Collect while preserving the ready output.")
	StorageManager.capacity = 50
	StorageManager.items = {}

	# Hardware Store remains compatible with the same component and consumes inputs at order time.
	var previous_level := GameManager.level
	GameManager.level = 4
	_check(BuildManager.place_building(Vector2i(9, 1), "hardware_store"), "Could not place Hardware Store for production acceptance.")
	await _wait_seconds(5.5)
	var hardware = _find_building("hardware_store")
	_check(hardware != null and hardware.status == "completed", "Hardware Store construction did not finish.")
	StorageManager.add_item("metal",1)
	StorageManager.add_item("wood",1)
	var hardware_component = hardware.production_component
	_check(hardware_component.get_slot_count() == 2, "Every commercial store must start with two queue slots.")
	var sim_cash_before_queue_expansion := EconomyManager.sim_cash
	_check(hardware_component.purchase_store_queue_slot(1), "Commercial queue must allow a SimCash-funded slot expansion.")
	_check(hardware_component.get_slot_count() == 3 and EconomyManager.sim_cash == sim_cash_before_queue_expansion - 1, "Purchased commercial queue capacity must add one slot and deduct the supplied SimCash price.")
	var restored_queue := ProductionComponentScript.new()
	restored_queue.shop_id = "hardware_store"
	add_child(restored_queue)
	restored_queue.from_save_array(hardware_component.to_save_array())
	_check(restored_queue.get_slot_count() == 3, "Purchased commercial queue capacity must survive save/load.")
	restored_queue.queue_free()
	EconomyManager.sim_cash = sim_cash_before_queue_expansion
	_check(hardware_component.start_craft("hammer",0), "Hardware Store must craft Hammer from Metal and Wood.")
	_check(StorageManager.get_count("metal") == 0 and StorageManager.get_count("wood") == 0, "Hammer recipe must consume Metal and Wood at start.")
	var hammer_slot: Dictionary = hardware_component.slots[0]
	hammer_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	hardware_component.slots[0] = hammer_slot
	hardware_component.refresh_slots()
	_check(hardware_component.collect(0) and StorageManager.get_count("hammer") == 1, "Completed Hammer must collect into City Storage.")
	BuildManager.unregister_building(hardware.building_id)
	hardware.queue_free()
	GameManager.level = previous_level

	# Existing level-1 upgrade recipe needs Nails and Metal from the shared warehouse.
	StorageManager.add_item("metal",1)
	StorageManager.add_item("nails",1)
	var population_before_upgrade: int = int(home.current_population) if home != null else 0
	var city_population_before_upgrade := GameManager.population
	_check(home != null and home.try_upgrade(), "House upgrade failed despite having Nails and Metal.")
	_check(home != null and home.upgrade_in_progress and home.upgrade_stage == 1, "House upgrade must enter a short scaffold phase before changing its level.")
	_check(home != null and home.current_population == population_before_upgrade and GameManager.population == city_population_before_upgrade, "Residential population must not change before the upgrade animation completes.")
	_check(home != null and home.get_upgrade_remaining_seconds() > 0, "Residential upgrade must expose a persisted remaining-time value.")
	production_hud.open_residential_panel(home)
	_check(home.residential_plan_selected, "Opening a home plan must select its blue hardhat indicator.")
	_check(production_hud.residential_overlay.find_child("ResidentialPlanDataNote", true, false) != null, "Residential panel must disclose that the fixed plan table is a Mshin fallback.")
	_check(production_hud.residential_overlay.find_child("ResidentialUpgradeInProgress", true, false) != null, "Residential panel must show the scaffold upgrade state.")
	production_hud._close_residential_panel()
	_check(not home.residential_plan_selected, "Closing a home plan must hide its selected hardhat indicator.")
	home.upgrade_finish_unix = int(Time.get_unix_time_from_system()) - 1
	home._process(0.0)
	_check(home != null and not home.upgrade_in_progress and home.upgrade_stage == 2, "Residential upgrade must complete when its finish timestamp elapses.")
	print("[GameplaySmoke] upgraded home population=%d city=%d happiness=%.1f served_power=%s served_water=%s" % [home.current_population if home else -1, GameManager.population, GameManager.happiness, str(ServiceManager.power_served_ids.has(home.building_id)) if home else "n/a", str(ServiceManager.water_served_ids.has(home.building_id)) if home else "n/a"])
	_check(home != null and home.current_population > population_before_upgrade and GameManager.population > city_population_before_upgrade, "House upgrade did not increase service-adjusted population.")

	# Save a second upgrade while its scaffold timer is active to verify timestamp persistence.
	StorageManager.add_item("planks",1)
	StorageManager.add_item("wood",1)
	_check(home != null and home.try_upgrade(), "Second residential upgrade could not start with Planks and Wood.")
	_check(home != null and home.upgrade_in_progress and home.upgrade_stage == 2, "Second residential upgrade must remain in progress before save.")
	home.upgrade_finish_unix = int(Time.get_unix_time_from_system()) + 3600

	# Verify the four supported road tiers, their real unlock levels and the
	# researched upper-end per-tile upgrade costs before persisting the city.
	var road_upgrade_cell := Vector2i(0, 0)
	var saved_level_before_road_test := GameManager.level
	var saved_money_before_road_test := EconomyManager.simoleons
	GameManager.level = 8
	EconomyManager.simoleons = 5000
	_check(road_system.get_road_upgrade_error(road_upgrade_cell).contains("City Level 9"), "Four-lane roads must remain locked before City Level 9.")
	GameManager.level = 9
	_check(road_system.get_road_upgrade_cost(road_upgrade_cell) == 300, "Four-lane road upgrade must use the sourced 300-Simoleon upper-range per-tile cost.")
	_check(road_system.upgrade_road(road_upgrade_cell), "A road must upgrade to four lanes at City Level 9.")
	_check(road_system.get_road_level(road_upgrade_cell) == 2, "Four-lane upgrade did not persist its road tier.")
	GameManager.level = 14
	_check(road_system.get_road_upgrade_error(road_upgrade_cell).contains("City Level 15"), "Six-lane roads must remain locked before City Level 15.")
	GameManager.level = 15
	_check(road_system.get_road_upgrade_cost(road_upgrade_cell) == 1200, "Six-lane road upgrade must use the sourced 1200-Simoleon upper-range per-tile cost.")
	_check(road_system.upgrade_road(road_upgrade_cell), "A four-lane road must upgrade to six lanes at City Level 15.")
	GameManager.level = 19
	_check(road_system.get_road_upgrade_error(road_upgrade_cell).contains("City Level 20"), "Avenues must remain locked before City Level 20.")
	GameManager.level = 20
	_check(road_system.get_road_upgrade_cost(road_upgrade_cell) == 1500, "Avenue upgrade must use the sourced 1500-Simoleon upper-range per-tile cost.")
	_check(road_system.upgrade_road(road_upgrade_cell), "A six-lane road must upgrade to an Avenue at City Level 20.")
	_check(road_system.get_road_level(road_upgrade_cell) == 4, "Avenue upgrade did not reach road tier four.")
	_check(road_system.get_road_upgrade_error(road_upgrade_cell).contains("already an Avenue"), "An Avenue must reject further upgrades.")
	_check(road_system.get_road_upgrade_error(RoadSystemScript.GATEWAY_ROAD_CELL).contains("Gateway"), "The permanent highway Gateway must not be upgraded.")

	# Bulldozing an upgraded tile refunds half of its most recent upgrade only.
	GameManager.level = 9
	var refund_test_cell := Vector2i(18, 0)
	_check(road_system.place_road(refund_test_cell), "Could not create the isolated road tile for the upgrade-refund test.")
	_check(road_system.upgrade_road(refund_test_cell), "Refund test road could not be upgraded to four lanes.")
	var money_before_refund := EconomyManager.simoleons
	_check(road_system.remove_road(refund_test_cell), "Could not bulldoze the upgraded refund-test road.")
	_check(EconomyManager.simoleons == money_before_refund + 150, "Bulldozing a four-lane road must refund 50% of its latest 300-Simoleon upgrade.")
	GameManager.level = saved_level_before_road_test
	EconomyManager.simoleons = saved_money_before_road_test
	EconomyManager.simoleons_changed.emit(EconomyManager.simoleons)

	var saved_population_expected := GameManager.population
	_check(SaveManager.save_game(), "SaveManager could not write the city save.")

	for building in BuildManager.buildings.values():
		if is_instance_valid(building):
			building.queue_free()
	BuildManager.buildings.clear()
	BuildManager.building_cells.clear()
	BuildManager.factory_count = 0
	for road_mesh in road_system.roads.values():
		if is_instance_valid(road_mesh):
			road_mesh.queue_free()
	road_system.roads.clear()
	await get_tree().process_frame
	_check(SaveManager.load_game(), "SaveManager could not restore the saved city.")
	var restored_home = _find_building("residential_1")
	_check(road_system.get_road_count() == starter_road_count + 16, "Road network was not restored from save.")
	_check(road_system.is_road_connected_to_gateway(RoadSystemScript.GATEWAY_ROAD_CELL), "Save/load must restore the permanent highway gateway before other road tiles.")
	_check(road_system.get_road_level(Vector2i(0, 0)) == 4, "Save/load must preserve the upgraded Avenue road tier.")
	_check(BuildManager.buildings.size() == 5, "All five buildings were not restored from save.")
	_check(restored_home != null and restored_home.upgrade_stage == 2, "House upgrade stage was not restored.")
	_check(restored_home != null and restored_home.upgrade_in_progress and restored_home.upgrade_finish_unix > int(Time.get_unix_time_from_system()), "Residential upgrade finish timestamp was not restored from save.")
	if restored_home != null:
		restored_home.upgrade_finish_unix = int(Time.get_unix_time_from_system()) - 1
		restored_home._process(0.0)
		_check(not restored_home.upgrade_in_progress and restored_home.upgrade_stage == 3, "Restored residential upgrade did not finish from its saved timestamp.")
	_check(GameManager.population > saved_population_expected, "Completing the restored upgrade must add residents without subtracting the previous population.")

	if failures.is_empty():
		print("[GameplaySmoke] PASS: road network, footprint collision, road access, touch drag safety, fire hazard coverage/smoke timers, construction, production, collection, crafting, utilities, upgrade, population, save and load.")
		_finish(0)
	else:
		push_error("[GameplaySmoke] FAILURES: %d" % failures.size())
		_finish(1)

func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
