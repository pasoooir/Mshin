extends Node3D

var _road_system_cache: Node

const CargoShipVisualScript = preload("res://scripts/world/CargoShipVisual.gd")
const MeadowLivestockScript = preload("res://scripts/world/MeadowLivestock.gd")
const DistantMountainBackdropScript = preload("res://scripts/world/DistantMountainBackdrop.gd")

const TERRAIN_HALF_DEPTH := 90.0
const TERRAIN_LEFT := -90.0
const TERRAIN_DIVISIONS := 96
const CITY_HALF_EXTENT := 40

# Permanent six-lane divided motorway at the city entrance. Keep the access
# opening aligned with the seeded Gateway connector and outside the build grid.
const HIGHWAY_CENTER_X := -55.0
const HIGHWAY_ASPHALT_WIDTH := 24.0
const HIGHWAY_SHOULDER_WIDTH := 26.8
const HIGHWAY_LENGTH := 700.0
const HIGHWAY_LANE_COUNT := 6
const HIGHWAY_MEDIAN_WIDTH := 0.8
const HIGHWAY_LAMP_COUNT := 12
const MEADOW_SHEEP_COUNT := 12
const MEADOW_CATTLE_COUNT := 3
const ENVIRONMENT_SMALL_DETAIL_END := 190.0
const ENVIRONMENT_SMALL_DETAIL_MARGIN := 18.0
const TREE_BELT_DETAIL_END := 280.0
const TREE_BELT_DETAIL_MARGIN := 24.0
const AUSTRALIAN_GRASSLAND_PALETTE := [
	Color("#244D27"), Color("#326334"), Color("#46763A"),
	Color("#1D4525"), Color("#597B3B"), Color("#2D582C")
]

func _ready() -> void:
	# Headless CI validates simulation and placement logic, not GPU geometry.
	# Preserve the stable scene contract with lightweight Node3D markers while
	# skipping all procedural meshes and MultiMesh resources.
	if DisplayServer.get_name() == "headless":
		_add_headless_test_markers()
		print("[WorldPresentation] Procedural visuals skipped in headless test mode")
		return
	RegionManager.region_changed.connect(_on_region_changed)
	LandExpansionManager.land_changed.connect(_on_land_expansion_changed)
	_build_environment()
	_build_terrain()
	var mountain_backdrop := DistantMountainBackdropScript.new()
	mountain_backdrop.name = "DistantMountainBackdrop"
	add_child(mountain_backdrop)
	_build_near_city_rock_outcrops(mountain_backdrop)
	_build_land_expansion_markers()
	_build_city_grid()
	_build_coastal_highway()
	_build_dirt_tracks()
	_build_highway_lighting()
	_build_tree_belts()
	_build_grass_detail()
	_build_meadow_shrubs_and_stones()
	_build_meadow_livestock()
	_build_shoreline_details()
	_build_cargo_ship_visual()
	_build_sunlight()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.34, 0.55)
	sky_material.sky_horizon_color = Color(0.72, 0.84, 0.91)
	sky_material.ground_bottom_color = Color(0.13, 0.19, 0.17)
	sky_material.ground_horizon_color = Color(0.55, 0.63, 0.61)
	_apply_region_climate(sky_material, environment)
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.82)
	environment.fog_density = 0.00065
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world_environment.environment = environment
	add_child(world_environment)


func _apply_region_climate(sky_material: ProceduralSkyMaterial, environment: Environment) -> void:
	var climate := str(RegionManager.get_active_region().get("climate", "temperate"))
	match climate:
		"tropical":
			sky_material.sky_top_color = Color("#176A9A")
			sky_material.sky_horizon_color = Color("#A7DCE7")
			sky_material.ground_bottom_color = Color("#285B4B")
			sky_material.ground_horizon_color = Color("#6C9B84")
			environment.fog_light_color = Color("#A9D5D5")
		"arctic":
			sky_material.sky_top_color = Color("#405A79")
			sky_material.sky_horizon_color = Color("#D4E2EB")
			sky_material.ground_bottom_color = Color("#899BA7")
			sky_material.ground_horizon_color = Color("#C0D0D8")
			environment.fog_light_color = Color("#C4D4DF")
		"desert":
			sky_material.sky_top_color = Color("#9A603A")
			sky_material.sky_horizon_color = Color("#F0C88E")
			sky_material.ground_bottom_color = Color("#8B6B43")
			sky_material.ground_horizon_color = Color("#C7A36B")
			environment.fog_light_color = Color("#E6C89D")
		"lush":
			sky_material.sky_top_color = Color("#226A75")
			sky_material.sky_horizon_color = Color("#B7D9A8")
			sky_material.ground_bottom_color = Color("#244C32")
			sky_material.ground_horizon_color = Color("#6E9860")
			environment.fog_light_color = Color("#B9D4AE")
		"mediterranean":
			sky_material.sky_top_color = Color("#3977A5")
			sky_material.sky_horizon_color = Color("#E8D0A3")
			sky_material.ground_bottom_color = Color("#596342")
			sky_material.ground_horizon_color = Color("#A9A078")
			environment.fog_light_color = Color("#D9D0B7")
		"temperate":
			# Australian coastal grassland: clear blue sky with a warm, green horizon.
			sky_material.sky_top_color = Color("#287BB0")
			sky_material.sky_horizon_color = Color("#B8D9D1")
			sky_material.ground_bottom_color = Color("#315B39")
			sky_material.ground_horizon_color = Color("#83A96F")
			environment.fog_light_color = Color("#C0D8C4")
		_:
			sky_material.sky_top_color = Color("#287BB0")
			sky_material.sky_horizon_color = Color("#B8D9D1")
			sky_material.ground_bottom_color = Color("#315B39")
			sky_material.ground_horizon_color = Color("#83A96F")
			environment.fog_light_color = Color("#C0D8C4")

func _on_region_changed(_region_id: String) -> void:
	refresh_region_appearance()

func refresh_region_appearance() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if is_instance_valid(world_environment) and world_environment.environment != null and world_environment.environment.sky != null:
		var sky_material := world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		if is_instance_valid(sky_material):
			_apply_region_climate(sky_material, world_environment.environment)
	for node_name in ["NaturalTerrain", "CoastalWater", "ShallowWater", "LandExpansionMarkers", "BuildablePlotGrid"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_land_expansion_markers()
	_build_city_grid()


func _on_land_expansion_changed() -> void:
	for node_name in ["NaturalTerrain", "CoastalWater", "ShallowWater", "LandExpansionMarkers", "BuildablePlotGrid"]:
		var old_node := get_node_or_null(node_name)
		if is_instance_valid(old_node):
			old_node.free()
	_build_terrain()
	_build_land_expansion_markers()
	_build_city_grid()


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := TERRAIN_DIVISIONS
	for z_index in range(divisions):
		var z0 := -TERRAIN_HALF_DEPTH + (float(z_index) / divisions) * TERRAIN_HALF_DEPTH * 2.0
		var z1 := -TERRAIN_HALF_DEPTH + (float(z_index + 1) / divisions) * TERRAIN_HALF_DEPTH * 2.0
		var coast0 := _coastline(z0)
		var coast1 := _coastline(z1)
		for x_index in range(divisions):
			var u0 := float(x_index) / divisions
			var u1 := float(x_index + 1) / divisions
			var x00 := lerpf(TERRAIN_LEFT, coast0, u0)
			var x10 := lerpf(TERRAIN_LEFT, coast0, u1)
			var x01 := lerpf(TERRAIN_LEFT, coast1, u0)
			var x11 := lerpf(TERRAIN_LEFT, coast1, u1)
			_add_terrain_vertex(surface, Vector3(x00, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x01, 0.0, z1))
			_add_terrain_vertex(surface, Vector3(x10, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x10, 0.0, z0))
			_add_terrain_vertex(surface, Vector3(x01, 0.0, z1))
			_add_terrain_vertex(surface, Vector3(x11, 0.0, z1))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "NaturalTerrain"
	terrain.mesh = surface.commit()
	var terrain_material := _create_natural_ground_material()
	terrain.material_override = terrain_material
	_request_ground_texture("grass", "https://cdn.meshy.ai/landing-assets/textures/grass/wild-meadow-grass/wild-meadow-grass-2k.jpg", terrain_material)
	_request_ground_texture("sand", "https://cdn.meshy.ai/landing-assets/textures/ground/pitted-sandy-ground/pitted-sandy-ground-2k.jpg", terrain_material)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)

	# Both water bands follow the exact sampled coastline instead of using
	# fixed rectangles. This prevents the new mountain/backdrop geometry from
	# exposing green slivers, burying the beach or cutting the sea at the edges.
	var water := MeshInstance3D.new()
	water.name = "CoastalWater"
	water.mesh = _create_coastal_water_mesh(8.0, 159.0, 96, 12, -0.055)
	water.material_override = _create_water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var shallow_water := MeshInstance3D.new()
	shallow_water.name = "ShallowWater"
	shallow_water.mesh = _create_coastal_water_mesh(0.12, 8.0, 96, 4, -0.025)
	shallow_water.material_override = _create_shallow_water_material()
	shallow_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shallow_water)
	_build_creek_channel()


