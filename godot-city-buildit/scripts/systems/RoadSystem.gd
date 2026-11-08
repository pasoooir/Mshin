extends Node3D

signal road_placed(grid_pos: Vector2i)
signal road_removed(grid_pos: Vector2i)

const GRID_SIZE: float = 2.0
const GRID_HALF: float = GRID_SIZE * 0.5
const ROAD_COST: int = 50
const ROAD_HALF_WIDTH: float = 0.66
const CURB_WIDTH: float = 0.08
const SIDEWALK_WIDTH: float = 0.24
const ROAD_SURFACE_Y: float = 0.04
const ROAD_SURFACE_HEIGHT: float = 0.08
const ROAD_TEXTURE_WORLD_SCALE: float = 8.0

const DIR_UP := Vector2i(0, -1)
const DIR_DOWN := Vector2i(0, 1)
const DIR_LEFT := Vector2i(-1, 0)
const DIR_RIGHT := Vector2i(1, 0)
const CARDINAL_DIRECTIONS: Array[Vector2i] = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]

const TILE_END: String = "end"
const TILE_STRAIGHT: String = "straight"
const TILE_CORNER: String = "corner"
const TILE_T: String = "t_junction"
const TILE_CROSS: String = "cross"

var roads: Dictionary = {}
var road_refresh_counts: Dictionary = {}
var is_road_mode: bool = false

static var _shared_asphalt_material: StandardMaterial3D
static var _shared_sidewalk_material: StandardMaterial3D
static var _shared_curb_material: StandardMaterial3D
static var _shared_yellow_material: StandardMaterial3D
static var _shared_white_material: StandardMaterial3D

func _ready() -> void:
	print("[RoadSystem] Ready")

func set_road_mode(active: bool) -> void:
	is_road_mode = active
	if active:
		BuildManager.cancel_placement()

func seed_starter_access() -> void:
	# Seed the complete two-row starter connector first, then build each tile
	# against the finished neighbor graph so no tile keeps a stale end-cap mesh.
	for x in range(-23, 2):
		for z in [-1, 0]:
			roads[Vector2i(x, z)] = null
	for cell in roads.keys():
		_refresh_road_mesh(cell)

func has_road(grid_pos: Vector2i) -> bool:
	return roads.has(grid_pos)

func get_road_connections(grid_pos: Vector2i) -> Array[Vector2i]:
	var connections: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		if roads.has(grid_pos + direction):
			connections.append(direction)
	return connections

func get_road_tile_kind(grid_pos: Vector2i) -> String:
	var connections := get_road_connections(grid_pos)
	match connections.size():
		0, 1:
			return TILE_END
		2:
			if connections[0] + connections[1] == Vector2i.ZERO:
				return TILE_STRAIGHT
			return TILE_CORNER
		3:
			return TILE_T
		_:
			return TILE_CROSS

func _get_tile_arms(grid_pos: Vector2i) -> Array[Vector2i]:
	var connections := get_road_connections(grid_pos)
	if connections.is_empty():
		return [DIR_UP, DIR_DOWN]
	if connections.size() == 1:
		var direction: Vector2i = connections[0]
		return [direction, -direction]
	return connections

func _has_adjacent_road(grid_pos: Vector2i) -> bool:
	if roads.is_empty():
		return true
	for direction in CARDINAL_DIRECTIONS:
		if roads.has(grid_pos + direction):
			return true
	return false

func get_road_placement_error(grid_pos: Vector2i) -> String:
	if roads.has(grid_pos):
		return "A road already exists on this tile."
	if not BuildManager.is_inside_world(grid_pos):
		return "This tile is outside the buildable city area."
	if not _has_adjacent_road(grid_pos):
		return "Start beside the existing highway or road; roads must connect."
	if not BuildManager.is_cell_free(grid_pos, Vector2i.ONE):
		return "This tile is occupied by a building."
	if not EconomyManager.can_afford(ROAD_COST):
		return "Not enough Simoleons. Each road tile costs 50."
	return ""

func place_road(grid_pos: Vector2i) -> bool:
	if get_road_placement_error(grid_pos) != "":
		return false
	if not EconomyManager.spend_simoleons(ROAD_COST):
		return false
	roads[grid_pos] = null
	_refresh_road_neighborhood(grid_pos)
	road_placed.emit(grid_pos)
	return true

