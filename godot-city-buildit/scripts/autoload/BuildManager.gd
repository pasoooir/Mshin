extends Node

signal building_placed(building_data: Dictionary)
signal building_removed(building_id: String)
signal construction_started(building_id: String)
signal construction_finished(building_id: String)
signal placement_mode_changed(active: bool)

const GRID_SIZE: float = 2.0
const WORLD_HALF_CELLS: int = 40
const BuildingScene = preload("res://scenes/buildings/Building.tscn")

var buildings: Dictionary = {}
# Every occupied grid cell points directly to its building for O(1) interaction and placement checks.
var building_cells: Dictionary = {}
var selected_building_type: String = ""
var is_placing: bool = false
var factory_count: int = 0

var building_types: Dictionary = {
	"residential_1": {"name":"Small House", "category":"residential", "cost":0, "size":Vector2i(2,2), "population":15, "build_time":3.0, "color":Color(0.95,0.72,0.5), "level":1},
	"residential_2": {"name":"Apartment", "category":"residential", "cost":0, "size":Vector2i(2,2), "population":28, "build_time":5.0, "color":Color(0.88,0.62,0.68), "level":3},
	# New player-facing residential choices. Legacy residential_1/_2 remain load-compatible.
	"residential_villa": {"name":"Villa House", "category":"residential", "subtype":"villa", "cost":0, "size":Vector2i(2,2), "population":15, "build_time":3.0, "color":Color(0.95,0.72,0.5), "level":1},
	"residential_apartment": {"name":"Apartment", "category":"residential", "subtype":"apartment", "cost":200, "size":Vector2i(2,2), "population":35, "build_time":5.0, "color":Color(0.88,0.62,0.68), "level":3},
	"residential_farm": {"name":"Farm", "category":"residential", "subtype":"farm", "cost":150, "size":Vector2i(2,2), "population":12, "build_time":4.0, "color":Color(0.72,0.78,0.45), "level":2},
	"building_supplies": {"name":"Building Supplies", "category":"commercial", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":2},
	# New commercial menu choices. shop_chain keeps the existing Nails recipe path.
	"shop_chain": {"name":"Chain Store", "category":"commercial", "subtype":"chain", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":1},
	"restaurant_traditional": {"name":"Traditional Restaurant", "category":"commercial", "subtype":"restaurant", "cost":400, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.75,0.45,0.30), "level":4, "production_slots":1, "shop_id":"restaurant_traditional"},
	"fast_food": {"name":"Fast Food Restaurant", "category":"commercial", "subtype":"fast_food", "cost":25000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.95,0.55,0.20), "level":25, "production_slots":1},
	"art_supplies": {"name":"Art Supplies Store", "category":"commercial", "subtype":"art", "cost":300, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.40,0.75), "level":5, "production_slots":1, "shop_id":"art_supplies"},
	"hardware_store": {"name":"Hardware Store", "category":"commercial", "cost":2500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.3,0.55,0.85), "level":4, "production_slots":1},
	"farmers_market": {"name":"Farmer's Market", "category":"commercial", "cost":5000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.4,0.75,0.4), "level":8, "production_slots":1},
	"furniture_store": {"name":"Furniture Store", "category":"commercial", "cost":8000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.6,0.45,0.3), "level":10, "production_slots":1},
	"gardening_supplies": {"name":"Gardening Supplies Store", "category":"commercial", "subtype":"gardening_supplies", "cost":13000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.40,0.68,0.38), "level":14, "production_slots":1, "shop_id":"gardening_supplies"},
	"donut_shop": {"name":"Donut Shop", "category":"commercial", "subtype":"donut_shop", "cost":17000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.92,0.55,0.62), "level":18, "production_slots":1, "shop_id":"donut_shop"},
	"home_appliances": {"name":"Home Appliances Store", "category":"commercial", "subtype":"home_appliances", "cost":30000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.36,0.58,0.78), "level":29, "production_slots":1, "shop_id":"home_appliances"},
	"fashion_store": {"name":"Fashion Store", "category":"commercial", "subtype":"fashion_store", "cost":22000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.82,0.48,0.68), "level":19, "production_slots":1, "shop_id":"fashion_store"},
	"sports_shop": {"name":"Sports Shop", "category":"commercial", "subtype":"sports_shop", "cost":80000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.42,0.66,0.46), "level":35, "production_slots":1, "shop_id":"sports_shop"},
	"toy_store": {"name":"Toy Store", "category":"commercial", "subtype":"toy_store", "cost":100000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.90,0.64,0.26), "level":40, "production_slots":1, "shop_id":"toy_store"},
	"restoration_office": {"name":"Restoration Office", "category":"commercial", "subtype":"restoration_office", "cost":250000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.55,0.58,0.64), "level":45, "production_slots":1, "shop_id":"restoration_office"},
	"farmers_store": {"name":"Country Store", "category":"commercial", "subtype":"farmers_store", "cost":300000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.68,0.54,0.34), "level":50, "production_slots":1, "shop_id":"farmers_store"},
	"dessert_shop": {"name":"Dessert Shop", "category":"commercial", "subtype":"dessert_shop", "cost":350000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.90,0.58,0.68), "level":55, "production_slots":1, "shop_id":"dessert_shop"},
	"factory_small": {"name":"Small Factory", "category":"industrial", "factory_tier":"small", "cost":0, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.55,0.6), "produces":"metal", "level":1, "production_slots":2, "pollution":1, "pollution_radius":12.0},
	"factory_basic": {"name":"Basic Factory", "category":"industrial", "factory_tier":"basic", "cost":500, "size":Vector2i(2,2), "population":0, "population_required":4000, "build_time":5.0, "color":Color(0.48,0.50,0.56), "level":1, "production_slots":3, "pollution":1, "pollution_radius":10.0},
	"factory_mass": {"name":"Mass Production Factory", "category":"industrial", "factory_tier":"mass", "cost":7000, "size":Vector2i(2,2), "population":0, "population_required":27000, "build_time":6.0, "color":Color(0.43,0.47,0.53), "level":1, "production_slots":4, "pollution":1, "pollution_radius":8.0},
	"factory_hightech": {"name":"High-tech Factory", "category":"industrial", "factory_tier":"hightech", "cost":20000, "size":Vector2i(2,2), "population":0, "population_required":80000, "build_time":7.0, "color":Color(0.38,0.54,0.62), "level":1, "production_slots":5, "pollution":1, "pollution_radius":6.0},
	"factory_nano": {"name":"Nano-tech Factory", "category":"industrial", "factory_tier":"nano", "cost":50000, "size":Vector2i(2,2), "population":0, "population_required":150000, "build_time":8.0, "color":Color(0.34,0.62,0.66), "level":1, "production_slots":5, "pollution":0, "pollution_radius":0.0},
	"industrial_1": {"name":"Small Factory (Legacy)", "category":"industrial", "legacy_only":true, "cost":0, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.55,0.6), "produces":"metal", "level":1, "production_slots":2, "pollution":1, "pollution_radius":12.0},
	"industrial_2": {"name":"Factory (Legacy)", "category":"industrial", "legacy_only":true, "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.45,0.45,0.5), "produces":"wood", "level":2, "production_slots":2},
	"industrial_3": {"name":"Factory+ (Legacy)", "category":"industrial", "legacy_only":true, "cost":1500, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.4,0.42,0.48), "produces":"plastic", "level":5, "production_slots":2},
	"power_wind": {"name":"Wind Power Plant", "category":"service", "service_group":"power", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.7,0.9,0.85), "power":12, "pollution":0, "pollution_radius":0.0, "level":1},
	"power_coal": {"name":"Coal Power Plant", "category":"service", "service_group":"power", "cost":1000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.38,0.39,0.42), "power":12, "pollution":1, "pollution_radius":10.0, "level":1},
	"power_wind_deluxe": {"name":"Deluxe Wind Power Plant", "category":"service", "service_group":"power", "cost":15000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.62,0.86,0.82), "power":22, "pollution":0, "pollution_radius":0.0, "level":10},
	"power_solar": {"name":"Solar Power Plant", "category":"service", "service_group":"power", "cost":22000, "size":Vector2i(2,4), "population":0, "build_time":7.0, "color":Color(0.95,0.78,0.35), "power":35, "pollution":0, "pollution_radius":0.0, "level":15},
	"power_oil": {"name":"Oil Power Plant", "category":"service", "service_group":"power", "cost":15000, "size":Vector2i(2,4), "population":0, "build_time":7.0, "color":Color(0.42,0.39,0.34), "power":40, "pollution":1, "pollution_radius":8.0, "level":18},
	"power_nuclear": {"name":"Nuclear Power Plant", "category":"service", "service_group":"power", "cost":35000, "size":Vector2i(3,3), "population":0, "build_time":9.0, "color":Color(0.58,0.72,0.62), "power":60, "pollution":1, "pollution_radius":12.0, "level":22},
	"water_tower": {"name":"Water Tower", "category":"service", "service_group":"water", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.45,0.72,0.95), "water":12, "pollution":0, "pollution_radius":0.0, "level":1},
	"water_pump": {"name":"Water Pumping Station", "category":"service", "service_group":"water", "cost":45000, "size":Vector2i(2,3), "population":0, "build_time":8.0, "color":Color(0.34,0.62,0.86), "water":55, "pollution":0, "pollution_radius":0.0, "level":12},
	"fire_station_small": {"name":"Small Fire Station", "category":"service", "service_group":"fire", "cost":3100, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.96,0.42,0.32), "fire":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":5},
	"fire_station": {"name":"Fire Station", "category":"service", "service_group":"fire", "cost":5500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.92,0.32,0.28), "fire":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":5},
	"fire_station_deluxe": {"name":"Deluxe Fire Station", "category":"service", "service_group":"fire", "cost":21000, "size":Vector2i(4,2), "population":0, "build_time":8.0, "color":Color(0.88,0.24,0.20), "fire":1, "coverage_tiles":22, "pollution":0, "pollution_radius":0.0, "level":5},
	"police_station": {"name":"Police Station", "category":"service", "service_group":"police", "cost":3000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.28,0.42,0.78), "police":1, "level":12},
	"police_small": {"name":"Small Police Station", "category":"service", "service_group":"police", "cost":5100, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.20,0.34,0.68), "police":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":12},
	"police_basic": {"name":"Basic Police Station", "category":"service", "service_group":"police", "cost":9400, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.16,0.29,0.62), "police":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":12},
	"police_precinct": {"name":"Police Precinct", "category":"service", "service_group":"police", "cost":36000, "size":Vector2i(4,2), "population":0, "build_time":8.0, "color":Color(0.12,0.23,0.52), "police":1, "coverage_tiles":24, "pollution":0, "pollution_radius":0.0, "level":12},
	"clinic_small": {"name":"Small Clinic", "category":"service", "service_group":"health", "cost":14000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.34,0.72,0.66), "health":1, "coverage_tiles":10, "pollution":0, "pollution_radius":0.0, "level":16},
	"clinic": {"name":"Clinic", "category":"service", "service_group":"health", "cost":21000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.24,0.64,0.60), "health":1, "coverage_tiles":15, "pollution":0, "pollution_radius":0.0, "level":16},
	"hospital": {"name":"Hospital", "category":"service", "service_group":"health", "cost":58000, "size":Vector2i(4,2), "population":0, "build_time":9.0, "color":Color(0.18,0.54,0.54), "health":1, "coverage_tiles":24, "pollution":0, "pollution_radius":0.0, "level":16},
	"sewage_small": {"name":"Small Sewage Outflow", "category":"service", "service_group":"sewage", "cost":4000, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.48,0.56,0.39), "sewage":7, "pollution":1, "pollution_radius":10.0, "level":8},
	"sewage_basic": {"name":"Basic Sewage Outflow", "category":"service", "service_group":"sewage", "cost":12000, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.43,0.51,0.38), "sewage":28, "pollution":1, "pollution_radius":12.0, "level":8},
	"sewage_deluxe": {"name":"Deluxe Sewage Treatment Plant", "category":"service", "service_group":"sewage", "cost":35000, "size":Vector2i(2,3), "population":0, "build_time":8.0, "color":Color(0.48,0.68,0.62), "sewage":55, "pollution":0, "pollution_radius":0.0, "level":14},
	"waste_dump_small": {"name":"Small Garbage Dump", "category":"service", "service_group":"waste", "cost":6000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.55,0.48,0.36), "waste":15, "pollution":1, "pollution_radius":10.0, "level":14},
	"waste_dump": {"name":"Garbage Dump", "category":"service", "service_group":"waste", "cost":12000, "size":Vector2i(2,3), "population":0, "build_time":6.0, "color":Color(0.48,0.43,0.35), "waste":31, "pollution":1, "pollution_radius":12.0, "level":14},
	"waste_incinerator": {"name":"Garbage Incinerator", "category":"service", "service_group":"waste", "cost":15000, "size":Vector2i(2,2), "population":0, "build_time":7.0, "color":Color(0.46,0.45,0.43), "waste":40, "pollution":1, "pollution_radius":16.0, "pollution_severity":"heavy", "pollution_label":"Heavy pollution", "level":14},
	"waste_recycling": {"name":"Recycling Center", "category":"service", "service_group":"waste", "cost":60000, "size":Vector2i(3,2), "population":0, "build_time":9.0, "color":Color(0.36,0.72,0.52), "waste":70, "pollution":0, "pollution_radius":0.0, "level":20},
	"town_hall": {"name":"Town Hall", "category":"service", "service_group":"government", "government":1, "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.72,0.68,0.55), "level":1},
	"park_small": {"name":"Small Park", "category":"park", "cost":300, "size":Vector2i(1,1), "population":0, "build_time":3.0, "color":Color(0.35,0.75,0.4), "level":3, "happiness":5}
}