func _create_coastal_water_mesh(shore_offset: float, far_x: float, rows: int, columns: int, water_y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		var z0 := lerpf(-95.0, 95.0, float(row) / float(rows))
		var z1 := lerpf(-95.0, 95.0, float(row + 1) / float(rows))
		var near_x0 := _coastline(z0) + shore_offset
		var near_x1 := _coastline(z1) + shore_offset
		for column in range(columns):
			var u0 := float(column) / float(columns)
			var u1 := float(column + 1) / float(columns)
			var x00 := lerpf(near_x0, far_x, u0)
			var x10 := lerpf(near_x0, far_x, u1)
			var x01 := lerpf(near_x1, far_x, u0)
			var x11 := lerpf(near_x1, far_x, u1)
			var uv00 := Vector2(u0, float(row) / rows)
			var uv10 := Vector2(u1, float(row) / rows)
			var uv01 := Vector2(u0, float(row + 1) / rows)
			var uv11 := Vector2(u1, float(row + 1) / rows)
			surface.set_uv(uv00)
			surface.add_vertex(Vector3(x00, water_y, z0))
			surface.set_uv(uv01)
			surface.add_vertex(Vector3(x01, water_y, z1))
			surface.set_uv(uv10)
			surface.add_vertex(Vector3(x10, water_y, z0))
			surface.set_uv(uv10)
			surface.add_vertex(Vector3(x10, water_y, z0))
			surface.set_uv(uv01)
			surface.add_vertex(Vector3(x01, water_y, z1))
			surface.set_uv(uv11)
			surface.add_vertex(Vector3(x11, water_y, z1))
	surface.generate_normals()
	return surface.commit()

func _add_terrain_vertex(surface: SurfaceTool, point: Vector3) -> void:
	# Stable world-space texture scale plus restrained relief outside the build grid.
	surface.set_uv(Vector2(point.x * 0.16, point.z * 0.16))
	var coast := _coastline(point.z)
	var broad_noise := sin(point.x * 0.071 + point.z * 0.047) * cos(point.z * 0.083 - point.x * 0.052)
	var fine_noise := sin(point.x * 0.73 + point.z * 0.91) * cos(point.z * 0.67 - point.x * 0.58)
	var blend := clampf((broad_noise * 0.78 + fine_noise * 0.22 + 1.0) * 0.5, 0.0, 1.0)
	var color: Color
	if point.x > coast - 7.0:
		color = Color("#927B59").lerp(Color("#D0B987"), blend)
	elif point.x > coast - 13.0:
		color = Color("#587744").lerp(Color("#B1A16C"), blend * 0.58)
	else:
		var palette_index := int(abs(floor(point.x * 0.31 + point.z * 0.19))) % AUSTRALIAN_GRASSLAND_PALETTE.size()
		color = AUSTRALIAN_GRASSLAND_PALETTE[palette_index].lerp(Color("#A0A15B"), blend * 0.12)
		if fine_noise > 0.58:
			color = color.lerp(Color("#315F31"), 0.13)
		elif fine_noise < -0.62:
			color = color.lerp(Color("#8E9C50"), 0.10)
	# Exposed stony patches and dry sediment break up the former continuous green carpet.
	var rock_field := sin(point.x * 0.105 + point.z * 0.071) * cos(point.z * 0.137 - point.x * 0.063)
	var scree_mask := smoothstep(0.48, 0.82, rock_field) * smoothstep(18.0, 52.0, absf(point.z))
	color = color.lerp(Color("#777365"), scree_mask * 0.38)
	var climate := str(RegionManager.get_active_region().get("climate", "temperate"))
	match climate:
		"arctic":
			color = color.lerp(Color("#DCE7EC"), 0.72)
		"desert":
			color = color.lerp(Color("#B58B55"), 0.68)
		"tropical":
			color = color.lerp(Color("#2F6F43"), 0.30)
		"lush":
			color = color.lerp(Color("#3E783C"), 0.42)
		"mediterranean":
			color = color.lerp(Color("#8C875B"), 0.38)
	var in_east_pasture := point.x >= -42.0 and point.x <= 44.0
	var in_west_pasture := point.x >= -90.0 and point.x <= -69.0
	if absf(point.z) >= 80.0 and absf(point.z) <= 90.0 and (in_east_pasture or in_west_pasture):
		color = color.lerp(Color("#B4A36F"), 0.24)
	if not LandExpansionManager.is_world_position_unlocked(point):
		color = color.lerp(Color("#36523A"), 0.12)
	var terrain_point := point
	terrain_point.y = _terrain_height(point.x, point.z)
	surface.set_color(color)
	surface.add_vertex(terrain_point)


func _terrain_height(x: float, z: float) -> float:
	# The initial owned city is 48 x 48 m. Keep it level, then blend into
	# visible rolling grassland immediately outside its true boundary.
	if absf(x - HIGHWAY_CENTER_X) < 14.0:
		return 0.0
	var distance_from_city := maxf(absf(x) - 24.0, absf(z) - 24.0)
	var relief_mask := smoothstep(-1.0, 9.0, distance_from_city)
	var broad := sin(x * 0.071 + z * 0.049) * 1.15
	var cross := cos(z * 0.113 - x * 0.087) * 0.58
	var rolling := sin(x * 0.19 - z * 0.16) * cos(z * 0.21 + x * 0.13) * 0.24
	var fine := sin(x * 0.61 + z * 0.47) * 0.10
	var natural_relief := (broad + cross + rolling + fine) * relief_mask
	# The last 14 m of beach gently settle to the sea datum. The water mesh
	# begins just offshore, so neither land nor ocean floats above the other.
	var beach_fade := smoothstep(0.0, 14.0, _coastline(z) - x)
	return natural_relief * beach_fade

func _coastline(z: float) -> float:
	return 51.0 + sin(z * 0.045) * 2.2 + cos(z * 0.021) * 1.1


func _build_land_expansion_markers() -> void:
	var tiles := LandExpansionManager.get_available_expansion_tiles()
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for tile in tiles:
		var x0 := float(tile.x * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z0 := float(tile.y * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var x1 := x0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z1 := z0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var corners := [Vector3(x0, 0.055, z0), Vector3(x1, 0.055, z0), Vector3(x1, 0.055, z1), Vector3(x0, 0.055, z1)]
		for edge in range(4):
			lines.set_color(Color(1.0, 0.76, 0.30, 0.86))
			lines.add_vertex(corners[edge])
			lines.add_vertex(corners[(edge + 1) % 4])
	var marker := MeshInstance3D.new()
	marker.name = "LandExpansionMarkers"
	marker.mesh = lines.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
	add_child(marker)

func _build_city_grid() -> void:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	for tile in LandExpansionManager.get_owned_tiles():
		var x0 := float(tile.x * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z0 := float(tile.y * LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var x1 := x0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		var z1 := z0 + float(LandExpansionManager.TILE_CELLS) * BuildManager.GRID_SIZE
		for cell_step in range(0, LandExpansionManager.TILE_CELLS + 1, 4):
			var x := x0 + float(cell_step) * BuildManager.GRID_SIZE
			var z := z0 + float(cell_step) * BuildManager.GRID_SIZE
			lines.set_color(Color(0.72, 0.82, 0.68, 0.30))
			lines.add_vertex(Vector3(x, 0.035, z0))
			lines.add_vertex(Vector3(x, 0.035, z1))
			lines.add_vertex(Vector3(x0, 0.035, z))
			lines.add_vertex(Vector3(x1, 0.035, z))
	var grid_instance := MeshInstance3D.new()
	grid_instance.name = "BuildablePlotGrid"
	grid_instance.mesh = lines.commit()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.vertex_color_use_as_albedo = true
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.no_depth_test = false
	grid_instance.material_override = grid_material
	add_child(grid_instance)


func _build_coastal_highway() -> void:
	# The highway is a permanent landmark, not a buildable city road. Its
	# carriageways, shoulders, median and connector are deliberately separate.
	var shoulder := MeshInstance3D.new()
	shoulder.name = "HighwayShoulder"
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(HIGHWAY_SHOULDER_WIDTH, 0.08, HIGHWAY_LENGTH)
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(HIGHWAY_CENTER_X, 0.11, 0.0)
	var shoulder_material := StandardMaterial3D.new()
	shoulder_material.albedo_color = Color("#777D79")
	shoulder_material.roughness = 1.0
	shoulder.material_override = shoulder_material
	add_child(shoulder)

	var highway := MeshInstance3D.new()
	highway.name = "CoastalHighway"
	var highway_mesh := BoxMesh.new()
	highway_mesh.size = Vector3(HIGHWAY_ASPHALT_WIDTH, 0.16, HIGHWAY_LENGTH)
	highway_mesh.subdivide_width = 2
	highway_mesh.subdivide_depth = 32
	highway.mesh = highway_mesh
	highway.position = Vector3(HIGHWAY_CENTER_X, 0.075, 0.0)
	var highway_asphalt := _create_asphalt_material()
	highway_asphalt.uv1_scale = Vector3(12.0, 96.0, 1.0)
	highway.material_override = highway_asphalt
	highway.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(highway)

	# Contrasting shoulder strips sit just inside the asphalt edge and are
	# batched into one draw call for mobile rendering.
	var shoulder_strip_mesh := BoxMesh.new()
	shoulder_strip_mesh.size = Vector3(1.45, 0.012, HIGHWAY_LENGTH - 2.0)
	var shoulder_strips := MultiMesh.new()
	shoulder_strips.transform_format = MultiMesh.TRANSFORM_3D
	shoulder_strips.mesh = shoulder_strip_mesh
	shoulder_strips.instance_count = 2
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		shoulder_strips.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(HIGHWAY_CENTER_X + side * 10.25, 0.163, 0.0)))
	var shoulder_strip_instance := MultiMeshInstance3D.new()
	shoulder_strip_instance.name = "HighwayShoulderStrips"
	shoulder_strip_instance.multimesh = shoulder_strips
	var shoulder_strip_material := StandardMaterial3D.new()
	shoulder_strip_material.albedo_color = Color("#A0A4A0")
	shoulder_strip_material.roughness = 1.0
	shoulder_strip_instance.material_override = shoulder_strip_material
	add_child(shoulder_strip_instance)

	# Three lanes in each direction. Four dashed separators are one MultiMesh,
	# not 124 individual MeshInstance3D nodes.
	_add_highway_lane_dashes()
	for edge_x in [HIGHWAY_CENTER_X - 11.35, HIGHWAY_CENTER_X + 11.35]:
		_add_road_marking(Vector3(edge_x, 0.164, 0.0), Vector3(0.12, 0.012, HIGHWAY_LENGTH - 2.0), Color("#E8ECE8"))
	for shoulder_line_x in [HIGHWAY_CENTER_X - 9.7, HIGHWAY_CENTER_X + 9.7]:
		_add_road_marking(Vector3(shoulder_line_x, 0.164, 0.0), Vector3(0.10, 0.012, HIGHWAY_LENGTH - 2.0), Color("#DDE2DE"))
	for median_line_x in [HIGHWAY_CENTER_X - 0.52, HIGHWAY_CENTER_X + 0.52]:
		_add_road_marking(Vector3(median_line_x, 0.164, 0.0), Vector3(0.085, 0.012, HIGHWAY_LENGTH - 2.0), Color("#F2C84B"))

	# Concrete median is interrupted only at the city access crossing.
	var median_mesh := BoxMesh.new()
	median_mesh.size = Vector3(HIGHWAY_MEDIAN_WIDTH, 0.56, HIGHWAY_LENGTH)
	var median_multimesh := MultiMesh.new()
	median_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	median_multimesh.mesh = median_mesh
	median_multimesh.instance_count = 2
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.48))
		median_multimesh.set_instance_transform(index, Transform3D(basis, Vector3(HIGHWAY_CENTER_X, 0.435, side * 178.0)))
	var median := MultiMeshInstance3D.new()
	median.name = "HighwayConcreteMedian"
	median.multimesh = median_multimesh
	var median_material := StandardMaterial3D.new()
	median_material.albedo_color = Color("#AEB3AF")
	median_material.roughness = 0.94
	median.material_override = median_material
	median.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(median)

	# One batched guardrail mesh: continuous on the outer edge and opened on
	# the city-facing side so the connector and sidewalks remain unobstructed.
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.14, 0.58, HIGHWAY_LENGTH)
	var rails := MultiMesh.new()
	rails.transform_format = MultiMesh.TRANSFORM_3D
	rails.mesh = rail_mesh
	rails.instance_count = 3
	rails.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(HIGHWAY_CENTER_X - 13.35, 0.46, 0.0)))
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.48))
		rails.set_instance_transform(index + 1, Transform3D(basis, Vector3(HIGHWAY_CENTER_X + 13.35, 0.46, side * 49.5)))
	var guardrails := MultiMeshInstance3D.new()
	guardrails.name = "HighwayGuardrails"
	guardrails.multimesh = rails
	var guardrail_material := StandardMaterial3D.new()
	guardrail_material.albedo_color = Color("#C0C6C8")
	guardrail_material.metallic = 0.62
	guardrail_material.roughness = 0.48
	guardrails.material_override = guardrail_material
	guardrails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(guardrails)

	# The existing sidewalks stop at the access opening, preserving the city
	# pedestrian edge while avoiding a floating strip across the carriageway.
	_add_sidewalk_segment(-49.5, 91.0)
	_add_sidewalk_segment(49.5, 91.0)

	var access_road := MeshInstance3D.new()
	access_road.name = "HighwayCityConnector"
	var access_mesh := BoxMesh.new()
	access_mesh.size = Vector3(52.5, 0.16, 8.0)
	access_mesh.subdivide_width = 4
	access_mesh.subdivide_depth = 2
	access_road.mesh = access_mesh
	access_road.position = Vector3(-42.75, 0.095, 0.0)
	var connector_asphalt := highway_asphalt.duplicate() as StandardMaterial3D
	connector_asphalt.uv1_scale = Vector3(24.0, 5.0, 1.0)
	access_road.material_override = connector_asphalt
	access_road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(access_road)
	_request_matching_asphalt_texture(highway_asphalt, connector_asphalt)


