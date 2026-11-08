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
	"building_supplies": {"name":"Building Supplies", "category":"commercial", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":1, "recipes":["nails","planks","bricks","cement","glue"]},
	# New commercial menu choices. shop_chain keeps the existing Nails recipe path.
	"shop_chain": {"name":"Chain Store", "category":"commercial", "subtype":"chain", "cost":100, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.35,0.68,0.95), "level":1, "production_slots":1, "recipes":["nails"]},
	"restaurant_traditional": {"name":"Traditional Restaurant", "category":"commercial", "subtype":"restaurant", "cost":400, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.75,0.45,0.30), "level":4, "recipes":[]},
	"fast_food": {"name":"Fast Food", "category":"commercial", "subtype":"fast_food", "cost":350, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.95,0.55,0.20), "level":3, "recipes":[]},
	"art_supplies": {"name":"Art Supplies Store", "category":"commercial", "subtype":"art", "cost":300, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.40,0.75), "level":5, "recipes":[]},
	"hardware_store": {"name":"Hardware Store", "category":"commercial", "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.3,0.55,0.85), "level":4, "production_slots":1, "recipes":["hammer","measuring_tape","shovel","paint"]},
	"farmers_market": {"name":"Farmer's Market", "category":"commercial", "cost":800, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.4,0.75,0.4), "level":8, "production_slots":1, "recipes":["vegetables"]},
	"furniture_store": {"name":"Furniture Store", "category":"commercial", "cost":1200, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.6,0.45,0.3), "level":10, "production_slots":1, "recipes":["chair","table"]},
	"industrial_1": {"name":"Small Factory", "category":"industrial", "cost":0, "size":Vector2i(2,2), "population":0, "build_time":4.0, "color":Color(0.55,0.55,0.6), "produces":"metal", "level":1, "production_slots":2, "can_produce":["metal","wood"]},
	"industrial_2": {"name":"Factory", "category":"industrial", "cost":500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.45,0.45,0.5), "produces":"wood", "level":2, "production_slots":2, "can_produce":["metal","wood"]},
	"industrial_3": {"name":"Factory+", "category":"industrial", "cost":1500, "size":Vector2i(2,2), "population":0, "build_time":6.0, "color":Color(0.4,0.42,0.48), "produces":"plastic", "level":5, "production_slots":2, "can_produce":["metal","wood","plastic"]},
	"power_wind": {"name":"Wind Power", "category":"service", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.7,0.9,0.85), "power":12, "level":1},
	"water_tower": {"name":"Water Tower", "category":"service", "cost":1500, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.45,0.72,0.95), "water":12, "level":1},
	"fire_station": {"name":"Fire Station", "category":"service", "cost":2500, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.92,0.32,0.28), "level":5},
	"police_station": {"name":"Police Station", "category":"service", "cost":3000, "size":Vector2i(2,2), "population":0, "build_time":5.0, "color":Color(0.28,0.42,0.78), "level":12},
	"sewage_pipe": {"name":"Sewage Pipe", "category":"service", "cost":2000, "size":Vector2i(1,1), "population":0, "build_time":4.0, "color":Color(0.5,0.55,0.4), "level":8},
	"park_small": {"name":"Small Park", "category":"park", "cost":300, "size":Vector2i(1,1), "population":0, "build_time":3.0, "color":Color(0.35,0.75,0.4), "level":3, "happiness":5}
}

func _ready() -> void:
	print("[BuildManager] Ready: %d building types" % building_types.size())

func get_available_buildings(category: String = "") -> Array:
	var result: Array = []
	for key in building_types:
		var definition: Dictionary = building_types[key]
		if int(definition.get("level", 1)) <= GameManager.level and (category == "" or definition.get("category", "") == category):
			if definition.get("category", "") != "industrial" or factory_count < LevelProgression.max_factories:
				result.append(key)
	return result

func select_building(type_id: String) -> void:
	if not building_types.has(type_id):
		push_warning("Unknown building type: " + type_id)
		return
	var definition: Dictionary = building_types[type_id]
	if int(definition.get("level", 1)) > GameManager.level:
		return
	if definition.get("category", "") == "industrial" and factory_count >= LevelProgression.max_factories:
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
	if definition.get("category", "") == "industrial" and factory_count >= LevelProgression.max_factories:
		return false
	return true

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
	if cost > 0 and not EconomyManager.spend_simoleons(cost):
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
	var building_node = BuildingScene.instantiate()
	var scene = get_tree().current_scene
	var world = scene.get_node_or_null("World/Buildings") if scene else null
	if world == null:
		push_error("Cannot place building: World/Buildings node is missing.")
		return false
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
	building_removed.emit(building_id)