var is_moving: bool = false
var moving_building: Building = null
var moving_original_grid: Vector2i = Vector2i.ZERO
var moving_preview_valid: bool = false
const MOVABLE_BUILDING_TYPES := [
	"residential_1", "residential_villa", "residential_apartment", "residential_farm",
	"building_supplies", "shop_chain", "restaurant_traditional", "fast_food",
	"art_supplies", "hardware_store", "farmers_market", "furniture_store",
	"factory_small", "factory_basic", "factory_mass", "factory_hightech", "factory_nano", "industrial_1", "industrial_2", "industrial_3",
	"power_wind", "power_coal", "power_wind_deluxe", "power_solar", "power_oil", "power_nuclear", "water_tower", "water_pump", "fire_station_small", "fire_station", "fire_station_deluxe", "police_station", "police_small", "police_basic", "police_precinct", "clinic_small", "clinic", "hospital", "sewage_small", "sewage_basic", "sewage_deluxe", "waste_dump_small", "waste_dump", "waste_incinerator", "waste_recycling", "town_hall",
	"park_small"
]

func _ready() -> void:
	print("[BuildManager] Ready: %d building types" % building_types.size())

func can_build_another_factory() -> bool:
	return factory_count < LevelProgression.get_factory_limit_for_level(GameManager.level)