func _request_matching_asphalt_texture(highway_material: StandardMaterial3D, connector_material: StandardMaterial3D) -> void:
	var request := HTTPRequest.new()
	request.name = "SharedAsphaltTextureRequest"
	request.timeout = 12.0
	add_child(request)
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not body.is_empty():
			var image := Image.new()
			if image.load_jpg_from_buffer(body) == OK:
				image.generate_mipmaps()
				var texture := ImageTexture.create_from_image(image)
				highway_material.albedo_texture = texture
				connector_material.albedo_texture = texture
			else:
				push_warning("[WorldPresentation] Asphalt CDN image invalid; matching local fallback retained")
		else:
			push_warning("[WorldPresentation] Asphalt CDN unavailable; matching local fallback retained")
		request.queue_free()
	)
	if request.request("https://cdn.meshy.ai/landing-assets/textures/concrete/smooth-grey-asphalt/smooth-grey-asphalt-2k.jpg") != OK:
		request.queue_free()


func _build_highway_lighting() -> void:
	# Twelve full-size motorway luminaires, batched by geometry to keep the
	# permanent landmark inexpensive on mobile GPUs.
	var pole_positions: Array[Vector3] = []
	var arm_positions: Array[Vector3] = []
	var head_positions: Array[Vector3] = []
	var emitter_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var pole_x: float = HIGHWAY_CENTER_X + float(side) * 14.8
		var inward: float = -float(side)
		for z in [-70.0, -42.0, -14.0, 14.0, 42.0, 70.0]:
			pole_positions.append(Vector3(pole_x, 4.2, z))
			arm_positions.append(Vector3(pole_x + inward * 1.35, 7.95, z))
			head_positions.append(Vector3(pole_x + inward * 2.55, 7.88, z))
			emitter_positions.append(Vector3(pole_x + inward * 2.55, 7.77, z))

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.075
	pole_mesh.bottom_radius = 0.14
	pole_mesh.height = 8.4
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color("#59636A")
	pole_material.metallic = 0.72
	pole_material.roughness = 0.42
	var poles := _make_world_multimesh("MotorwayLightPoles", pole_mesh, pole_positions, pole_material)
	poles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.8, 0.13, 0.13)
	var arm_material := StandardMaterial3D.new()
	arm_material.albedo_color = Color("#69747A")
	arm_material.metallic = 0.68
	arm_material.roughness = 0.44
	var arms := _make_world_multimesh("MotorwayLightArms", arm_mesh, arm_positions, arm_material)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.95, 0.18, 0.52)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("#343D42")
	head_material.metallic = 0.38
	head_material.roughness = 0.5
	var heads := _make_world_multimesh("MotorwayLuminaireHousings", head_mesh, head_positions, head_material)
	var emitter_mesh := BoxMesh.new()
	emitter_mesh.size = Vector3(0.70, 0.035, 0.34)
	var emitter_material := StandardMaterial3D.new()
	emitter_material.albedo_color = Color("#F7E9B7")
	emitter_material.emission_enabled = true
	emitter_material.emission = Color("#F4DFA2")
	emitter_material.emission_energy_multiplier = 0.35
	var emitters := _make_world_multimesh("MotorwayLuminairePanels", emitter_mesh, emitter_positions, emitter_material)

	var lighting_root := Node3D.new()
	lighting_root.name = "HighwayLighting"
	add_child(lighting_root)
	for component in [poles, arms, heads, emitters]:
		lighting_root.add_child(component)


func _make_world_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	return instance