func place_road_at_world(world_pos: Vector3) -> bool:
	return place_road(BuildManager.world_to_grid(world_pos))

func remove_road(grid_pos: Vector2i) -> bool:
	if not roads.has(grid_pos):
		return false
	var road_mesh = roads[grid_pos]
	roads.erase(grid_pos)
	if is_instance_valid(road_mesh):
		road_mesh.queue_free()
	_refresh_road_neighborhood(grid_pos)
	road_removed.emit(grid_pos)
	return true

func _refresh_road_neighborhood(grid_pos: Vector2i) -> void:
	# Connectivity changes can alter the removed/placed tile and each of its
	# four neighbors (for example straight -> T, or corner -> end).
	_refresh_road_mesh(grid_pos)
	for direction in CARDINAL_DIRECTIONS:
		var neighbour: Vector2i = grid_pos + direction
		if roads.has(neighbour):
			_refresh_road_mesh(neighbour)

func _refresh_road_mesh(grid_pos: Vector2i) -> void:
	if not roads.has(grid_pos):
		return
	var old_mesh = roads.get(grid_pos)
	var new_mesh := _create_road_mesh(grid_pos)
	var revision := int(road_refresh_counts.get(grid_pos, 0)) + 1
	road_refresh_counts[grid_pos] = revision
	new_mesh.set_meta("road_tile_kind", get_road_tile_kind(grid_pos))
	new_mesh.set_meta("road_revision", revision)
	add_child(new_mesh)
	new_mesh.position = Vector3(
		float(grid_pos.x) * GRID_SIZE + GRID_HALF,
		0.025,
		float(grid_pos.y) * GRID_SIZE + GRID_HALF
	)
	roads[grid_pos] = new_mesh
	if is_instance_valid(old_mesh):
		old_mesh.queue_free()

func _create_road_mesh(grid_pos: Vector2i) -> Node3D:
	# Headless gameplay tests still exercise the neighbor graph and placement
	# rules without creating renderer resources.
	if DisplayServer.get_name() == "headless":
		return Node3D.new()

	var arms := _get_tile_arms(grid_pos)
	var tile_kind := get_road_tile_kind(grid_pos)
	var asphalt_tool := SurfaceTool.new()
	var marking_tool := SurfaceTool.new()
	var white_marking_tool := SurfaceTool.new()
	var curb_tool := SurfaceTool.new()
	var sidewalk_tool := SurfaceTool.new()
	asphalt_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	marking_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	white_marking_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	curb_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	sidewalk_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var asphalt_boxes := 0
	var marking_boxes := 0
	var white_marking_boxes := 0
	var curb_boxes := 0
	var sidewalk_boxes := 0

	# Build the road surface as connected half-cell arms. A connected
	# perpendicular neighbor expands that side to the tile edge; otherwise
	# the road edge, raised curb and sidewalk occupy the remaining strip.
	for direction in arms:
		var left_direction := Vector2i(-direction.y, direction.x)
		var right_direction := -left_direction
		var left_connected: bool = arms.has(left_direction)
		var right_connected: bool = arms.has(right_direction)
		var left_extent: float = GRID_HALF if left_connected else ROAD_HALF_WIDTH
		var right_extent: float = GRID_HALF if right_connected else ROAD_HALF_WIDTH
		var width: float = left_extent + right_extent
		var side_offset: float = (right_extent - left_extent) * 0.5
		var arm_center_along := _direction_to_world(direction) * 0.5
		var arm_center := arm_center_along + _direction_to_world(right_direction) * side_offset
		var along_x: bool = direction.x != 0
		var road_size := Vector3(1.01, ROAD_SURFACE_HEIGHT, width) if along_x else Vector3(width, ROAD_SURFACE_HEIGHT, 1.01)
		_append_box(asphalt_tool, grid_pos, arm_center + Vector3(0.0, ROAD_SURFACE_Y, 0.0), road_size)
		asphalt_boxes += 1

		for side_direction in [left_direction, right_direction]:
			if arms.has(side_direction):
				continue
			var side_extent: float = left_extent if side_direction == left_direction else right_extent
			var curb_center := arm_center_along + _direction_to_world(side_direction) * (side_extent + CURB_WIDTH * 0.5)
			curb_center.y = 0.09
			var curb_size := Vector3(1.02, 0.14, CURB_WIDTH) if along_x else Vector3(CURB_WIDTH, 0.14, 1.02)
			_append_box(curb_tool, grid_pos, curb_center, curb_size)
			curb_boxes += 1

			var sidewalk_center := arm_center_along + _direction_to_world(side_direction) * (side_extent + CURB_WIDTH + SIDEWALK_WIDTH * 0.5)
			sidewalk_center.y = 0.03
			var sidewalk_size := Vector3(1.02, 0.06, SIDEWALK_WIDTH) if along_x else Vector3(SIDEWALK_WIDTH, 0.06, 1.02)
			_append_box(sidewalk_tool, grid_pos, sidewalk_center, sidewalk_size)
			sidewalk_boxes += 1

	# A dead-end stub receives a transverse curb cap at the unconnected end.
	var connections := get_road_connections(grid_pos)
	if connections.size() <= 1:
		var travel_direction: Vector2i = connections[0] if connections.size() == 1 else DIR_UP
		var cap_direction := -travel_direction
		var cap_center := _direction_to_world(cap_direction) * 0.965
		cap_center.y = 0.09
		var cap_size := Vector3(ROAD_HALF_WIDTH * 2.0, 0.14, CURB_WIDTH) if cap_direction.x != 0 else Vector3(CURB_WIDTH, 0.14, ROAD_HALF_WIDTH * 2.0)
		_append_box(curb_tool, grid_pos, cap_center, cap_size)
		curb_boxes += 1

	_add_road_markings(marking_tool, white_marking_tool, sidewalk_tool, grid_pos, tile_kind, arms)
	marking_boxes = _count_marking_boxes(tile_kind, arms, grid_pos)
	white_marking_boxes = arms.size() * 5 if tile_kind == TILE_CROSS else 0
	if tile_kind == TILE_CROSS:
		sidewalk_boxes += 4

	var road_mesh := ArrayMesh.new()
	_add_surface(road_mesh, asphalt_tool, _get_asphalt_material(), asphalt_boxes)
	_add_surface(road_mesh, marking_tool, _get_yellow_marking_material(), marking_boxes)
	_add_surface(road_mesh, white_marking_tool, _get_white_marking_material(), white_marking_boxes)
	_add_surface(road_mesh, curb_tool, _get_curb_material(), curb_boxes)
	_add_surface(road_mesh, sidewalk_tool, _get_sidewalk_material(), sidewalk_boxes)

	var instance := MeshInstance3D.new()
	instance.name = "Road_%d_%d_%s" % [grid_pos.x, grid_pos.y, tile_kind]
	instance.mesh = road_mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

