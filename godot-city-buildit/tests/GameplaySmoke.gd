extends Node3D

const IconAtlas = preload("res://scripts/ui/IconAtlas.gd")
const RoadSystemScript = preload("res://scripts/systems/RoadSystem.gd")

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

func _run_gameplay_test() -> void:
	await get_tree().process_frame
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
	_check(road_system.get_road_tile_kind(Vector2i(10, 0)) == RoadSystemScript.TILE_T, "A three-neighbor starter-road tile was not classified as a T-junction.")
	_check(road_system.get_road_tile_kind(Vector2i(10, -1)) == RoadSystemScript.TILE_T, "The opposite starter-road row did not resolve its T-junction topology.")
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
		_check(right_toolbar is PanelContainer, "Right-side construction tools must use the compact category dock.")
		if right_toolbar is PanelContainer:
			var toolbar_items = right_toolbar.get_node_or_null("RightToolbarItems")
			_check(toolbar_items is GridContainer, "Right toolbar must use a two-column grid instead of a long scroll list.")
			_check(toolbar_items != null and toolbar_items.get_child_count() == 7, "Right toolbar must show all seven construction categories.")
			if toolbar_items is GridContainer:
				_check(toolbar_items.columns == 2, "Right toolbar category grid must have two columns.")
				for category_button in toolbar_items.get_children():
					_check(category_button.custom_minimum_size.x >= 58.0 and category_button.custom_minimum_size.y >= 58.0, "Category buttons must remain large enough for mobile touch targets.")
			var build_toggle = hud.get_node_or_null("BuildMenuButton")
			_check(build_toggle is Button, "The persistent Build button must open the category dock.")
			_check(not right_toolbar.visible, "Category dock should stay collapsed until the player opens Build.")
			hud._toggle_category_menu()
			_check(right_toolbar.visible, "Build button action did not open the category dock.")
			hud._toggle_category_menu()
			_check(not right_toolbar.visible, "Build button action did not close the category dock.")
		hud._show_submenu("residential")
		_check(hud.submenu.get_node("residential_villa").text == "Villa House", "Residential submenu label must be English.")
		_check(hud.submenu.get_child_count() == 4, "Residential submenu should show three choices and a close button.")
		_check(hud.submenu.get_node_or_null("residential_villa") != null, "Residential villa option is missing.")
		_check(hud.submenu.get_node_or_null("residential_apartment") != null, "Residential apartment option is missing.")
		_check(hud.submenu.get_node_or_null("residential_farm") != null, "Residential farm option is missing.")
		hud._on_building_choice_pressed("residential_villa")
		_check(BuildManager.selected_building_type == "residential_villa" and BuildManager.is_placing, "Villa choice did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._show_submenu("commercial")
		_check(hud.submenu.get_child_count() == 5, "Commercial submenu should show four choices and a close button.")
		_check(hud.submenu.get_node_or_null("shop_chain") != null, "Chain store option is missing.")
		_check(hud.submenu.get_node("shop_chain").text == "Chain Store", "Commercial submenu labels must be English.")
		_check(hud.submenu.get_node_or_null("restaurant_traditional") != null, "Traditional restaurant option is missing.")
		_check(hud.submenu.get_node_or_null("fast_food") != null, "Fast food option is missing.")
		_check(hud.submenu.get_node_or_null("art_supplies") != null, "Art supplies option is missing.")
		_check(ProductionManager.get_default_recipe_for_building("shop_chain") == "nails", "Chain store should reuse the existing Nails recipe.")
		hud._on_building_choice_pressed("fast_food")
		_check(BuildManager.selected_building_type == "fast_food" and BuildManager.is_placing, "Fast food choice did not enter placement mode.")
		BuildManager.cancel_placement()
		# Verify representative new types pass the real road-access/footprint placement path.
		for placement_case in [
			{"type":"residential_villa","grid":Vector2i(12, 1)},
			{"type":"residential_farm","grid":Vector2i(14, 1)},
			{"type":"fast_food","grid":Vector2i(16, 1)}
		]:
			var type_id: String = placement_case["type"]
			var grid_pos: Vector2i = placement_case["grid"]
			BuildManager.select_building(type_id)
			_check(BuildManager.can_place_at(grid_pos, type_id), "%s should be placeable beside the starter road." % type_id)
			_check(BuildManager.place_building(grid_pos, type_id), "%s could not be placed beside the starter road." % type_id)
			var placed_choice = BuildManager.building_at_cell(grid_pos)
			_check(placed_choice != null and placed_choice.building_type == type_id, "%s placement did not create the selected building." % type_id)
			if placed_choice:
				BuildManager.unregister_building(placed_choice.building_id)
				placed_choice.queue_free()
			BuildManager.cancel_placement()
		hud._show_submenu("road")
		_check(hud.submenu.get_node_or_null("road_build") != null, "Road build submenu action is missing.")
		_check(hud.submenu.get_node_or_null("bulldoze_road") != null, "Road bulldozer submenu action is missing.")
		hud._on_submenu_option("road", "road_build")
		_check(road_system.is_road_mode, "Road build menu action did not enable road placement.")
		hud._on_cancel_pressed()
		hud._show_submenu("road")
		hud._on_submenu_option("road", "bulldoze_road")
		_check(input_node.bulldoze_road_mode, "Road bulldozer menu action did not enable road removal.")
		hud._on_cancel_pressed()
		hud._show_submenu("industrial")
		_check(hud.submenu.get_node_or_null("industrial_1") != null and hud.submenu.get_node_or_null("industrial_2") != null, "Both level-based factory choices must be listed.")
		_check(hud.submenu.get_node("industrial_1").text == "Small Factory - Metal", "Industrial submenu labels must be English.")
		hud._on_submenu_option("industrial", "industrial_1")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "industrial_1", "Small factory menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		hud._show_submenu("services")
		_check(hud.submenu.get_node_or_null("power_wind") != null and hud.submenu.get_node_or_null("water_tower") != null and hud.submenu.get_node_or_null("fire_station") != null, "Power, water and fire service choices must be listed.")
		_check(hud.submenu.get_node("power_wind").text == "Wind Power", "Services submenu labels must be English.")
		hud._on_submenu_option("services", "power_wind")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "power_wind", "Wind power menu action did not enter placement mode.")
		BuildManager.cancel_placement()
		var menu_test_level := GameManager.level
		GameManager.level = 1
		hud._show_submenu("services")
		var locked_fire = hud.submenu.get_node_or_null("fire_station")
		_check(locked_fire != null and not locked_fire.disabled, "Locked fire station must remain clickable.")
		_check(locked_fire.text.find("Unlocked at Level 5") >= 0, "Locked entries must use the plain English unlock label.")
		hud._on_submenu_option("services", "fire_station")
		_check(not BuildManager.is_placing and hud.status_label.text.find("Level 5") >= 0, "Locked fire station did not explain its unlock level.")
		GameManager.level = menu_test_level
		hud._on_category_pressed("park")
		_check(BuildManager.is_placing and BuildManager.selected_building_type == "park_small", "Park button did not directly enter park placement mode.")
		BuildManager.cancel_placement()
		hud._on_category_pressed("bulldoze")
		_check(input_node.bulldoze_mode and not input_node.bulldoze_road_mode, "Main bulldozer button did not activate general demolition mode.")
		_check(hud.status_label.text == "Bulldozer active — tap a building twice to demolish. Tap a road to remove it. Press X to cancel.", "Bulldozer activation message is missing or unclear.")
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

	# Production durations are shortened only in this deterministic smoke test.
	ProductionManager.raw_materials["metal"]["time"] = 0.2
	ProductionManager.crafted_items["nails"]["time"] = 0.2
	# The factory starts its first Metal batch automatically when construction completes.
	_check(factory != null and factory.is_producing, "Factory did not automatically start Metal after construction.")
	factory.production_time = 0.2
	factory.production_timer = 0.2
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and factory.is_producing, "Tapping an active factory should report its running Metal batch.")
	await _wait_seconds(0.35)
	_check(factory != null and factory.has_ready_product, "Factory did not finish its first Metal.")
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and not factory.has_ready_product and StorageManager.get_item_count("metal") == 1, "Tapping the ready factory did not collect first Metal.")
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and factory.is_producing, "Tapping the factory did not start its second Metal batch.")
	await _wait_seconds(0.35)
	_check(factory != null and factory.has_ready_product, "Factory did not finish its second Metal.")
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and not factory.has_ready_product and StorageManager.get_item_count("metal") == 2, "Tapping the ready factory did not collect second Metal.")
	_check(StorageManager.get_item_count("metal") == 2, "Two collected Metal units were not stored.")

	var supplies = _find_building("building_supplies")
	input_node._try_interact(BuildManager.grid_to_world(supplies.grid_pos))
	_check(supplies != null and supplies.is_producing, "Tapping Building Supplies did not start Nails production.")
	_check(StorageManager.get_item_count("metal") == 0, "Nails production did not consume exactly two Metal.")
	await _wait_seconds(0.35)
	_check(supplies != null and supplies.has_ready_product, "Building Supplies did not finish Nails.")
	input_node._try_interact(BuildManager.grid_to_world(supplies.grid_pos))
	_check(supplies != null and not supplies.has_ready_product and StorageManager.get_item_count("nails") == 1, "Tapping ready Building Supplies did not collect Nails.")
	_check(StorageManager.get_item_count("nails") == 1, "Crafted Nails were not stored.")
	_check(not supplies.is_producing and not supplies.has_ready_product, "Commercial store should stop after collecting its product.")
	StorageManager.add_item("metal", 2)
	input_node._try_interact(BuildManager.grid_to_world(supplies.grid_pos))
	_check(supplies.is_producing, "Tapping Building Supplies again should order another timed Nails batch.")
	# Cancel the second batch for the next test and restore the required Metal/Wood inputs.
	supplies.is_producing = false
	supplies.production_timer = 0.0
	if supplies.production_icon:
		supplies.production_icon.visible = false

	# Hardware Store unlocks at level 4 and must craft Hammer from Metal + Wood.
	var previous_level := GameManager.level
	GameManager.level = 4
	_check(BuildManager.place_building(Vector2i(9, 1), "hardware_store"), "Could not place Hardware Store for production acceptance.")
	await _wait_seconds(5.5)
	var hardware = _find_building("hardware_store")
	_check(hardware != null and hardware.status == "completed", "Hardware Store construction did not finish.")
	StorageManager.add_item("metal", 1)
	StorageManager.add_item("wood", 1)
	ProductionManager.crafted_items["hammer"]["time"] = 0.2
	input_node._try_interact(BuildManager.grid_to_world(hardware.grid_pos))
	_check(hardware != null and hardware.is_producing and hardware.current_product == "hammer", "Hardware Store did not start timed Hammer production.")
	_check(StorageManager.get_item_count("metal") == 0 and StorageManager.get_item_count("wood") == 0, "Hammer recipe did not consume Metal and Wood.")
	await _wait_seconds(0.35)
	_check(hardware != null and hardware.has_ready_product, "Hardware Store did not finish Hammer.")
	input_node._try_interact(BuildManager.grid_to_world(hardware.grid_pos))
	_check(StorageManager.get_item_count("hammer") == 1 and not hardware.is_producing, "Hardware Store did not collect Hammer and stop.")
	BuildManager.unregister_building(hardware.building_id)
	hardware.queue_free()
	GameManager.level = previous_level

	# Existing level-1 upgrade recipe also needs one Metal in addition to Nails.
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and factory.is_producing, "Collecting the factory's ready Metal did not restart production.")
	# Simulate a stopped/idle factory and verify that tapping it resumes production.
	factory.is_producing = false
	factory.production_timer = 0.0
	if factory.production_icon:
		factory.production_icon.visible = false
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and factory.is_producing, "Tapping an idle factory did not restart Metal production.")
	await _wait_seconds(0.35)
	input_node._try_interact(BuildManager.grid_to_world(factory.grid_pos))
	_check(factory != null and StorageManager.get_item_count("metal") == 2, "Tapping factory did not collect the restarted Metal batch.")
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
		print("[GameplaySmoke] PASS: road network, footprint collision, road access, touch drag safety, construction, production, collection, crafting, utilities, upgrade, population, save and load.")
		_finish(0)
	else:
		push_error("[GameplaySmoke] FAILURES: %d" % failures.size())
		_finish(1)

func _finish(exit_code: int = 0) -> void:
	get_tree().quit(exit_code)