func _add_highway_lane_dashes() -> void:
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.09, 0.012, 3.0)
	var lane_positions: Array[Vector3] = []
	for lane_x in [
		HIGHWAY_CENTER_X - 6.6, HIGHWAY_CENTER_X - 3.3,
		HIGHWAY_CENTER_X + 3.3, HIGHWAY_CENTER_X + 6.6
	]:
		for segment in range(-55, 56):
			lane_positions.append(Vector3(lane_x, 0.164, float(segment) * 6.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dash_mesh
	multimesh.instance_count = lane_positions.size()
	for index in range(lane_positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, lane_positions[index]))
	var markings := MultiMeshInstance3D.new()
	markings.name = "HighwayLaneDashes"
	markings.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#E9ECE8")
	markings.material_override = material
	add_child(markings)


func _add_sidewalk_segment(center_z: float, length_z: float) -> void:
	var sidewalk := MeshInstance3D.new()
	sidewalk.name = "RoadsideSidewalk"
	var sidewalk_mesh := BoxMesh.new()
	sidewalk_mesh.size = Vector3(1.05, 0.12, length_z)
	sidewalk.mesh = sidewalk_mesh
	sidewalk.position = Vector3(-42.92, 0.075, center_z)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.57, 0.59, 0.56)
	concrete.roughness = 1.0
	sidewalk.material_override = concrete
	add_child(sidewalk)

	var curb := MeshInstance3D.new()
	curb.name = "RoadsideCurb"
	var curb_mesh := BoxMesh.new()
	curb_mesh.size = Vector3(0.18, 0.20, length_z)
	curb.mesh = curb_mesh
	curb.position = Vector3(-43.53, 0.12, center_z)
	var curb_material := StandardMaterial3D.new()
	curb_material.albedo_color = Color(0.73, 0.75, 0.70)
	curb_material.roughness = 0.95
	curb.material_override = curb_material
	add_child(curb)

func _add_road_marking(position: Vector3, size: Vector3, color: Color) -> void:
	var marking := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	marking.mesh = mesh
	marking.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marking.material_override = material
	add_child(marking)

func _build_tree_belts() -> void:
	var positions: Array[Vector3] = []
	for x in [-84.0, -76.0, -62.0, -48.0, -30.0, -14.0, 8.0, 26.0, 42.0]:
		positions.append(Vector3(x, _terrain_height(x, -68.0), -68.0 + sin(x * 0.1) * 4.0))
		positions.append(Vector3(x + 3.0, _terrain_height(x, 68.0), 68.0 + cos(x * 0.12) * 4.0))
	for z in [-78.0, -56.0, -34.0, 28.0, 52.0, 76.0]:
		positions.append(Vector3(-78.0 + sin(z * 0.7) * 3.0, _terrain_height(-78.0, z), z))
		positions.append(Vector3(43.0 + sin(z * 0.08) * 2.0, _terrain_height(43.0, z), z))
	# Extra irregular gum trees create a broken, natural edge rather than a fence-like row.
	for index in range(20):
		var x := -74.0 + fposmod(float(index) * 17.3, 116.0)
		var z := -58.0 + fposmod(float(index) * 29.1, 116.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 15.0 or x > _coastline(z) - 14.0 or _is_city_road_footprint(x, z):
			continue
		positions.append(Vector3(x, _terrain_height(x, z), z))

	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.24
	root_mesh.bottom_radius = 0.34
	root_mesh.height = 0.16
	var bark_material := StandardMaterial3D.new()
	bark_material.vertex_color_use_as_albedo = true
	bark_material.albedo_texture = _create_bark_texture()
	bark_material.roughness = 1.0
	root_mesh.material = bark_material
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.8
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = bark_material
	var canopy_mesh := _create_clustered_canopy_mesh()
	var canopy_material := StandardMaterial3D.new()
	canopy_material.vertex_color_use_as_albedo = true
	canopy_material.albedo_texture = _create_foliage_texture()
	canopy_material.roughness = 0.96
	var tree_shadows := _create_tree_shadow_multimesh(positions)
	add_child(tree_shadows)
	var roots := _create_tree_multimesh("TreeRootBases", root_mesh, positions, 0.08)
	var trunks := _create_tree_multimesh("TreeTrunks", trunk_mesh, positions, 1.40)
	var crowns := _create_tree_multimesh("TreeCanopies", canopy_mesh, positions, 2.85)
	crowns.material_override = canopy_material
	add_child(roots)
	add_child(trunks)
	add_child(crowns)

func _create_clustered_canopy_mesh() -> ArrayMesh:
	# Low-poly ellipsoids intersect deliberately to form a single coherent
	# broadleaf crown. The mesh is authored once and instanced across the belt.
	var lobe := SphereMesh.new()
	lobe.radius = 1.0
	lobe.height = 1.9
	lobe.radial_segments = 16
	lobe.rings = 10
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.0, 0.0), Vector3(1.00, 0.82, 0.92)],
		[Vector3(-0.68, -0.12, 0.02), Vector3(0.72, 0.70, 0.78)],
		[Vector3(0.66, -0.08, 0.08), Vector3(0.76, 0.72, 0.82)],
		[Vector3(0.02, 0.12, -0.66), Vector3(0.78, 0.74, 0.70)],
		[Vector3(-0.04, 0.18, 0.64), Vector3(0.76, 0.76, 0.72)],
		[Vector3(0.02, 0.68, -0.02), Vector3(0.66, 0.72, 0.66)]
	]
	for lobe_data in lobes:
		var offset: Vector3 = lobe_data[0]
		var scale: Vector3 = lobe_data[1]
		var transform := Transform3D(Basis.IDENTITY.scaled(scale), offset)
		surface.append_from(lobe, 0, transform)
	return surface.commit()


func _tree_instance_transform(index: int, position: Vector3, height_offset: float) -> Transform3D:
	# Gentle individual lean, variable trunk/crown proportions and asymmetry.
	var scale := 0.88 + float((index * 7) % 7) * 0.095
	var width_variation := 0.82 + float((index * 3) % 6) * 0.085
	var height_variation := 0.82 + float((index * 7) % 6) * 0.105
	var depth_variation := 0.78 + float((index * 11) % 6) * 0.10
	var yaw := float((index * 37) % 360) * PI / 180.0
	var lean := deg_to_rad(-9.0 + float((index * 13) % 19))
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	basis = basis.scaled(Vector3(scale * width_variation, scale * height_variation, scale * depth_variation))
	var origin := position + Vector3(0.0, height_offset * scale * height_variation, 0.0)
	return Transform3D(basis, origin)

func _create_tree_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], height_offset: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.use_colors = true
	multimesh.instance_count = positions.size()
	var trunk_palette: Array[Color] = [
		Color(0.43, 0.27, 0.16), Color(0.52, 0.34, 0.21),
		Color(0.36, 0.23, 0.15), Color(0.58, 0.39, 0.25)
	]
	var root_palette: Array[Color] = [
		Color(0.42, 0.29, 0.19), Color(0.50, 0.35, 0.23),
		Color(0.36, 0.25, 0.17), Color(0.55, 0.39, 0.26)
	]
	var foliage_palette: Array[Color] = [
		Color(0.39, 0.59, 0.43), Color(0.47, 0.64, 0.49),
		Color(0.55, 0.66, 0.48), Color(0.31, 0.52, 0.43),
		Color(0.62, 0.70, 0.54), Color(0.42, 0.57, 0.45)
	]
	for index in range(positions.size()):
		multimesh.set_instance_transform(index, _tree_instance_transform(index, positions[index], height_offset))
		if node_name == "TreeCanopies":
			multimesh.set_instance_color(index, foliage_palette[index % foliage_palette.size()])
		elif node_name == "TreeTrunks":
			multimesh.set_instance_color(index, trunk_palette[index % trunk_palette.size()])
		else:
			multimesh.set_instance_color(index, root_palette[index % root_palette.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	# The tree belt already has one batched, soft contact-shadow pass. Rendering
	# every root/trunk/canopy into the directional shadow map multiplies shadow
	# caster work without a visible quality gain at the camera's normal distance.
	# Keep the detailed geometry and its baked-style contact shadows; skip only
	# the three redundant real-time shadow-caster batches.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = TREE_BELT_DETAIL_END
	instance.visibility_range_end_margin = TREE_BELT_DETAIL_MARGIN
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return instance


func _create_tree_shadow_multimesh(positions: Array[Vector3]) -> MultiMeshInstance3D:
	# One batched radial alpha mesh gives each tree a soft, stable contact shadow.
	# It is deliberately unlit and does not cast shadows, so the mobile cost is one draw.
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var p := Vector2((float(x) + 0.5) / 63.0 * 2.0 - 1.0, (float(y) + 0.5) / 63.0 * 2.0 - 1.0)
			var radius := p.length()
			var alpha := 0.0
			if radius < 1.0:
				alpha = pow(1.0 - radius * radius, 2.2) * 0.62
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var shadow_texture := ImageTexture.create_from_image(image)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.albedo_color = Color(0.13, 0.105, 0.075, 0.34)
	shadow_material.albedo_texture = shadow_texture
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow_material.no_depth_test = false
	shadow_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(3.8, 2.8)
	shadow_mesh.material = shadow_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shadow_mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		var scale := 0.82 + float((index * 7) % 5) * 0.09
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] + Vector3(0.0, 0.018, 0.0)))
	var shadows := MultiMeshInstance3D.new()
	shadows.name = "TreeContactShadows"
	shadows.multimesh = multimesh
	shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadows.visibility_range_end = TREE_BELT_DETAIL_END
	shadows.visibility_range_end_margin = TREE_BELT_DETAIL_MARGIN
	shadows.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return shadows