func _direction_to_world(direction: Vector2i) -> Vector3:
	return Vector3(float(direction.x), 0.0, float(direction.y))

func _append_box(surface_tool: SurfaceTool, grid_pos: Vector2i, center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var faces: Array = [
		[Vector3.UP, [Vector3(-half.x, half.y, -half.z), Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(half.x, half.y, -half.z)]],
		[Vector3.DOWN, [Vector3(-half.x, -half.y, half.z), Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z)]],
		[Vector3.FORWARD, [Vector3(half.x, -half.y, -half.z), Vector3(-half.x, -half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z)]],
		[Vector3.BACK, [Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)]],
		[Vector3.RIGHT, [Vector3(half.x, -half.y, half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(half.x, half.y, half.z)]],
		[Vector3.LEFT, [Vector3(-half.x, -half.y, -half.z), Vector3(-half.x, -half.y, half.z), Vector3(-half.x, half.y, half.z), Vector3(-half.x, half.y, -half.z)]]
	]
	var triangle_indices := [0, 1, 2, 0, 2, 3]
	for face in faces:
		var face_normal: Vector3 = face[0]
		var corners: Array = face[1]
		for index in triangle_indices:
			var point: Vector3 = center + corners[index]
			surface_tool.set_normal(face_normal)
			surface_tool.set_uv(Vector2(
				(float(grid_pos.x) * GRID_SIZE + GRID_HALF + point.x) / ROAD_TEXTURE_WORLD_SCALE,
				(float(grid_pos.y) * GRID_SIZE + GRID_HALF + point.z) / ROAD_TEXTURE_WORLD_SCALE
			))
			surface_tool.add_vertex(point)

