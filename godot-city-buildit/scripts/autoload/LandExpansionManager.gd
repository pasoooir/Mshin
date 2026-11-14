extends Node

signal land_changed

const TILE_CELLS := 8
const MIN_TILE := -5
const MAX_TILE := 4
const MIN_EXPANSION_LEVEL := 10
const INITIAL_TILE_MIN := -3
const INITIAL_TILE_MAX := 2
const EXPANSION_MIN_TILE_X := -3
const EXPANSION_MAX_TILE_X := 2
const EXPANSION_MIN_TILE_Y := -5
const EXPANSION_MAX_TILE_Y := 4
const EXPANSION_ITEM_IDS := ["dozer_wheel", "dozer_blade", "dozer_exhaust"]

var owned_tiles: Dictionary = {}

func _ready() -> void:
	_register_expansion_items()
	if owned_tiles.is_empty():
		_reset_initial_land()

func _register_expansion_items() -> void:
	StorageManager.register_item_definition("dozer_wheel", "Dozer Wheel", "special")
	StorageManager.register_item_definition("dozer_blade", "Dozer Blade", "special")
	StorageManager.register_item_definition("dozer_exhaust", "Dozer Exhaust", "special")

func get_expansion_item_definition(item_id: String) -> Dictionary:
	var names := {
		"dozer_wheel": "Dozer Wheel",
		"dozer_blade": "Dozer Blade",
		"dozer_exhaust": "Dozer Exhaust"
	}
	if not names.has(item_id):
		return {}
	return {"id": item_id, "name": str(names[item_id]), "value": 800, "level": MIN_EXPANSION_LEVEL, "time_sec": 0, "type": "special"}

func _tile_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

func _is_tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= MIN_TILE and tile.x <= MAX_TILE and tile.y >= MIN_TILE and tile.y <= MAX_TILE

func _reset_initial_land() -> void:
	owned_tiles.clear()
	for x in range(INITIAL_TILE_MIN, INITIAL_TILE_MAX + 1):
		for y in range(INITIAL_TILE_MIN, INITIAL_TILE_MAX + 1):
			owned_tiles[_tile_key(Vector2i(x, y))] = true

func get_tile_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(TILE_CELLS)), floori(float(cell.y) / float(TILE_CELLS)))

func is_tile_owned(tile: Vector2i) -> bool:
	return owned_tiles.has(_tile_key(tile))

func is_cell_unlocked(cell: Vector2i) -> bool:
	if cell.x < -40 or cell.x >= 40 or cell.y < -40 or cell.y >= 40:
		return false
	return is_tile_owned(get_tile_for_cell(cell))

func is_cell_road_buildable(cell: Vector2i) -> bool:
	if not is_cell_unlocked(cell):
		return false
	# Reserve the western highway asphalt cells; the permanent Gateway begins
	# at x=-23 and remains restorable, while new city roads cannot overlap it.
	return not (cell.x >= -34 and cell.x <= -22)

func are_cells_unlocked(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	for cell in cells:
		if not is_cell_unlocked(cell):
			return false
	return true

func is_world_position_unlocked(world_position: Vector3) -> bool:
	var cell := Vector2i(floori(world_position.x / BuildManager.GRID_SIZE), floori(world_position.z / BuildManager.GRID_SIZE))
	return is_cell_unlocked(cell)

func _is_adjacent_to_owned(tile: Vector2i) -> bool:
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_tile_owned(tile + direction):
			return true
	return false

func get_available_expansion_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(EXPANSION_MIN_TILE_X, EXPANSION_MAX_TILE_X + 1):
		for y in range(EXPANSION_MIN_TILE_Y, EXPANSION_MAX_TILE_Y + 1):
			var tile := Vector2i(x, y)
			if not is_tile_owned(tile) and _is_adjacent_to_owned(tile):
				result.append(tile)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var cost_a := _distance_from_initial_land(a)
		var cost_b := _distance_from_initial_land(b)
		if cost_a == cost_b:
			return a.y == b.y and a.x < b.x or a.y < b.y
		return cost_a < cost_b
	)
	return result

func _distance_from_initial_land(tile: Vector2i) -> int:
	var dx := maxi(0, maxi(INITIAL_TILE_MIN - tile.x, tile.x - INITIAL_TILE_MAX))
	var dy := maxi(0, maxi(INITIAL_TILE_MIN - tile.y, tile.y - INITIAL_TILE_MAX))
	return maxi(dx, dy)