func _create_bark_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var grain := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
			var ridge := 0.5 + 0.5 * sin(float(x) * 0.82 + sin(float(y) * 0.19) * 1.4)
			var shade := clampf(0.70 + ridge * 0.20 + grain * 0.10, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)


func _create_foliage_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var broad := sin(float(x) * 0.31 + float(y) * 0.17) * cos(float(y) * 0.27 - float(x) * 0.13)
			var fine := fposmod(sin(float(x) * 91.7 + float(y) * 37.3) * 19341.7, 1.0)
			var shade := clampf(0.76 + broad * 0.12 + fine * 0.12, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)


# Procedural textures are generated locally at startup: no CDN, external asset or runtime download.
func _create_grass_texture() -> Texture2D:
	# Subtle green/olive mottling and sparse dry-grass flecks modulate the
	# vertex palette. This is a small local tile, not a flat green overlay.
	const TEXTURE_SIZE := 128
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			var broad := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * cos(angle_y * 2.0 - sin(angle_x * 3.0))
			var fine := sin(angle_x * 31.0 + angle_y * 23.0) * 0.5 + cos(angle_x * 43.0 - angle_y * 37.0) * 0.5
			var speckle := sin(angle_x * 79.0 + cos(angle_y * 67.0)) * cos(angle_y * 71.0 - sin(angle_x * 83.0))
			var value := clampf(0.66 + broad * 0.10 + fine * 0.055, 0.42, 0.82)
			var green := clampf(value * 1.16 + 0.035, 0.0, 1.0)
			var blue := clampf(value * 0.72, 0.0, 1.0)
			var texel := Color(value * 0.88, green, blue, 1.0)
			if speckle > 0.975:
				texel = texel.lerp(Color("#B0A16A"), 0.18)
			image.set_pixel(x, y, texel)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)



func _create_natural_ground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float coastline = 51.0 + sin(world_position.z * 0.045) * 2.2 + cos(world_position.z * 0.021) * 1.1;
	float transition_noise = sin(world_position.z * 0.19 + world_position.x * 0.07) * 1.4;
	float sand_mask = smoothstep(coastline - 7.5 + transition_noise, coastline + 1.5 + transition_noise, world_position.x);
	vec2 ground_uv = UV * 0.62;
	vec3 meadow = texture(grass_texture, ground_uv).rgb * COLOR.rgb;
	vec3 sand = texture(sand_texture, ground_uv * 0.46).rgb * COLOR.rgb;
	ALBEDO = mix(meadow, sand, sand_mask);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_texture", _create_grass_texture())
	material.set_shader_parameter("sand_texture", _create_sand_texture())
	return material


func _create_sand_texture() -> Texture2D:
	const TEXTURE_SIZE := 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			# Periodic multi-scale grain keeps the fallback seamless at tile edges.
			var dune := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * 0.5 + cos(angle_y * 2.0 - sin(angle_x * 3.0)) * 0.5
			var grain := sin(angle_x * 31.0 + angle_y * 23.0) * 0.5 + cos(angle_x * 43.0 - angle_y * 37.0) * 0.5
			var fine := sin(angle_x * 79.0 + cos(angle_y * 67.0)) * cos(angle_y * 71.0 - sin(angle_x * 83.0))
			var value := clampf(0.68 + dune * 0.055 + grain * 0.035 + fine * 0.018, 0.54, 0.82)
			image.set_pixel(x, y, Color(value * 1.0, value * 0.91, value * 0.73, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _request_ground_texture(slot: String, url: String, material: ShaderMaterial) -> void:
	var request := HTTPRequest.new()
	request.name = "GroundTextureRequest_" + slot
	request.timeout = 12.0
	add_child(request)
	request.request_completed.connect(_on_ground_texture_received.bind(material, slot, request))
	var error := request.request(url)
	if error != OK:
		request.queue_free()
		push_warning("[WorldPresentation] CDN texture request could not start for " + slot)


func _on_ground_texture_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, material: ShaderMaterial, slot: String, request: HTTPRequest) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not body.is_empty():
		var image := Image.new()
		var error := image.load_jpg_from_buffer(body)
		if error == OK:
			image.generate_mipmaps()
			material.set_shader_parameter(slot + "_texture", ImageTexture.create_from_image(image))
		else:
			push_warning("[WorldPresentation] Invalid CDN image for " + slot + "; procedural fallback retained")
	else:
		push_warning("[WorldPresentation] CDN unavailable for " + slot + "; procedural fallback retained")
	request.queue_free()

func _create_asphalt_material() -> StandardMaterial3D:
	# Medium charcoal-gray asphalt with several scales of aggregate grain.
	# Periodic noise layers keep the texture seamless across the long motorway.
	const TEXTURE_SIZE := 256
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y in range(TEXTURE_SIZE):
		var angle_y := TAU * float(y) / float(TEXTURE_SIZE)
		for x in range(TEXTURE_SIZE):
			var angle_x := TAU * float(x) / float(TEXTURE_SIZE)
			var broad := sin(angle_x * 2.0 + cos(angle_y * 3.0)) * 0.55 + cos(angle_y * 2.0 - sin(angle_x * 3.0)) * 0.45
			var medium := sin(angle_x * 7.0 + angle_y * 5.0) * 0.5 + cos(angle_x * 11.0 - angle_y * 9.0) * 0.5
			var grain := sin(angle_x * 37.0 + angle_y * 29.0) * 0.5 + cos(angle_x * 53.0 - angle_y * 47.0) * 0.5
			var fine_grain := sin(angle_x * 83.0 + angle_y * 71.0) * 0.5 + cos(angle_x * 97.0 - angle_y * 89.0) * 0.5
			var aggregate_signal := sin(angle_x * 61.0 + cos(angle_y * 73.0)) * cos(angle_y * 67.0 - sin(angle_x * 59.0))
			var aggregate := 0.018 if aggregate_signal > 0.985 else (-0.018 if aggregate_signal < -0.985 else 0.0)
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
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.normal_enabled = true
	material.normal_texture = ImageTexture.create_from_image(normal_image)
	material.normal_scale = 0.24
	material.roughness = 0.97
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

func _create_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 deep_color : source_color = vec4(0.015, 0.20, 0.38, 1.0);
uniform vec4 blue_color : source_color = vec4(0.035, 0.43, 0.62, 1.0);
uniform vec4 turquoise_color : source_color = vec4(0.12, 0.67, 0.70, 1.0);
uniform float wave_height = 0.11;
varying vec3 world_position;
void vertex() {
	vec3 p = VERTEX;
	float wave_a = sin((p.x * 0.22) + (p.z * 0.12) + TIME * 1.15);
	float wave_b = cos((p.x * 0.11) - (p.z * 0.19) + TIME * 0.82);
	p.y += (wave_a * 0.55 + wave_b * 0.45) * wave_height;
	VERTEX = p;
	world_position = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}
void fragment() {
	float bands = sin(world_position.x * 0.075 + world_position.z * 0.045 + TIME * 0.45);
	float depth_mix = smoothstep(-0.9, 0.9, bands);
	vec3 water_color = mix(deep_color.rgb, blue_color.rgb, depth_mix);
	float turquoise = smoothstep(0.25, 0.95, sin(world_position.x * 0.035 + world_position.z * 0.018));
	water_color = mix(water_color, turquoise_color.rgb, turquoise * 0.42);
	float ripple = pow(max(0.0, sin(world_position.x * 0.62 + world_position.z * 0.18 + TIME * 1.8)), 18.0);
	ALBEDO = water_color + vec3(ripple * 0.16);
	ROUGHNESS = 0.22;
	METALLIC = 0.08;
	SPECULAR = 0.72;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _create_shallow_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
void fragment() {
	float ripple = sin(UV.x * 42.0 + TIME * 1.2) * cos(UV.y * 17.0 - TIME * 0.7);
	vec3 lagoon = mix(vec3(0.10, 0.56, 0.62), vec3(0.25, 0.76, 0.73), ripple * 0.18 + 0.35);
	ALBEDO = lagoon;
	ROUGHNESS = 0.3;
	SPECULAR = 0.65;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _is_city_road_footprint(x: float, z: float) -> bool:
	# RoadSystem is a scene node, not an autoload singleton. Resolve it from
	# the active scene once, then reuse the reference for scatter placement.
	var cell := Vector2i(floori(x / BuildManager.GRID_SIZE), floori(z / BuildManager.GRID_SIZE))
	if not is_instance_valid(_road_system_cache):
		var scene := get_tree().current_scene
		if scene == null:
			return false
		_road_system_cache = scene.find_child("RoadSystem", true, false)
	if not is_instance_valid(_road_system_cache) or not _road_system_cache.has_method("has_road"):
		return false
	return bool(_road_system_cache.call("has_road", cell))

func _build_grass_detail() -> void:
	# Each instance is a multi-blade tussock, not a single rectangular stalk.
	var blade_mesh := _create_meadow_grass_clump_mesh()
	var blade_material := StandardMaterial3D.new()
	blade_material.vertex_color_use_as_albedo = true
	blade_material.roughness = 0.98
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var positions: Array[Vector3] = []
	for index in range(2400):
		var x := -88.0 + fposmod(float(index) * 19.37, 132.0)
		var z := -88.0 + fposmod(float(index) * 31.73, 176.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or _is_city_road_footprint(x, z):
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 5.0 or x > _coastline(z) - 13.0:
			continue
		positions.append(Vector3(x, _terrain_height(x, z) + 0.025, z))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade_mesh
	multimesh.instance_count = positions.size()
	var grass_palette: Array[Color] = [
		Color("#426C35"), Color("#71934A"), Color("#A0A05A"),
		Color("#557D43"), Color("#879B58"), Color("#355D35")
	]
	for index in range(positions.size()):
		var scale := 0.72 + float((index * 13) % 11) * 0.09
		var tilt := deg_to_rad(-12.0 + float((index * 7) % 25))
		var yaw := float(index % 12) * 0.5236
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), tilt)
		basis = basis.scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index]))
		multimesh.set_instance_color(index, grass_palette[index % grass_palette.size()])
	var grass := MultiMeshInstance3D.new()
	grass.name = "ColorfulGrassDetail"
	grass.multimesh = multimesh
	grass.material_override = blade_material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	grass.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(grass)


