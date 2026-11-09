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
	var build_button := hud.get_node_or_null("BuildMenuButton") as Button
	var toolbar := hud.get_node_or_null("RightToolbar") as Control
	_check(build_button != null, "Hard-hat Build button was not created.")
	_check(toolbar != null, "Right-side category toolbar was not created.")
	if build_button == null or toolbar == null:
		return
	_check(toolbar.visible, "Build categories must be visible and discoverable on first entry.")
	_check(_node_has_label_text(build_button, "CLOSE"), "Visible build menu must expose a CLOSE control.")
	build_button.emit_signal("pressed")
	await get_tree().process_frame
	_check(not toolbar.visible, "Tapping CLOSE must hide the build category toolbar.")
	build_button.emit_signal("pressed")
	await get_tree().process_frame
	_check(toolbar.visible, "Tapping BUILD must reveal the right-side category toolbar.")
	var viewport_rect := get_viewport().get_visible_rect()
	_check(toolbar.get_global_rect().intersects(viewport_rect), "Right-side category toolbar is outside the visible screen.")
	_check(toolbar.get_global_rect().size.x < viewport_rect.size.x * 0.2, "Build category dock covers too much of the mobile play area.")
	var toolbar_items := toolbar.find_child("RightToolbarItems", true, false) as VBoxContainer
	_check(toolbar_items != null and toolbar_items.get_child_count() == 7, "Right toolbar must show seven categories in a vertical list.")
	var expected_names := ["Tool_Road", "Tool_Residential", "Tool_Commercial", "Tool_Industrial", "Tool_Services", "Tool_Specializations", "Tool_Bulldoze"]
	for i in range(expected_names.size()):
		var button := toolbar.find_child(expected_names[i], true, false) as Button
		_check(button != null, "Missing ordered category button: " + expected_names[i])
		if button and toolbar_items:
			_check(toolbar_items.get_child(i) == button, "Build categories are not in the required top-to-bottom order.")
			_check(button.custom_minimum_size.y >= 48.0, "Category touch target is too small.")
	_check(hud.get_node_or_null("BottomActions") != null, "Permanent city actions are missing.")
	_check(hud.get_node("BottomActions").visible, "Storage, Trade and Save should be visible while no category is selected.")
	hud._on_category_pressed("services")
	await get_tree().process_frame
	_check(hud.submenu_scroll.visible and not hud.get_node("BottomActions").visible, "Selecting a category must replace city actions with its bottom submenu.")
	for group_id in ["group_power", "group_water", "group_sewage", "group_waste", "group_fire", "group_police", "group_health", "group_government"]:
		_check(hud.submenu.get_node_or_null(group_id) != null, "Services group is missing: " + group_id)
	_check(hud.submenu.get_child_count() == 9, "Services level one must contain exactly eight fixed groups and Cancel.")
	hud._on_submenu_option("services", "group_water")
	await get_tree().process_frame
	_check(hud.submenu.get_node_or_null("water_tower") != null, "Water submenu must contain the Water Tower.")
	_check(hud.submenu.get_node_or_null("water_pump") != null, "Water submenu must contain the Water Pump.")
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Water submenu must expose Back and Cancel.")
	var locked_pump := hud.submenu.get_node_or_null("water_pump") as Button
	_check(locked_pump != null and not locked_pump.disabled, "Locked Water Pump must remain tappable for unlock feedback.")
	if locked_pump:
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Sewage submenu must expose Back and Cancel.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Waste submenu must expose Back and Cancel.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Fire submenu must expose Back and Cancel.")
	var basic_fire_button := hud.submenu.get_node_or_null("fire_station") as Button
	_check(basic_fire_button != null and _node_has_label_text_containing(basic_fire_button, "Coverage: 15 tiles"), "Basic Fire Station must display its coverage range in the submenu.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Police submenu must expose Back and Cancel.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Power submenu must expose Back and Cancel.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Active submenu must always provide Cancel.")
	hud._on_submenu_option("services", "back")
	_check(hud.submenu.get_node_or_null("group_power") != null, "Back must return to the Services group list.")
	hud._on_submenu_option("services", "group_health")
	await get_tree().process_frame
	for health_id in ["clinic_small", "clinic", "hospital"]:
		_check(hud.submenu.get_node_or_null(health_id) != null, "Health submenu is missing: " + health_id)
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Health submenu must expose Back and Cancel.")
	var locked_small_clinic := hud.submenu.get_node_or_null("clinic_small") as Button
	_check(locked_small_clinic != null and _node_has_label_text_containing(locked_small_clinic, "Coverage: 10 tiles"), "Small Clinic must display its coverage range in the submenu.")
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
	_check(hud.submenu.get_node_or_null("Submenu_Back") != null and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Government submenu must expose Back and Cancel.")
	var town_hall_definition: Dictionary = BuildManager.building_types["town_hall"]
	_check(int(town_hall_definition.get("government", 0)) == 1, "Town Hall must expose the separate government metadata key.")
	_check(str(town_hall_definition.get("service_group", "")) == "government", "Town Hall must belong to the Government group.")
	_check(int(town_hall_definition.get("fire", 0)) == 0 and int(town_hall_definition.get("police", 0)) == 0 and int(town_hall_definition.get("health", 0)) == 0, "Town Hall must not provide Fire, Police or Health coverage.")
	_check(int(town_hall_definition.get("power", 0)) == 0 and int(town_hall_definition.get("water", 0)) == 0, "Town Hall must not provide utility capacity.")
	var saved_government_level := GameManager.level
	GameManager.level = 1
	hud._on_submenu_option("services", "town_hall")
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
	_check(BuildManager.is_placing and BuildManager.selected_building_type == "clinic_small", "Unlocked Small Clinic must enter building placement mode.")
	BuildManager.cancel_placement()
	GameManager.level = previous_level
	hud._on_submenu_option("services", "back")
	hud._on_cancel_pressed()
	await get_tree().process_frame
	_check(not hud.submenu_scroll.visible and hud.get_node("BottomActions").visible, "Cancel must return to permanent city actions.")
	hud._close_build_menu()
	_check(not toolbar.visible, "Closing Build must hide the category toolbar.")

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
		_check(right_toolbar is PanelContainer, "Right-side construction tools must use a compact category dock.")
		if right_toolbar is PanelContainer:
			var toolbar_items = right_toolbar.find_child("RightToolbarItems", true, false)
			_check(toolbar_items is VBoxContainer, "Right toolbar categories must use a vertical scroll list.")
			_check(toolbar_items != null and toolbar_items.get_child_count() == 7, "Right toolbar must show all seven construction categories.")
			var build_toggle = hud.get_node_or_null("BuildMenuButton")
			_check(build_toggle is Button, "The persistent Build button must open the category dock.")
			_check(not right_toolbar.visible, "Category dock should stay collapsed until the player opens Build.")
			hud._toggle_category_menu()
			_check(right_toolbar.visible, "Build button action did not open the category dock.")
			hud._toggle_category_menu()
			_check(not right_toolbar.visible, "Build button action did not close the category dock.")
		hud._toggle_category_menu()
		hud._on_category_pressed("residential")
		_check(hud.submenu_scroll.visible and hud.submenu.get_node_or_null("residential_villa") != null, "Residential submenu must show available house choices.")
		_check(hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Residential submenu must always include Cancel.")
		hud._on_building_choice_pressed("residential_villa")
		_check(BuildManager.selected_building_type == "residential_villa" and BuildManager.is_placing, "Villa choice did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("commercial")
		_check(hud.submenu.get_node_or_null("hardware_store") != null, "Commercial menu is missing Hardware Store.")
		_check(hud.submenu.get_node_or_null("farmers_market") != null, "Commercial menu is missing Farmer's Market.")
		_check(hud.submenu.get_node_or_null("furniture_store") != null, "Commercial menu is missing Furniture Store.")
		_check(ProductionManager.get_default_recipe_for_building("shop_chain") == "nails", "Chain store should reuse the existing Nails recipe.")
		hud._on_submenu_option("commercial", "fast_food")
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
		_check(_node_has_label_text(hud.submenu.get_node("factory_small"), "Small Factory"), "Industrial submenu labels must be clear.")
		hud._on_submenu_option("industrial", "factory_small")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "factory_small", "Small factory menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("services")
		for group_id in ["group_power", "group_water", "group_sewage", "group_waste", "group_fire", "group_police", "group_health", "group_government"]:
			_check(hud.submenu.get_node_or_null(group_id) != null, "Services submenu is missing group " + group_id)
		hud._on_submenu_option("services", "group_power")
		_check(hud.submenu.get_node_or_null("power_wind") != null, "Power group must contain Wind Power.")
		hud._on_submenu_option("services", "power_wind")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "power_wind", "Wind power menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		var menu_test_level := GameManager.level
		GameManager.level = 1
		hud._on_category_pressed("services")
		hud._on_submenu_option("services", "group_fire")
		var locked_fire = hud.submenu.get_node_or_null("fire_station")
		_check(locked_fire != null and not locked_fire.disabled, "Locked fire station must remain clickable.")
		_check(locked_fire != null and locked_fire.find_child("LockIcon", true, false) is TextureRect and (locked_fire.find_child("LockIcon", true, false) as TextureRect).texture != null, "Locked fire station must show the transparent PNG lock overlay.")
		_check(_node_has_label_text_containing(locked_fire, "Unlocks at Level 5"), "Locked fire station must show its unlock level.")
		hud._on_submenu_option("services", "fire_station")
		_check(not BuildManager.is_placing and hud.status_label.text.find("Level 5") >= 0, "Locked fire station did not explain its unlock level.")
		GameManager.level = menu_test_level
		hud._on_category_pressed("specializations")
		_check(hud.submenu.get_node_or_null("group_parks") != null, "Specializations must show Parks as a subgroup.")
		hud._on_submenu_option("specializations", "group_parks")
		_check(hud.submenu.get_node_or_null("park_small") != null, "Parks subgroup must contain Small Park.")
		hud._on_submenu_option("specializations", "park_small")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "park_small", "Small Park menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("bulldoze")
		_check(input_node.bulldoze_mode and not input_node.bulldoze_road_mode, "Main bulldozer category did not activate demolition mode.")
		_check(hud.submenu_scroll.visible and hud.submenu.get_node_or_null("Submenu_Cancel") != null, "Bulldoze mode must show its indicator and Cancel action.")
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
	var metal_button := production_hud.production_panel.find_child("Slot0_metal", true, false) as Button
	_check(metal_button != null, "Factory panel must offer unlocked Metal production.")
	if metal_button:
		metal_button.emit_signal("pressed")
	_check(not factory_component.get_slot(0).is_empty(), "Selecting Metal must start the first factory slot.")
	production_hud.open_production_panel(factory)
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