func get_tile_cost(tile: Vector2i) -> Dictionary:
	var distance := _distance_from_initial_land(tile)
	var variation := absi(tile.x * 7 + tile.y * 11) % 2
	var base := clampi(1 + distance + variation, 1, 6)
	return {
		"dozer_wheel": base,
		"dozer_blade": maxi(1, base + (1 if variation == 0 else 0)),
		"dozer_exhaust": base
	}

func get_tile_error(tile: Vector2i) -> String:
	if not _is_tile_in_bounds(tile):
		return "This land is outside the expansion boundary."
	if tile.x < EXPANSION_MIN_TILE_X or tile.x > EXPANSION_MAX_TILE_X or tile.y < EXPANSION_MIN_TILE_Y or tile.y > EXPANSION_MAX_TILE_Y:
		return "This plot is reserved for the highway corridor or coastline."
	if is_tile_owned(tile):
		return "This land is already part of your city."
	if not _is_adjacent_to_owned(tile):
		return "Expand adjacent land first. New plots must connect to your current city limits."
	if GameManager.level < MIN_EXPANSION_LEVEL:
		return "Reach Mayor Level %d to expand your city." % MIN_EXPANSION_LEVEL
	var cost := get_tile_cost(tile)
	if not StorageManager.has_items(cost):
		var missing: Array[String] = []
		for item_id in EXPANSION_ITEM_IDS:
			var needed := int(cost[item_id])
			var have := StorageManager.get_count(item_id)
			if have < needed:
				var item_definition: Dictionary = StorageManager.item_definitions.get(item_id, {})
				missing.append("%s %d/%d" % [str(item_definition.get("name", item_id)), have, needed])
		return "Missing expansion items: " + " · ".join(PackedStringArray(missing))
	return ""

func can_expand_tile(tile: Vector2i) -> bool:
	return get_tile_error(tile).is_empty()

func expand_tile(tile: Vector2i) -> bool:
	if not can_expand_tile(tile):
		return false
	var cost := get_tile_cost(tile)
	if not StorageManager.remove_items(cost):
		return false
	owned_tiles[_tile_key(tile)] = true
	land_changed.emit()
	return true

func _own_legacy_cell(cell: Vector2i) -> bool:
	if cell.x < -40 or cell.x >= 40 or cell.y < -40 or cell.y >= 40:
		return false
	var tile := get_tile_for_cell(cell)
	if not _is_tile_in_bounds(tile) or is_tile_owned(tile):
		return false
	owned_tiles[_tile_key(tile)] = true
	return true

func migrate_legacy_land(road_data: Array, building_data: Array) -> void:
	# Version 3 saves predate land ownership. Preserve every plot already used
	# by a saved road/building so older cities cannot lose or fail to restore work.
	var changed := false
	for road in road_data:
		if road is Array and road.size() >= 2:
			changed = _own_legacy_cell(Vector2i(int(road[0]), int(road[1]))) or changed
	for saved_building in building_data:
		if not (saved_building is Dictionary):
			continue
		var grid_data: Variant = saved_building.get("grid", [])
		var type_id := str(saved_building.get("type", ""))
		if not (grid_data is Array) or grid_data.size() < 2 or not BuildManager.building_types.has(type_id):
			continue
		var anchor := Vector2i(int(grid_data[0]), int(grid_data[1]))
		var rotation := int(saved_building.get("rotation_quarters", 0))
		var footprint := BuildManager.get_footprint_cells(anchor, BuildManager.get_building_size(type_id, rotation))
		for cell in footprint:
			changed = _own_legacy_cell(cell) or changed
	if changed:
		land_changed.emit()

func get_owned_tile_count() -> int:
	return owned_tiles.size()

func to_save_dict() -> Dictionary:
	var tiles: Array = []
	for key in owned_tiles.keys():
		var parts := str(key).split(":")
		if parts.size() == 2:
			tiles.append([int(parts[0]), int(parts[1])])
	tiles.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]) or int(a[1]) < int(b[1])
	)
	return {"owned_tiles": tiles}

func from_save_dict(data: Dictionary) -> void:
	owned_tiles.clear()
	var saved_tiles: Variant = data.get("owned_tiles", [])
	if not (saved_tiles is Array) or saved_tiles.is_empty():
		_reset_initial_land()
		land_changed.emit()
		return
	for entry in saved_tiles:
		if not (entry is Array) or entry.size() != 2:
			continue
		var tile := Vector2i(int(entry[0]), int(entry[1]))
		if _is_tile_in_bounds(tile):
			owned_tiles[_tile_key(tile)] = true
	if owned_tiles.is_empty():
		_reset_initial_land()
	land_changed.emit()