func _create_meadow_grass_clump_mesh() -> ArrayMesh:
	# Five crossed tapered blades give every instance a readable tuft silhouette.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade_index in range(5):
		var angle := TAU * float(blade_index) / 5.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-direction.z, 0.0, direction.x)
		var blade_height := 0.78 + float((blade_index * 7) % 4) * 0.13
		var lean := direction * (0.18 + float(blade_index % 3) * 0.07)
		var base := Vector3.ZERO
		var tip := lean + Vector3(0.0, blade_height, 0.0)
		var left := base - tangent * 0.085
		var right := base + tangent * 0.085
		var color := Color("#4B7439").lerp(Color("#91A956"), float(blade_index) * 0.09)
		surface.set_color(color)
		surface.add_vertex(left)
		surface.add_vertex(right)
		surface.add_vertex(tip)
		surface.add_vertex(tip)
		surface.add_vertex(right)
		surface.add_vertex(left)
	surface.generate_normals()
	return surface.commit()

func _build_meadow_livestock() -> void:
	# Livestock stays in two sandy grazing strips beyond the playable city boundary.
	# The controller refuses asphalt, connected roads and any land later unlocked by the player.
	var sheep_positions: Array[Vector3] = []
	for index in range(MEADOW_SHEEP_COUNT):
		var column := index % 6
		var north := index < 6
		var x := -34.0 + float(column) * 13.2
		if index < 3:
			x = -84.0 + float(index) * 5.0
		var z := -85.0 if north else 85.0
		sheep_positions.append(Vector3(x, 0.0, z))
	var cattle_positions: Array[Vector3] = [
		Vector3(-80.0, 0.0, -85.0), Vector3(1.0, 0.0, 85.0), Vector3(27.0, 0.0, -85.0)
	]

	var flock := MeadowLivestockScript.new()
	flock.name = "MeadowLivestock"
	flock.configure(sheep_positions, cattle_positions)
	add_child(flock)

	var wool_mesh := SphereMesh.new()
	wool_mesh.radius = 0.76
	wool_mesh.height = 1.35
	var wool_material := StandardMaterial3D.new()
	wool_material.albedo_color = Color("#F0EBDD")
	wool_material.roughness = 0.98
	var sheep_bodies := _make_world_multimesh("SheepWoolBodies", wool_mesh, _animal_body_positions(sheep_positions, 0.88), wool_material)
	flock.add_child(sheep_bodies)
	_register_livestock_part(flock, sheep_bodies, sheep_positions.size(), 0, [Vector3(0.0, 0.88, 0.0)])

	var tuft_mesh := SphereMesh.new()
	tuft_mesh.radius = 0.31
	tuft_mesh.height = 0.58
	var tuft_positions: Array[Vector3] = []
	for origin in sheep_positions:
		for offset in [Vector3(-0.28, 1.15, -0.34), Vector3(0.20, 1.18, -0.32), Vector3(-0.28, 1.16, 0.34), Vector3(0.22, 1.18, 0.34)]:
			tuft_positions.append(origin + offset)
	var tufts := _make_world_multimesh("SheepWoolTufts", tuft_mesh, tuft_positions, wool_material)
	flock.add_child(tufts)
	_register_livestock_part(flock, tufts, sheep_positions.size(), 0, [Vector3(-0.28, 1.15, -0.34), Vector3(0.20, 1.18, -0.32), Vector3(-0.28, 1.16, 0.34), Vector3(0.22, 1.18, 0.34)])

	var sheep_head_mesh := SphereMesh.new()
	sheep_head_mesh.radius = 0.30
	sheep_head_mesh.height = 0.66
	var sheep_head_material := StandardMaterial3D.new()
	sheep_head_material.albedo_color = Color("#514A40")
	sheep_head_material.roughness = 0.92
	var sheep_heads := _make_world_multimesh("SheepHeads", sheep_head_mesh, _animal_head_positions(sheep_positions, 0.92), sheep_head_material)
	flock.add_child(sheep_heads)
	_register_livestock_part(flock, sheep_heads, sheep_positions.size(), 0, [Vector3(0.68, 0.92, 0.0)])

	var sheep_leg_mesh := CylinderMesh.new()
	sheep_leg_mesh.top_radius = 0.055
	sheep_leg_mesh.bottom_radius = 0.075
	sheep_leg_mesh.height = 0.62
	var leg_material := StandardMaterial3D.new()
	leg_material.albedo_color = Color("#4A4037")
	leg_material.roughness = 0.95
	var leg_offsets: Array[Vector3] = [Vector3(-0.42, 0.32, -0.42), Vector3(-0.42, 0.32, 0.42), Vector3(0.42, 0.32, -0.42), Vector3(0.42, 0.32, 0.42)]
	var sheep_legs := _make_world_multimesh("SheepLegs", sheep_leg_mesh, _animal_leg_positions(sheep_positions, 0.32), leg_material)
	flock.add_child(sheep_legs)
	_register_livestock_part(flock, sheep_legs, sheep_positions.size(), 0, leg_offsets, true)

	var cow_body_mesh := SphereMesh.new()
	cow_body_mesh.radius = 0.95
	cow_body_mesh.height = 1.55
	var cow_material := StandardMaterial3D.new()
	cow_material.albedo_color = Color("#E8E2D5")
	cow_material.roughness = 0.98
	var cow_bodies := _make_world_multimesh("CattleBodies", cow_body_mesh, _animal_body_positions(cattle_positions, 1.02), cow_material)
	flock.add_child(cow_bodies)
	_register_livestock_part(flock, cow_bodies, cattle_positions.size(), sheep_positions.size(), [Vector3(0.0, 1.02, 0.0)])

	var patch_mesh := SphereMesh.new()
	patch_mesh.radius = 0.43
	patch_mesh.height = 0.18
	var patch_material := StandardMaterial3D.new()
	patch_material.albedo_color = Color("#574333")
	patch_material.roughness = 1.0
	var patch_positions: Array[Vector3] = []
	for origin in cattle_positions:
		patch_positions.append(origin + Vector3(0.10, 1.16, -0.56))
		patch_positions.append(origin + Vector3(-0.34, 1.15, 0.48))
	var patches := _make_world_multimesh("CattleCoatPatches", patch_mesh, patch_positions, patch_material)
	flock.add_child(patches)
	_register_livestock_part(flock, patches, cattle_positions.size(), sheep_positions.size(), [Vector3(0.10, 1.16, -0.56), Vector3(-0.34, 1.15, 0.48)])

	var cow_head_mesh := SphereMesh.new()
	cow_head_mesh.radius = 0.38
	cow_head_mesh.height = 0.72
	var cow_head_material := StandardMaterial3D.new()
	cow_head_material.albedo_color = Color("#6B5140")
	cow_head_material.roughness = 0.96
	var cow_heads := _make_world_multimesh("CattleHeads", cow_head_mesh, _animal_head_positions(cattle_positions, 1.02), cow_head_material)
	flock.add_child(cow_heads)
	_register_livestock_part(flock, cow_heads, cattle_positions.size(), sheep_positions.size(), [Vector3(0.68, 1.02, 0.0)])

	var cow_legs := _make_world_multimesh("CattleLegs", sheep_leg_mesh, _animal_leg_positions(cattle_positions, 0.36), leg_material)
	flock.add_child(cow_legs)
	_register_livestock_part(flock, cow_legs, cattle_positions.size(), sheep_positions.size(), leg_offsets, true)