func can_build_factory_type(type_id: String) -> bool:
	if not building_types.has(type_id):
		return false
	var definition: Dictionary = building_types[type_id]
	if str(definition.get("category", "")) != "industrial":
		return true
	return GameManager.population >= int(definition.get("population_required", 0))

func get_factory_type_population_requirement(type_id: String) -> int:
	return int(building_types.get(type_id, {}).get("population_required", 0))

func get_available_buildings(category: String = "") -> Array:
	var result: Array = []
	for key in building_types:
		var definition: Dictionary = building_types[key]
		if bool(definition.get("legacy_only", false)):
			continue
		if int(definition.get("level", 1)) <= GameManager.level and (category == "" or definition.get("category", "") == category):
			if definition.get("category", "") != "industrial" or (can_build_another_factory() and can_build_factory_type(key)):
				result.append(key)
	return result

func select_building(type_id: String) -> void:
	if not building_types.has(type_id):
		push_warning("Unknown building type: " + type_id)
		return
	var definition: Dictionary = building_types[type_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return
	if definition.get("category", "") == "industrial" and (not can_build_another_factory() or not can_build_factory_type(type_id)):
		return
	selected_building_type = type_id
	is_placing = true
	var road_system = get_tree().current_scene.get_node_or_null("World/RoadSystem") if get_tree().current_scene else null
	if road_system:
		road_system.set_road_mode(false)
	placement_mode_changed.emit(true)

func cancel_placement() -> void:
	selected_building_type = ""
	is_placing = false
	placement_mode_changed.emit(false)
	var scene = get_tree().current_scene
	var ghost = scene.get_node_or_null("GhostPreview") if scene else null
	if ghost:
		ghost.hide_ghost()

func get_footprint_cells(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(anchor + Vector2i(x, y))
	return cells

func is_inside_world(anchor: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	return anchor.x >= -WORLD_HALF_CELLS and anchor.y >= -WORLD_HALF_CELLS and anchor.x + size.x <= WORLD_HALF_CELLS and anchor.y + size.y <= WORLD_HALF_CELLS

func is_cell_free(grid_pos: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	if not is_inside_world(grid_pos, size):
		return false
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	for cell in get_footprint_cells(grid_pos, size):
		if road_system and road_system.has_road(cell):
			return false
		if building_cells.has(cell):
			var occupied = building_cells[cell]
			if is_instance_valid(occupied):
				return false
			building_cells.erase(cell)
	return true

func has_road_access(anchor: Vector2i, size: Vector2i) -> bool:
	var scene = get_tree().current_scene
	var road_system = scene.get_node_or_null("World/RoadSystem") if scene else null
	if road_system == null:
		return false
	for x in range(size.x):
		if road_system.has_road(anchor + Vector2i(x, -1)) or road_system.has_road(anchor + Vector2i(x, size.y)):
			return true
	for y in range(size.y):
		if road_system.has_road(anchor + Vector2i(-1, y)) or road_system.has_road(anchor + Vector2i(size.x, y)):
			return true
	return false

func can_place_at(grid_pos: Vector2i, type_id: String = "") -> bool:
	var chosen: String = type_id if type_id != "" else selected_building_type
	if chosen == "" or not building_types.has(chosen):
		return false
	var definition: Dictionary = building_types[chosen]
	var size: Vector2i = definition.get("size", Vector2i(2,2))
	if not is_cell_free(grid_pos, size) or not has_road_access(grid_pos, size):
		return false
	if int(definition.get("level", 1)) > GameManager.level:
		return false
	if not EconomyManager.can_afford(int(definition.get("cost", 0))):
		return false
	if definition.get("category", "") == "industrial" and (not can_build_another_factory() or not can_build_factory_type(chosen)):
		return false
	return true

func can_move_to(grid_pos: Vector2i) -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		return false
	var size: Vector2i = moving_building.definition.get("size", Vector2i(2, 2))
	return is_cell_free(grid_pos, size) and has_road_access(grid_pos, size)

func begin_move(building: Variant) -> bool:
	if is_moving or not is_instance_valid(building) or not (building is Building):
		return false
	var target_building: Building = building as Building
	if not MOVABLE_BUILDING_TYPES.has(target_building.building_type):
		return false
	if buildings.get(target_building.building_id) != target_building:
		return false
	moving_building = target_building
	moving_original_grid = target_building.grid_pos
	for cell in get_footprint_cells(target_building.grid_pos, target_building.definition.get("size", Vector2i(2, 2))):
		if building_cells.get(cell) == target_building:
			building_cells.erase(cell)
	is_moving = true
	moving_preview_valid = false
	target_building.set_move_preview(true, false)
	return true

func preview_move_at(grid_pos: Vector2i) -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		return false
	moving_preview_valid = can_move_to(grid_pos)
	var size: Vector2i = moving_building.definition.get("size", Vector2i(2, 2))
	moving_building.global_position = grid_to_world(grid_pos) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.55, (size.y - 1) * GRID_SIZE * 0.5)
	if moving_building.has_method("set_move_preview"):
		moving_building.set_move_preview(true, moving_preview_valid)
	return moving_preview_valid

func invalidate_move_preview() -> void:
	if not is_moving:
		return
	moving_preview_valid = false
	if is_instance_valid(moving_building) and moving_building.has_method("set_move_preview"):
		moving_building.set_move_preview(true, false)

func finish_move() -> bool:
	if not is_moving or not is_instance_valid(moving_building):
		cancel_move()
		return false
	var building := moving_building
	var target := world_to_grid(Vector3(building.global_position.x - (building.definition.get("size", Vector2i(2, 2)).x - 1) * GRID_SIZE * 0.5, 0.0, building.global_position.z - (building.definition.get("size", Vector2i(2, 2)).y - 1) * GRID_SIZE * 0.5))
	if not moving_preview_valid or not can_move_to(target):
		cancel_move()
		return false
	building.grid_pos = target
	var size: Vector2i = building.definition.get("size", Vector2i(2, 2))
	for cell in get_footprint_cells(target, size):
		building_cells[cell] = building
	building.global_position = grid_to_world(target) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
	if building.has_method("set_move_preview"):
		building.set_move_preview(false, true)
	moving_building = null
	is_moving = false
	moving_preview_valid = false
	ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	return true

func cancel_move() -> void:
	if not is_moving:
		return
	var building := moving_building
	if is_instance_valid(building):
		building.grid_pos = moving_original_grid
		var size: Vector2i = building.definition.get("size", Vector2i(2, 2))
		for cell in get_footprint_cells(moving_original_grid, size):
			building_cells[cell] = building
		building.global_position = grid_to_world(moving_original_grid) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
		if building.has_method("set_move_preview"):
			building.set_move_preview(false, true)
	moving_building = null
	is_moving = false
	moving_preview_valid = false

func move_building_to(building: Node, target: Vector2i) -> bool:
	if not begin_move(building):
		return false
	preview_move_at(target)
	return finish_move()

func place_building_at_world(world_pos: Vector3) -> bool:
	if not is_placing or selected_building_type == "":
		return false
	return place_building(world_to_grid(world_pos))

func place_building(grid_pos: Vector2i, type_id: String = "", saved_stage: int = 1, saved_status: String = "constructing") -> bool:
	var chosen: String = type_id if type_id != "" else selected_building_type
	if not can_place_at(grid_pos, chosen):
		return false
	var definition: Dictionary = building_types[chosen]
	var cost: int = int(definition.get("cost", 0))
	if cost > 0 and not EconomyManager.can_afford(cost):
		return false
	var scene = get_tree().current_scene
	var world = scene.get_node_or_null("World/Buildings") if scene else null
	if world == null:
		push_error("Cannot place building: World/Buildings node is missing.")
		return false
	var building_node = BuildingScene.instantiate()
	if building_node == null:
		return false
	if cost > 0 and not EconomyManager.spend_simoleons(cost):
		building_node.free()
		return false
	var building_id: String = "b_%d_%d" % [Time.get_ticks_msec(), buildings.size()]
	var data: Dictionary = {
		"id": building_id,
		"type": chosen,
		"grid_pos": grid_pos,
		"definition": definition.duplicate(true),
		"status": saved_status,
		"build_time": float(definition.get("build_time", 4.0)),
		"upgrade_stage": clampi(saved_stage, 1, 6)
	}
	world.add_child(building_node)
	var size: Vector2i = definition.get("size", Vector2i(2,2))
	building_node.global_position = grid_to_world(grid_pos) + Vector3((size.x - 1) * GRID_SIZE * 0.5, 0.0, (size.y - 1) * GRID_SIZE * 0.5)
	# Register the node and its complete footprint before setup() can emit
	# construction-complete/service events. This keeps population and happiness
	# recalculation from seeing a temporarily empty city during instant restores.
	buildings[building_id] = building_node
	for occupied_cell in get_footprint_cells(grid_pos, size):
		building_cells[occupied_cell] = building_node
	building_node.setup(data)
	if definition.get("category", "") == "industrial":
		factory_count += 1
	construction_started.emit(building_id)
	building_placed.emit(data)
	GameManager.add_experience(3)
	return true

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(floori(world_pos.x / GRID_SIZE), floori(world_pos.z / GRID_SIZE))

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * GRID_SIZE + GRID_SIZE * 0.5, 0.0, grid_pos.y * GRID_SIZE + GRID_SIZE * 0.5)

func get_selected_size() -> Vector2i:
	if selected_building_type != "" and building_types.has(selected_building_type):
		return building_types[selected_building_type].get("size", Vector2i(2,2))
	return Vector2i(2,2)

func notify_construction_finished(building_id: String) -> void:
	construction_finished.emit(building_id)

func building_at_cell(grid_pos: Vector2i) -> Node:
	var building = building_cells.get(grid_pos)
	if building != null and is_instance_valid(building):
		return building
	if building != null:
		building_cells.erase(grid_pos)
	return null

func unregister_building(building_id: String) -> void:
	var building = buildings.get(building_id)
	if building == null:
		return
	var definition: Dictionary = building.definition
	if building.has_method("set_fire_smoke"):
		building.set_fire_smoke(false)
	var size: Vector2i = definition.get("size", Vector2i(2, 2))
	for cell in get_footprint_cells(building.grid_pos, size):
		if building_cells.get(cell) == building:
			building_cells.erase(cell)
	buildings.erase(building_id)
	if definition.get("category", "") == "industrial":
		factory_count = maxi(0, factory_count - 1)
	# Remove population contributed by completed residential or populated buildings.
	var removed_population := int(building.current_population)
	if removed_population <= 0:
		removed_population = int(definition.get("population", 0))
	if removed_population > 0:
		GameManager.set_population(maxi(0, GameManager.population - removed_population))
	var happiness_bonus := float(definition.get("happiness", 0))
	if happiness_bonus > 0.0:
		GameManager.set_happiness(maxf(0.0, GameManager.happiness - happiness_bonus))
	if has_node("/root/ServiceManager"):
		ServiceManager.recalculate_from_buildings()
	if has_node("/root/FireHazardManager"):
		FireHazardManager.on_city_changed()
	building_removed.emit(building_id)