func _add_road_markings(surface_tool: SurfaceTool, white_surface_tool: SurfaceTool, sidewalk_surface_tool: SurfaceTool, grid_pos: Vector2i, tile_kind: String, arms: Array[Vector2i]) -> void:
	if tile_kind == TILE_CROSS:
		for direction in arms:
			_add_crosswalk(white_surface_tool, grid_pos, direction)
		# Small raised corner pads keep pedestrian space visually connected
		# through a four-way intersection instead of ending sidewalks abruptly.
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				var corner_center := Vector3(x_side * 0.82, 0.095, z_side * 0.82)
				_append_box(sidewalk_surface_tool, grid_pos, corner_center, Vector3(0.34, 0.06, 0.34))
		return

	if tile_kind == TILE_CORNER:
		for direction in arms:
			_add_arm_center_dashes(surface_tool, grid_pos, direction)
		return

	var main_axis := Vector2i.ZERO
	if arms.has(DIR_LEFT) and arms.has(DIR_RIGHT):
		main_axis = DIR_RIGHT
	elif arms.has(DIR_UP) and arms.has(DIR_DOWN):
		main_axis = DIR_DOWN
	elif tile_kind == TILE_END and not arms.is_empty():
		main_axis = arms[0]
	if main_axis == Vector2i.ZERO:
		return

	if tile_kind == TILE_T:
		# Preserve the through-road centerline but leave a balanced open gap at the junction.
		for side in [-1.0, 1.0]:
			var center: Vector3 = _direction_to_world(main_axis) * (0.72 * float(side))
			center.y = 0.088
			var dash_size := Vector3(0.42, 0.006, 0.045) if main_axis.x != 0 else Vector3(0.045, 0.006, 0.42)
			_append_box(surface_tool, grid_pos, center, dash_size)
	else:
		_add_axis_dashes(surface_tool, grid_pos, main_axis, false)

func _add_axis_dashes(surface_tool: SurfaceTool, grid_pos: Vector2i, axis: Vector2i, leave_center_gap: bool) -> void:
	var grid_coordinate: int = grid_pos.x if axis.x != 0 else grid_pos.y
	var cell_start: float = float(grid_coordinate) * GRID_SIZE
	for offset in range(int(GRID_SIZE)):
		var dash_center_along: float = float(offset) + 0.31
		var local_along: float = cell_start + dash_center_along - (cell_start + GRID_HALF)
		if leave_center_gap and absf(local_along) < 0.42:
			continue
		var center := _direction_to_world(axis) * local_along
		center.y = 0.088
		var dash_size := Vector3(0.50, 0.006, 0.045) if axis.x != 0 else Vector3(0.045, 0.006, 0.50)
		_append_box(surface_tool, grid_pos, center, dash_size)

func _add_arm_center_dashes(surface_tool: SurfaceTool, grid_pos: Vector2i, direction: Vector2i) -> void:
	for distance in [0.43, 0.77]:
		var center := _direction_to_world(direction) * float(distance)
		center.y = 0.088
		var dash_size := Vector3(0.28, 0.006, 0.045) if direction.x != 0 else Vector3(0.045, 0.006, 0.28)
		_append_box(surface_tool, grid_pos, center, dash_size)

func _add_crosswalk(surface_tool: SurfaceTool, grid_pos: Vector2i, direction: Vector2i) -> void:
	var lateral := Vector2i(-direction.y, direction.x)
	for stripe_index in range(5):
		var lateral_offset := (float(stripe_index) - 2.0) * 0.22
		var center := _direction_to_world(direction) * 0.57 + _direction_to_world(lateral) * lateral_offset
		center.y = 0.089
		var stripe_size := Vector3(0.10, 0.006, 0.075) if direction.x != 0 else Vector3(0.075, 0.006, 0.10)
		_append_box(surface_tool, grid_pos, center, stripe_size)

func _count_marking_boxes(tile_kind: String, arms: Array[Vector2i], grid_pos: Vector2i) -> int:
	if tile_kind == TILE_CROSS:
		return 0
	if tile_kind == TILE_CORNER:
		return arms.size() * 2
	if tile_kind == TILE_T:
		return 2
	return 2

func _add_surface(array_mesh: ArrayMesh, surface_tool: SurfaceTool, material: Material, expected_boxes: int) -> void:
	if expected_boxes <= 0:
		return
	var arrays := surface_tool.commit_to_arrays()
	if arrays[Mesh.ARRAY_VERTEX].is_empty():
		return
	var surface_index := array_mesh.get_surface_count()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(surface_index, material)