func _register_livestock_part(flock: Node3D, instance: MultiMeshInstance3D, animal_count: int, owner_offset: int, local_offsets: Array[Vector3], animate_legs: bool = false) -> void:
	var owners: Array[int] = []
	var offsets: Array[Vector3] = []
	for animal_index in range(animal_count):
		for local_offset in local_offsets:
			owners.append(owner_offset + animal_index)
			offsets.append(local_offset)
	flock.call("register_part", instance, owners, offsets, animate_legs)


func _animal_body_positions(origins: Array[Vector3], height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		result.append(origin + Vector3(0.0, height, 0.0))
	return result


func _animal_head_positions(origins: Array[Vector3], height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		result.append(origin + Vector3(0.68, height, 0.0))
	return result


func _animal_leg_positions(origins: Array[Vector3], body_height: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for origin in origins:
		for offset in [Vector3(-0.42, 0.32, -0.42), Vector3(-0.42, 0.32, 0.42), Vector3(0.42, 0.32, -0.42), Vector3(0.42, 0.32, 0.42)]:
			result.append(origin + offset)
	return result


func _build_near_city_rock_outcrops(backdrop: Node3D) -> void:
	# Twelve fractured sandstone outcrops sit just beyond the initial 48 m
	# buildable square, inside the normal city-camera footprint.
	var rock_mesh := backdrop.call("_create_rock_outcrop_mesh") as ArrayMesh
	var rock_material := backdrop.call("_create_rock_surface_material") as ShaderMaterial
	var anchors: Array[Vector2] = [
		Vector2(-18.0, -27.0), Vector2(-6.0, -27.0), Vector2(6.0, -27.0), Vector2(18.0, -27.0),
		Vector2(-18.0, 27.0), Vector2(-6.0, 27.0), Vector2(6.0, 27.0), Vector2(18.0, 27.0),
		Vector2(27.0, -18.0), Vector2(27.0, -6.0), Vector2(27.0, 6.0), Vector2(27.0, 18.0)
	]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = rock_mesh
	batch.instance_count = anchors.size()
	var palette: Array[Color] = [Color("#827B69"), Color("#A09278"), Color("#69675D"), Color("#8D806B")]
	for index in range(anchors.size()):
		var anchor := anchors[index]
		var size := 2.30 + float((index * 5) % 4) * 0.30
		var scale := Vector3(size * 0.92, size * (1.10 + float(index % 3) * 0.12), size * 0.86)
		var yaw := float(index * 47 % 360) * PI / 180.0
		var position := Vector3(anchor.x, _terrain_height(anchor.x, anchor.y) + 0.12, anchor.y)
		batch.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw).scaled(scale), position))
		batch.set_instance_color(index, palette[index % palette.size()])
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "NearCityFracturedRockBatch"
	rocks.multimesh = batch
	rocks.material_override = rock_material
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocks.visibility_range_end = TREE_BELT_DETAIL_END
	rocks.visibility_range_end_margin = TREE_BELT_DETAIL_MARGIN
	rocks.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(rocks)

func _build_dirt_tracks() -> void:
	# Three eroded dirt spurs peel away from the motorway into the outer meadow.
	# All ribbons share one vertex-colored surface and one draw call.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var starts: Array[float] = [-69.0, -5.0, 67.0]
	var finishes: Array[float] = [-48.0, 22.0, 46.0]
	for road_index in range(3):
		var previous_left := Vector3.ZERO
		var previous_right := Vector3.ZERO
		for step in range(29):
			var t := float(step) / 28.0
			var x := lerpf(HIGHWAY_CENTER_X, -17.0 + float(road_index) * 1.5, t)
			var z := lerpf(starts[road_index], finishes[road_index], t) + sin(t * PI) * (float(road_index) - 1.0) * 7.0
			var width := 2.25 - t * 0.55 + sin(t * PI * 4.0 + float(road_index)) * 0.16
			var center_y := _terrain_height(x, z) + 0.055
			var left := Vector3(x, center_y + 0.012, z - width)
			var right := Vector3(x, center_y + 0.012, z + width)
			if step > 0:
				var tint := 0.82 + 0.12 * sin(float(step * 7 + road_index * 11))
				var dust := Color(0.43, 0.34, 0.23) * tint
				var edge := Color(0.30, 0.27, 0.20) * tint
				surface.set_color(edge)
				surface.set_uv(Vector2(float(step) * 0.4, 0.0))
				surface.add_vertex(previous_left)
				surface.set_color(dust)
				surface.set_uv(Vector2(float(step) * 0.4, 1.0))
				surface.add_vertex(previous_right)
				surface.set_color(dust)
				surface.set_uv(Vector2(float(step) * 0.4 + 0.4, 0.0))
				surface.add_vertex(left)
				surface.set_color(dust)
				surface.add_vertex(left)
				surface.add_vertex(previous_right)
				surface.set_color(edge)
				surface.add_vertex(right)
			previous_left = left
			previous_right = right
	surface.generate_normals()
	var roads := MeshInstance3D.new()
	roads.name = "NaturalDirtTracks"
	roads.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	roads.material_override = material
	roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roads)


func _build_creek_channel() -> void:
	# A shallow incised creek: lowered bed, sloped eroded banks and a separate
	# narrow water ribbon. It is real cross-section geometry, not a flat plane.
	var bank_surface := SurfaceTool.new()
	bank_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_surface := SurfaceTool.new()
	water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 44
	var offsets: Array[float] = [-4.0, -2.0, -1.05, 1.05, 2.0, 4.0]
	for step in range(STEPS):
		var z0 := -84.0 + float(step) / float(STEPS - 1) * 168.0
		var z1 := -84.0 + float(step + 1) / float(STEPS - 1) * 168.0
		var x0 := 36.0 + sin(z0 * 0.045) * 2.0
		var x1 := 36.0 + sin(z1 * 0.045) * 2.0
		var heights: Array[float] = [0.01, -0.18, -0.73, -0.73, -0.18, 0.01]
		for band in range(offsets.size() - 1):
			var p00 := Vector3(x0 + offsets[band], _terrain_height(x0 + offsets[band], z0) + heights[band], z0)
			var p01 := Vector3(x1 + offsets[band], _terrain_height(x1 + offsets[band], z1) + heights[band], z1)
			var p10 := Vector3(x0 + offsets[band + 1], _terrain_height(x0 + offsets[band + 1], z0) + heights[band + 1], z0)
			var p11 := Vector3(x1 + offsets[band + 1], _terrain_height(x1 + offsets[band + 1], z1) + heights[band + 1], z1)
			var sediment := Color("#756448") if band == 0 or band == 4 else Color("#574B39")
			bank_surface.set_color(sediment)
			bank_surface.add_vertex(p00)
			bank_surface.add_vertex(p01)
			bank_surface.add_vertex(p10)
			bank_surface.set_color(Color("#8C7955") if band == 1 or band == 3 else sediment)
			bank_surface.add_vertex(p10)
			bank_surface.add_vertex(p01)
			bank_surface.add_vertex(p11)
		var water_y0 := _terrain_height(x0, z0) - 0.43 + sin(z0 * 0.24) * 0.025
		var water_y1 := _terrain_height(x1, z1) - 0.43 + sin(z1 * 0.24) * 0.025
		water_surface.set_color(Color("#2E8D9A"))
		water_surface.add_vertex(Vector3(x0 - 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x1 - 0.92, water_y1, z1))
		water_surface.add_vertex(Vector3(x0 + 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x0 + 0.92, water_y0, z0))
		water_surface.add_vertex(Vector3(x1 - 0.92, water_y1, z1))
		water_surface.add_vertex(Vector3(x1 + 0.92, water_y1, z1))
	bank_surface.generate_normals()
	water_surface.generate_normals()
	var banks := MeshInstance3D.new()
	banks.name = "ErodedCreekBanksAndBed"
	banks.mesh = bank_surface.commit()
	var bank_material := StandardMaterial3D.new()
	bank_material.vertex_color_use_as_albedo = true
	bank_material.roughness = 1.0
	banks.material_override = bank_material
	banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(banks)
	var water := MeshInstance3D.new()
	water.name = "MeadowCreekWater"
	water.mesh = water_surface.commit()
	water.material_override = _create_water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_build_creek_rock_edges()


func _build_creek_rock_edges() -> void:
	# One low-poly stone mesh, instanced along both eroded creek banks.
	var stone := SphereMesh.new()
	stone.radius = 1.0
	stone.height = 1.0
	stone.radial_segments = 7
	stone.rings = 4
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = stone
	batch.instance_count = 104
	var palette: Array[Color] = [Color("#777568"), Color("#A09278"), Color("#5E625A"), Color("#88765D")]
	for index in range(104):
		var z := -82.0 + float(index) * 1.58
		var center_x := 36.0 + sin(z * 0.045) * 2.0
		var side := -1.0 if index % 2 == 0 else 1.0
		var size := 0.20 + float((index * 7) % 6) * 0.075
		var x := center_x + side * (2.1 + float(index % 3) * 0.65)
		var scale := Vector3(size * (1.0 + float(index % 3) * 0.25), size * 0.48, size * 0.72)
		var basis := Basis(Vector3.UP, float(index * 47 % 360) * PI / 180.0).scaled(scale)
		batch.set_instance_transform(index, Transform3D(basis, Vector3(x, _terrain_height(x, z) + 0.05, z)))
		batch.set_instance_color(index, palette[index % palette.size()])
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "CreekBankStoneBatch"
	rocks.multimesh = batch
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	rocks.material_override = material
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocks.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	rocks.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	rocks.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(rocks)


