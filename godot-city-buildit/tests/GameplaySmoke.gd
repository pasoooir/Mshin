extends Node3D

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")
const RoadSystemScript = preload("res://scripts/systems/RoadSystem.gd")
const ProductionComponentScript = preload("res://scripts/production/ProductionComponent.gd")

class FireHazardTestBuilding extends Node3D:
	var building_id: String = ""
	var building_type: String = ""
	var definition: Dictionary = {}
	var status: String = "constructing"
	var smoke_active: bool = false

	func set_fire_smoke(active: bool) -> void:
		smoke_active = active

var failures: Array[String] = []

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

func _find_building(type_id: String):
	for building in BuildManager.buildings.values():
		if is_instance_valid(building) and building.building_type == type_id:
			return building
	return null

func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _test_storage_and_production_chain() -> void:
	var saved_storage: Dictionary = StorageManager.to_save_dict()
	StorageManager.capacity = 50
	StorageManager.items = {}
	_check(StorageManager.capacity == 50 and StorageManager.get_used() == 0, "New City Storage must start with 50 empty slots.")
	_check(StorageManager.add_item("metal", 2), "Storage must accept items within its capacity.")
	_check(StorageManager.get_count("metal") == 2 and StorageManager.get_free() == 48, "Storage item count/free-space accounting is incorrect.")
	_check(StorageManager.remove_items({"metal":2}), "Storage must remove a validated recipe input set.")
	_check(StorageManager.get_used() == 0, "Removing recipe inputs must update used storage.")
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
	var nails: Dictionary = ProductionManager.get_recipe("nails")
	_check(int(nails.get("time_sec",0)) == 300 and nails.get("inputs",{}) == {"metal":2}, "Nails must require 2 Metal and take 5 minutes.")
	_check(BuildManager.building_types.factory_small.get("production_slots",0) == 2, "Small Factory must expose two parallel production slots.")
	_check(BuildManager.building_types.factory_basic.get("production_slots",0) == 3 and BuildManager.building_types.factory_basic.get("population_required",0) == 4000, "Basic Factory must have 3 slots and require 4,000 population.")
	_check(BuildManager.building_types.factory_mass.get("production_slots",0) == 4 and BuildManager.building_types.factory_mass.get("population_required",0) == 27000, "Mass Production must have 4 slots and require 27,000 population.")
	_check(BuildManager.building_types.factory_hightech.get("production_slots",0) == 5 and BuildManager.building_types.factory_hightech.get("population_required",0) == 80000, "High-tech Factory must have 5 slots and require 80,000 population.")
	_check(BuildManager.building_types.factory_nano.get("production_slots",0) == 5 and BuildManager.building_types.factory_nano.get("pollution",1) == 0 and BuildManager.building_types.factory_nano.get("population_required",0) == 150000, "Nano-tech Factory must have 5 slots, no pollution and require 150,000 population.")
	_check(BuildManager.building_types.factory_small.get("can_produce",[]).has("electrical"), "Small Factory must support all raw products, gated only by each material's Mayor Level.")
	_check(BuildManager.building_types.building_supplies.get("production_slots",0) == 2, "Building Supplies must expose a two-order queue.")
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
	GameManager.population = 150000
	_check(BuildManager.can_build_factory_type("factory_nano"), "Nano-tech Factory must unlock at 150,000 residents.")
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
	var building_script = load("res://scripts/buildings/Building.gd")
	var test_building = building_script.new()
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
	var hud = get_node_or_null("HUD")
	_check(hud != null, "Main scene HUD is missing.")
	if hud == null:
		return
	var build_button := hud.get_node_or_null("BuildMenuButton")
	var toolbar := hud.get_node_or_null("RightToolbar") as Control
	_check(build_button == null, "Legacy hard-hat Build button must be removed from the HUD.")
	_check(toolbar != null and toolbar.visible, "Transparent right-side category PNG rail must be visible immediately.")
	if toolbar == null:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	_check(toolbar.get_global_rect().intersects(viewport_rect), "Right-side category PNG rail is outside the visible screen.")
	_check(toolbar.get_global_rect().size.x < viewport_rect.size.x * 0.12, "Transparent category rail covers too much of the mobile play area.")
	var toolbar_items := toolbar.find_child("RightToolbarItems", true, false) as VBoxContainer
	_check(toolbar_items != null and toolbar_items.get_child_count() == 7, "Right rail must show seven categories in a vertical list.")
	var expected_names := ["Tool_Residential", "Tool_Commercial", "Tool_Industrial", "Tool_Services", "Tool_Specializations", "Tool_Road", "Tool_Bulldoze"]
	for i in range(expected_names.size()):
		var button := toolbar.find_child(expected_names[i], true, false) as Button
		_check(button != null, "Missing ordered category PNG: " + expected_names[i])
		if button and toolbar_items:
			_check(toolbar_items.get_child(i) == button, "Right rail categories are not in the required top-to-bottom order.")
			_check(button.custom_minimum_size.y >= 64.0, "Category PNG touch target is too small.")
			var category_icon := button.get_node_or_null("CategoryPNG") as TextureRect
			_check(category_icon != null and category_icon.texture != null and category_icon.custom_minimum_size.x >= 64.0, "Category PNG must be transparent artwork at a readable size.")
			_check(button.get_theme_stylebox("normal").get_class() == "StyleBoxEmpty", "Category PNG must not have a card background.")
	var currency_stack := hud.get_node_or_null("TopRightCurrencies") as VBoxContainer
	_check(currency_stack != null and currency_stack.get_child_count() == 3, "Top-right resources must be exactly three compact rows.")
	for row_name in ["SimoleonsCurrencyRow", "MoneyCurrencyRow", "Golden_keyCurrencyRow"]:
		_check(currency_stack != null and currency_stack.find_child(row_name, true, false) is HBoxContainer, "Missing resource row: " + row_name)
	_check(currency_stack != null and currency_stack.find_child("SimoleonsCurrencyPlus", true, false) is Button, "Simoleons row must show the blue + tile.")
	_check(currency_stack != null and currency_stack.find_child("SimCashCurrencyPlus", true, false) is Button, "SimCash row must show the blue + tile.")
	_check(currency_stack != null and currency_stack.find_child("GoldenKeysCurrencyPlus", true, false) == null, "Golden key row must not show an unnecessary + tile.")
	_check(hud.get_node_or_null("BottomActions") != null, "Permanent city actions are missing.")
	_check(hud.get_node("BottomActions").visible, "Storage, Trade and Save should be visible while no category is selected.")
	hud._on_category_pressed("services")
	await get_tree().process_frame
	_check(toolbar.visible, "Right-side transparent PNG shortcuts must remain visible while a category submenu is open.")
	_check(hud.submenu_scroll.visible and not hud.get_node("BottomActions").visible, "Selecting a category must replace city actions with its bottom submenu.")
	_check(hud.submenu_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Catalog horizontal scroll chrome must stay hidden.")
	_check(hud.submenu_scroll.scroll_deadzone <= 10, "Horizontal submenu swipe must respond with a short touch deadzone.")
	_check(hud.submenu.alignment == BoxContainer.ALIGNMENT_BEGIN, "Horizontal submenu items must start at the leading edge for predictable swiping.")
	for group_id in ["group_power", "group_water", "group_sewage", "group_waste", "group_fire", "group_police", "group_health", "group_government"]:
		_check(hud.submenu.get_node_or_null(group_id) != null, "Services group is missing: " + group_id)

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

func _run_gameplay_test() -> void:
	await get_tree().process_frame
	await _test_build_menu_visibility()
	_test_wind_turbine_rotor_animation()
	_test_storage_and_production_chain()
	_test_fire_hazard_state_machine()
	_test_immigration_coefficients()
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
		hud._on_submenu_option("commercial", "fast_food")
		_confirm_catalog_build(hud)
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
		_check(hud.storage_panel.find_child("StorageIncreaseCapacity", true, false) is Button, "City Storage must show its green Increase Capacity action.")
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
	var factory = _find_building("industrial_1")
	_check(home != null and home.status == "completed", "House construction did not finish.")
	_check(factory != null and factory.status == "completed", "Factory construction did not finish.")
	_check(GameManager.population > 0, "Completed house did not add any occupied population.")
	_check(GameManager.happiness > 0.0 and GameManager.happiness <= 100.0, "First completed house happiness must remain in the valid non-zero range.")
	_check(ServiceManager.total_power >= 12 and ServiceManager.total_water >= 12, "Power/water capacity was not registered.")
	_check(home != null and ServiceManager.is_building_served(home), "House was not served by nearby power and water.")

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
	_check(not factory_component.get_slot(0).is_empty(), "Selecting Metal must start the first factory slot.")
	production_hud.open_production_panel(factory)
	_check(production_hud.production_panel.find_child("TimerSlot0", true, false) is Label, "Active factory production must show a live countdown label.")
	_check(production_hud.production_panel.find_child("ProgressSlot0", true, false) is ProgressBar, "Active factory production must show a live progress bar.")
	var second_metal_button := production_hud.production_panel.find_child("Slot1_metal", true, false) as Button
	_check(second_metal_button != null, "Factory panel must allow a second parallel Metal batch.")
	if second_metal_button:
		second_metal_button.emit_signal("pressed")
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
	if nails_button_0:
		nails_button_0.emit_signal("pressed")
	else:
		_check(false, "Building Supplies must offer Nails at level 1.")
	production_hud.open_production_panel(supplies)
	var nails_button_1 := production_hud.production_panel.find_child("Slot1_nails", true, false) as Button
	if nails_button_1:
		nails_button_1.emit_signal("pressed")
	else:
		_check(false, "Building Supplies second slot must accept a Nails order.")
	_check(StorageManager.get_count("metal") == 0, "Starting two Nails orders must deduct four Metal immediately.")
	for slot_index in range(2):
		var slot: Dictionary = shop_component.slots[slot_index]
		slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
		shop_component.slots[slot_index] = slot
	shop_component.refresh_slots()
	production_hud.open_production_panel(supplies)
	var collect_nails_0 := production_hud.production_panel.find_child("CollectSlot0", true, false) as Button
	if collect_nails_0:
		collect_nails_0.emit_signal("pressed")
	production_hud.open_production_panel(supplies)
	var collect_nails_1 := production_hud.production_panel.find_child("CollectSlot1", true, false) as Button
	if collect_nails_1:
		collect_nails_1.emit_signal("pressed")
	_check(StorageManager.get_count("nails") == 2, "Both completed Nails orders must return to City Storage.")

	# Verify a full warehouse blocks collection without losing the ready batch.
	_check(factory_component.start_factory("metal",0), "Factory must accept a new order after a collection.")
	var full_slot: Dictionary = factory_component.slots[0]
	full_slot["finish_unix"] = int(Time.get_unix_time_from_system()) - 1
	factory_component.slots[0] = full_slot
	factory_component.refresh_slots()
	StorageManager.capacity = 1
	StorageManager.items = {"occupied":1}
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
	_check(home != null and home.try_upgrade(), "House upgrade failed despite having Nails and Metal.")
	_check(home != null and home.upgrade_stage == 2, "House did not advance to level 2.")
	print("[GameplaySmoke] upgraded home population=%d city=%d happiness=%.1f served_power=%s served_water=%s" % [home.current_population if home else -1, GameManager.population, GameManager.happiness, str(ServiceManager.power_served_ids.has(home.building_id)) if home else "n/a", str(ServiceManager.water_served_ids.has(home.building_id)) if home else "n/a"])
	_check(home != null and home.current_population > population_before_upgrade and GameManager.population > population_before_upgrade, "House upgrade did not increase service-adjusted population.")

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
	_check(BuildManager.buildings.size() == 5, "All five buildings were not restored from save.")
	_check(restored_home != null and restored_home.upgrade_stage == 2, "House upgrade stage was not restored.")
	_check(GameManager.population == saved_population_expected, "Population was not restored from save.")

	if failures.is_empty():
		print("[GameplaySmoke] PASS: road network, footprint collision, road access, touch drag safety, fire hazard coverage/smoke timers, construction, production, collection, crafting, utilities, upgrade, population, save and load.")
		_finish(0)
	else:
		push_error("[GameplaySmoke] FAILURES: %d" % failures.size())
		_finish(1)

func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