func _get_asphalt_material() -> StandardMaterial3D:
	if _shared_asphalt_material != null:
		return _shared_asphalt_material
	var texture_pair := _create_asphalt_textures()
	_shared_asphalt_material = StandardMaterial3D.new()
	_shared_asphalt_material.albedo_texture = texture_pair[0]
	_shared_asphalt_material.normal_enabled = true
	_shared_asphalt_material.normal_texture = texture_pair[1]
	_shared_asphalt_material.normal_scale = 0.24
	_shared_asphalt_material.roughness = 0.97
	_shared_asphalt_material.metallic = 0.0
	_shared_asphalt_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _shared_asphalt_material

func _create_asphalt_textures() -> Array[Texture2D]:
	const TEXTURE_SIZE: int = 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			# Integer-frequency trigonometric layers tile seamlessly in both
			# directions, so neighboring road cells never show texture seams.
			var broad := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * 0.55 + cos(angle_y * 2.0 - sin(angle_x * 3.0)) * 0.45
			var medium := sin(angle_x * 7.0 + angle_y * 5.0) * 0.5 + cos(angle_x * 11.0 - angle_y * 9.0) * 0.5
			var grain := sin(angle_x * 37.0 + angle_y * 29.0) * 0.5 + cos(angle_x * 53.0 - angle_y * 47.0) * 0.5
			var fine_grain := sin(angle_x * 83.0 + angle_y * 71.0) * 0.5 + cos(angle_x * 97.0 - angle_y * 89.0) * 0.5
			var aggregate_signal := sin(angle_x * 61.0 + cos(angle_y * 73.0)) * cos(angle_y * 67.0 - sin(angle_x * 59.0))
			var aggregate := 0.025 if aggregate_signal > 0.985 else (-0.025 if aggregate_signal < -0.985 else 0.0)
			var height_value := clampf(0.235 + broad * 0.032 + medium * 0.018 + grain * 0.009 + fine_grain * 0.004 + aggregate, 0.12, 0.34)
			heights[y * TEXTURE_SIZE + x] = height_value
			image.set_pixel(x, y, Color(height_value * 0.92, height_value * 0.96, height_value * 1.02, 1.0))
	var normal_image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var left := heights[y * TEXTURE_SIZE + posmod(x - 1, TEXTURE_SIZE)]
			var right := heights[y * TEXTURE_SIZE + posmod(x + 1, TEXTURE_SIZE)]
			var up := heights[posmod(y - 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var down := heights[posmod(y + 1, TEXTURE_SIZE) * TEXTURE_SIZE + x]
			var dx := (right - left) * 4.0
			var dy := (down - up) * 4.0
			normal_image.set_pixel(x, y, Color(0.5 - dx, 0.5 - dy, 1.0, 1.0))
	image.generate_mipmaps()
	normal_image.generate_mipmaps()
	return [ImageTexture.create_from_image(image), ImageTexture.create_from_image(normal_image)]

func _get_sidewalk_material() -> StandardMaterial3D:
	if _shared_sidewalk_material != null:
		return _shared_sidewalk_material
	_shared_sidewalk_material = StandardMaterial3D.new()
	_shared_sidewalk_material.albedo_color = Color(0.62, 0.63, 0.59)
	_shared_sidewalk_material.roughness = 0.96
	return _shared_sidewalk_material

func _get_curb_material() -> StandardMaterial3D:
	if _shared_curb_material != null:
		return _shared_curb_material
	_shared_curb_material = StandardMaterial3D.new()
	_shared_curb_material.albedo_color = Color(0.72, 0.73, 0.69)
	_shared_curb_material.roughness = 0.94
	return _shared_curb_material

func _get_yellow_marking_material() -> StandardMaterial3D:
	if _shared_yellow_material != null:
		return _shared_yellow_material
	_shared_yellow_material = StandardMaterial3D.new()
	_shared_yellow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_yellow_material.albedo_color = Color(0.96, 0.77, 0.24, 1.0)
	return _shared_yellow_material

func _get_white_marking_material() -> StandardMaterial3D:
	if _shared_white_material != null:
		return _shared_white_material
	_shared_white_material = StandardMaterial3D.new()
	_shared_white_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_white_material.albedo_color = Color(0.92, 0.92, 0.86, 1.0)
	return _shared_white_material

func get_road_count() -> int:
	return roads.size()