func _build_meadow_shrubs_and_stones() -> void:
	# Scrub is concentrated around the city perimeter as well as the outer meadow.
	var shrub_mesh := _create_meadow_shrub_mesh()
	var shrub_batch := MultiMesh.new()
	shrub_batch.transform_format = MultiMesh.TRANSFORM_3D
	shrub_batch.use_colors = true
	shrub_batch.mesh = shrub_mesh
	var shrub_positions: Array[Vector3] = []
	for index in range(260):
		var x := -87.0 + fposmod(float(index) * 23.71, 130.0)
		var z := -86.0 + fposmod(float(index) * 37.19, 172.0)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 15.0 or x > _coastline(z) - 14.0:
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 6.0 or _is_city_road_footprint(x, z):
			continue
		shrub_positions.append(Vector3(x, _terrain_height(x, z) + 0.85, z))
	# A deterministic broken ring keeps larger scrub visible from the city camera.
	for index in range(72):
		var angle := TAU * float(index) / 72.0
		var radius := 27.5 + sin(float(index) * 2.7) * 1.3
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if absf(x - HIGHWAY_CENTER_X) < 16.0 or x > _coastline(z) - 15.0 or _is_city_road_footprint(x, z):
			continue
		var creek_x := 36.0 + sin(z * 0.045) * 2.0
		if absf(x - creek_x) < 6.0:
			continue
		shrub_positions.append(Vector3(x, _terrain_height(x, z) + 0.9, z))
	shrub_batch.instance_count = shrub_positions.size()
	var shrub_palette: Array[Color] = [Color("#456A3C"), Color("#71834B"), Color("#536F52"), Color("#8B9256"), Color("#3D6046")]
	for index in range(shrub_positions.size()):
		var size := 0.88 + float((index * 11) % 9) * 0.105
		var yaw := float(index * 31 % 360) * PI / 180.0
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size * 1.25, size, size * 0.92))
		shrub_batch.set_instance_transform(index, Transform3D(basis, shrub_positions[index]))
		shrub_batch.set_instance_color(index, shrub_palette[index % shrub_palette.size()])
	var shrubs := MultiMeshInstance3D.new()
	shrubs.name = "AustralianMeadowScrub"
	shrubs.multimesh = shrub_batch
	var shrub_material := StandardMaterial3D.new()
	shrub_material.vertex_color_use_as_albedo = true
	shrub_material.roughness = 1.0
	shrubs.material_override = shrub_material
	shrubs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shrubs.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	shrubs.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	shrubs.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(shrubs)

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 1.0
	stone_mesh.height = 1.0
	stone_mesh.radial_segments = 7
	stone_mesh.rings = 4
	var stone_batch := MultiMesh.new()
	stone_batch.transform_format = MultiMesh.TRANSFORM_3D
	stone_batch.use_colors = true
	stone_batch.mesh = stone_mesh
	var stone_positions: Array[Vector3] = []
	for index in range(220):
		var x := -88.0 + fposmod(float(index) * 29.31, 134.0)
		var z := -87.0 + fposmod(float(index) * 41.17, 174.0)
		if absf(x) < 25.0 and absf(z) < 25.0:
			continue
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or x > _coastline(z) - 10.0 or _is_city_road_footprint(x, z):
			continue
		stone_positions.append(Vector3(x, _terrain_height(x, z) + 0.12, z))
	for index in range(96):
		var angle := TAU * float(index) / 96.0
		var radius := 25.5 + float(index % 4) * 1.5
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if absf(x - HIGHWAY_CENTER_X) < 14.0 or x > _coastline(z) - 10.0 or _is_city_road_footprint(x, z):
			continue
		stone_positions.append(Vector3(x, _terrain_height(x, z) + 0.12, z))
	stone_batch.instance_count = stone_positions.size()
	var stone_palette: Array[Color] = [Color("#77766A"), Color("#9B8D75"), Color("#62665E"), Color("#8B795F")]
	for index in range(stone_positions.size()):
		var size := 0.18 + float((index * 5) % 8) * 0.095
		var basis := Basis(Vector3.UP, float(index * 53 % 360) * PI / 180.0).scaled(Vector3(size * 1.25, size * 0.48, size * 0.88))
		stone_batch.set_instance_transform(index, Transform3D(basis, stone_positions[index]))
		stone_batch.set_instance_color(index, stone_palette[index % stone_palette.size()])
	var stones := MultiMeshInstance3D.new()
	stones.name = "MeadowFieldstoneBatch"
	stones.multimesh = stone_batch
	var stone_material := StandardMaterial3D.new()
	stone_material.vertex_color_use_as_albedo = true
	stone_material.roughness = 1.0
	stones.material_override = stone_material
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stones.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	stones.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	stones.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(stones)

func _create_meadow_shrub_mesh() -> ArrayMesh:
	# Three irregular intersecting leaf masses make a readable scrub silhouette.
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.8
	sphere.radial_segments = 8
	sphere.rings = 5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.72, 0.78, 0.70)), Vector3.ZERO))
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.58, 0.60, 0.56)), Vector3(-0.48, -0.12, 0.10)))
	surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.62, 0.68, 0.58)), Vector3(0.43, -0.08, -0.18)))
	return surface.commit()



func _build_shoreline_details() -> void:
	# One low-poly MultiMesh replaces 38 independent pebble nodes/materials.
	# Per-instance scale, yaw and color preserve the varied natural shoreline.
	var pebbles := _create_shoreline_pebble_multimesh()
	add_child(pebbles)


func _create_shoreline_pebble_multimesh() -> MultiMeshInstance3D:
	const PEBBLE_COUNT := 38
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 1.0
	pebble_mesh.height = 2.0
	pebble_mesh.radial_segments = 10
	pebble_mesh.rings = 5
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = pebble_mesh
	multimesh.instance_count = PEBBLE_COUNT
	for index in range(PEBBLE_COUNT):
		multimesh.set_instance_transform(index, _shoreline_pebble_transform(index))
		multimesh.set_instance_color(index, _shoreline_pebble_color(index))
	var pebble_material := StandardMaterial3D.new()
	pebble_material.vertex_color_use_as_albedo = true
	pebble_material.roughness = 0.95
	var pebbles := MultiMeshInstance3D.new()
	pebbles.name = "ShorelinePebbleBatch"
	pebbles.multimesh = multimesh
	pebbles.material_override = pebble_material
	# Small ground stones add no useful cast shadows; disabling them saves mobile shadow work.
	pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pebbles.visibility_range_end = ENVIRONMENT_SMALL_DETAIL_END
	pebbles.visibility_range_end_margin = ENVIRONMENT_SMALL_DETAIL_MARGIN
	pebbles.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return pebbles


func _shoreline_pebble_transform(index: int) -> Transform3D:
	var z := -88.0 + float(index) * 4.6
	var x := _coastline(z) - 1.8 + sin(float(index) * 4.1) * 1.8
	var radius := 0.28 + float(index % 3) * 0.09
	var yaw := float((index * 41) % 360) * PI / 180.0
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(radius, 0.11, radius * (0.82 + float(index % 4) * 0.06)))
	return Transform3D(basis, Vector3(x, 0.05, z))


func _shoreline_pebble_color(index: int) -> Color:
	var stone_palette: Array[Color] = [
		Color(0.55, 0.53, 0.46),
		Color(0.69, 0.65, 0.55),
		Color(0.42, 0.46, 0.43)
	]
	return stone_palette[index % stone_palette.size()]

func _build_cargo_ship_visual() -> void:
	var ship := CargoShipVisualScript.new()
	ship.name = "CargoShipVisual"
	add_child(ship)

func _build_sunlight() -> void:
	add_child(_create_warm_fill_light())


func _create_warm_fill_light() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "CoastalWarmSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.70)
	sun.light_energy = 0.34
	# The main scene's key DirectionalLight3D owns the single shadow map.
	# This warm secondary light remains as a soft fill, but must not allocate a
	# second directional shadow map or create conflicting duplicate shadows.
	sun.shadow_enabled = false
	sun.light_specular = 0.35
	return sun


func _add_headless_test_markers() -> void:
	# These names are part of the smoke-test scene contract; they intentionally
	# contain no MeshInstance3D nodes and therefore allocate no render meshes.
	for marker_name in ["NaturalTerrain", "DistantMountainBackdrop", "CoastalWater", "BuildablePlotGrid", "LandExpansionMarkers", "CoastalHighway", "HighwayLighting", "MeadowLivestock", "CargoShipVisual"]:
		var marker := Node3D.new()
		marker.name = marker_name
		add_child(marker)
