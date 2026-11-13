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
		_check(is_equal_approx(HappinessManager.calculate_home_happiness(low_home), baseline_happiness + 12.0), "Sewage service must replace the -6 shortage penalty with the existing +6 service bonus.")

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
	_check(bool(sewage_preview.get("visible", false)), "Sewage placement must show a coverage preview.")
	_check(bool(waste_preview.get("visible", false)), "Waste placement must show a coverage preview.")
	_check(is_equal_approx(float(power_preview.get("radius", -1.0)), ServiceManager.coverage_radius), "Power preview radius must match the live ServiceManager coverage radius.")
	_check(is_equal_approx(float(water_preview.get("radius", -1.0)), ServiceManager.coverage_radius), "Water preview radius must match the live ServiceManager coverage radius.")
	_check(is_equal_approx(float(sewage_preview.get("radius", -1.0)), HappinessManager.SEWAGE_COVERAGE_RADIUS), "Sewage preview radius must match its happiness coverage radius.")
	_check(is_equal_approx(float(waste_preview.get("radius", -1.0)), HappinessManager.WASTE_COVERAGE_RADIUS), "Waste preview radius must match its happiness coverage radius.")
	_check(power_preview.get("disc_color", Color.WHITE) != water_preview.get("disc_color", Color.WHITE), "Power and Water coverage previews must use distinct colors.")
	_check(sewage_preview.get("disc_color", Color.WHITE) != waste_preview.get("disc_color", Color.WHITE), "Sewage and Waste coverage previews must use distinct colors.")
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

e_id in expected_capacities.keys():
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
			_check(ServiceManager.waste_served_ids.size() < 14, "A small waste facility must leave some connected homes unserved.")
		else:
			_check(ServiceManager.used_waste == 18, "A larger waste facility must serve all connected demand units.")
			_check(ServiceManager.waste_served_ids.size() == 14, "A sufficient waste facility must serve all connected homes.")
		_check(HappinessManager._home_has_extra_service(low_home), "A waste-served home must count as receiving an extra service.")

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

